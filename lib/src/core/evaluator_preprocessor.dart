// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import '../shared/util.dart';
import 'base_stream.dart';
import 'core_utils.dart';
import 'parser.dart';
import 'primitives.dart';

class OpSpec {
  const OpSpec({
    required this.id,
    required this.numArgs,
    required this.variableArgs,
  });

  final int id;
  final int numArgs;
  final bool variableArgs;
}

class EvalState {
  Float32List ctm = Float32List.fromList(IDENTITY_MATRIX.map((n) => n.toDouble()).toList());

  EvalState clone() {
    final cloned = EvalState();
    cloned.ctm = Float32List.fromList(ctm);
    return cloned;
  }
}

class StateManager {
  StateManager([EvalState? initialState])
      : state = initialState ?? EvalState(),
        stateStack = <EvalState>[];

  EvalState state;
  final List<EvalState> stateStack;

  void save() {
    stateStack.add(state);
    state = state.clone();
  }

  void restore() {
    if (stateStack.isNotEmpty) {
      state = stateStack.removeLast();
    }
  }

  void transform(List<dynamic> args) {
    final m = args.map((x) => (x as num).toDouble()).toList();
    state.ctm = Float32List.fromList(PdfJsUtil.transform(state.ctm, m));
  }
}

class EvaluatorOperation {
  EvaluatorOperation({this.fn = 0, List<dynamic>? args})
      : args = args ?? <dynamic>[];

  int fn;
  List<dynamic> args;
}

class EvaluatorPreprocessor {
  EvaluatorPreprocessor(
    BaseStream stream, [
    dynamic xref,
    StateManager? stateManager,
  ])  : parser = Parser(
          lexer: Lexer(stream, EvaluatorPreprocessor.opMap),
          xref: xref,
        ),
        stateManager = stateManager ?? StateManager();

  static const int maxInvalidPathOps = 10;

  static final Map<String, OpSpec> opMap = {
    // Graphic state
    'w': const OpSpec(id: OPS.setLineWidth, numArgs: 1, variableArgs: false),
    'J': const OpSpec(id: OPS.setLineCap, numArgs: 1, variableArgs: false),
    'j': const OpSpec(id: OPS.setLineJoin, numArgs: 1, variableArgs: false),
    'M': const OpSpec(id: OPS.setMiterLimit, numArgs: 1, variableArgs: false),
    'd': const OpSpec(id: OPS.setDash, numArgs: 2, variableArgs: false),
    'ri': const OpSpec(id: OPS.setRenderingIntent, numArgs: 1, variableArgs: false),
    'i': const OpSpec(id: OPS.setFlatness, numArgs: 1, variableArgs: false),
    'gs': const OpSpec(id: OPS.setGState, numArgs: 1, variableArgs: false),
    'q': const OpSpec(id: OPS.save, numArgs: 0, variableArgs: false),
    'Q': const OpSpec(id: OPS.restore, numArgs: 0, variableArgs: false),
    'cm': const OpSpec(id: OPS.transform, numArgs: 6, variableArgs: false),

    // Path
    'm': const OpSpec(id: OPS.moveTo, numArgs: 2, variableArgs: false),
    'l': const OpSpec(id: OPS.lineTo, numArgs: 2, variableArgs: false),
    'c': const OpSpec(id: OPS.curveTo, numArgs: 6, variableArgs: false),
    'v': const OpSpec(id: OPS.curveTo2, numArgs: 4, variableArgs: false),
    'y': const OpSpec(id: OPS.curveTo3, numArgs: 4, variableArgs: false),
    'h': const OpSpec(id: OPS.closePath, numArgs: 0, variableArgs: false),
    're': const OpSpec(id: OPS.rectangle, numArgs: 4, variableArgs: false),
    'S': const OpSpec(id: OPS.stroke, numArgs: 0, variableArgs: false),
    's': const OpSpec(id: OPS.closeStroke, numArgs: 0, variableArgs: false),
    'f': const OpSpec(id: OPS.fill, numArgs: 0, variableArgs: false),
    'F': const OpSpec(id: OPS.fill, numArgs: 0, variableArgs: false),
    'f*': const OpSpec(id: OPS.eoFill, numArgs: 0, variableArgs: false),
    'B': const OpSpec(id: OPS.fillStroke, numArgs: 0, variableArgs: false),
    'B*': const OpSpec(id: OPS.eoFillStroke, numArgs: 0, variableArgs: false),
    'b': const OpSpec(id: OPS.closeFillStroke, numArgs: 0, variableArgs: false),
    'b*': const OpSpec(id: OPS.closeEOFillStroke, numArgs: 0, variableArgs: false),
    'n': const OpSpec(id: OPS.endPath, numArgs: 0, variableArgs: false),

    // Clipping
    'W': const OpSpec(id: OPS.clip, numArgs: 0, variableArgs: false),
    'W*': const OpSpec(id: OPS.eoClip, numArgs: 0, variableArgs: false),

    // Text
    'BT': const OpSpec(id: OPS.beginText, numArgs: 0, variableArgs: false),
    'ET': const OpSpec(id: OPS.endText, numArgs: 0, variableArgs: false),
    'Tc': const OpSpec(id: OPS.setCharSpacing, numArgs: 1, variableArgs: false),
    'Tw': const OpSpec(id: OPS.setWordSpacing, numArgs: 1, variableArgs: false),
    'Tz': const OpSpec(id: OPS.setHScale, numArgs: 1, variableArgs: false),
    'TL': const OpSpec(id: OPS.setLeading, numArgs: 1, variableArgs: false),
    'Tf': const OpSpec(id: OPS.setFont, numArgs: 2, variableArgs: false),
    'Tr': const OpSpec(id: OPS.setTextRenderingMode, numArgs: 1, variableArgs: false),
    'Ts': const OpSpec(id: OPS.setTextRise, numArgs: 1, variableArgs: false),
    'Td': const OpSpec(id: OPS.moveText, numArgs: 2, variableArgs: false),
    'TD': const OpSpec(id: OPS.setLeadingMoveText, numArgs: 2, variableArgs: false),
    'Tm': const OpSpec(id: OPS.setTextMatrix, numArgs: 6, variableArgs: false),
    'T*': const OpSpec(id: OPS.nextLine, numArgs: 0, variableArgs: false),
    'Tj': const OpSpec(id: OPS.showText, numArgs: 1, variableArgs: false),
    'TJ': const OpSpec(id: OPS.showSpacedText, numArgs: 1, variableArgs: false),
    "'": const OpSpec(id: OPS.nextLineShowText, numArgs: 1, variableArgs: false),
    '"': const OpSpec(id: OPS.nextLineSetSpacingShowText, numArgs: 3, variableArgs: false),

    // Type3 fonts
    'd0': const OpSpec(id: OPS.setCharWidth, numArgs: 2, variableArgs: false),
    'd1': const OpSpec(id: OPS.setCharWidthAndBounds, numArgs: 6, variableArgs: false),

    // Color
    'CS': const OpSpec(id: OPS.setStrokeColorSpace, numArgs: 1, variableArgs: false),
    'cs': const OpSpec(id: OPS.setFillColorSpace, numArgs: 1, variableArgs: false),
    'SC': const OpSpec(id: OPS.setStrokeColor, numArgs: 4, variableArgs: true),
    'SCN': const OpSpec(id: OPS.setStrokeColorN, numArgs: 33, variableArgs: true),
    'sc': const OpSpec(id: OPS.setFillColor, numArgs: 4, variableArgs: true),
    'scn': const OpSpec(id: OPS.setFillColorN, numArgs: 33, variableArgs: true),
    'G': const OpSpec(id: OPS.setStrokeGray, numArgs: 1, variableArgs: false),
    'g': const OpSpec(id: OPS.setFillGray, numArgs: 1, variableArgs: false),
    'RG': const OpSpec(id: OPS.setStrokeRGBColor, numArgs: 3, variableArgs: false),
    'rg': const OpSpec(id: OPS.setFillRGBColor, numArgs: 3, variableArgs: false),
    'K': const OpSpec(id: OPS.setStrokeCMYKColor, numArgs: 4, variableArgs: false),
    'k': const OpSpec(id: OPS.setFillCMYKColor, numArgs: 4, variableArgs: false),

    // Shading
    'sh': const OpSpec(id: OPS.shadingFill, numArgs: 1, variableArgs: false),

    // Images
    'BI': const OpSpec(id: OPS.beginInlineImage, numArgs: 0, variableArgs: false),
    'ID': const OpSpec(id: OPS.beginImageData, numArgs: 0, variableArgs: false),
    'EI': const OpSpec(id: OPS.endInlineImage, numArgs: 1, variableArgs: false),

    // XObjects
    'Do': const OpSpec(id: OPS.paintXObject, numArgs: 1, variableArgs: false),
    'MP': const OpSpec(id: OPS.markPoint, numArgs: 1, variableArgs: false),
    'DP': const OpSpec(id: OPS.markPointProps, numArgs: 2, variableArgs: false),
    'BMC': const OpSpec(id: OPS.beginMarkedContent, numArgs: 1, variableArgs: false),
    'BDC': const OpSpec(id: OPS.beginMarkedContentProps, numArgs: 2, variableArgs: false),
    'EMC': const OpSpec(id: OPS.endMarkedContent, numArgs: 0, variableArgs: false),

    // Compatibility
    'BX': const OpSpec(id: OPS.beginCompat, numArgs: 0, variableArgs: false),
    'EX': const OpSpec(id: OPS.endCompat, numArgs: 0, variableArgs: false),
  };

  final Parser parser;
  final StateManager stateManager;
  final List<dynamic> nonProcessedArgs = <dynamic>[];
  bool _isPathOp = false;
  int _numInvalidPathOPS = 0;

  int get savedStatesDepth => stateManager.stateStack.length;

  bool read(EvaluatorOperation operation) {
    var args = operation.args;
    while (true) {
      final obj = parser.getObj();
      if (obj is Cmd) {
        final cmd = obj.cmd;
        final opSpec = opMap[cmd];
        if (opSpec == null) {
          warn('Unknown command "$cmd".');
          continue;
        }

        final fn = opSpec.id;
        final numArgs = opSpec.numArgs;
        var argsLength = args.length;

        if (!_isPathOp) {
          _numInvalidPathOPS = 0;
        }
        _isPathOp = fn >= OPS.moveTo && fn <= OPS.endPath;

        if (!opSpec.variableArgs) {
          if (argsLength != numArgs) {
            while (argsLength > numArgs) {
              nonProcessedArgs.add(args.removeAt(0));
              argsLength--;
            }
            while (argsLength < numArgs && nonProcessedArgs.isNotEmpty) {
              args.insert(0, nonProcessedArgs.removeLast());
              argsLength++;
            }
          }

          if (argsLength < numArgs) {
            final partialMsg = 'command $cmd: expected $numArgs args, but received $argsLength args.';
            if (_isPathOp && ++_numInvalidPathOPS > maxInvalidPathOps) {
              throw FormatError('Invalid $partialMsg');
            }
            warn('Skipping $partialMsg');
            args.clear();
            continue;
          }
        }

        preprocessCommand(fn, args);
        operation.fn = fn;
        operation.args = args;
        return true;
      }
      if (obj == eof) {
        return false;
      }
      if (obj != null) {
        args.add(obj);
        if (args.length > 33) {
          throw FormatError('Too many arguments');
        }
      }
    }
  }

  void preprocessCommand(int fn, List<dynamic> args) {
    switch (fn) {
      case OPS.save:
        stateManager.save();
        break;
      case OPS.restore:
        stateManager.restore();
        break;
      case OPS.transform:
        stateManager.transform(args);
        break;
    }
  }
}
