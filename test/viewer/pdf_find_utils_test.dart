import 'package:test/test.dart';

import '../../example/src/pdf_find_utils.dart';

void main() {
  group('getCharacterType', () {
    test('classifies the representative upstream characters', () {
      final cases = <String, CharacterType>{
        'A': CharacterType.alphaLetter,
        'a': CharacterType.alphaLetter,
        '0': CharacterType.alphaLetter,
        '5': CharacterType.alphaLetter,
        'Ä': CharacterType.alphaLetter,
        'ä': CharacterType.alphaLetter,
        '_': CharacterType.alphaLetter,
        ' ': CharacterType.space,
        '\t': CharacterType.space,
        '\r': CharacterType.space,
        '\n': CharacterType.space,
        '\u00a0': CharacterType.space,
        '-': CharacterType.punctuation,
        ',': CharacterType.punctuation,
        '.': CharacterType.punctuation,
        ';': CharacterType.punctuation,
        ':': CharacterType.punctuation,
        '™': CharacterType.alphaLetter,
        'ล': CharacterType.thaiLetter,
        '䀀': CharacterType.hanLetter,
        '縷': CharacterType.hanLetter,
        'ダ': CharacterType.katakanaLetter,
        'ぐ': CharacterType.hiraganaLetter,
        'ﾀ': CharacterType.halfwidthKatakanaLetter,
      };
      for (final MapEntry(key: character, value: expected) in cases.entries) {
        expect(getCharacterType(character.runes.single), expected,
            reason: 'character $character');
      }
    });
  });

  test('combining mark detection covers major scripts and supplementary marks',
      () {
    expect(isCombiningMark(0x0301), isTrue);
    expect(isCombiningMark(0x05b0), isTrue);
    expect(isCombiningMark(0x064e), isTrue);
    expect(isCombiningMark(0x3099), isTrue);
    expect(isCombiningMark(0x1d167), isTrue);
    expect(isCombiningMark('a'.codeUnitAt(0)), isFalse);
  });

  test('diacritic exceptions follow the PDF.js word-search set', () {
    expect(isDiacriticException(0x3099), isTrue);
    expect(isDiacriticException(0x094d), isTrue);
    expect(isDiacriticException(0x0f74), isTrue);
    expect(isDiacriticException(0x0301), isFalse);
  });

  test('CJK detection includes BMP and supplementary ideographs', () {
    expect(isCjk(0x3042), isTrue);
    expect(isCjk(0x30a2), isTrue);
    expect(isCjk(0x4e00), isTrue);
    expect(isCjk(0x20000), isTrue);
    expect(isCjk('A'.codeUnitAt(0)), isFalse);
  });

  test('NFKC range advertises fractions, ligatures, and fullwidth forms', () {
    final ranges = getNormalizeWithNfkc();
    expect(ranges, contains('\u00bc-\u00be'));
    expect(ranges, contains('\ufb00-\ufb06'));
    expect(ranges, contains('\uff01-\uff5e'));
  });
}
