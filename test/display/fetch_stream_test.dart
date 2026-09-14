// Copyright 2026. Apache License 2.0.

@TestOn('browser')

import 'dart:typed_data';

import 'package:pdfjs/src/display/fetch_stream.dart';
import 'package:pdfjs/src/display/network.dart';
import 'package:pdfjs/src/display/network_stream.dart';
import 'package:test/test.dart';

Uint8List _bytesOf(Map<String, dynamic> result) {
  return Uint8List.view(result['value'] as ByteBuffer);
}

void main() {
  group('PDFFetchStream', () {
    const dataUrl = 'data:application/pdf;base64,JVBERi0xLjQK';

    test('validates its source URL and allows only one full reader', () {
      expect(
        () => PDFFetchStream({'url': 'file:///test.pdf'}),
        throwsArgumentError,
      );
      expect(() => PDFFetchStream({}), throwsArgumentError);

      final stream = PDFFetchStream({'url': dataUrl});
      stream.getFullReader();
      expect(stream.getFullReader, throwsStateError);
    });

    test('fetches a complete PDF and reports progress', () async {
      final stream = PDFFetchStream({
        'url': dataUrl,
        'disableStream': false,
        'rangeChunkSize': 4,
      });
      final reader = stream.getFullReader();
      var progress = <int>[];
      reader.onProgress = (loaded, total) => progress = [loaded, total];

      await reader.headersReady;
      final first = await reader.read();
      final second = await reader.read();

      expect(String.fromCharCodes(_bytesOf(first)), '%PDF-1.4\n');
      expect(first['done'], isFalse);
      expect(second['done'], isTrue);
      expect(reader.loaded, 9);
      expect(stream.progressiveDataLength, 9);
      expect(progress.first, 9);
      expect(reader.isStreamingSupported, isTrue);
    });

    test('fetches ranges and slices servers that ignore Range', () async {
      final stream = PDFFetchStream({'url': dataUrl});
      final fullReader = stream.getFullReader();
      await fullReader.headersReady;

      final rangeReader = stream.getRangeReader(1, 4)!;
      final result = await rangeReader.read();

      expect(String.fromCharCodes(_bytesOf(result)), 'PDF');
      expect((await rangeReader.read())['done'], isTrue);
    });

    test('cancels readers and chooses the correct network backend', () async {
      final stream = PDFFetchStream({'url': dataUrl});
      final reader = stream.getFullReader();
      await reader.headersReady;
      stream.cancelAllRequests('stop');

      expect((await reader.read())['done'], isTrue);
      expect(getNetworkStream('https://example.com/file.pdf'), PDFFetchStream);
      expect(getNetworkStream('file:///file.pdf'), PDFNetworkStream);
    });
  });
}
