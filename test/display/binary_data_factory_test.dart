// Copyright 2026. Apache License 2.0.

@TestOn('browser')

import 'package:pdfjs/src/display/binary_data_factory.dart';
import 'package:test/test.dart';

void main() {
  group('DOMBinaryDataFactory', () {
    test('requires the URL corresponding to the requested resource', () async {
      final factory = DOMBinaryDataFactory();

      await expectLater(
        factory.fetch(kind: 'cMapUrl', filename: 'Test'),
        throwsStateError,
      );
      await expectLater(
        factory.fetch(kind: 'standardFontDataUrl', filename: 'Test'),
        throwsStateError,
      );
      await expectLater(
        factory.fetch(kind: 'wasmUrl', filename: 'Test'),
        throwsStateError,
      );
    });

    test('rejects unknown resource kinds', () async {
      final factory = DOMBinaryDataFactory();

      await expectLater(
        factory.fetch(kind: 'unknown', filename: 'Test'),
        throwsUnimplementedError,
      );
    });

    test('loads uncompressed CMaps as text bytes', () async {
      final factory = DOMBinaryDataFactory(cMapUrl: 'data:text/plain,');

      final data = await factory.fetch(kind: 'cMapUrl', filename: 'ABC');

      expect(data, [65, 66, 67]);
    });

    test('loads binary resources as bytes', () async {
      final factory = DOMBinaryDataFactory(
        wasmUrl: 'data:application/octet-stream;base64,AQID',
      );

      final data = await factory.fetch(kind: 'wasmUrl', filename: '');

      expect(data, [1, 2, 3]);
    });

    test('reports the resource type and URL when fetching fails', () async {
      final factory = DOMBinaryDataFactory(wasmUrl: 'invalid://resource/');

      await expectLater(
        factory.fetch(kind: 'wasmUrl', filename: 'module.wasm'),
        throwsA(
          predicate(
            (error) => error.toString().contains(
                  'Unable to load wasm data at: '
                  'invalid://resource/module.wasm',
                ),
          ),
        ),
      );
    });
  });
}
