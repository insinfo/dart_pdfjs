// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../shared/util.dart';
import 'base_stream.dart';
import 'evaluator_preprocessor.dart';
import 'operator_list.dart';
import 'primitives.dart';
import 'xref.dart';

/// Converts a PDF blend-mode value to the Canvas blend-mode spelling.
String normalizeBlendMode(dynamic value, [bool parsingArray = false]) {
  if (value is List) {
    for (final item in value) {
      final result = normalizeBlendMode(item, true);
      if (result.isNotEmpty) return result;
    }
    return 'source-over';
  }
  if (value is! Name) return parsingArray ? '' : 'source-over';
  return switch (value.name) {
    'Normal' || 'Compatible' => 'source-over',
    'Multiply' => 'multiply',
    'Screen' => 'screen',
    'Overlay' => 'overlay',
    'Darken' => 'darken',
    'Lighten' => 'lighten',
    'ColorDodge' => 'color-dodge',
    'ColorBurn' => 'color-burn',
    'HardLight' => 'hard-light',
    'SoftLight' => 'soft-light',
    'Difference' => 'difference',
    'Exclusion' => 'exclusion',
    'Hue' => 'hue',
    'Saturation' => 'saturation',
    'Color' => 'color',
    'Luminosity' => 'luminosity',
    _ => parsingArray ? '' : 'source-over',
  };
}

/// A small time-slice helper mirroring the evaluator's cooperative scheduling.
class TimeSlotManager {
  TimeSlotManager({this.duration = const Duration(milliseconds: 20)}) {
    reset();
  }

  final Duration duration;
  late DateTime _endTime;
  int _checked = 0;

  bool check() {
    if (++_checked < 100) return false;
    _checked = 0;
    return !DateTime.now().isBefore(_endTime);
  }

  void reset() {
    _endTime = DateTime.now().add(duration);
    _checked = 0;
  }
}

class _TextState {
  List<double> textMatrix = <double>[1, 0, 0, 1, 0, 0];
  List<double> lineMatrix = <double>[1, 0, 0, 1, 0, 0];
  String fontName = '';
  double fontSize = 0;
  double charSpacing = 0;
  double wordSpacing = 0;
  double hScale = 1;
  double leading = 0;
  double rise = 0;

  void beginText() {
    textMatrix = <double>[1, 0, 0, 1, 0, 0];
    lineMatrix = <double>[1, 0, 0, 1, 0, 0];
  }

  void setMatrix(List<dynamic> values) {
    textMatrix = values.map((v) => (v as num).toDouble()).toList();
    lineMatrix = List<double>.from(textMatrix);
  }

  void move(double tx, double ty) {
    lineMatrix[4] += tx * lineMatrix[0] + ty * lineMatrix[2];
    lineMatrix[5] += tx * lineMatrix[1] + ty * lineMatrix[3];
    textMatrix = List<double>.from(lineMatrix);
  }

  void nextLine() => move(0, -leading);
}

/// The content-stream evaluator used by pages and Form XObjects.
///
/// This implementation deliberately keeps font translation and decoded image
/// production outside of the syntax pass. It nevertheless emits a complete
/// basic operator list, resolves graphics-state resources, recursively expands
/// Form XObjects, registers fonts as dependencies, and converts inline images
/// to the display-list operation expected by CanvasGraphics.
class PartialEvaluator {
  final XRef xref;
  final dynamic handler;
  final int pageIndex;
  final dynamic idFactory;
  final dynamic fontCache;
  final dynamic builtInCMapCache;
  final dynamic standardFontDataCache;
  final dynamic globalColorSpaceCache;
  final dynamic globalImageCache;
  final dynamic systemFontCache;
  final Map<String, dynamic> options;

  int _nextFontId = 1;
  int _nextImageId = 1;
  final Map<Object, String> _fontIds = <Object, String>{};
  final Set<Object> _activeForms = <Object>{};

  PartialEvaluator({
    required this.xref,
    this.handler,
    required this.pageIndex,
    this.idFactory,
    this.fontCache,
    this.builtInCMapCache,
    this.standardFontDataCache,
    this.globalColorSpaceCache,
    this.globalImageCache,
    this.systemFontCache,
    this.options = const {},
  });

  /// Scans [resources] and nested Form XObjects for non-normal blend modes.
  bool hasBlendModes(dynamic resources, Set<dynamic> knownNormalResources) {
    if (resources is! Dict) return false;
    final pending = <Dict>[resources];
    final visited = <Object>{};
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      final identity = current.objId ?? current;
      if (!visited.add(identity)) continue;

      final graphicStates = current.get('ExtGState');
      if (graphicStates is Dict) {
        for (var state in graphicStates.getRawValues()) {
          state = _fetchIfRef(state);
          if (state is! Dict) continue;
          final bm = state.get('BM');
          if (bm is Name && bm.name != 'Normal' && bm.name != 'Compatible') {
            return true;
          }
          if (bm is List &&
              bm.whereType<Name>().any(
                    (name) =>
                        name.name != 'Normal' && name.name != 'Compatible',
                  )) {
            return true;
          }
        }
      }

      final xObjects = current.get('XObject');
      if (xObjects is Dict) {
        for (var xObject in xObjects.getRawValues()) {
          xObject = _fetchIfRef(xObject);
          if (xObject is BaseStream && xObject.dict is Dict) {
            final nested = (xObject.dict as Dict).get('Resources');
            if (nested is Dict) pending.add(nested);
          }
        }
      }
    }
    knownNormalResources.addAll(visited);
    return false;
  }

  Future<void> getOperatorList({
    required dynamic contentStream,
    required dynamic executionContext,
    required OperatorList operatorList,
    dynamic resources,
  }) async {
    if (contentStream is! BaseStream) {
      throw ArgumentError.value(
          contentStream, 'contentStream', 'must be a BaseStream');
    }
    final resourceDict = resources is Dict ? resources : Dict(xref);
    final stateManager = StateManager();
    final preprocessor =
        EvaluatorPreprocessor(contentStream, xref, stateManager);
    final operation = EvaluatorOperation();
    final timeSlot = TimeSlotManager();

    while (preprocessor.read(operation)) {
      await _ensureNotCancelled(executionContext);
      final fn = operation.fn;
      final args = List<dynamic>.from(operation.args);

      switch (fn) {
        case OPS.setFont:
          await handleSetFont(
            resourceDict,
            args,
            args.isNotEmpty ? args.first : null,
            operatorList,
            executionContext,
            stateManager.state,
          );
          break;
        case OPS.setGState:
          _handleSetGState(resourceDict, args, operatorList);
          break;
        case OPS.paintXObject:
          await _handlePaintXObject(
            resourceDict,
            args,
            operatorList,
            executionContext,
            stateManager.state,
          );
          break;
        case OPS.endInlineImage:
          _handleInlineImage(args, operatorList);
          break;
        case OPS.beginInlineImage:
        case OPS.beginImageData:
          // Parser-only sentinels. Parser.getObj returns the completed inline
          // image stream with EI, so these never need to reach the renderer.
          break;
        default:
          operatorList.addOp(fn, args);
      }

      operation.args = <dynamic>[];
      if (timeSlot.check()) {
        await Future<void>.delayed(Duration.zero);
        timeSlot.reset();
      }
    }
  }

  Future<void> _ensureNotCancelled(dynamic context) async {
    if (context == null) return;
    try {
      final result = context.ensureNotTerminated();
      if (result is Future) await result;
    } on NoSuchMethodError {
      // A task object is optional for direct API and unit-test usage.
    }
  }

  dynamic _fetchIfRef(dynamic value) =>
      value is Ref ? xref.fetch(value) : value;

  dynamic _resource(Dict resources, String category, dynamic key) {
    final name = key is Name ? key.name : key?.toString();
    if (name == null) return null;
    final table = resources.get(category);
    if (table is! Dict) return null;
    return _fetchIfRef(table.getRaw(name));
  }

  void _handleSetGState(
    Dict resources,
    List<dynamic> args,
    OperatorList operatorList,
  ) {
    final state =
        _resource(resources, 'ExtGState', args.isEmpty ? null : args[0]);
    if (state is! Dict) {
      operatorList.addOp(OPS.setGState, args);
      return;
    }
    final translated = <List<dynamic>>[];
    for (final entry in state.getRawEntries()) {
      final value = _fetchIfRef(entry.value);
      switch (entry.key) {
        case 'LW':
          translated.add(<dynamic>['LW', value]);
          break;
        case 'LC':
          translated.add(<dynamic>['LC', value]);
          break;
        case 'LJ':
          translated.add(<dynamic>['LJ', value]);
          break;
        case 'ML':
          translated.add(<dynamic>['ML', value]);
          break;
        case 'D':
          translated.add(<dynamic>['D', value]);
          break;
        case 'RI':
          translated.add(<dynamic>['RI', value is Name ? value.name : value]);
          break;
        case 'FL':
          translated.add(<dynamic>['FL', value]);
          break;
        case 'CA':
          translated.add(<dynamic>['CA', value]);
          break;
        case 'ca':
          translated.add(<dynamic>['ca', value]);
          break;
        case 'BM':
          translated.add(<dynamic>['BM', normalizeBlendMode(value)]);
          break;
        case 'SMask':
          translated.add(<dynamic>[
            'SMask',
            value is Name && value.name == 'None' ? false : value
          ]);
          break;
      }
    }
    if (translated.isNotEmpty)
      operatorList.addOp(OPS.setGState, <dynamic>[translated]);
  }

  Future<void> _handlePaintXObject(
    Dict resources,
    List<dynamic> args,
    OperatorList operatorList,
    dynamic task,
    EvalState initialState,
  ) async {
    if (args.isEmpty) return;
    final xObject = _resource(resources, 'XObject', args[0]);
    if (xObject is! BaseStream || xObject.dict is! Dict) {
      // Preserve unresolved operations: callers may provide an object through
      // a display-side cache unknown to the core evaluator.
      operatorList.addOp(OPS.paintXObject, args);
      return;
    }
    final dict = xObject.dict as Dict;
    final subtype = dict.get('Subtype');
    if (subtype is Name && subtype.name == 'Form') {
      await _buildFormXObject(
          resources, xObject, operatorList, task, initialState);
      return;
    }
    if (subtype is Name && subtype.name == 'Image') {
      final identity = dict.objId ?? xObject;
      final id = 'img_p${pageIndex}_${_nextImageId++}';
      operatorList.addDependency(id);
      operatorList.addImageOps(
        OPS.paintImageXObject,
        <dynamic>[
          id,
          (dict.get('Width') as num?)?.toInt() ?? 0,
          (dict.get('Height') as num?)?.toInt() ?? 0,
          identity,
        ],
        null,
      );
      return;
    }
    operatorList.addOp(OPS.paintXObject, args);
  }

  Future<void> _buildFormXObject(
    Dict parentResources,
    BaseStream form,
    OperatorList operatorList,
    dynamic task,
    EvalState initialState,
  ) async {
    final dict = form.dict as Dict;
    final identity = dict.objId ?? form;
    if (!_activeForms.add(identity)) {
      warn('Ignoring recursive Form XObject.');
      return;
    }
    try {
      final matrix = _numberList(dict.getArray('Matrix'));
      final bbox = _numberList(dict.getArray('BBox'));
      operatorList.addOp(OPS.paintFormXObjectBegin, <dynamic>[
        matrix == null ? null : Float32List.fromList(matrix),
        bbox == null ? null : Float32List.fromList(bbox),
      ]);
      form.reset();
      final local = dict.get('Resources');
      await getOperatorList(
        contentStream: form,
        executionContext: task,
        operatorList: operatorList,
        resources: local is Dict ? local : parentResources,
      );
      operatorList.addOp(OPS.paintFormXObjectEnd);
    } finally {
      _activeForms.remove(identity);
    }
  }

  List<double>? _numberList(dynamic value) {
    if (value is! List || value.any((v) => v is! num)) return null;
    return value.map((v) => (v as num).toDouble()).toList();
  }

  void _handleInlineImage(List<dynamic> args, OperatorList operatorList) {
    if (args.isEmpty || args[0] is! BaseStream) {
      operatorList.addOp(OPS.paintInlineImageXObject, args);
      return;
    }
    final image = args[0] as BaseStream;
    final dict = image.dict;
    final width =
        dict is Dict ? (dict.get('W', 'Width') as num?)?.toInt() ?? 0 : 0;
    final height =
        dict is Dict ? (dict.get('H', 'Height') as num?)?.toInt() ?? 0 : 0;
    image.reset();
    final bytes = image.getBytes();
    operatorList.addImageOps(
      OPS.paintInlineImageXObject,
      <dynamic>[
        <String, dynamic>{
          'width': width,
          'height': height,
          'data': Uint8List.fromList(bytes),
          'raw': true,
          'dict': dict,
        },
      ],
      null,
    );
  }

  Future<Map<String, dynamic>> getTextContent({
    required dynamic contentStream,
    dynamic resources,
  }) async {
    if (contentStream is! BaseStream) {
      throw ArgumentError.value(
          contentStream, 'contentStream', 'must be a BaseStream');
    }
    final resourceDict = resources is Dict ? resources : Dict(xref);
    final preprocessor = EvaluatorPreprocessor(contentStream, xref);
    final operation = EvaluatorOperation();
    final state = _TextState();
    final items = <Map<String, dynamic>>[];
    final styles = <String, dynamic>{};

    while (preprocessor.read(operation)) {
      final args = operation.args;
      switch (operation.fn) {
        case OPS.beginText:
          state.beginText();
          break;
        case OPS.setFont:
          state.fontName =
              args[0] is Name ? (args[0] as Name).name : args[0].toString();
          state.fontSize = (args[1] as num).toDouble();
          styles.putIfAbsent(
            state.fontName,
            () => _fontStyle(resourceDict, args[0]),
          );
          break;
        case OPS.setCharSpacing:
          state.charSpacing = (args[0] as num).toDouble();
          break;
        case OPS.setWordSpacing:
          state.wordSpacing = (args[0] as num).toDouble();
          break;
        case OPS.setHScale:
          state.hScale = (args[0] as num).toDouble() / 100;
          break;
        case OPS.setLeading:
          state.leading = (args[0] as num).toDouble();
          break;
        case OPS.setTextRise:
          state.rise = (args[0] as num).toDouble();
          break;
        case OPS.setTextMatrix:
          state.setMatrix(args);
          break;
        case OPS.moveText:
          state.move((args[0] as num).toDouble(), (args[1] as num).toDouble());
          break;
        case OPS.setLeadingMoveText:
          state.leading = -(args[1] as num).toDouble();
          state.move((args[0] as num).toDouble(), (args[1] as num).toDouble());
          break;
        case OPS.nextLine:
          state.nextLine();
          break;
        case OPS.showText:
          _appendTextItem(items, state, args[0], false);
          break;
        case OPS.showSpacedText:
          _appendTextItem(items, state, args[0], false);
          break;
        case OPS.nextLineShowText:
          state.nextLine();
          _appendTextItem(items, state, args[0], true);
          break;
        case OPS.nextLineSetSpacingShowText:
          state.wordSpacing = (args[0] as num).toDouble();
          state.charSpacing = (args[1] as num).toDouble();
          state.nextLine();
          _appendTextItem(items, state, args[2], true);
          break;
      }
      operation.args = <dynamic>[];
    }
    return <String, dynamic>{'items': items, 'styles': styles};
  }

  Map<String, dynamic> _fontStyle(Dict resources, dynamic name) {
    final font = _resource(resources, 'Font', name);
    final dict = font is Dict ? font : null;
    final base = dict?.get('BaseFont');
    final descriptor = dict?.get('FontDescriptor');
    final ascent = descriptor is Dict ? descriptor.get('Ascent') : null;
    final descent = descriptor is Dict ? descriptor.get('Descent') : null;
    return <String, dynamic>{
      'fontFamily':
          base is Name ? base.name : (base?.toString() ?? name.toString()),
      'ascent': ascent is num ? ascent / 1000 : 0.8,
      'descent': descent is num ? descent / 1000 : -0.2,
      'vertical': false,
    };
  }

  void _appendTextItem(
    List<Map<String, dynamic>> items,
    _TextState state,
    dynamic source,
    bool hasEol,
  ) {
    final buffer = StringBuffer();
    double adjustment = 0;
    if (source is String) {
      buffer.write(source);
    } else if (source is List) {
      for (final value in source) {
        if (value is String) {
          buffer.write(value);
        } else if (value is num) {
          adjustment +=
              -value.toDouble() / 1000 * state.fontSize * state.hScale;
        }
      }
    }
    final text = buffer.toString();
    final spaces = text.codeUnits.where((c) => c == 0x20).length;
    final width = math.max(
      0,
      text.length * state.fontSize * 0.5 * state.hScale +
          math.max(0, text.length - 1) * state.charSpacing +
          spaces * state.wordSpacing +
          adjustment,
    );
    items.add(<String, dynamic>{
      'str': text,
      'dir': 'ltr',
      'width': width,
      'height': state.fontSize.abs(),
      'transform': <double>[
        state.textMatrix[0] * state.fontSize * state.hScale,
        state.textMatrix[1] * state.fontSize * state.hScale,
        state.textMatrix[2] * state.fontSize,
        state.textMatrix[3] * state.fontSize,
        state.textMatrix[4],
        state.textMatrix[5] + state.rise,
      ],
      'fontName': state.fontName,
      'hasEOL': hasEol,
    });
    state.textMatrix[4] += width * state.textMatrix[0];
    state.textMatrix[5] += width * state.textMatrix[1];
  }

  Future<void> handleSetFont(
    dynamic resources,
    List<dynamic> fontArgs,
    dynamic fontRef,
    OperatorList operatorList,
    dynamic task,
    dynamic state, [
    dynamic fallbackFontDict,
    dynamic cssFontInfo,
  ]) async {
    if (fontArgs.length < 2) return;
    final dict = resources is Dict ? resources : Dict(xref);
    final font = fallbackFontDict ?? _resource(dict, 'Font', fontRef);
    final identity = font is Dict ? (font.objId ?? font) : (font ?? fontRef);
    final id = _fontIds.putIfAbsent(
        identity as Object, () => 'g_p${pageIndex}_f${_nextFontId++}');
    operatorList.addDependency(id);
    operatorList.addOp(OPS.setFont, <dynamic>[id, fontArgs[1]]);
  }
}
