// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import '../shared/util.dart';
import 'cff_parser.dart';
import 'encodings.dart';
import 'glyphlist.dart';


double _getFloat214(ByteData view, int offset) {
  return view.getInt16(offset) / 16384.0;
}

int _getSubroutineBias(List subrs) {
  final numSubrs = subrs.length;
  var bias = 32768;
  if (numSubrs < 1240) {
    bias = 107;
  } else if (numSubrs < 33900) {
    bias = 1131;
  }
  return bias;
}

class CmapRange {
  int start;
  int end;
  int idDelta;
  List<int>? ids;

  CmapRange({
    required this.start,
    required this.end,
    this.idDelta = 0,
    this.ids,
  });
}

List<CmapRange> _parseCmap(Uint8List data, int start, int end) {
  final view = ByteData.sublistView(data);
  final offset = view.getUint16(start + 2) == 1
      ? view.getUint32(start + 8)
      : view.getUint32(start + 16);
  final format = view.getUint16(start + offset);
  if (format == 4) {
    final segCount = view.getUint16(start + offset + 6) >> 1;
    var p = start + offset + 14;
    final ranges = List<CmapRange>.generate(
      segCount,
      (_) => CmapRange(start: 0, end: 0),
    );
    for (var i = 0; i < segCount; i++, p += 2) {
      ranges[i].end = view.getUint16(p);
    }
    p += 2;
    for (var i = 0; i < segCount; i++, p += 2) {
      ranges[i].start = view.getUint16(p);
    }
    for (var i = 0; i < segCount; i++, p += 2) {
      ranges[i].idDelta = view.getUint16(p);
    }
    for (var i = 0; i < segCount; i++, p += 2) {
      var idOffset = view.getUint16(p);
      if (idOffset == 0) {
        continue;
      }
      final count = ranges[i].end - ranges[i].start + 1;
      ranges[i].ids = List<int>.filled(count, 0);
      for (var j = 0; j < count; j++) {
        ranges[i].ids![j] = view.getUint16(p + idOffset);
        idOffset += 2;
      }
    }
    return ranges;
  } else if (format == 12) {
    final groups = view.getUint32(start + offset + 12);
    var p = start + offset + 16;
    final ranges = <CmapRange>[];
    for (var i = 0; i < groups; i++) {
      final rStart = view.getUint32(p);
      final rEnd = view.getUint32(p + 4);
      final rDelta = view.getUint32(p + 8) - rStart;
      ranges.add(CmapRange(start: rStart, end: rEnd, idDelta: rDelta));
      p += 12;
    }
    return ranges;
  }
  throw FormatError('unsupported cmap: $format');
}

class CffInfo {
  final List<dynamic> glyphs;
  final List<dynamic>? subrs;
  final List<dynamic>? gsubrs;
  final bool isCFFCIDFont;
  final dynamic fdSelect;
  final dynamic fdArray;

  CffInfo({
    required this.glyphs,
    this.subrs,
    this.gsubrs,
    this.isCFFCIDFont = false,
    this.fdSelect,
    this.fdArray,
  });
}

CffInfo _parseCff(
  Uint8List data,
  int start,
  int end,
  bool seacAnalysisEnabled,
) {
  final parser = CFFParser(
    data.sublist(start, end),
    {},
    seacAnalysisEnabled,
  );
  final dynamic cff = parser.parse();
  return CffInfo(
    glyphs: (cff?.charStrings?.objects as List?) ?? [],
    subrs: cff?.topDict?.privateDict?.subrsIndex?.objects as List?,
    gsubrs: cff?.globalSubrIndex?.objects as List?,
    isCFFCIDFont: (cff?.isCIDFont as bool?) ?? false,
    fdSelect: cff?.fdSelect,
    fdArray: cff?.fdArray,
  );
}

List<Uint8List> _parseGlyfTable(
  Uint8List glyf,
  Uint8List loca,
  bool isGlyphLocationsLong,
) {
  final view = ByteData.sublistView(loca);
  final itemSize = isGlyphLocationsLong ? 4 : 2;
  int itemDecode(ByteData dv, int offset) =>
      isGlyphLocationsLong ? dv.getUint32(offset) : 2 * dv.getUint16(offset);

  final glyphs = <Uint8List>[];
  var startOffset = itemDecode(view, 0);
  for (var j = itemSize; j < loca.length; j += itemSize) {
    final endOffset = itemDecode(view, j);
    glyphs.add(glyf.sublist(startOffset, endOffset));
    startOffset = endOffset;
  }
  return glyphs;
}

(int charCode, int glyphId) _lookupCmap(List<CmapRange> ranges, String unicode) {
  final code = unicode.runes.first;
  var gid = 0;
  var l = 0;
  var r = ranges.length - 1;
  while (l < r) {
    final c = (l + r + 1) >> 1;
    if (code < ranges[c].start) {
      r = c - 1;
    } else {
      l = c;
    }
  }
  if (ranges[l].start <= code && code <= ranges[l].end) {
    final delta = ranges[l].idDelta;
    final ids = ranges[l].ids;
    final idVal = ids != null ? ids[code - ranges[l].start] : code;
    gid = (delta + idVal) & 0xffff;
  }
  return (code, gid);
}

void _compileGlyf(
  Uint8List code,
  Commands cmds,
  TrueTypeCompiled font, [
  Set<Uint8List>? visitedGlyphs,
]) {
  visitedGlyphs ??= <Uint8List>{};
  if (visitedGlyphs.contains(code)) {
    warn('compileGlyf: skipping recursive composite glyph reference.');
    return;
  }
  visitedGlyphs.add(code);

  List<double>? firstPoint;

  void moveTo(double x, double y) {
    if (firstPoint != null) {
      cmds.add(DrawOPS.lineTo, firstPoint!);
    }
    firstPoint = [x, y];
    cmds.add(DrawOPS.moveTo, [x, y]);
  }

  void lineTo(double x, double y) {
    cmds.add(DrawOPS.lineTo, [x, y]);
  }

  void quadraticCurveTo(double xa, double ya, double x, double y) {
    cmds.add(DrawOPS.quadraticCurveTo, [xa, ya, x, y]);
  }

  final view = ByteData.sublistView(code);
  var i = 0;
  final numberOfContours = view.getInt16(i);
  int flags;
  var x = 0.0;
  var y = 0.0;
  i += 10;

  if (numberOfContours < 0) {
    // Composite glyph
    do {
      flags = view.getUint16(i);
      final glyphIndex = view.getUint16(i + 2);
      i += 4;
      num arg1, arg2;
      if ((flags & 0x01) != 0) {
        if ((flags & 0x02) != 0) {
          arg1 = view.getInt16(i);
          arg2 = view.getInt16(i + 2);
        } else {
          arg1 = view.getUint16(i);
          arg2 = view.getUint16(i + 2);
        }
        i += 4;
      } else if ((flags & 0x02) != 0) {
        arg1 = view.getInt8(i++);
        arg2 = view.getInt8(i++);
      } else {
        arg1 = code[i++];
        arg2 = code[i++];
      }
      if ((flags & 0x02) != 0) {
        x = arg1.toDouble();
        y = arg2.toDouble();
      } else {
        x = 0.0;
        y = 0.0;
      }
      var scaleX = 1.0;
      var scaleY = 1.0;
      var scale01 = 0.0;
      var scale10 = 0.0;
      if ((flags & 0x08) != 0) {
        scaleX = scaleY = _getFloat214(view, i);
        i += 2;
      } else if ((flags & 0x40) != 0) {
        scaleX = _getFloat214(view, i);
        scaleY = _getFloat214(view, i + 2);
        i += 4;
      } else if ((flags & 0x80) != 0) {
        scaleX = _getFloat214(view, i);
        scale01 = _getFloat214(view, i + 2);
        scale10 = _getFloat214(view, i + 4);
        scaleY = _getFloat214(view, i + 6);
        i += 8;
      }
      if (glyphIndex < font.glyphs.length) {
        final subglyph = font.glyphs[glyphIndex];
        if (subglyph.isNotEmpty) {
          cmds.save();
          cmds.transform([scaleX, scale01, scale10, scaleY, x, y]);
          _compileGlyf(subglyph, cmds, font, visitedGlyphs);
          cmds.restore();
        }
      }
    } while ((flags & 0x20) != 0);
  } else {
    // Simple glyph
    final endPtsOfContours = <int>[];
    for (var j = 0; j < numberOfContours; j++) {
      endPtsOfContours.add(view.getUint16(i));
      i += 2;
    }
    final instructionLength = view.getUint16(i);
    i += 2 + instructionLength; // Skip instructions
    final numberOfPoints = endPtsOfContours.last + 1;
    final points = <_GlyphPoint>[];
    while (points.length < numberOfPoints) {
      flags = code[i++];
      var repeat = 1;
      if ((flags & 0x08) != 0) {
        repeat += code[i++];
      }
      while (repeat-- > 0) {
        points.add(_GlyphPoint(flags: flags));
      }
    }
    for (var j = 0; j < numberOfPoints; j++) {
      switch (points[j].flags & 0x12) {
        case 0x00:
          x += view.getInt16(i);
          i += 2;
          break;
        case 0x02:
          x -= code[i++];
          break;
        case 0x12:
          x += code[i++];
          break;
      }
      points[j].x = x;
    }
    for (var j = 0; j < numberOfPoints; j++) {
      switch (points[j].flags & 0x24) {
        case 0x00:
          y += view.getInt16(i);
          i += 2;
          break;
        case 0x04:
          y -= code[i++];
          break;
        case 0x24:
          y += code[i++];
          break;
      }
      points[j].y = y;
    }

    var startPoint = 0;
    for (var c = 0; c < numberOfContours; c++) {
      final endPoint = endPtsOfContours[c];
      final contour = points.sublist(startPoint, endPoint + 1);
      if ((contour[0].flags & 1) != 0) {
        contour.add(contour[0]);
      } else if ((contour.last.flags & 1) != 0) {
        contour.insert(0, contour.last);
      } else {
        final p = _GlyphPoint(
          flags: 1,
          x: (contour[0].x + contour.last.x) / 2.0,
          y: (contour[0].y + contour.last.y) / 2.0,
        );
        contour.insert(0, p);
        contour.add(p);
      }
      moveTo(contour[0].x, contour[0].y);
      for (var j = 1, jj = contour.length; j < jj; j++) {
        if ((contour[j].flags & 1) != 0) {
          lineTo(contour[j].x, contour[j].y);
        } else if (j + 1 < jj && (contour[j + 1].flags & 1) != 0) {
          quadraticCurveTo(
            contour[j].x,
            contour[j].y,
            contour[j + 1].x,
            contour[j + 1].y,
          );
          j++;
        } else {
          quadraticCurveTo(
            contour[j].x,
            contour[j].y,
            (contour[j].x + contour[j + 1].x) / 2.0,
            (contour[j].y + contour[j + 1].y) / 2.0,
          );
        }
      }
      startPoint = endPoint + 1;
    }
  }
  visitedGlyphs.remove(code);
}

class _GlyphPoint {
  int flags;
  double x;
  double y;

  _GlyphPoint({required this.flags, this.x = 0.0, this.y = 0.0});
}

void _compileCharString(
  Uint8List charStringCode,
  Commands cmds,
  Type2Compiled font,
  int glyphId,
) {
  List<double>? firstPoint;

  void moveTo(double x, double y) {
    if (firstPoint != null) {
      cmds.add(DrawOPS.lineTo, firstPoint!);
    }
    firstPoint = [x, y];
    cmds.add(DrawOPS.moveTo, [x, y]);
  }

  void lineTo(double x, double y) {
    cmds.add(DrawOPS.lineTo, [x, y]);
  }

  void bezierCurveTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x,
    double y,
  ) {
    cmds.add(DrawOPS.curveTo, [x1, y1, x2, y2, x, y]);
  }

  final stack = <double>[];
  var x = 0.0;
  var y = 0.0;
  var stems = 0;

  void parse(Uint8List code) {
    final view = ByteData.sublistView(code);
    var i = 0;
    while (i < code.length) {
      var stackClean = false;
      var v = code[i++];
      double xa, xb, ya, yb, y1, y2, y3;
      int n;
      Uint8List? subrCode;

      switch (v) {
        case 1: // hstem
          stems += stack.length >> 1;
          stackClean = true;
          break;
        case 3: // vstem
          stems += stack.length >> 1;
          stackClean = true;
          break;
        case 4: // vmoveto
          y += stack.removeLast();
          moveTo(x, y);
          stackClean = true;
          break;
        case 5: // rlineto
          while (stack.isNotEmpty) {
            x += stack.removeAt(0);
            y += stack.removeAt(0);
            lineTo(x, y);
          }
          break;
        case 6: // hlineto
          while (stack.isNotEmpty) {
            x += stack.removeAt(0);
            lineTo(x, y);
            if (stack.isEmpty) break;
            y += stack.removeAt(0);
            lineTo(x, y);
          }
          break;
        case 7: // vlineto
          while (stack.isNotEmpty) {
            y += stack.removeAt(0);
            lineTo(x, y);
            if (stack.isEmpty) break;
            x += stack.removeAt(0);
            lineTo(x, y);
          }
          break;
        case 8: // rrcurveto
          while (stack.isNotEmpty) {
            xa = x + stack.removeAt(0);
            ya = y + stack.removeAt(0);
            xb = xa + stack.removeAt(0);
            yb = ya + stack.removeAt(0);
            x = xb + stack.removeAt(0);
            y = yb + stack.removeAt(0);
            bezierCurveTo(xa, ya, xb, yb, x, y);
          }
          break;
        case 10: // callsubr
          n = stack.removeLast().toInt();
          subrCode = null;
          if (font.isCFFCIDFont) {
            final fdIndex = font.fdSelect?.getFDIndex(glyphId) ?? -1;
            if (fdIndex >= 0 && fdIndex < (font.fdArray?.length ?? 0)) {
              final fontDict = font.fdArray[fdIndex];
              List? subrs;
              if (fontDict.privateDict?.subrsIndex != null) {
                subrs = fontDict.privateDict.subrsIndex.objects;
              }
              if (subrs != null) {
                n += _getSubroutineBias(subrs);
                if (n >= 0 && n < subrs.length) {
                  subrCode = subrs[n] as Uint8List?;
                }
              }
            } else {
              warn('Invalid fd index for glyph index.');
            }
          } else if (font.subrs != null) {
            final idx = n + font.subrsBias;
            if (idx >= 0 && idx < font.subrs!.length) {
              subrCode = font.subrs![idx] as Uint8List?;
            }
          }
          if (subrCode != null) {
            parse(subrCode);
          }
          break;
        case 11: // return
          return;
        case 12:
          v = code[i++];
          switch (v) {
            case 34: // flex
              xa = x + stack.removeAt(0);
              xb = xa + stack.removeAt(0);
              y1 = y + stack.removeAt(0);
              x = xb + stack.removeAt(0);
              bezierCurveTo(xa, y, xb, y1, x, y1);
              xa = x + stack.removeAt(0);
              xb = xa + stack.removeAt(0);
              x = xb + stack.removeAt(0);
              bezierCurveTo(xa, y1, xb, y, x, y);
              break;
            case 35: // flex
              xa = x + stack.removeAt(0);
              ya = y + stack.removeAt(0);
              xb = xa + stack.removeAt(0);
              yb = ya + stack.removeAt(0);
              x = xb + stack.removeAt(0);
              y = yb + stack.removeAt(0);
              bezierCurveTo(xa, ya, xb, yb, x, y);
              xa = x + stack.removeAt(0);
              ya = y + stack.removeAt(0);
              xb = xa + stack.removeAt(0);
              yb = ya + stack.removeAt(0);
              x = xb + stack.removeAt(0);
              y = yb + stack.removeAt(0);
              bezierCurveTo(xa, ya, xb, yb, x, y);
              stack.removeLast(); // fd
              break;
            case 36: // hflex1
              xa = x + stack.removeAt(0);
              y1 = y + stack.removeAt(0);
              xb = xa + stack.removeAt(0);
              y2 = y1 + stack.removeAt(0);
              x = xb + stack.removeAt(0);
              bezierCurveTo(xa, y1, xb, y2, x, y2);
              xa = x + stack.removeAt(0);
              xb = xa + stack.removeAt(0);
              y3 = y2 + stack.removeAt(0);
              x = xb + stack.removeAt(0);
              bezierCurveTo(xa, y2, xb, y3, x, y);
              break;
            case 37: // flex1
              final x0 = x;
              final y0 = y;
              xa = x + stack.removeAt(0);
              ya = y + stack.removeAt(0);
              xb = xa + stack.removeAt(0);
              yb = ya + stack.removeAt(0);
              x = xb + stack.removeAt(0);
              y = yb + stack.removeAt(0);
              bezierCurveTo(xa, ya, xb, yb, x, y);
              xa = x + stack.removeAt(0);
              ya = y + stack.removeAt(0);
              xb = xa + stack.removeAt(0);
              yb = ya + stack.removeAt(0);
              x = xb;
              y = yb;
              if ((x - x0).abs() > (y - y0).abs()) {
                x += stack.removeAt(0);
              } else {
                y += stack.removeAt(0);
              }
              bezierCurveTo(xa, ya, xb, yb, x, y);
              break;
            default:
              throw FormatError('unknown operator: 12 $v');
          }
          break;
        case 14: // endchar
          if (stack.length >= 4) {
            final achar = stack.removeLast().toInt();
            final bchar = stack.removeLast().toInt();
            y = stack.removeLast();
            x = stack.removeLast();
            cmds.save();
            cmds.translate(x, y);
            final acharName = standardEncoding[achar];
            final acharGlyph = font.glyphNameMap[acharName];
            if (acharGlyph != null) {
              final cmap = _lookupCmap(font.cmap, String.fromCharCode(acharGlyph));
              if (cmap.$2 < font.glyphs.length) {
                _compileCharString(
                  font.glyphs[cmap.$2] as Uint8List,
                  cmds,
                  font,
                  cmap.$2,
                );
              }
            }
            cmds.restore();

            final bcharName = standardEncoding[bchar];
            final bcharGlyph = font.glyphNameMap[bcharName];
            if (bcharGlyph != null) {
              final cmap = _lookupCmap(font.cmap, String.fromCharCode(bcharGlyph));
              if (cmap.$2 < font.glyphs.length) {
                _compileCharString(
                  font.glyphs[cmap.$2] as Uint8List,
                  cmds,
                  font,
                  cmap.$2,
                );
              }
            }
          }
          return;
        case 18: // hstemhm
          stems += stack.length >> 1;
          stackClean = true;
          break;
        case 19: // hintmask
        case 20: // cntrmask
          stems += stack.length >> 1;
          i += (stems + 7) >> 3;
          stackClean = true;
          break;
        case 21: // rmoveto
          y += stack.removeLast();
          x += stack.removeLast();
          moveTo(x, y);
          stackClean = true;
          break;
        case 22: // hmoveto
          x += stack.removeLast();
          moveTo(x, y);
          stackClean = true;
          break;
        case 23: // vstemhm
          stems += stack.length >> 1;
          stackClean = true;
          break;
        case 24: // rcurveline
          while (stack.length > 2) {
            xa = x + stack.removeAt(0);
            ya = y + stack.removeAt(0);
            xb = xa + stack.removeAt(0);
            yb = ya + stack.removeAt(0);
            x = xb + stack.removeAt(0);
            y = yb + stack.removeAt(0);
            bezierCurveTo(xa, ya, xb, yb, x, y);
          }
          x += stack.removeAt(0);
          y += stack.removeAt(0);
          lineTo(x, y);
          break;
        case 25: // rlinecurve
          while (stack.length > 6) {
            x += stack.removeAt(0);
            y += stack.removeAt(0);
            lineTo(x, y);
          }
          xa = x + stack.removeAt(0);
          ya = y + stack.removeAt(0);
          xb = xa + stack.removeAt(0);
          yb = ya + stack.removeAt(0);
          x = xb + stack.removeAt(0);
          y = yb + stack.removeAt(0);
          bezierCurveTo(xa, ya, xb, yb, x, y);
          break;
        case 26: // vvcurveto
          if (stack.length % 2 != 0) {
            x += stack.removeAt(0);
          }
          while (stack.isNotEmpty) {
            xa = x;
            ya = y + stack.removeAt(0);
            xb = xa + stack.removeAt(0);
            yb = ya + stack.removeAt(0);
            x = xb;
            y = yb + stack.removeAt(0);
            bezierCurveTo(xa, ya, xb, yb, x, y);
          }
          break;
        case 27: // hhcurveto
          if (stack.length % 2 != 0) {
            y += stack.removeAt(0);
          }
          while (stack.isNotEmpty) {
            xa = x + stack.removeAt(0);
            ya = y;
            xb = xa + stack.removeAt(0);
            yb = ya + stack.removeAt(0);
            x = xb + stack.removeAt(0);
            y = yb;
            bezierCurveTo(xa, ya, xb, yb, x, y);
          }
          break;
        case 28:
          stack.add(view.getInt16(i).toDouble());
          i += 2;
          break;
        case 29: // callgsubr
          n = stack.removeLast().toInt() + font.gsubrsBias;
          if (font.gsubrs != null && n >= 0 && n < font.gsubrs!.length) {
            subrCode = font.gsubrs![n] as Uint8List?;
            if (subrCode != null) {
              parse(subrCode);
            }
          }
          break;
        case 30: // vhcurveto
          while (stack.isNotEmpty) {
            xa = x;
            ya = y + stack.removeAt(0);
            xb = xa + stack.removeAt(0);
            yb = ya + stack.removeAt(0);
            x = xb + stack.removeAt(0);
            y = yb + (stack.length == 1 ? stack.removeAt(0) : 0);
            bezierCurveTo(xa, ya, xb, yb, x, y);
            if (stack.isEmpty) break;

            xa = x + stack.removeAt(0);
            ya = y;
            xb = xa + stack.removeAt(0);
            yb = ya + stack.removeAt(0);
            y = yb + stack.removeAt(0);
            x = xb + (stack.length == 1 ? stack.removeAt(0) : 0);
            bezierCurveTo(xa, ya, xb, yb, x, y);
          }
          break;
        case 31: // hvcurveto
          while (stack.isNotEmpty) {
            xa = x + stack.removeAt(0);
            ya = y;
            xb = xa + stack.removeAt(0);
            yb = ya + stack.removeAt(0);
            y = yb + stack.removeAt(0);
            x = xb + (stack.length == 1 ? stack.removeAt(0) : 0);
            bezierCurveTo(xa, ya, xb, yb, x, y);
            if (stack.isEmpty) break;

            xa = x;
            ya = y + stack.removeAt(0);
            xb = xa + stack.removeAt(0);
            yb = ya + stack.removeAt(0);
            x = xb + stack.removeAt(0);
            y = yb + (stack.length == 1 ? stack.removeAt(0) : 0);
            bezierCurveTo(xa, ya, xb, yb, x, y);
          }
          break;
        default:
          if (v < 32) {
            throw FormatError('unknown operator: $v');
          }
          if (v < 247) {
            stack.add((v - 139).toDouble());
          } else if (v < 251) {
            stack.add(((v - 247) * 256 + code[i++] + 108).toDouble());
          } else if (v < 255) {
            stack.add((-(v - 251) * 256 - code[i++] - 108).toDouble());
          } else {
            stack.add(view.getInt32(i) / 65536.0);
            i += 4;
          }
          break;
      }
      if (stackClean) {
        stack.clear();
      }
    }
  }

  parse(charStringCode);
}

class Commands {
  final List<double> cmds = [];
  final List<List<double>> transformStack = [];
  List<double> currentTransform = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];

  void add(int cmd, [List<double>? args]) {
    if (args != null) {
      for (var i = 0, ii = args.length; i < ii; i += 2) {
        Util.applyTransform(args, currentTransform, i);
      }
      cmds.add(cmd.toDouble());
      cmds.addAll(args);
    } else {
      cmds.add(cmd.toDouble());
    }
  }

  void transform(List<num> transf) {
    currentTransform = Util.transform(currentTransform, transf);
  }

  void translate(double x, double y) {
    transform([1.0, 0.0, 0.0, 1.0, x, y]);
  }

  void save() {
    transformStack.add(List<double>.from(currentTransform));
  }

  void restore() {
    currentTransform = transformStack.isNotEmpty
        ? transformStack.removeLast()
        : [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];
  }

  Float32List getPath() {
    return Float32List.fromList(cmds);
  }
}

abstract class CompiledFont {
  final List<num> fontMatrix;
  final Map<int, Float32List> compiledGlyphs = {};
  final Map<int, int> compiledCharCodeToGlyphId = {};

  CompiledFont(this.fontMatrix);

  static final Float32List noop = Float32List(0);

  List<CmapRange> get cmap;
  List<dynamic> get glyphs;

  Float32List getPathJs(String unicode) {
    final pair = _lookupCmap(cmap, unicode);
    final charCode = pair.$1;
    final glyphId = pair.$2;

    var fn = compiledGlyphs[glyphId];
    Object? compileEx;
    if (fn == null) {
      try {
        if (glyphId < glyphs.length) {
          fn = compileGlyph(glyphs[glyphId], glyphId);
        } else {
          fn = CompiledFont.noop;
        }
      } catch (ex) {
        fn = CompiledFont.noop;
        compileEx = ex;
      }
      compiledGlyphs[glyphId] = fn;
    }
    compiledCharCodeToGlyphId.putIfAbsent(charCode, () => glyphId);

    if (compileEx != null) {
      throw compileEx;
    }
    return fn;
  }

  Float32List compileGlyph(dynamic code, int glyphId) {
    if (code == null) return CompiledFont.noop;
    if (code is Uint8List && (code.isEmpty || code[0] == 14)) {
      return CompiledFont.noop;
    }

    var fm = fontMatrix;
    final cmds = Commands();
    cmds.transform(fm);
    compileGlyphImpl(code, cmds, glyphId);
    cmds.add(DrawOPS.closePath);

    return cmds.getPath();
  }

  void compileGlyphImpl(dynamic code, Commands cmds, int glyphId);

  bool hasBuiltPath(String unicode) {
    final pair = _lookupCmap(cmap, unicode);
    return compiledGlyphs.containsKey(pair.$2) &&
        compiledCharCodeToGlyphId.containsKey(pair.$1);
  }
}

class TrueTypeCompiled extends CompiledFont {
  @override
  final List<Uint8List> glyphs;
  @override
  final List<CmapRange> cmap;

  TrueTypeCompiled(
    this.glyphs,
    this.cmap, [
    List<num>? fontMatrix,
  ]) : super(fontMatrix ?? [0.000488, 0, 0, 0.000488, 0, 0]);

  @override
  void compileGlyphImpl(dynamic code, Commands cmds, int glyphId) {
    if (code is Uint8List) {
      _compileGlyf(code, cmds, this);
    }
  }
}

class Type2Compiled extends CompiledFont {
  @override
  final List<dynamic> glyphs;
  @override
  final List<CmapRange> cmap;
  final List<dynamic>? gsubrs;
  final List<dynamic>? subrs;
  final Map<String, int> glyphNameMap;
  final int gsubrsBias;
  final int subrsBias;
  final bool isCFFCIDFont;
  final dynamic fdSelect;
  final dynamic fdArray;

  Type2Compiled(
    CffInfo cffInfo,
    this.cmap, [
    List<num>? fontMatrix,
  ])  : glyphs = cffInfo.glyphs,
        gsubrs = cffInfo.gsubrs ?? [],
        subrs = cffInfo.subrs ?? [],
        glyphNameMap = getGlyphsUnicode(),
        gsubrsBias = _getSubroutineBias(cffInfo.gsubrs ?? []),
        subrsBias = _getSubroutineBias(cffInfo.subrs ?? []),
        isCFFCIDFont = cffInfo.isCFFCIDFont,
        fdSelect = cffInfo.fdSelect,
        fdArray = cffInfo.fdArray,
        super(fontMatrix ?? [0.001, 0, 0, 0.001, 0, 0]);

  @override
  void compileGlyphImpl(dynamic code, Commands cmds, int glyphId) {
    if (code is Uint8List) {
      _compileCharString(code, cmds, this, glyphId);
    }
  }
}

class FontRendererFactory {
  static CompiledFont create(dynamic font, bool seacAnalysisEnabled) {
    final data = font.data is Uint8List
        ? font.data as Uint8List
        : Uint8List.fromList((font.data as List).cast<int>());
    final view = ByteData.sublistView(data);

    List<CmapRange>? cmap;
    Uint8List? glyf;
    Uint8List? loca;
    CffInfo? cff;
    int? indexToLocFormat;
    int? unitsPerEm;

    final numTables = view.getUint16(4);
    for (var i = 0, p = 12; i < numTables; i++, p += 16) {
      final tag = bytesToString(data.sublist(p, p + 4));
      final offset = view.getUint32(p + 8);
      final length = view.getUint32(p + 12);
      switch (tag) {
        case 'cmap':
          cmap = _parseCmap(data, offset, offset + length);
          break;
        case 'glyf':
          glyf = data.sublist(offset, offset + length);
          break;
        case 'loca':
          loca = data.sublist(offset, offset + length);
          break;
        case 'head':
          unitsPerEm = view.getUint16(offset + 18);
          indexToLocFormat = view.getUint16(offset + 50);
          break;
        case 'CFF ':
          cff = _parseCff(data, offset, offset + length, seacAnalysisEnabled);
          break;
      }
    }

    if (glyf != null && loca != null && cmap != null) {
      final isLocationsLong = (indexToLocFormat ?? 0) != 0;
      final fontMatrix = unitsPerEm == null || unitsPerEm == 0
          ? (font.fontMatrix as List<num>? ?? fontIdentityMatrix)
          : [1.0 / unitsPerEm, 0.0, 0.0, 1.0 / unitsPerEm, 0.0, 0.0];
      return TrueTypeCompiled(
        _parseGlyfTable(glyf, loca, isLocationsLong),
        cmap,
        fontMatrix,
      );
    }
    if (cff != null && cmap != null) {
      return Type2Compiled(cff, cmap, font.fontMatrix as List<num>?);
    }
    throw FormatError('Unable to instantiate font renderer: missing tables');
  }
}
