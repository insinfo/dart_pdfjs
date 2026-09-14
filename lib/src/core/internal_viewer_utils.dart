// Copyright 2026 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;

import '../shared/util.dart';
import 'base_stream.dart';
import 'evaluator_preprocessor.dart';
import 'parser.dart';
import 'postscript/lexer.dart';
import 'primitives.dart';

abstract final class InternalViewerUtils {
  static final Map<int, String> opsIdToName = {
    OPS.dependency: 'dependency',
    OPS.setLineWidth: 'setLineWidth',
    OPS.setLineCap: 'setLineCap',
    OPS.setLineJoin: 'setLineJoin',
    OPS.setMiterLimit: 'setMiterLimit',
    OPS.setDash: 'setDash',
    OPS.setRenderingIntent: 'setRenderingIntent',
    OPS.setFlatness: 'setFlatness',
    OPS.setGState: 'setGState',
    OPS.save: 'save',
    OPS.restore: 'restore',
    OPS.transform: 'transform',
    OPS.moveTo: 'moveTo',
    OPS.lineTo: 'lineTo',
    OPS.curveTo: 'curveTo',
    OPS.curveTo2: 'curveTo2',
    OPS.curveTo3: 'curveTo3',
    OPS.closePath: 'closePath',
    OPS.rectangle: 'rectangle',
    OPS.stroke: 'stroke',
    OPS.closeStroke: 'closeStroke',
    OPS.fill: 'fill',
    OPS.eoFill: 'eoFill',
    OPS.fillStroke: 'fillStroke',
    OPS.eoFillStroke: 'eoFillStroke',
    OPS.closeFillStroke: 'closeFillStroke',
    OPS.closeEOFillStroke: 'closeEOFillStroke',
    OPS.endPath: 'endPath',
    OPS.clip: 'clip',
    OPS.eoClip: 'eoClip',
    OPS.beginText: 'beginText',
    OPS.endText: 'endText',
    OPS.setCharSpacing: 'setCharSpacing',
    OPS.setWordSpacing: 'setWordSpacing',
    OPS.setHScale: 'setHScale',
    OPS.setLeading: 'setLeading',
    OPS.setFont: 'setFont',
    OPS.setTextRenderingMode: 'setTextRenderingMode',
    OPS.setTextRise: 'setTextRise',
    OPS.moveText: 'moveText',
    OPS.setLeadingMoveText: 'setLeadingMoveText',
    OPS.setTextMatrix: 'setTextMatrix',
    OPS.nextLine: 'nextLine',
    OPS.showText: 'showText',
    OPS.showSpacedText: 'showSpacedText',
    OPS.nextLineShowText: 'nextLineShowText',
    OPS.nextLineSetSpacingShowText: 'nextLineSetSpacingShowText',
    OPS.setCharWidth: 'setCharWidth',
    OPS.setCharWidthAndBounds: 'setCharWidthAndBounds',
    OPS.setStrokeColorSpace: 'setStrokeColorSpace',
    OPS.setFillColorSpace: 'setFillColorSpace',
    OPS.setStrokeColor: 'setStrokeColor',
    OPS.setStrokeColorN: 'setStrokeColorN',
    OPS.setFillColor: 'setFillColor',
    OPS.setFillColorN: 'setFillColorN',
    OPS.setStrokeGray: 'setStrokeGray',
    OPS.setFillGray: 'setFillGray',
    OPS.setStrokeRGBColor: 'setStrokeRGBColor',
    OPS.setFillRGBColor: 'setFillRGBColor',
    OPS.setStrokeCMYKColor: 'setStrokeCMYKColor',
    OPS.setFillCMYKColor: 'setFillCMYKColor',
    OPS.shadingFill: 'shadingFill',
    OPS.beginInlineImage: 'beginInlineImage',
    OPS.beginImageData: 'beginImageData',
    OPS.endInlineImage: 'endInlineImage',
    OPS.paintXObject: 'paintXObject',
    OPS.markPoint: 'markPoint',
    OPS.markPointProps: 'markPointProps',
    OPS.beginMarkedContent: 'beginMarkedContent',
    OPS.beginMarkedContentProps: 'beginMarkedContentProps',
    OPS.endMarkedContent: 'endMarkedContent',
    OPS.beginCompat: 'beginCompat',
    OPS.endCompat: 'endCompat',
    OPS.paintFormXObjectBegin: 'paintFormXObjectBegin',
    OPS.paintFormXObjectEnd: 'paintFormXObjectEnd',
    OPS.beginGroup: 'beginGroup',
    OPS.endGroup: 'endGroup',
    OPS.beginAnnotation: 'beginAnnotation',
    OPS.endAnnotation: 'endAnnotation',
    OPS.paintImageMaskXObject: 'paintImageMaskXObject',
    OPS.paintImageMaskXObjectGroup: 'paintImageMaskXObjectGroup',
    OPS.paintImageXObject: 'paintImageXObject',
    OPS.paintInlineImageXObject: 'paintInlineImageXObject',
    OPS.paintInlineImageXObjectGroup: 'paintInlineImageXObjectGroup',
    OPS.paintImageXObjectRepeat: 'paintImageXObjectRepeat',
    OPS.paintImageMaskXObjectRepeat: 'paintImageMaskXObjectRepeat',
    OPS.paintSolidColorImageMask: 'paintSolidColorImageMask',
    OPS.constructPath: 'constructPath',
    OPS.setStrokeTransparent: 'setStrokeTransparent',
    OPS.setFillTransparent: 'setFillTransparent',
    OPS.rawFillPath: 'rawFillPath',
  };

  static List<dynamic> tokenizeStream(BaseStream stream, dynamic xref) {
    final tokens = <dynamic>[];
    final parser = Parser(
      lexer: Lexer(stream),
      xref: xref,
      allowStreams: false,
    );
    while (true) {
      dynamic obj;
      try {
        obj = parser.getObj();
      } catch (_) {
        break;
      }
      if (obj == EOF) {
        break;
      }
      final token = tokenToJSObject(obj);
      if (token != null) {
        tokens.add(token);
      }
    }
    return tokens;
  }

  static Map<String, dynamic> getContentTokens(dynamic contentsVal, dynamic xref) {
    final resolvedVal = xref != null ? xref.fetchIfRef(contentsVal) : contentsVal;
    final List<dynamic> refs = resolvedVal is List ? resolvedVal : [contentsVal];
    final rawContents = <Map<String, dynamic>>[];
    final tokens = <Map<String, dynamic>>[];
    final rawBytesArr = <String>[];

    for (final rawRef in refs) {
      if (rawRef is Ref) {
        rawContents.add({'num': rawRef.num, 'gen': rawRef.gen});
      }
      final dynamic stream = xref != null ? xref.fetchIfRef(rawRef) : rawRef;
      if (stream is! BaseStream) {
        continue;
      }
      rawBytesArr.add(stream.getString());
      stream.reset();
      final streamTokens = tokenizeStream(stream, xref);
      for (final tok in streamTokens) {
        if (tok is Map<String, dynamic>) {
          tokens.add(tok);
        }
      }
    }
    final rawBytes = rawBytesArr.join('\n');
    final grouped = groupIntoInstructions(tokens);
    return {
      'contentStream': true,
      'instructions': grouped['instructions'],
      'cmdNames': grouped['cmdNames'],
      'rawContents': rawContents,
      'rawBytes': rawBytes,
    };
  }

  static Map<String, dynamic> groupIntoInstructions(List<Map<String, dynamic>> tokens) {
    final opMap = EvaluatorPreprocessor.opMap;
    final instructions = <Map<String, dynamic>>[];
    final cmdNames = <String, String>{};
    final argBuffer = <Map<String, dynamic>>[];

    for (final token in tokens) {
      if (token['type'] != 'cmd') {
        argBuffer.add(token);
        continue;
      }
      final cmdVal = token['value'] as String;
      final op = opMap[cmdVal];
      if (op != null && !cmdNames.containsKey(cmdVal)) {
        final name = opsIdToName[op.id];
        if (name != null) {
          cmdNames[cmdVal] = name;
        }
      }
      List<Map<String, dynamic>> args;
      if (op == null || op.variableArgs) {
        args = List<Map<String, dynamic>>.from(argBuffer);
        argBuffer.clear();
      } else {
        final orphanCount = math.max(0, argBuffer.length - op.numArgs);
        for (var i = 0; i < orphanCount; i++) {
          instructions.add({'cmd': null, 'args': [argBuffer.removeAt(0)]});
        }
        args = List<Map<String, dynamic>>.from(argBuffer);
        argBuffer.clear();
      }
      instructions.add({'cmd': cmdVal, 'args': args});
    }
    for (final t in argBuffer) {
      instructions.add({'cmd': null, 'args': [t]});
    }
    return {
      'instructions': instructions,
      'cmdNames': cmdNames,
    };
  }

  static List<Map<String, dynamic>> tokenizePSSource(String source) {
    final lexer = PsLexer(source);
    final lines = <Map<String, dynamic>>[];
    var indent = 0;
    var buffer = <Map<String, dynamic>>[];

    void flush() {
      if (buffer.isNotEmpty) {
        lines.add({
          'indent': indent,
          'tokens': List<Map<String, dynamic>>.from(buffer),
        });
        buffer.clear();
      }
    }

    while (true) {
      final tok = lexer.next();
      if (tok.id == TOKEN.eof) {
        break;
      }
      if (tok.id == TOKEN.lbrace) {
        flush();
        lines.add({
          'indent': indent,
          'tokens': [
            {'type': 'brace', 'value': '{'}
          ],
        });
        indent++;
      } else if (tok.id == TOKEN.rbrace) {
        flush();
        indent = math.max(0, indent - 1);
        lines.add({
          'indent': indent,
          'tokens': [
            {'type': 'brace', 'value': '}'}
          ],
        });
      } else if (tok.id == TOKEN.number) {
        buffer.add({'type': 'number', 'value': tok.value});
      } else if (tok.id == TOKEN.trueToken) {
        buffer.add({'type': 'boolean', 'value': true});
      } else if (tok.id == TOKEN.falseToken) {
        buffer.add({'type': 'boolean', 'value': false});
      } else if (tok.value != null) {
        buffer.add({'type': 'cmd', 'value': tok.value});
        flush();
      }
    }
    flush();
    return lines;
  }

  static dynamic tokenToJSObject(dynamic obj) {
    if (obj is Cmd) {
      return {'type': 'cmd', 'value': obj.cmd};
    }
    if (obj is Name) {
      return {'type': 'name', 'value': obj.name};
    }
    if (obj is Ref) {
      return {'type': 'ref', 'num': obj.num, 'gen': obj.gen};
    }
    if (obj is List) {
      return {'type': 'array', 'value': obj.map(tokenToJSObject).toList()};
    }
    if (obj is Dict) {
      final result = <String, dynamic>{};
      for (final entry in obj.getRawEntries()) {
        result[entry.key] = tokenToJSObject(entry.value);
      }
      return {'type': 'dict', 'value': result};
    }
    if (obj is num) {
      return {'type': 'number', 'value': obj};
    }
    if (obj is String) {
      return {'type': 'string', 'value': obj};
    }
    if (obj is bool) {
      return {'type': 'boolean', 'value': obj};
    }
    if (obj == null) {
      return {'type': 'null'};
    }
    return null;
  }
}
