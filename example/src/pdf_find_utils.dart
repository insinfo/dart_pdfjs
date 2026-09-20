// Copyright 2018 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

/// Character classes used by the viewer's whole-word search algorithm.
enum CharacterType {
  space,
  alphaLetter,
  punctuation,
  hanLetter,
  katakanaLetter,
  hiraganaLetter,
  halfwidthKatakanaLetter,
  thaiLetter,
}

bool _isAlphabeticalScript(int code) => code < 0x2e80;
bool _isAscii(int code) => (code & 0xff80) == 0;
bool _isAsciiAlpha(int code) =>
    (code >= 0x61 && code <= 0x7a) || (code >= 0x41 && code <= 0x5a);
bool _isAsciiDigit(int code) => code >= 0x30 && code <= 0x39;
bool _isAsciiSpace(int code) =>
    code == 0x20 || code == 0x09 || code == 0x0d || code == 0x0a;
bool _isHan(int code) =>
    (code >= 0x3400 && code <= 0x9fff) || (code >= 0xf900 && code <= 0xfaff);
bool _isKatakana(int code) => code >= 0x30a0 && code <= 0x30ff;
bool _isHiragana(int code) => code >= 0x3040 && code <= 0x309f;
bool _isHalfwidthKatakana(int code) => code >= 0xff60 && code <= 0xff9f;
bool _isThai(int code) => (code & 0xff80) == 0x0e00;

/// Classifies one Unicode code point for word-boundary detection.
///
/// This follows Gecko's `WordBreaker.cpp`, as does the JavaScript viewer.
CharacterType getCharacterType(int charCode) {
  if (_isAlphabeticalScript(charCode)) {
    if (_isAscii(charCode)) {
      if (_isAsciiSpace(charCode)) return CharacterType.space;
      if (_isAsciiAlpha(charCode) ||
          _isAsciiDigit(charCode) ||
          charCode == 0x5f) {
        return CharacterType.alphaLetter;
      }
      return CharacterType.punctuation;
    }
    if (_isThai(charCode)) return CharacterType.thaiLetter;
    if (charCode == 0xa0) return CharacterType.space;
    return CharacterType.alphaLetter;
  }
  if (_isHan(charCode)) return CharacterType.hanLetter;
  if (_isKatakana(charCode)) return CharacterType.katakanaLetter;
  if (_isHiragana(charCode)) return CharacterType.hiraganaLetter;
  if (_isHalfwidthKatakana(charCode)) {
    return CharacterType.halfwidthKatakanaLetter;
  }
  return CharacterType.alphaLetter;
}

/// Compatibility characters whose NFKC representation is significant while
/// searching. Dart has no built-in Unicode normalization API; the controller
/// performs the equivalent deterministic mappings directly.
String getNormalizeWithNfkc() =>
    '\u00a0\u00bc-\u00be\ufb00-\ufb06\uff01-\uff5e';

/// Whether [charCode] is a Unicode combining mark relevant to PDF searching.
///
/// Dart's regular-expression implementation doesn't expose Unicode property
/// escapes on every supported runtime. Keeping the ranges here also makes the
/// find controller usable in VM tests and in a browser without JS interop.
bool isCombiningMark(int charCode) =>
    (charCode >= 0x0300 && charCode <= 0x036f) ||
    (charCode >= 0x0483 && charCode <= 0x0489) ||
    (charCode >= 0x0591 && charCode <= 0x05bd) ||
    charCode == 0x05bf ||
    (charCode >= 0x05c1 && charCode <= 0x05c2) ||
    (charCode >= 0x05c4 && charCode <= 0x05c5) ||
    charCode == 0x05c7 ||
    (charCode >= 0x0610 && charCode <= 0x061a) ||
    (charCode >= 0x064b && charCode <= 0x065f) ||
    charCode == 0x0670 ||
    (charCode >= 0x06d6 && charCode <= 0x06ed) ||
    (charCode >= 0x0711 && charCode <= 0x0711) ||
    (charCode >= 0x0730 && charCode <= 0x074a) ||
    (charCode >= 0x07a6 && charCode <= 0x07b0) ||
    (charCode >= 0x0816 && charCode <= 0x082d) ||
    (charCode >= 0x0859 && charCode <= 0x085b) ||
    (charCode >= 0x08d3 && charCode <= 0x0903) ||
    (charCode >= 0x093a && charCode <= 0x094f) ||
    (charCode >= 0x0951 && charCode <= 0x0957) ||
    (charCode >= 0x0962 && charCode <= 0x0963) ||
    (charCode >= 0x0981 && charCode <= 0x09cd) ||
    (charCode >= 0x0a01 && charCode <= 0x0a51) ||
    (charCode >= 0x0a70 && charCode <= 0x0a75) ||
    (charCode >= 0x0a81 && charCode <= 0x0acd) ||
    (charCode >= 0x0b01 && charCode <= 0x0bcd) ||
    (charCode >= 0x0c00 && charCode <= 0x0c56) ||
    (charCode >= 0x0d00 && charCode <= 0x0d4d) ||
    (charCode >= 0x0e31 && charCode <= 0x0e4e) ||
    (charCode >= 0x0f18 && charCode <= 0x0fbc) ||
    (charCode >= 0x102b && charCode <= 0x109d) ||
    (charCode >= 0x135d && charCode <= 0x135f) ||
    (charCode >= 0x1712 && charCode <= 0x17d3) ||
    (charCode >= 0x180b && charCode <= 0x18a9) ||
    (charCode >= 0x1ab0 && charCode <= 0x1aff) ||
    (charCode >= 0x1dc0 && charCode <= 0x1dff) ||
    (charCode >= 0x20d0 && charCode <= 0x20ff) ||
    (charCode >= 0x2cef && charCode <= 0x2cf1) ||
    (charCode >= 0x2de0 && charCode <= 0x2dff) ||
    (charCode >= 0x302a && charCode <= 0x302f) ||
    (charCode >= 0x3099 && charCode <= 0x309a) ||
    (charCode >= 0xa66f && charCode <= 0xa672) ||
    (charCode >= 0xa674 && charCode <= 0xa69f) ||
    (charCode >= 0xfe00 && charCode <= 0xfe0f) ||
    (charCode >= 0xfe20 && charCode <= 0xfe2f) ||
    (charCode >= 0x1d165 && charCode <= 0x1d1ad) ||
    (charCode >= 0xe0100 && charCode <= 0xe01ef);

/// Combining marks which PDF.js deliberately treats as letters for matching.
bool isDiacriticException(int charCode) => const <int>{
      0x3099,
      0x309a,
      0x094d,
      0x09cd,
      0x0a4d,
      0x0acd,
      0x0b4d,
      0x0bcd,
      0x0c4d,
      0x0ccd,
      0x0d3b,
      0x0d3c,
      0x0d4d,
      0x0dca,
      0x0e3a,
      0x0eba,
      0x0f84,
      0x1039,
      0x103a,
      0x1714,
      0x1734,
      0x17d2,
      0x1a60,
      0x1b44,
      0x1baa,
      0x1bab,
      0x1bf2,
      0x1bf3,
      0x2d7f,
      0xa806,
      0xa82c,
      0xa8c4,
      0xa953,
      0xa9c0,
      0xaaf6,
      0xabed,
      0x0c56,
      0x0f71,
      0x0f72,
      0x0f7a,
      0x0f7b,
      0x0f7c,
      0x0f7d,
      0x0f80,
      0x0f74,
    }.contains(charCode);

/// Returns whether a code point is CJK text for end-of-line normalization.
bool isCjk(int charCode) =>
    (charCode >= 0x3400 && charCode <= 0x9fff) ||
    (charCode >= 0xf900 && charCode <= 0xfaff) ||
    (charCode >= 0x3040 && charCode <= 0x30ff) ||
    (charCode >= 0x20000 && charCode <= 0x3134f);
