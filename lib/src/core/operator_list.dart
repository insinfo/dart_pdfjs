// Copyright 2017 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;
import 'dart:typed_data';

import '../shared/util.dart';

class _PatternRule {
  final bool Function(QueueOptimizerContext context)? checkFn;
  final bool Function(QueueOptimizerContext context, int i)? iterateFn;
  final int Function(QueueOptimizerContext context, int i)? processFn;

  _PatternRule({this.checkFn, this.iterateFn, this.processFn});
}

final Map<int, dynamic> _initialState = <int, dynamic>{};

void _addState(
  Map<int, dynamic> parentState,
  List<int> pattern,
  bool Function(QueueOptimizerContext context)? checkFn,
  bool Function(QueueOptimizerContext context, int i)? iterateFn,
  int Function(QueueOptimizerContext context, int i)? processFn,
) {
  Map<int, dynamic> state = parentState;
  for (var i = 0; i < pattern.length - 1; i++) {
    final item = pattern[i];
    final next = state.putIfAbsent(item, () => <int, dynamic>{});
    state = next as Map<int, dynamic>;
  }
  state[pattern.last] = _PatternRule(
    checkFn: checkFn,
    iterateFn: iterateFn,
    processFn: processFn,
  );
}

void _initOptimizerRules() {
  if (_initialState.isNotEmpty) return;

  // 1. Inline image group: (save, transform, paintInlineImageXObject, restore)+
  _addState(
    _initialState,
    [OPS.save, OPS.transform, OPS.paintInlineImageXObject, OPS.restore],
    null,
    (context, i) {
      final fnArray = context.fnArray;
      final iFirstSave = context.iCurr - 3;
      final pos = (i - iFirstSave) % 4;
      switch (pos) {
        case 0:
          return fnArray[i] == OPS.save;
        case 1:
          return fnArray[i] == OPS.transform;
        case 2:
          return fnArray[i] == OPS.paintInlineImageXObject;
        case 3:
          return fnArray[i] == OPS.restore;
      }
      return false;
    },
    (context, i) {
      const minImages = 10;
      const maxImages = 200;
      const maxWidth = 1000;
      const imagePadding = 1;

      final fnArray = context.fnArray;
      final argsArray = context.argsArray;
      final curr = context.iCurr;
      final iFirstSave = curr - 3;
      final iFirstTransform = curr - 2;
      final iFirstPIIXO = curr - 1;

      final count = math.min((i - iFirstSave) ~/ 4, maxImages);
      if (count < minImages) {
        return i - ((i - iFirstSave) % 4);
      }

      var maxX = 0;
      final map = <Map<String, dynamic>>[];
      var maxLineHeight = 0;
      var currentX = imagePadding;
      var currentY = imagePadding;

      for (var q = 0; q < count; q++) {
        final transform = argsArray[iFirstTransform + (q << 2)];
        final img = argsArray[iFirstPIIXO + (q << 2)][0];
        final int w = img is Map ? img['width'] : (img as dynamic).width;
        final int h = img is Map ? img['height'] : (img as dynamic).height;

        if (currentX + w > maxWidth) {
          maxX = math.max(maxX, currentX);
          currentY += maxLineHeight + 2 * imagePadding;
          currentX = 0;
          maxLineHeight = 0;
        }

        map.add({
          'transform': transform,
          'x': currentX,
          'y': currentY,
          'w': w,
          'h': h,
        });

        currentX += w + 2 * imagePadding;
        maxLineHeight = math.max(maxLineHeight, h);
      }

      final imgWidth = math.max(maxX, currentX) + imagePadding;
      final imgHeight = currentY + maxLineHeight + imagePadding;
      final imgData = Uint8List(imgWidth * imgHeight * 4);
      final imgRowSize = imgWidth << 2;

      for (var q = 0; q < count; q++) {
        final imgObj = argsArray[iFirstPIIXO + (q << 2)][0];
        final dynamic rawData = imgObj is Map ? imgObj['data'] : (imgObj as dynamic).data;
        final Uint8List data = rawData is Uint8List ? rawData : Uint8List.fromList((rawData as List).cast<int>());
        final int rowSize = (map[q]['w'] as int) << 2;
        var dataOffset = 0;
        var offset = ((map[q]['x'] as int) + (map[q]['y'] as int) * imgWidth) << 2;

        if (offset - imgRowSize >= 0) {
          imgData.setRange(offset - imgRowSize, offset - imgRowSize + rowSize, data.sublist(0, rowSize));
        }

        final int h = map[q]['h'] as int;
        for (var k = 0; k < h; k++) {
          imgData.setRange(offset, offset + rowSize, data.sublist(dataOffset, dataOffset + rowSize));
          dataOffset += rowSize;
          offset += imgRowSize;
        }
        if (offset + rowSize <= imgData.length && dataOffset - rowSize >= 0) {
          imgData.setRange(offset, offset + rowSize, data.sublist(dataOffset - rowSize, dataOffset));
        }
      }

      final img = {
        'width': imgWidth,
        'height': imgHeight,
        'kind': ImageKind.RGBA_32BPP,
        'data': imgData,
      };

      fnArray.removeRange(iFirstSave, iFirstSave + count * 4);
      argsArray.removeRange(iFirstSave, iFirstSave + count * 4);

      fnArray.insert(iFirstSave, OPS.paintInlineImageXObjectGroup);
      argsArray.insert(iFirstSave, [img, map]);

      return iFirstSave + 1;
    },
  );

  // 2. Image mask group: (save, transform, paintImageMaskXObject, restore)+
  _addState(
    _initialState,
    [OPS.save, OPS.transform, OPS.paintImageMaskXObject, OPS.restore],
    null,
    (context, i) {
      final fnArray = context.fnArray;
      final iFirstSave = context.iCurr - 3;
      final pos = (i - iFirstSave) % 4;
      switch (pos) {
        case 0:
          return fnArray[i] == OPS.save;
        case 1:
          return fnArray[i] == OPS.transform;
        case 2:
          return fnArray[i] == OPS.paintImageMaskXObject;
        case 3:
          return fnArray[i] == OPS.restore;
      }
      return false;
    },
    (context, i) {
      const minImages = 10;
      const maxSameImages = 1000;
      const maxImages = 100;

      final fnArray = context.fnArray;
      final argsArray = context.argsArray;
      final curr = context.iCurr;
      final iFirstSave = curr - 3;
      final iFirstTransform = curr - 2;
      final iFirstPIMXO = curr - 1;

      var count = (i - iFirstSave) ~/ 4;
      if (count < minImages) {
        return i - ((i - iFirstSave) % 4);
      }

      var isSameImage = false;
      final firstPIMXOArg0 = argsArray[iFirstPIMXO][0];
      final firstTransform = argsArray[iFirstTransform] as List;
      final t0 = firstTransform[0];
      final t1 = firstTransform[1];
      final t2 = firstTransform[2];
      final t3 = firstTransform[3];

      if (t1 == t2) {
        isSameImage = true;
        var iTransform = iFirstTransform + 4;
        var iPIMXO = iFirstPIMXO + 4;
        for (var q = 1; q < count; q++, iTransform += 4, iPIMXO += 4) {
          final transformArgs = argsArray[iTransform] as List;
          if (argsArray[iPIMXO][0] != firstPIMXOArg0 ||
              transformArgs[0] != t0 ||
              transformArgs[1] != t1 ||
              transformArgs[2] != t2 ||
              transformArgs[3] != t3) {
            if (q < minImages) {
              isSameImage = false;
            } else {
              count = q;
            }
            break;
          }
        }
      }

      if (isSameImage) {
        count = math.min(count, maxSameImages);
        final positions = Float32List(count * 2);
        var iTransform = iFirstTransform;
        for (var q = 0; q < count; q++, iTransform += 4) {
          final transformArgs = argsArray[iTransform] as List;
          positions[q << 1] = (transformArgs[4] as num).toDouble();
          positions[(q << 1) + 1] = (transformArgs[5] as num).toDouble();
        }

        fnArray.removeRange(iFirstSave, iFirstSave + count * 4);
        argsArray.removeRange(iFirstSave, iFirstSave + count * 4);

        fnArray.insert(iFirstSave, OPS.paintImageMaskXObjectRepeat);
        argsArray.insert(iFirstSave, [
          firstPIMXOArg0,
          t0,
          t1,
          t2,
          t3,
          positions,
        ]);
      } else {
        count = math.min(count, maxImages);
        final images = <dynamic>[];
        for (var q = 0; q < count; q++) {
          final transformArgs = argsArray[iFirstTransform + (q << 2)];
          final maskParams = argsArray[iFirstPIMXO + (q << 2)][0];
          images.add({
            'data': maskParams is Map ? maskParams['data'] : (maskParams as dynamic).data,
            'width': maskParams is Map ? maskParams['width'] : (maskParams as dynamic).width,
            'height': maskParams is Map ? maskParams['height'] : (maskParams as dynamic).height,
            'interpolate': maskParams is Map ? maskParams['interpolate'] : (maskParams as dynamic).interpolate,
            'count': maskParams is Map ? maskParams['count'] : (maskParams as dynamic).count,
            'transform': transformArgs,
          });
        }

        fnArray.removeRange(iFirstSave, iFirstSave + count * 4);
        argsArray.removeRange(iFirstSave, iFirstSave + count * 4);

        fnArray.insert(iFirstSave, OPS.paintImageMaskXObjectGroup);
        argsArray.insert(iFirstSave, [images]);
      }

      return iFirstSave + 1;
    },
  );

  // 3. Image repeat: (save, transform, paintImageXObject, restore)+
  _addState(
    _initialState,
    [OPS.save, OPS.transform, OPS.paintImageXObject, OPS.restore],
    (context) {
      final argsArray = context.argsArray;
      final iFirstTransform = context.iCurr - 2;
      final transform = argsArray[iFirstTransform] as List;
      return transform[1] == 0 && transform[2] == 0;
    },
    (context, i) {
      final fnArray = context.fnArray;
      final argsArray = context.argsArray;
      final iFirstSave = context.iCurr - 3;
      final pos = (i - iFirstSave) % 4;
      switch (pos) {
        case 0:
          return fnArray[i] == OPS.save;
        case 1:
          if (fnArray[i] != OPS.transform) return false;
          final iFirstTransform = context.iCurr - 2;
          final first = argsArray[iFirstTransform] as List;
          final currTransform = argsArray[i] as List;
          return currTransform[0] == first[0] &&
              currTransform[1] == 0 &&
              currTransform[2] == 0 &&
              currTransform[3] == first[3];
        case 2:
          if (fnArray[i] != OPS.paintImageXObject) return false;
          final iFirstPIXO = context.iCurr - 1;
          return argsArray[i][0] == argsArray[iFirstPIXO][0];
        case 3:
          return fnArray[i] == OPS.restore;
      }
      return false;
    },
    (context, i) {
      const minImages = 3;
      const maxImages = 1000;

      final fnArray = context.fnArray;
      final argsArray = context.argsArray;
      final curr = context.iCurr;
      final iFirstSave = curr - 3;
      final iFirstTransform = curr - 2;
      final iFirstPIXO = curr - 1;
      final firstPIXOArg0 = argsArray[iFirstPIXO][0];
      final firstTransform = argsArray[iFirstTransform] as List;

      final count = math.min((i - iFirstSave) ~/ 4, maxImages);
      if (count < minImages) {
        return i - ((i - iFirstSave) % 4);
      }

      final positions = Float32List(count * 2);
      var iTransform = iFirstTransform;
      for (var q = 0; q < count; q++, iTransform += 4) {
        final transformArgs = argsArray[iTransform] as List;
        positions[q << 1] = (transformArgs[4] as num).toDouble();
        positions[(q << 1) + 1] = (transformArgs[5] as num).toDouble();
      }

      final args = [
        firstPIXOArg0,
        firstTransform[0],
        firstTransform[3],
        positions,
      ];

      fnArray.removeRange(iFirstSave, iFirstSave + count * 4);
      argsArray.removeRange(iFirstSave, iFirstSave + count * 4);

      fnArray.insert(iFirstSave, OPS.paintImageXObjectRepeat);
      argsArray.insert(iFirstSave, args);

      return iFirstSave + 1;
    },
  );

  // 4. Show text group: (beginText, setFont, setTextMatrix, showText, endText)+
  _addState(
    _initialState,
    [OPS.beginText, OPS.setFont, OPS.setTextMatrix, OPS.showText, OPS.endText],
    null,
    (context, i) {
      final fnArray = context.fnArray;
      final argsArray = context.argsArray;
      final iFirstSave = context.iCurr - 4;
      final pos = (i - iFirstSave) % 5;
      switch (pos) {
        case 0:
          return fnArray[i] == OPS.beginText;
        case 1:
          return fnArray[i] == OPS.setFont;
        case 2:
          return fnArray[i] == OPS.setTextMatrix;
        case 3:
          if (fnArray[i] != OPS.showText) return false;
          final iFirstSetFont = context.iCurr - 3;
          final firstFont = argsArray[iFirstSetFont];
          return argsArray[i][0] == firstFont[0] && argsArray[i][1] == firstFont[1];
        case 4:
          return fnArray[i] == OPS.endText;
      }
      return false;
    },
    (context, i) {
      const minChars = 3;
      const maxChars = 1000;

      final fnArray = context.fnArray;
      final argsArray = context.argsArray;
      final curr = context.iCurr;
      final iFirstBeginText = curr - 4;
      final iFirstSetFont = curr - 3;
      final firstFont = argsArray[iFirstSetFont];

      var count = math.min((i - iFirstBeginText) ~/ 5, maxChars);
      if (count < minChars) {
        return i - ((i - iFirstBeginText) % 5);
      }

      var iFirst = iFirstBeginText;
      if (iFirstBeginText >= 4 &&
          fnArray[iFirstBeginText - 4] == fnArray[iFirstSetFont] &&
          fnArray[iFirstBeginText - 3] == fnArray[curr - 2] &&
          fnArray[iFirstBeginText - 2] == fnArray[curr - 1] &&
          fnArray[iFirstBeginText - 1] == fnArray[curr] &&
          argsArray[iFirstBeginText - 4][0] == firstFont[0] &&
          argsArray[iFirstBeginText - 4][1] == firstFont[1]) {
        count++;
        iFirst -= 5;
      }

      var iEndText = iFirst + 4;
      for (var q = 1; q < count; q++) {
        fnArray.removeRange(iEndText, iEndText + 3);
        argsArray.removeRange(iEndText, iEndText + 3);
        iEndText += 2;
      }

      return iEndText + 1;
    },
  );

  // 5. Construct path: (save, transform, constructPath, restore)
  _addState(
    _initialState,
    [OPS.save, OPS.transform, OPS.constructPath, OPS.restore],
    (context) {
      final argsArray = context.argsArray;
      final iFirstConstructPath = context.iCurr - 1;
      final op = argsArray[iFirstConstructPath][0];

      if (op != OPS.stroke &&
          op != OPS.closeStroke &&
          op != OPS.fillStroke &&
          op != OPS.eoFillStroke &&
          op != OPS.closeFillStroke &&
          op != OPS.closeEOFillStroke) {
        return true;
      }
      final iFirstTransform = context.iCurr - 2;
      final transform = argsArray[iFirstTransform] as List;
      return transform[0] == 1 &&
          transform[1] == 0 &&
          transform[2] == 0 &&
          transform[3] == 1;
    },
    (context, i) => false,
    (context, i) {
      final fnArray = context.fnArray;
      final argsArray = context.argsArray;
      final curr = context.iCurr;
      final iFirstSave = curr - 3;
      final iFirstTransform = curr - 2;
      final iFirstConstructPath = curr - 1;
      final args = argsArray[iFirstConstructPath] as List;
      final transform = (argsArray[iFirstTransform] as List).cast<num>();

      final pathArgs = args[1] as List;
      final buffer = pathArgs[0] as List<num>;
      final minMax = args.length > 2 ? (args[2] as List<num>?) : null;

      if (minMax != null) {
        final newBBox = List<num>.from(f32BboxInit);
        Util.axialAlignedBoundingBox(minMax, transform, newBBox);
        for (var k = 0; k < 4; k++) {
          minMax[k] = newBBox[k];
        }

        for (var k = 0; k < buffer.length;) {
          final drawOp = buffer[k++].toInt();
          switch (drawOp) {
            case DrawOPS.moveTo:
            case DrawOPS.lineTo:
              Util.applyTransform(buffer, transform, k);
              k += 2;
              break;
            case DrawOPS.curveTo:
              Util.applyTransformToBezier(buffer, transform, k);
              k += 6;
              break;
          }
        }
      }

      fnArray.removeRange(iFirstSave, iFirstSave + 4);
      argsArray.removeRange(iFirstSave, iFirstSave + 4);

      fnArray.insert(iFirstSave, OPS.constructPath);
      argsArray.insert(iFirstSave, args);

      return iFirstSave + 1;
    },
  );
}

class QueueOptimizerContext {
  int iCurr = 0;
  final List<int> fnArray;
  final List<dynamic> argsArray;
  final bool isOffscreenCanvasSupported;

  QueueOptimizerContext({
    required this.fnArray,
    required this.argsArray,
    this.isOffscreenCanvasSupported = false,
  });
}

abstract class NullOptimizer {
  final OperatorList queue;

  NullOptimizer(this.queue);

  void push(int fn, dynamic args) {
    queue.fnArray.add(fn);
    queue.argsArray.add(args);
    optimize();
  }

  void optimize() {}
  void flush() {}
  void reset() {}
}

class QueueOptimizer extends NullOptimizer {
  dynamic state;
  _PatternRule? match;
  int lastProcessed = 0;
  late final QueueOptimizerContext context;

  QueueOptimizer(super.queue) {
    _initOptimizerRules();
    context = QueueOptimizerContext(
      fnArray: queue.fnArray,
      argsArray: queue.argsArray,
      isOffscreenCanvasSupported: OperatorList.isOffscreenCanvasSupported,
    );
  }

  @override
  void optimize() {
    final fnArray = queue.fnArray;
    var i = lastProcessed;
    var ii = fnArray.length;
    var curState = state;
    var curMatch = match;

    if (curState == null && curMatch == null && i + 1 == ii && !_initialState.containsKey(fnArray[i])) {
      lastProcessed = ii;
      return;
    }

    while (i < ii) {
      if (curMatch != null) {
        final iterate = curMatch.iterateFn?.call(context, i) ?? false;
        if (iterate) {
          i++;
          continue;
        }
        i = curMatch.processFn?.call(context, i + 1) ?? i + 1;
        ii = fnArray.length;
        curMatch = null;
        curState = null;
        if (i >= ii) {
          break;
        }
      }

      final dynamic nextState = (curState as Map<int, dynamic>? ?? _initialState)[fnArray[i]];
      if (nextState == null || nextState is Map) {
        curState = nextState;
        i++;
        continue;
      }

      context.iCurr = i;
      i++;
      final rule = nextState as _PatternRule;
      if (rule.checkFn != null && !rule.checkFn!(context)) {
        curState = null;
        continue;
      }
      curMatch = rule;
      curState = null;
    }

    state = curState;
    match = curMatch;
    lastProcessed = i;
  }

  @override
  void flush() {
    while (match != null) {
      final length = queue.fnArray.length;
      lastProcessed = match!.processFn?.call(context, length) ?? length;
      match = null;
      state = null;
      optimize();
    }
  }

  @override
  void reset() {
    state = null;
    match = null;
    lastProcessed = 0;
  }
}

class OperatorList {
  static const int CHUNK_SIZE = 1000;
  static const int CHUNK_SIZE_ABOUT = CHUNK_SIZE - 5;
  static bool isOffscreenCanvasSupported = false;

  final dynamic _streamSink;
  final List<int> fnArray = <int>[];
  final List<dynamic> argsArray = <dynamic>[];
  late final NullOptimizer optimizer;
  final Set<String> dependencies = <String>{};
  int _totalLength = 0;
  int weight = 0;

  OperatorList([int intent = 0, dynamic streamSink]) : _streamSink = streamSink {
    optimizer = streamSink != null && (intent & RenderingIntentFlag.opList) == 0
        ? QueueOptimizer(this)
        : _DefaultNullOptimizer(this);
  }

  static void setOptions({bool isOffscreenCanvasSupported = false}) {
    OperatorList.isOffscreenCanvasSupported = isOffscreenCanvasSupported;
  }

  int get length => argsArray.length;

  int get totalLength => _totalLength + length;

  void addOp(int fn, [dynamic args = const []]) {
    optimizer.push(fn, args);
    weight++;
    if (_streamSink != null) {
      if (weight >= CHUNK_SIZE) {
        flush();
      } else if (weight >= CHUNK_SIZE_ABOUT && (fn == OPS.restore || fn == OPS.endText)) {
        flush();
      }
    }
  }

  void addImageOps(int fn, dynamic args, dynamic optionalContent, [bool hasMask = false]) {
    if (hasMask) {
      addOp(OPS.save);
      addOp(OPS.setGState, [
        [
          ['SMask', false]
        ]
      ]);
    }
    if (optionalContent != null) {
      addOp(OPS.beginMarkedContentProps, ['OC', optionalContent]);
    }

    addOp(fn, args);

    if (optionalContent != null) {
      addOp(OPS.endMarkedContent, []);
    }
    if (hasMask) {
      addOp(OPS.restore);
    }
  }

  void addDependency(String dependency) {
    if (dependencies.contains(dependency)) {
      return;
    }
    dependencies.add(dependency);
    addOp(OPS.dependency, [dependency]);
  }

  void addDependencies(Iterable<String> deps) {
    for (final dep in deps) {
      addDependency(dep);
    }
  }

  void addOpList(OperatorList opList) {
    for (final dep in opList.dependencies) {
      dependencies.add(dep);
    }
    for (var i = 0; i < opList.length; i++) {
      addOp(opList.fnArray[i], opList.argsArray[i]);
    }
  }

  Map<String, dynamic> getIR() {
    return {
      'fnArray': fnArray,
      'argsArray': argsArray,
      'length': length,
    };
  }

  void flush([bool lastChunk = false, dynamic separateAnnots]) {
    optimizer.flush();
    final len = length;
    _totalLength += len;

    if (_streamSink != null) {
      _streamSink.enqueue(
        {
          'fnArray': List<int>.from(fnArray),
          'argsArray': List<dynamic>.from(argsArray),
          'lastChunk': lastChunk,
          'separateAnnots': separateAnnots,
          'length': len,
        },
      );
    }

    dependencies.clear();
    fnArray.clear();
    argsArray.clear();
    weight = 0;
    optimizer.reset();
  }
}

class _DefaultNullOptimizer extends NullOptimizer {
  _DefaultNullOptimizer(super.queue);
}

/// CheckedOperatorList tracks whether operations require isolation (e.g. blend modes, smask).
class CheckedOperatorList extends OperatorList {
  bool needsIsolation = false;

  CheckedOperatorList([super.intent = 0, super.streamSink]);

  @override
  void addOp(int fn, [dynamic args = const []]) {
    if (!needsIsolation) {
      if (fn == OPS.beginGroup) {
        if (args is List && args.isNotEmpty && args[0] is CheckedOperatorList) {
          needsIsolation = (args[0] as CheckedOperatorList).needsIsolation;
        }
      } else if (fn == OPS.setGState) {
        if (args is List && args.isNotEmpty && args[0] is List) {
          for (final entry in args[0] as List) {
            if (entry is List && entry.length >= 2) {
              final key = entry[0];
              final val = entry[1];
              if (key == 'BM' && val != 'source-over') {
                needsIsolation = true;
                break;
              }
              if (key == 'SMask' && val != false) {
                needsIsolation = true;
                break;
              }
            }
          }
        }
      }
    }
    super.addOp(fn, args);
  }
}
