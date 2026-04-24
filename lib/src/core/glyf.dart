// Copyright 2021 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

const int onCurvePoint = 1 << 0;
const int xShortVector = 1 << 1;
const int yShortVector = 1 << 2;
const int repeatFlag = 1 << 3;
const int xIsSameOrPositiveXShortVector = 1 << 4;
const int yIsSameOrPositiveYShortVector = 1 << 5;
const int overlapSimple = 1 << 6;

const int arg1And2AreWords = 1 << 0;
const int argsAreXyValues = 1 << 1;
const int weHaveAScale = 1 << 3;
const int moreComponents = 1 << 5;
const int weHaveAnXAndYScale = 1 << 6;
const int weHaveATwoByTwo = 1 << 7;
const int weHaveInstructions = 1 << 8;

class GlyfWriteResult {
  const GlyfWriteResult({
    required this.isLocationLong,
    required this.loca,
    required this.glyf,
  });

  final bool isLocationLong;
  final Uint8List loca;
  final Uint8List glyf;
}

class GlyfTable {
  GlyfTable({
    required Uint8List glyfTable,
    required bool isGlyphLocationsLong,
    required Uint8List locaTable,
    required int numGlyphs,
  }) {
    final loca = ByteData.view(
      locaTable.buffer,
      locaTable.offsetInBytes,
      locaTable.lengthInBytes,
    );
    final glyf = ByteData.view(
      glyfTable.buffer,
      glyfTable.offsetInBytes,
      glyfTable.lengthInBytes,
    );
    final offsetSize = isGlyphLocationsLong ? 4 : 2;
    var prev = isGlyphLocationsLong ? loca.getUint32(0) : 2 * loca.getUint16(0);
    var pos = 0;
    for (var i = 0; i < numGlyphs; i++) {
      pos += offsetSize;
      final next =
          isGlyphLocationsLong ? loca.getUint32(pos) : 2 * loca.getUint16(pos);
      if (next == prev) {
        glyphs.add(Glyph());
        continue;
      }

      glyphs.add(Glyph.parse(prev, glyf));
      prev = next;
    }
  }

  final List<Glyph> glyphs = [];

  int getSize() {
    var size = 0;
    for (final glyph in glyphs) {
      size += (glyph.getSize() + 3) & ~3;
    }
    return size;
  }

  GlyfWriteResult write() {
    final totalSize = getSize();
    final glyfBytes = Uint8List(totalSize);
    final glyfTable = ByteData.view(glyfBytes.buffer);
    final isLocationLong = totalSize > 0x1fffe;
    final offsetSize = isLocationLong ? 4 : 2;
    final locaBytes = Uint8List((glyphs.length + 1) * offsetSize);
    final locaTable = ByteData.view(locaBytes.buffer);

    if (isLocationLong) {
      locaTable.setUint32(0, 0);
    } else {
      locaTable.setUint16(0, 0);
    }

    var pos = 0;
    var locaIndex = 0;
    for (final glyph in glyphs) {
      pos += glyph.write(pos, glyfTable);
      pos = (pos + 3) & ~3;

      locaIndex += offsetSize;
      if (isLocationLong) {
        locaTable.setUint32(locaIndex, pos);
      } else {
        locaTable.setUint16(locaIndex, pos >> 1);
      }
    }

    return GlyfWriteResult(
      isLocationLong: isLocationLong,
      loca: locaBytes,
      glyf: glyfBytes,
    );
  }

  void scale(List<double> factors) {
    for (var i = 0; i < glyphs.length; i++) {
      glyphs[i].scale(factors[i]);
    }
  }
}

class Glyph {
  Glyph({
    this.header,
    this.simple,
    this.composites,
  });

  final GlyphHeader? header;
  final SimpleGlyph? simple;
  final List<CompositeGlyph>? composites;

  static Glyph parse(int pos, ByteData glyf) {
    final parsedHeader = GlyphHeader.parse(pos, glyf);
    pos += parsedHeader.read;
    final header = parsedHeader.header;

    if (header.numberOfContours < 0) {
      final composites = <CompositeGlyph>[];
      while (true) {
        final parsedComposite = CompositeGlyph.parse(pos, glyf);
        pos += parsedComposite.read;
        composites.add(parsedComposite.composite);
        if ((parsedComposite.composite.flags & moreComponents) == 0) {
          break;
        }
      }
      return Glyph(header: header, composites: composites);
    }

    return Glyph(
      header: header,
      simple: SimpleGlyph.parse(pos, glyf, header.numberOfContours),
    );
  }

  int getSize() {
    final glyphHeader = header;
    if (glyphHeader == null) {
      return 0;
    }
    final simpleGlyph = simple;
    final size = simpleGlyph != null
        ? simpleGlyph.getSize()
        : composites!
            .fold<int>(0, (sum, composite) => sum + composite.getSize());
    return glyphHeader.getSize() + size;
  }

  int write(int pos, ByteData buf) {
    final glyphHeader = header;
    if (glyphHeader == null) {
      return 0;
    }

    final start = pos;
    pos += glyphHeader.write(pos, buf);
    final simpleGlyph = simple;
    if (simpleGlyph != null) {
      pos += simpleGlyph.write(pos, buf);
    } else {
      for (final composite in composites!) {
        pos += composite.write(pos, buf);
      }
    }
    return pos - start;
  }

  void scale(double factor) {
    final glyphHeader = header;
    if (glyphHeader == null) {
      return;
    }

    final xMiddle = (glyphHeader.xMin + glyphHeader.xMax) / 2;
    glyphHeader.scale(xMiddle, factor);
    final simpleGlyph = simple;
    if (simpleGlyph != null) {
      simpleGlyph.scale(xMiddle, factor);
    } else {
      for (final composite in composites!) {
        composite.scale(xMiddle, factor);
      }
    }
  }
}

class ParsedGlyphHeader {
  const ParsedGlyphHeader(this.read, this.header);

  final int read;
  final GlyphHeader header;
}

class GlyphHeader {
  GlyphHeader({
    required this.numberOfContours,
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
  });

  int numberOfContours;
  int xMin;
  int yMin;
  int xMax;
  int yMax;

  static ParsedGlyphHeader parse(int pos, ByteData glyf) {
    return ParsedGlyphHeader(
      10,
      GlyphHeader(
        numberOfContours: glyf.getInt16(pos),
        xMin: glyf.getInt16(pos + 2),
        yMin: glyf.getInt16(pos + 4),
        xMax: glyf.getInt16(pos + 6),
        yMax: glyf.getInt16(pos + 8),
      ),
    );
  }

  int getSize() => 10;

  int write(int pos, ByteData buf) {
    buf.setInt16(pos, numberOfContours);
    buf.setInt16(pos + 2, xMin);
    buf.setInt16(pos + 4, yMin);
    buf.setInt16(pos + 6, xMax);
    buf.setInt16(pos + 8, yMax);
    return 10;
  }

  void scale(double x, double factor) {
    xMin = (x + (xMin - x) * factor).round();
    xMax = (x + (xMax - x) * factor).round();
  }
}

class Contour {
  Contour({
    required this.flags,
    required this.xCoordinates,
    required this.yCoordinates,
  });

  final List<int> flags;
  final List<int> xCoordinates;
  final List<int> yCoordinates;
}

class SimpleGlyph {
  SimpleGlyph({
    required this.contours,
    required this.instructions,
  });

  final List<Contour> contours;
  final Uint8List instructions;

  static SimpleGlyph parse(int pos, ByteData glyf, int numberOfContours) {
    final endPtsOfContours = <int>[];
    for (var i = 0; i < numberOfContours; i++) {
      endPtsOfContours.add(glyf.getUint16(pos));
      pos += 2;
    }

    final numberOfPt = endPtsOfContours[numberOfContours - 1] + 1;
    final instructionLength = glyf.getUint16(pos);
    pos += 2;
    final instructions = _slice(glyf, pos, instructionLength);
    pos += instructionLength;

    final flags = <int>[];
    for (var i = 0; i < numberOfPt; pos++, i++) {
      var flag = glyf.getUint8(pos);
      flags.add(flag);
      if ((flag & repeatFlag) != 0) {
        final count = glyf.getUint8(++pos);
        flag ^= repeatFlag;
        for (var m = 0; m < count; m++) {
          flags.add(flag);
        }
        i += count;
      }
    }

    final allXCoordinates = <List<int>>[];
    var xCoordinates = <int>[];
    var yCoordinates = <int>[];
    var pointFlags = <int>[];
    final contours = <Contour>[];
    var endPtsOfContoursIndex = 0;
    var lastCoordinate = 0;

    for (var i = 0; i < numberOfPt; i++) {
      final flag = flags[i];
      if ((flag & xShortVector) != 0) {
        final x = glyf.getUint8(pos++);
        lastCoordinate += (flag & xIsSameOrPositiveXShortVector) != 0 ? x : -x;
      } else if ((flag & xIsSameOrPositiveXShortVector) == 0) {
        lastCoordinate += glyf.getInt16(pos);
        pos += 2;
      }
      xCoordinates.add(lastCoordinate);

      if (endPtsOfContours[endPtsOfContoursIndex] == i) {
        endPtsOfContoursIndex++;
        allXCoordinates.add(xCoordinates);
        xCoordinates = <int>[];
      }
    }

    lastCoordinate = 0;
    endPtsOfContoursIndex = 0;
    for (var i = 0; i < numberOfPt; i++) {
      final flag = flags[i];
      if ((flag & yShortVector) != 0) {
        final y = glyf.getUint8(pos++);
        lastCoordinate += (flag & yIsSameOrPositiveYShortVector) != 0 ? y : -y;
      } else if ((flag & yIsSameOrPositiveYShortVector) == 0) {
        lastCoordinate += glyf.getInt16(pos);
        pos += 2;
      }
      yCoordinates.add(lastCoordinate);
      pointFlags.add((flag & onCurvePoint) | (flag & overlapSimple));

      if (endPtsOfContours[endPtsOfContoursIndex] == i) {
        xCoordinates = allXCoordinates[endPtsOfContoursIndex];
        endPtsOfContoursIndex++;
        contours.add(
          Contour(
            flags: pointFlags,
            xCoordinates: xCoordinates,
            yCoordinates: yCoordinates,
          ),
        );
        yCoordinates = <int>[];
        pointFlags = <int>[];
      }
    }

    return SimpleGlyph(contours: contours, instructions: instructions);
  }

  int getSize() {
    var size = contours.length * 2 + 2 + instructions.length;
    var lastX = 0;
    var lastY = 0;
    for (final contour in contours) {
      size += contour.flags.length;
      for (var i = 0; i < contour.xCoordinates.length; i++) {
        final x = contour.xCoordinates[i];
        final y = contour.yCoordinates[i];
        var abs = (x - lastX).abs();
        if (abs > 255) {
          size += 2;
        } else if (abs > 0) {
          size += 1;
        }
        lastX = x;

        abs = (y - lastY).abs();
        if (abs > 255) {
          size += 2;
        } else if (abs > 0) {
          size += 1;
        }
        lastY = y;
      }
    }
    return size;
  }

  int write(int pos, ByteData buf) {
    final start = pos;
    final xCoordinates = <int>[];
    final yCoordinates = <int>[];
    final flags = <int>[];
    var lastX = 0;
    var lastY = 0;

    for (final contour in contours) {
      for (var i = 0; i < contour.xCoordinates.length; i++) {
        var flag = contour.flags[i];
        final x = contour.xCoordinates[i];
        var delta = x - lastX;
        if (delta == 0) {
          flag |= xIsSameOrPositiveXShortVector;
          xCoordinates.add(0);
        } else {
          final abs = delta.abs();
          if (abs <= 255) {
            flag |= delta >= 0
                ? xShortVector | xIsSameOrPositiveXShortVector
                : xShortVector;
            xCoordinates.add(abs);
          } else {
            xCoordinates.add(delta);
          }
        }
        lastX = x;

        final y = contour.yCoordinates[i];
        delta = y - lastY;
        if (delta == 0) {
          flag |= yIsSameOrPositiveYShortVector;
          yCoordinates.add(0);
        } else {
          final abs = delta.abs();
          if (abs <= 255) {
            flag |= delta >= 0
                ? yShortVector | yIsSameOrPositiveYShortVector
                : yShortVector;
            yCoordinates.add(abs);
          } else {
            yCoordinates.add(delta);
          }
        }
        lastY = y;
        flags.add(flag);
      }

      buf.setUint16(pos, xCoordinates.length - 1);
      pos += 2;
    }

    buf.setUint16(pos, instructions.length);
    pos += 2;
    if (instructions.isNotEmpty) {
      _writeBytes(buf, pos, instructions);
      pos += instructions.length;
    }

    for (final flag in flags) {
      buf.setUint8(pos++, flag);
    }

    for (var i = 0; i < xCoordinates.length; i++) {
      final x = xCoordinates[i];
      final flag = flags[i];
      if ((flag & xShortVector) != 0) {
        buf.setUint8(pos++, x);
      } else if ((flag & xIsSameOrPositiveXShortVector) == 0) {
        buf.setInt16(pos, x);
        pos += 2;
      }
    }

    for (var i = 0; i < yCoordinates.length; i++) {
      final y = yCoordinates[i];
      final flag = flags[i];
      if ((flag & yShortVector) != 0) {
        buf.setUint8(pos++, y);
      } else if ((flag & yIsSameOrPositiveYShortVector) == 0) {
        buf.setInt16(pos, y);
        pos += 2;
      }
    }

    return pos - start;
  }

  void scale(double x, double factor) {
    for (final contour in contours) {
      if (contour.xCoordinates.isEmpty) {
        continue;
      }
      for (var i = 0; i < contour.xCoordinates.length; i++) {
        contour.xCoordinates[i] =
            (x + (contour.xCoordinates[i] - x) * factor).round();
      }
    }
  }
}

class ParsedCompositeGlyph {
  const ParsedCompositeGlyph(this.read, this.composite);

  final int read;
  final CompositeGlyph composite;
}

class CompositeGlyph {
  CompositeGlyph({
    required this.flags,
    required this.glyphIndex,
    required this.argument1,
    required this.argument2,
    required this.transf,
    this.instructions,
  });

  int flags;
  final int glyphIndex;
  final int argument1;
  final int argument2;
  final List<int> transf;
  final Uint8List? instructions;

  static ParsedCompositeGlyph parse(int pos, ByteData glyf) {
    final start = pos;
    final transf = <int>[];
    var flags = glyf.getUint16(pos);
    final glyphIndex = glyf.getUint16(pos + 2);
    pos += 4;

    late final int argument1;
    late final int argument2;
    if ((flags & arg1And2AreWords) != 0) {
      if ((flags & argsAreXyValues) != 0) {
        argument1 = glyf.getInt16(pos);
        argument2 = glyf.getInt16(pos + 2);
      } else {
        argument1 = glyf.getUint16(pos);
        argument2 = glyf.getUint16(pos + 2);
      }
      pos += 4;
      flags ^= arg1And2AreWords;
    } else {
      if ((flags & argsAreXyValues) != 0) {
        argument1 = glyf.getInt8(pos);
        argument2 = glyf.getInt8(pos + 1);
      } else {
        argument1 = glyf.getUint8(pos);
        argument2 = glyf.getUint8(pos + 1);
      }
      pos += 2;
    }

    if ((flags & weHaveAScale) != 0) {
      transf.add(glyf.getUint16(pos));
      pos += 2;
    } else if ((flags & weHaveAnXAndYScale) != 0) {
      transf.addAll([glyf.getUint16(pos), glyf.getUint16(pos + 2)]);
      pos += 4;
    } else if ((flags & weHaveATwoByTwo) != 0) {
      transf.addAll([
        glyf.getUint16(pos),
        glyf.getUint16(pos + 2),
        glyf.getUint16(pos + 4),
        glyf.getUint16(pos + 6),
      ]);
      pos += 8;
    }

    Uint8List? instructions;
    if ((flags & weHaveInstructions) != 0) {
      final instructionLength = glyf.getUint16(pos);
      pos += 2;
      instructions = _slice(glyf, pos, instructionLength);
      pos += instructionLength;
    }

    return ParsedCompositeGlyph(
      pos - start,
      CompositeGlyph(
        flags: flags,
        glyphIndex: glyphIndex,
        argument1: argument1,
        argument2: argument2,
        transf: transf,
        instructions: instructions,
      ),
    );
  }

  int getSize() {
    var size = 2 + 2 + transf.length * 2;
    if ((flags & weHaveInstructions) != 0) {
      size += 2 + (instructions?.length ?? 0);
    }

    size += 2;
    if ((flags & 2) != 0) {
      if (!(argument1 >= -128 &&
          argument1 <= 127 &&
          argument2 >= -128 &&
          argument2 <= 127)) {
        size += 2;
      }
    } else if (!(argument1 >= 0 &&
        argument1 <= 255 &&
        argument2 >= 0 &&
        argument2 <= 255)) {
      size += 2;
    }
    return size;
  }

  int write(int pos, ByteData buf) {
    final start = pos;

    if ((flags & argsAreXyValues) != 0) {
      if (!(argument1 >= -128 &&
          argument1 <= 127 &&
          argument2 >= -128 &&
          argument2 <= 127)) {
        flags |= arg1And2AreWords;
      }
    } else if (!(argument1 >= 0 &&
        argument1 <= 255 &&
        argument2 >= 0 &&
        argument2 <= 255)) {
      flags |= arg1And2AreWords;
    }

    buf.setUint16(pos, flags);
    buf.setUint16(pos + 2, glyphIndex);
    pos += 4;

    if ((flags & arg1And2AreWords) != 0) {
      if ((flags & argsAreXyValues) != 0) {
        buf.setInt16(pos, argument1);
        buf.setInt16(pos + 2, argument2);
      } else {
        buf.setUint16(pos, argument1);
        buf.setUint16(pos + 2, argument2);
      }
      pos += 4;
    } else {
      buf.setUint8(pos, argument1);
      buf.setUint8(pos + 1, argument2);
      pos += 2;
    }

    if ((flags & weHaveInstructions) != 0) {
      final data = instructions ?? Uint8List(0);
      buf.setUint16(pos, data.length);
      pos += 2;
      if (data.isNotEmpty) {
        _writeBytes(buf, pos, data);
        pos += data.length;
      }
    }

    return pos - start;
  }

  void scale(double x, double factor) {}
}

Uint8List _slice(ByteData data, int pos, int length) {
  return Uint8List.fromList(
    Uint8List.view(data.buffer, data.offsetInBytes + pos, length),
  );
}

void _writeBytes(ByteData data, int pos, Uint8List bytes) {
  Uint8List.view(data.buffer, data.offsetInBytes, data.lengthInBytes)
      .setRange(pos, pos + bytes.length, bytes);
}
