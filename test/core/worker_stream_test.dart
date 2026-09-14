import 'dart:async';
import 'dart:typed_data';

import 'package:pdfjs/src/core/worker_stream.dart';
import 'package:test/test.dart';

class MockReadableReader {
  final List<Uint8List> chunks;
  bool cancelled = false;

  MockReadableReader(this.chunks);

  Future<Map<String, dynamic>> read() async {
    if (chunks.isEmpty) {
      return {'value': null, 'done': true};
    }
    final chunk = chunks.removeAt(0);
    return {'value': chunk, 'done': false};
  }

  void cancel(dynamic reason) {
    cancelled = true;
  }
}

class MockReadableStream {
  final MockReadableReader reader;
  MockReadableStream(this.reader);

  MockReadableReader getReader() => reader;
}

class MockMessageHandler {
  final Map<String, dynamic> headersData;
  final List<Uint8List> chunks;
  String? lastAction;
  dynamic lastData;

  MockMessageHandler({required this.headersData, required this.chunks});

  MockReadableStream sendWithStream(String action, [dynamic data]) {
    lastAction = action;
    lastData = data;
    return MockReadableStream(MockReadableReader(List<Uint8List>.from(chunks)));
  }

  Future<dynamic> sendWithPromise(String action, [dynamic data]) async {
    if (action == 'ReaderHeadersReady') {
      return headersData;
    }
    return null;
  }
}

class MockStreamSource {
  final MockMessageHandler msgHandler;
  MockStreamSource(this.msgHandler);
}

void main() {
  group('PDFWorkerStream', () {
    test('PDFWorkerStreamReader handles headers and reads chunks', () async {
      final msgHandler = MockMessageHandler(
        headersData: {
          'contentLength': 1024,
          'isStreamingSupported': true,
          'isRangeSupported': true,
        },
        chunks: [
          Uint8List.fromList([1, 2, 3]),
          Uint8List.fromList([4, 5]),
        ],
      );

      final stream = PDFWorkerStream(MockStreamSource(msgHandler));
      final reader = stream.getFullReader() as PDFWorkerStreamReader;

      await reader.headersReady;
      expect(reader.contentLength, equals(1024));
      expect(reader.isStreamingSupported, isTrue);
      expect(reader.isRangeSupported, isTrue);

      final r1 = await reader.read();
      expect(r1.done, isFalse);
      expect(r1.value, equals(Uint8List.fromList([1, 2, 3])));

      final r2 = await reader.read();
      expect(r2.done, isFalse);
      expect(r2.value, equals(Uint8List.fromList([4, 5])));

      final r3 = await reader.read();
      expect(r3.done, isTrue);

      reader.cancel('done');
    });

    test('PDFWorkerStreamRangeReader requests range and reads chunks', () async {
      final msgHandler = MockMessageHandler(
        headersData: {},
        chunks: [
          Uint8List.fromList([10, 20]),
        ],
      );

      final stream = PDFWorkerStream(MockStreamSource(msgHandler));
      final rangeReader = stream.getRangeReader(10, 20) as PDFWorkerStreamRangeReader;

      expect(msgHandler.lastAction, equals('GetRangeReader'));
      expect(msgHandler.lastData, equals({'begin': 10, 'end': 20}));

      final r1 = await rangeReader.read();
      expect(r1.done, isFalse);
      expect(r1.value, equals(Uint8List.fromList([10, 20])));

      final r2 = await rangeReader.read();
      expect(r2.done, isTrue);

      rangeReader.cancel('abort');
    });
  });
}
