import 'package:test/test.dart';

import 'package:pdfjs/src/core/font_substitutions.dart';

class _IdFactory implements FontSubstitutionIdFactory {
  _IdFactory(this.docId);

  final String docId;
  int nextId = 0;

  @override
  String createFontId() => '${nextId++}';

  @override
  String getDocId() => docId;
}

void main() {
  group('getFontSubstitution', () {
    test('generates a Helvetica substitution with local fonts and path', () {
      final cache = <String, FontSubstitutionInfo?>{};
      final info = getFontSubstitution(
        cache,
        _IdFactory('doc'),
        '/standard_fonts/',
        'Helvetica-Bold',
        null,
        'Type1',
      )!;

      expect(info.loadedName, 'doc_s0');
      expect(info.baseFontName, 'Helvetica-Bold');
      expect(info.css, '"Helvetica",doc_s0,sans-serif');
      expect(info.guessFallback, isFalse);
      expect(info.style, same(boldFontStyle));
      expect(info.src, contains('local(Helvetica Bold)'));
      expect(
          info.src, contains('url(/standard_fonts/LiberationSans-Bold.ttf)'));
    });

    test('strips subset prefixes for TrueType and Type1 fonts', () {
      final cache = <String, FontSubstitutionInfo?>{};
      final info = getFontSubstitution(
        cache,
        _IdFactory('doc'),
        null,
        'ABCDEF+Times-Italic',
        null,
        'TrueType',
      )!;

      expect(info.baseFontName, 'Times-Italic');
      expect(info.css, '"Times",doc_s0,serif');
      expect(info.style, same(italicFontStyle));
    });

    test('uses known aliases before falling back to guessed fonts', () {
      final cache = <String, FontSubstitutionInfo?>{};
      final info = getFontSubstitution(
        cache,
        _IdFactory('doc'),
        null,
        'Arial-Black',
        null,
        'TrueType',
      )!;

      expect(info.baseFontName, 'ArialBlack');
      expect(info.guessFallback, isFalse);
      expect(info.style, same(blackFontStyle));
      expect(info.src, contains('local(Arial Black)'));
      expect(info.css, '"ArialBlack",doc_s0,sans-serif');
    });

    test('falls back to a standard font and prepends valid base font', () {
      final cache = <String, FontSubstitutionInfo?>{};
      final info = getFontSubstitution(
        cache,
        _IdFactory('doc'),
        null,
        'Fancy Font',
        'Courier',
        'Type1',
      )!;

      expect(info.baseFontName, 'FancyFont');
      expect(info.css, '"FancyFont",doc_s0,monospace');
      expect(info.src, startsWith('local(FancyFont),local(Courier)'));
    });

    test('guesses valid unknown fonts and caches the result', () {
      final cache = <String, FontSubstitutionInfo?>{};
      final factory = _IdFactory('doc');
      final first = getFontSubstitution(
        cache,
        factory,
        null,
        'MyBoldItalicFont',
        null,
        'Type0',
      )!;
      final second = getFontSubstitution(
        cache,
        factory,
        null,
        'MyBoldItalicFont',
        null,
        'Type0',
      );

      expect(first, same(second));
      expect(first.guessFallback, isTrue);
      expect(first.style, same(boldItalicFontStyle));
      expect(factory.nextId, 1);
    });

    test('rejects invalid font names when no substitution exists', () {
      final cache = <String, FontSubstitutionInfo?>{};
      final info = getFontSubstitution(
        cache,
        _IdFactory('doc'),
        null,
        'Bad;Font',
        null,
        'Type0',
      );

      expect(info, isNull);
      expect(cache, containsPair('Bad;Font', null));
    });
  });
}
