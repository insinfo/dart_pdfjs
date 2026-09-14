// Copyright 2025 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:test/test.dart';
import 'package:pdfjs/src/core/to_unicode_map.dart';

void main() {
  group('ToUnicodeMap', () {
    test('should correctly map Extension B characters using codePointAt', () {
      final cmap = {0x20: '\u{20000}'}; // Example Extension B character (equivalent to surrogate pair \uD840\uDC00)
      final toUnicodeMap = ToUnicodeMap(cmap);

      const expected = 0x20000;
      int? actual;
      toUnicodeMap.forEach((charCode, unicode) {
        if (charCode.toString() == (0x20).toString()) {
          actual = unicode;
        }
      });

      expect(actual, equals(expected));
    });
  });
}
