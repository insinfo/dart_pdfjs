import 'dart:async';
import 'dart:typed_data';

import 'package:pdfjs/pdfjs.dart';
import 'package:test/test.dart';

class _TestTransport extends PDFDataRangeTransport {
  final List<(int, int)> requests = [];
  final Map<int, Uint8List> responses = {};
  bool autoRespond;
  bool aborted = false;
  dynamic abortReason;

  _TestTransport(
    super.length, {
    super.initialData,
    super.progressiveDone,
    super.contentDispositionFilename,
    this.autoRespond = false,
  });

  @override
  void requestDataRange(int begin, int end) {
    requests.add((begin, end));
    if (autoRespond) {
      final response = responses[begin] ??
          Uint8List.fromList(List.generate(end - begin, (i) => begin + i));
      scheduleMicrotask(() => onDataRange(begin, response));
    }
  }

  @override
  void abort([dynamic reason]) {
    aborted = true;
    abortReason = reason;
    super.abort(reason);
  }
}

void main() {
  group('PDFDataRangeTransport', () {
    test('queues events until transportReady and preserves their order', () {
      final transport = _TestTransport(100);
      final events = <String>[];
      transport.addRangeListener(
          (begin, bytes) => events.add('range:$begin:${bytes.first}'));
      transport.addProgressListener(
          (loaded, total) => events.add('progress:$loaded:$total'));
      transport.addProgressiveReadListener(
          (bytes) => events.add('read:${bytes.length}'));
      transport.addProgressiveDoneListener(() => events.add('done'));

      transport.onDataProgress(5, 100);
      transport.onDataProgressiveRead([1, 2, 3]);
      transport.onDataRange(20, Uint8List.fromList([9, 8]));
      transport.onDataProgressiveDone();
      expect(events, isEmpty);

      transport.transportReady();
      expect(events, [
        'progress:5:100',
        'read:3',
        'range:20:9',
        'done',
      ]);
    });

    test('compatibility listener receives typed event maps', () {
      final transport = _TestTransport(10);
      final events = <Map<String, dynamic>>[];
      transport.transportReady(events.add);
      transport.onDataRange(2, [4, 5]);
      transport.onDataProgressiveRead([6]);
      transport.onDataProgressiveDone();

      expect(events.map((event) => event['type']),
          ['range', 'progressiveRead', 'progressiveDone']);
      expect(events.first['begin'], 2);
      expect(events.first['chunk'], Uint8List.fromList([4, 5]));
    });

    test('validates constructor and incoming ranges', () {
      expect(() => _TestTransport(-1), throwsRangeError);
      expect(
        () => _TestTransport(2, initialData: Uint8List(3)),
        throwsArgumentError,
      );
      final transport = _TestTransport(10)..transportReady();
      expect(() => transport.onDataRange(-1, [1]), throwsRangeError);
      expect(() => transport.onDataRange(9, [1, 2]), throwsRangeError);
      expect(() => transport.onDataProgress(-1), throwsRangeError);
      expect(() => transport.onDataRange(0, 'invalid'), throwsArgumentError);
    });

    test('abort discards queued and subsequent events', () {
      final transport = _TestTransport(20);
      var calls = 0;
      transport.addProgressiveReadListener((_) => calls++);
      transport.onDataProgressiveRead([1]);
      transport.abort('stop');
      transport.transportReady();
      transport.onDataProgressiveRead([2]);
      expect(calls, 0);
      expect(transport.aborted, isTrue);
      expect(transport.abortReason, 'stop');
    });
  });

  group('PDFDataTransportStream full reader', () {
    test('exposes headers, initial data, filename and completion', () async {
      final transport = _TestTransport(
        8,
        initialData: Uint8List.fromList([1, 2, 3]),
        progressiveDone: true,
        contentDispositionFilename: 'sample.pdf',
      );
      final stream = PDFDataTransportStream({
        'pdfDataRangeTransport': transport,
      });
      final reader = stream.getFullReader();
      await reader.headersReady;

      expect(reader.contentLength, 8);
      expect(reader.filename, 'sample.pdf');
      expect(reader.isStreamingSupported, isTrue);
      expect(reader.isRangeSupported, isTrue);
      expect(reader.loaded, 3);
      expect((await reader.read()).value, Uint8List.fromList([1, 2, 3]));
      expect((await reader.read()).done, isTrue);
    });

    test('honors disableStream and disableRange', () async {
      final transport = _TestTransport(8, progressiveDone: true);
      final stream = PDFDataTransportStream({
        'pdfDataRangeTransport': transport,
        'disableStream': true,
        'disableRange': true,
      });
      final reader = stream.getFullReader();
      await reader.headersReady;
      expect(reader.isStreamingSupported, isFalse);
      expect(reader.isRangeSupported, isFalse);
    });

    test('ignores a non-PDF content disposition filename', () async {
      final transport = _TestTransport(
        8,
        progressiveDone: true,
        contentDispositionFilename: 'sample.txt',
      );
      final reader = PDFDataTransportStream({
        'pdfDataRangeTransport': transport,
      }).getFullReader();
      await reader.headersReady;
      expect(reader.filename, isNull);
    });

    test('pending read waits for progressive data', () async {
      final transport = _TestTransport(8);
      final reader = PDFDataTransportStream({
        'pdfDataRangeTransport': transport,
      }).getFullReader();
      final read = reader.read();
      var completed = false;
      read.then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      transport.onDataProgressiveRead(Uint8List.fromList([7, 8]));
      final result = await read;
      expect(result.done, isFalse);
      expect(result.value, Uint8List.fromList([7, 8]));
      expect(reader.loaded, 2);
    });

    test('queues progressive chunks and reports progress', () async {
      final transport = _TestTransport(20);
      final reader = PDFDataTransportStream({
        'pdfDataRangeTransport': transport,
      }).getFullReader();
      final progress = <(int, int)>[];
      reader.onProgress = (loaded, total) => progress.add((loaded, total));

      transport.onDataProgressiveRead([1, 2]);
      transport.onDataProgressiveRead([3, 4, 5]);
      expect((await reader.read()).value, Uint8List.fromList([1, 2]));
      expect((await reader.read()).value, Uint8List.fromList([3, 4, 5]));
      expect(progress, [(2, 20), (5, 20)]);

      transport.onDataProgress(12, 20);
      expect(progress.last, (12, 20));
    });

    test('progressiveDone resolves pending reads', () async {
      final transport = _TestTransport(4);
      final reader = PDFDataTransportStream({
        'pdfDataRangeTransport': transport,
      }).getFullReader();
      final first = reader.read();
      final second = reader.read();
      transport.onDataProgressiveDone();
      expect((await first).done, isTrue);
      expect((await second).done, isTrue);
      expect((await reader.read()).done, isTrue);
    });

    test('done retains already queued data before ending', () async {
      final transport = _TestTransport(4);
      final reader = PDFDataTransportStream({
        'pdfDataRangeTransport': transport,
      }).getFullReader();
      transport.onDataProgressiveRead([1, 2]);
      transport.onDataProgressiveDone();
      expect((await reader.read()).value, Uint8List.fromList([1, 2]));
      expect((await reader.read()).done, isTrue);
    });

    test('cancel resolves all pending reads and discards queued bytes',
        () async {
      final transport = _TestTransport(4);
      final reader = PDFDataTransportStream({
        'pdfDataRangeTransport': transport,
      }).getFullReader();
      final reads = [reader.read(), reader.read(), reader.read()];
      reader.cancel('cancelled');
      for (final read in reads) {
        expect((await read).done, isTrue);
      }
      transport.onDataProgressiveRead([9]);
      expect((await reader.read()).done, isTrue);
    });

    test('only permits one full reader', () {
      final stream = PDFDataTransportStream({
        'pdfDataRangeTransport': _TestTransport(1),
      });
      stream.getFullReader();
      expect(() => stream.getFullReader(), throwsStateError);
    });
  });

  group('PDFDataTransportStream range readers', () {
    test('requests and asynchronously receives an exact range', () async {
      final transport = _TestTransport(100, autoRespond: true);
      transport.responses[20] = Uint8List.fromList([7, 6, 5, 4]);
      final stream = PDFDataTransportStream({
        'pdfDataRangeTransport': transport,
      });
      final reader = stream.getRangeReader(20, 24)!;
      expect(transport.requests, [(20, 24)]);
      final result = await reader.read();
      expect(result.value, Uint8List.fromList([7, 6, 5, 4]));
      expect((await reader.read()).done, isTrue);
    });

    test('pending reads after the first are completed as done', () async {
      final transport = _TestTransport(100);
      final stream = PDFDataTransportStream({
        'pdfDataRangeTransport': transport,
      });
      final reader = stream.getRangeReader(10, 20)!;
      final first = reader.read();
      final second = reader.read();
      final third = reader.read();
      transport.onDataRange(10, Uint8List(10));
      expect((await first).done, isFalse);
      expect((await second).done, isTrue);
      expect((await third).done, isTrue);
    });

    test('queued range response is returned exactly once', () async {
      final transport = _TestTransport(100);
      final stream = PDFDataTransportStream({
        'pdfDataRangeTransport': transport,
      });
      final reader = stream.getRangeReader(30, 32)!;
      transport.onDataRange(30, [8, 9]);
      expect((await reader.read()).value, Uint8List.fromList([8, 9]));
      expect((await reader.read()).done, isTrue);
    });

    test('validates requested ranges', () {
      final stream = PDFDataTransportStream({
        'pdfDataRangeTransport': _TestTransport(100),
      });
      expect(() => stream.getRangeReader(-1, 10), throwsRangeError);
      expect(() => stream.getRangeReader(10, 10), throwsRangeError);
      expect(() => stream.getRangeReader(80, 101), throwsRangeError);
    });

    test('skips ranges already covered by progressive bytes', () async {
      final stream = PDFDataTransportStream({
        'pdfDataRangeTransport': _TestTransport(
          100,
          initialData: Uint8List(20),
        ),
      });
      stream.getFullReader();
      expect(stream.getRangeReader(0, 20), isNull);
    });

    test('unexpected response offset is rejected', () {
      final transport = _TestTransport(100);
      final stream = PDFDataTransportStream({
        'pdfDataRangeTransport': transport,
      });
      stream.getRangeReader(10, 20);
      expect(() => transport.onDataRange(11, Uint8List(9)), throwsStateError);
    });

    test('cancel resolves a pending range read', () async {
      final stream = PDFDataTransportStream({
        'pdfDataRangeTransport': _TestTransport(100),
      });
      final reader = stream.getRangeReader(10, 20)!;
      final pending = reader.read();
      reader.cancel('stop');
      expect((await pending).done, isTrue);
    });

    test('cancelAllRequests aborts host transport and readers', () async {
      final transport = _TestTransport(100);
      final stream = PDFDataTransportStream({
        'pdfDataRangeTransport': transport,
      });
      final full = stream.getFullReader();
      final range = stream.getRangeReader(10, 20)!;
      final fullRead = full.read();
      final rangeRead = range.read();
      stream.cancelAllRequests('shutdown');
      expect((await fullRead).done, isTrue);
      expect((await rangeRead).done, isTrue);
      expect(transport.aborted, isTrue);
      expect(transport.abortReason, 'shutdown');
    });
  });
}
