import 'dart:typed_data';

import 'package:pdfjs/src/core/chunked_stream.dart';
import 'package:pdfjs/src/core/core_utils.dart';
import 'package:test/test.dart';

void main() {
  group('ChunkedStream', () {
    test('chunks tracking and onReceiveData', () {
      final stream = ChunkedStream(100, 20, null);
      expect(stream.numChunks, 5);
      expect(stream.numChunksLoaded, 0);
      expect(stream.isDataLoaded, isFalse);
      expect(stream.getMissingChunks(), [0, 1, 2, 3, 4]);

      // Receive chunk 0 (0..20)
      final chunk0 = Uint8List(20)..fillRange(0, 20, 42);
      stream.onReceiveData(0, chunk0);
      expect(stream.hasChunk(0), isTrue);
      expect(stream.hasChunk(1), isFalse);
      expect(stream.numChunksLoaded, 1);

      // Accessing within loaded chunk works
      stream.pos = 0;
      expect(stream.getByte(), 42);

      // Accessing missing chunk throws MissingDataException
      stream.pos = 25;
      expect(() => stream.getByte(), throwsA(isA<MissingDataException>()));
    });

    test('makeSubStream propagates loaded status', () {
      final stream = ChunkedStream(40, 20, null);
      final c0 = Uint8List(20)..fillRange(0, 20, 1);
      final c1 = Uint8List(20)..fillRange(0, 20, 2);
      stream.onReceiveData(0, c0);
      stream.onReceiveData(20, c1);

      expect(stream.isDataLoaded, isTrue);

      final sub = stream.makeSubStream(10, 20);
      expect(sub.getByte(), 1);
      sub.pos = 20;
      expect(sub.getByte(), 2);
    });
  });
}
