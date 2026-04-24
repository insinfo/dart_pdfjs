import 'package:test/test.dart';

import 'package:pdfjs/src/core/core_utils.dart';

void main() {
  group('validateFontName', () {
    test('accepts CSS custom identifiers and quoted names', () {
      expect(validateFontName('Helvetica'), isTrue);
      expect(validateFontName('Liberation Sans'), isTrue);
      expect(validateFontName(r'Font\ Name'), isTrue);
      expect(validateFontName('"Times New Roman"'), isTrue);
      expect(validateFontName("'Courier New'"), isTrue);
    });

    test('rejects invalid custom identifiers', () {
      expect(validateFontName('123Font'), isFalse);
      expect(validateFontName('-5Font'), isFalse);
      expect(validateFontName('--Font'), isFalse);
      expect(validateFontName('Bad;Font'), isFalse);
      expect(validateFontName('Bad(Font)'), isFalse);
    });

    test('rejects unescaped matching quotes inside quoted strings', () {
      expect(validateFontName('"Bad " Font"'), isFalse);
      expect(validateFontName("'Bad ' Font'"), isFalse);
      expect(validateFontName(r'"Good \" Font"'), isTrue);
    });
  });
}
