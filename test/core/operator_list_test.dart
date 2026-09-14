// Copyright 2017 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:pdfjs/src/core/operator_list.dart';
import 'package:pdfjs/src/shared/util.dart';
import 'package:test/test.dart';

class MockStreamSink {
  final List<Map<String, dynamic>> enqueued = [];
  void enqueue(Map<String, dynamic> chunk) {
    enqueued.add(chunk);
  }
}

void main() {
  group('OperatorList', () {
    test('basic addOp and getIR', () {
      final opList = OperatorList();
      expect(opList.length, equals(0));

      opList.addOp(OPS.save);
      opList.addOp(OPS.setLineWidth, [2.0]);
      opList.addOp(OPS.restore);

      expect(opList.length, equals(3));
      final ir = opList.getIR();
      expect(ir['fnArray'], equals([OPS.save, OPS.setLineWidth, OPS.restore]));
      expect(ir['argsArray'], equals([[], [2.0], []]));
    });

    test('dependencies are uniquely registered', () {
      final opList = OperatorList();
      opList.addDependency('font_1');
      opList.addDependency('font_1'); // Duplicate
      opList.addDependency('font_2');

      expect(opList.dependencies, containsAll(['font_1', 'font_2']));
      expect(opList.dependencies.length, equals(2));

      // There should only be two dependency operations added
      final ir = opList.getIR();
      expect(ir['fnArray'], equals([OPS.dependency, OPS.dependency]));
      expect(ir['argsArray'], equals([['font_1'], ['font_2']]));
    });

    test('addImageOps wraps with mask and optional content', () {
      final opList = OperatorList();
      opList.addImageOps(
        OPS.paintImageXObject,
        ['img_1'],
        'OC_1',
        true, // hasMask
      );

      final ir = opList.getIR();
      final fns = ir['fnArray'] as List<int>;
      expect(fns.first, equals(OPS.save));
      expect(fns.contains(OPS.beginMarkedContentProps), isTrue);
      expect(fns.contains(OPS.paintImageXObject), isTrue);
      expect(fns.contains(OPS.endMarkedContent), isTrue);
      expect(fns.last, equals(OPS.restore));
    });

    test('flush passes data to stream sink and clears queue', () {
      final sink = MockStreamSink();
      final opList = OperatorList(0, sink);

      opList.addOp(OPS.save);
      opList.addOp(OPS.restore);
      expect(opList.length, equals(2));

      opList.flush(true);
      expect(opList.length, equals(0));
      expect(opList.totalLength, equals(2));
      expect(sink.enqueued.length, equals(1));
      expect(sink.enqueued[0]['lastChunk'], isTrue);
      expect(sink.enqueued[0]['length'], equals(2));
    });
  });

  group('CheckedOperatorList', () {
    test('detects isolation needed for blend mode', () {
      final checked = CheckedOperatorList();
      expect(checked.needsIsolation, isFalse);

      checked.addOp(OPS.setGState, [
        [
          ['BM', 'multiply'],
        ],
      ]);

      expect(checked.needsIsolation, isTrue);
    });

    test('detects isolation needed for soft mask', () {
      final checked = CheckedOperatorList();
      expect(checked.needsIsolation, isFalse);

      checked.addOp(OPS.setGState, [
        [
          ['SMask', 'mask_obj'],
        ],
      ]);

      expect(checked.needsIsolation, isTrue);
    });

    test('ignores normal blend mode and false soft mask', () {
      final checked = CheckedOperatorList();
      checked.addOp(OPS.setGState, [
        [
          ['BM', 'source-over'],
          ['SMask', false],
        ],
      ]);

      expect(checked.needsIsolation, isFalse);
    });

    test('propagates isolation from nested CheckedOperatorList in beginGroup', () {
      final child = CheckedOperatorList();
      child.addOp(OPS.setGState, [
        [['BM', 'screen']]
      ]);
      expect(child.needsIsolation, isTrue);

      final parent = CheckedOperatorList();
      expect(parent.needsIsolation, isFalse);
      parent.addOp(OPS.beginGroup, [child]);
      expect(parent.needsIsolation, isTrue);
    });
  });

  group('QueueOptimizer', () {
    test('optimizes constructPath surrounded by save/restore with identity transform', () {
      final sink = MockStreamSink();
      final opList = OperatorList(0, sink);

      // (save, transform, constructPath, restore)
      final transform = [1, 0, 0, 1, 10, 20]; // translation (10, 20)
      final pathBuffer = [DrawOPS.moveTo, 0.0, 0.0, DrawOPS.lineTo, 100.0, 50.0];
      final minMax = [0.0, 0.0, 100.0, 50.0];
      final constructPathArgs = [OPS.fill, [pathBuffer], minMax];

      opList.addOp(OPS.save);
      opList.addOp(OPS.transform, transform);
      opList.addOp(OPS.constructPath, constructPathArgs);
      opList.addOp(OPS.restore);

      opList.flush();

      expect(sink.enqueued.length, equals(1));
      final fnArray = sink.enqueued[0]['fnArray'] as List<int>;
      // The 4 operations (save, transform, constructPath, restore) collapsed to 1 constructPath!
      expect(fnArray, equals([OPS.constructPath]));

      // Path buffer coords translated by (10, 20)
      expect(pathBuffer[1], equals(10.0));
      expect(pathBuffer[2], equals(20.0));
      expect(pathBuffer[4], equals(110.0));
      expect(pathBuffer[5], equals(70.0));

      // Bounding box updated
      expect(minMax[0], equals(10.0));
      expect(minMax[1], equals(20.0));
      expect(minMax[2], equals(110.0));
      expect(minMax[3], equals(70.0));
    });
  });
}
