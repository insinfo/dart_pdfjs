// Copyright 2026. Apache License 2.0.

import 'dart:typed_data';
import 'package:pdfjs/src/core/base_stream.dart';
import 'package:pdfjs/src/core/core_utils.dart';
import 'package:pdfjs/src/core/pdf_manager.dart';
import 'package:pdfjs/src/core/stream.dart' as pdf_stream;
import 'package:test/test.dart';

class _ReadResult {
  final bool done;
  final dynamic value;
  _ReadResult({required this.done, this.value});
}

class _FakeRangeReader {
  final int begin;
  final int end;
  bool _read = false;

  _FakeRangeReader(this.begin, this.end);

  Future<_ReadResult> read() async {
    if (!_read) {
      _read = true;
      return _ReadResult(
        done: false,
        value: Uint8List(end - begin),
      );
    }
    return _ReadResult(done: true, value: null);
  }
}

class _FakeSource {
  final List<Map<String, dynamic>> requestedRanges = [];

  _FakeRangeReader getRangeReader(int begin, int end) {
    requestedRanges.add({'begin': begin, 'end': end});
    return _FakeRangeReader(begin, end);
  }
}

void main() {
  group('PDFManager / LocalPdfManager', () {
    test('LocalPdfManager handles static properties and ensure', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final stream = pdf_stream.Stream(data);
      final manager = LocalPdfManager(
        source: stream,
        docBaseUrl: 'https://example.com/doc.pdf',
        docId: 'test-doc-id',
        password: 'secret',
      );

      expect(manager.docBaseUrl, equals('https://example.com/doc.pdf'));
      expect(manager.docId, equals('test-doc-id'));
      expect(manager.password, equals('secret'));

      // ensure with function
      final resFn = await manager.ensure(null, () => 42);
      expect(resFn, equals(42));

      // ensure with function with args
      final resFnArgs = await manager.ensure(null, (int a, int b) => a + b, [10, 20]);
      expect(resFnArgs, equals(30));

      // ensure with Map property
      final mapObj = {'key': 'value', 'func': (int x) => x * 2};
      final resMapVal = await manager.ensure(mapObj, 'key');
      expect(resMapVal, equals('value'));
      final resMapFn = await manager.ensure(mapObj, 'func', [5]);
      expect(resMapFn, equals(10));

      // requestLoadedStream
      final loaded = await manager.requestLoadedStream();
      expect(loaded, isA<BaseStream>());
      expect(loaded.length, equals(5));
    });
  });

  group('PDFManager / NetworkPdfManager', () {
    test('NetworkPdfManager handles ensure with MissingDataException retry', () async {
      final fakeSource = _FakeSource();
      final manager = NetworkPdfManager(
        source: fakeSource,
        length: 1000,
        rangeChunkSize: 64,
        docBaseUrl: 'https://example.com/remote.pdf',
      );

      expect(manager.docBaseUrl, equals('https://example.com/remote.pdf'));

      var attempts = 0;
      int missingDataAction() {
        attempts++;
        if (attempts == 1) {
          throw MissingDataException(100, 200);
        }
        return 999;
      }

      final result = await manager.ensure(null, missingDataAction);
      expect(result, equals(999));
      expect(attempts, equals(2));
      expect(fakeSource.requestedRanges.length, equals(1));
      expect(fakeSource.requestedRanges.first['begin'], equals(64));
      expect(fakeSource.requestedRanges.first['end'], equals(256));
    });

    test('NetworkPdfManager sendProgressiveData forwards chunks', () {
      final fakeSource = _FakeSource();
      final manager = NetworkPdfManager(
        source: fakeSource,
        length: 100,
        rangeChunkSize: 50,
      );

      // Should accept Uint8List without throwing
      expect(() => manager.sendProgressiveData(Uint8List.fromList([1, 2, 3])), returnsNormally);
      // Should accept List<int> without throwing
      expect(() => manager.sendProgressiveData([4, 5, 6]), returnsNormally);
    });
  });
}
