// Copyright 2026. Apache License 2.0.

import 'package:pdfjs/src/display/pdf_objects.dart';
import 'package:test/test.dart';

class _Bitmap {
  bool closed = false;

  void close() {
    closed = true;
  }
}

class _ImageData {
  final _Bitmap bitmap;

  _ImageData(this.bitmap);
}

void main() {
  group('PDFObjects', () {
    test('clear closes bitmap resources stored in maps and objects', () {
      final mapBitmap = _Bitmap();
      final objectBitmap = _Bitmap();
      final objects = PDFObjects()
        ..resolve('map', {'bitmap': mapBitmap})
        ..resolve('object', _ImageData(objectBitmap))
        ..resolve('plain', {'value': 42});

      objects.clear();

      expect(mapBitmap.closed, isTrue);
      expect(objectBitmap.closed, isTrue);
      expect(objects.entries, isEmpty);
      expect(objects.has('map'), isFalse);
    });

    test('iterates only resolved objects and protects their lifecycle', () {
      final objects = PDFObjects();
      objects.get('pending', (_) {});
      objects.resolve('ready', 42);

      final entries = objects.entries.toList();
      expect(entries, hasLength(1));
      expect(entries.single.key, 'ready');
      expect(entries.single.value, 42);
      expect(objects.delete('pending'), isFalse);
      expect(objects.delete('ready'), isTrue);
      expect(() => objects.resolve('duplicate', 1), returnsNormally);
      expect(() => objects.resolve('duplicate', 2), throwsStateError);
    });
  });
}
