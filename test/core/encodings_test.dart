// Copyright 2017 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:test/test.dart';
import 'package:pdfjs/src/core/encodings.dart';

void main() {
  group('encodings', () {
    group('getEncoding', () {
      test('fetches a valid array for known encoding names', () {
        const knownEncodingNames = [
          'ExpertEncoding',
          'MacExpertEncoding',
          'MacRomanEncoding',
          'StandardEncoding',
          'SymbolSetEncoding',
          'WinAnsiEncoding',
          'ZapfDingbatsEncoding',
        ];

        for (final knownEncodingName in knownEncodingNames) {
          final encoding = getEncoding(knownEncodingName);
          expect(encoding, isA<List<String>>());
          expect(encoding!.length, equals(256));

          for (final item in encoding) {
            expect(item, isA<String>());
          }
        }
      });

      test('fetches `null` for unknown encoding names', () {
        expect(getEncoding('FooBarEncoding'), isNull);
      });
    });
  });
}
