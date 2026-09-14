@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:pdfjs/src/display/network.dart';
import 'package:test/test.dart';

void main() {
  const dataUrl = 'data:application/pdf;base64,JVBERi0xLjQKJXRlc3QK';

  group('PDFNetworkStream', () {
    test('requires a URL and identifies HTTP sources', () {
      expect(() => PDFNetworkStream({}), throwsArgumentError);
      expect(() => PDFNetworkStream({'url': ''}), throwsArgumentError);

      final http = PDFNetworkStream({'url': 'https://example.com/a.pdf'});
      final data = PDFNetworkStream({'url': dataUrl});
      expect(http.isHttp, isTrue);
      expect(data.isHttp, isFalse);
      expect(data.url.scheme, 'data');
    });

    test('reads the complete response as one non-streaming chunk', () async {
      final stream = PDFNetworkStream({
        'url': dataUrl,
        'disableStream': false,
      });
      final reader = stream.getFullReader();
      var progress = <int>[];
      reader.onProgress = (loaded, total) => progress = [loaded, total];

      await reader.headersReady;
      final first = await reader.read();
      final second = await reader.read();

      expect(
          String.fromCharCodes(networkResultBytes(first)), '%PDF-1.4\n%test\n');
      expect(first['done'], isFalse);
      expect(second['done'], isTrue);
      expect(reader.isStreamingSupported, isFalse);
      expect(reader.loaded, 15);
      expect(stream.progressiveDataLength, 15);
      expect(progress.first, 15);
    });

    test('allows only one full reader', () {
      final stream = PDFNetworkStream({'url': dataUrl});
      stream.getFullReader();
      expect(stream.getFullReader, throwsStateError);
    });

    test('reads custom ranges when the server ignores Range', () async {
      final stream = PDFNetworkStream({'url': dataUrl});
      final fullReader = stream.getFullReader();
      await fullReader.headersReady;

      final range1 = stream.getRangeReader(1, 4)!;
      final range2 = stream.getRangeReader(10, 14)!;
      expect(
          String.fromCharCodes(networkResultBytes(await range1.read())), 'PDF');
      expect(String.fromCharCodes(networkResultBytes(await range2.read())),
          'test');
      expect((await range1.read())['done'], isTrue);
      expect((await range2.read())['done'], isTrue);
    });

    test('validates ranges and skips already downloaded data', () async {
      final stream = PDFNetworkStream({'url': dataUrl});
      expect(() => stream.getRangeReader(-1, 2), throwsRangeError);
      expect(() => stream.getRangeReader(4, 4), throwsRangeError);

      final reader = stream.getFullReader();
      await reader.headersReady;
      await reader.read();
      expect(stream.getRangeReader(0, 10), isNull);
    });

    test('cancels full and range readers consistently', () async {
      final stream = PDFNetworkStream({'url': dataUrl});
      final full = stream.getFullReader();
      await full.headersReady;
      final range = stream.getRangeReader(1, 4)!;

      stream.cancelAllRequests('no longer needed');

      expect((await full.read())['done'], isTrue);
      expect((await range.read())['done'], isTrue);
    });

    test('converts ByteBuffer and Uint8List network results', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(networkResultBytes({'value': bytes}), [1, 2, 3]);
      expect(networkResultBytes({'value': bytes.buffer}), [1, 2, 3]);
      expect(() => networkResultBytes({'done': true}), throwsStateError);
    });
  });
}
