// Copyright 2017 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:test/test.dart';
import 'package:pdfjs/src/core/glyphlist.dart';
import 'package:pdfjs/src/core/unicode.dart';

void main() {
  group('unicode', () {
    group('mapSpecialUnicodeValues', () {
      test('should not re-map normal Unicode values', () {
        // A
        expect(mapSpecialUnicodeValues(0x0041), equals(0x0041));
        // fi
        expect(mapSpecialUnicodeValues(0xfb01), equals(0xfb01));
      });

      test('should re-map special Unicode values', () {
        // copyrightsans => copyright
        expect(mapSpecialUnicodeValues(0xf8e9), equals(0x00a9));
        // Private Use Area characters
        expect(mapSpecialUnicodeValues(0xffff), equals(0));
      });
    });

    group('getCharUnicodeCategory', () {
      test('should correctly determine the character category', () {
        final tests = <String, Map<String, bool>>{
          // Whitespace
          ' ': {
            'isZeroWidthDiacritic': false,
            'isInvisibleFormatMark': false,
            'isWhitespace': true,
          },
          '\t': {
            'isZeroWidthDiacritic': false,
            'isInvisibleFormatMark': false,
            'isWhitespace': true,
          },
          '\u2001': {
            'isZeroWidthDiacritic': false,
            'isInvisibleFormatMark': false,
            'isWhitespace': true,
          },
          '\uFEFF': {
            'isZeroWidthDiacritic': false,
            'isInvisibleFormatMark': false,
            'isWhitespace': true,
          },

          // Diacritic
          '\u0302': {
            'isZeroWidthDiacritic': true,
            'isInvisibleFormatMark': false,
            'isWhitespace': false,
          },
          '\u0344': {
            'isZeroWidthDiacritic': true,
            'isInvisibleFormatMark': false,
            'isWhitespace': false,
          },
          '\u0361': {
            'isZeroWidthDiacritic': true,
            'isInvisibleFormatMark': false,
            'isWhitespace': false,
          },

          // Invisible format mark
          '\u200B': {
            'isZeroWidthDiacritic': false,
            'isInvisibleFormatMark': true,
            'isWhitespace': false,
          },
          '\u200D': {
            'isZeroWidthDiacritic': false,
            'isInvisibleFormatMark': true,
            'isWhitespace': false,
          },

          // No whitespace or diacritic or invisible format mark
          'a': {
            'isZeroWidthDiacritic': false,
            'isInvisibleFormatMark': false,
            'isWhitespace': false,
          },
          '1': {
            'isZeroWidthDiacritic': false,
            'isInvisibleFormatMark': false,
            'isWhitespace': false,
          },
        };

        for (final entry in tests.entries) {
          final res = getCharUnicodeCategory(entry.key);
          expect(res.isWhitespace, equals(entry.value['isWhitespace']),
              reason: 'character "${entry.key}" isWhitespace');
          expect(res.isZeroWidthDiacritic,
              equals(entry.value['isZeroWidthDiacritic']),
              reason: 'character "${entry.key}" isZeroWidthDiacritic');
          expect(res.isInvisibleFormatMark,
              equals(entry.value['isInvisibleFormatMark']),
              reason: 'character "${entry.key}" isInvisibleFormatMark');
        }
      });
    });

    group('getUnicodeForGlyph', () {
      late Map<String, int> standardMap;
      late Map<String, int> dingbatsMap;

      setUpAll(() {
        standardMap = getGlyphsUnicode();
        dingbatsMap = getDingbatsGlyphsUnicode();
      });

      test('should get Unicode values for valid glyph names', () {
        expect(getUnicodeForGlyph('A', standardMap), equals(0x0041));
        expect(getUnicodeForGlyph('a1', dingbatsMap), equals(0x2701));
      });

      test(
          'should recover Unicode values from uniXXXX/uXXXX{XX} glyph names',
          () {
        expect(getUnicodeForGlyph('uni0041', standardMap), equals(0x0041));
        expect(getUnicodeForGlyph('u0041', standardMap), equals(0x0041));

        expect(getUnicodeForGlyph('uni2701', dingbatsMap), equals(0x2701));
        expect(getUnicodeForGlyph('u2701', dingbatsMap), equals(0x2701));
      });

      test('should not get Unicode values for invalid glyph names', () {
        expect(getUnicodeForGlyph('Qwerty', standardMap), equals(-1));
        expect(getUnicodeForGlyph('Qwerty', dingbatsMap), equals(-1));
      });
    });

    group('getUnicodeRangeFor', () {
      test('should get correct Unicode range', () {
        // A (Basic Latin)
        expect(getUnicodeRangeFor(0x0041), equals(0));
        // fi (Alphabetic Presentation Forms)
        expect(getUnicodeRangeFor(0xfb01), equals(62));
        // Combining diacritic (Cyrillic Extended-A)
        expect(getUnicodeRangeFor(0x2dff), equals(9));
      });

      test('should not get a Unicode range', () {
        expect(getUnicodeRangeFor(0xaa60), equals(-1));
      });
    });
  });
}
