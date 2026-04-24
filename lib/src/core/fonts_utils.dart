// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import '../shared/util.dart';
import 'encodings.dart';
import 'glyphlist.dart';
import 'unicode.dart';

const bool SEAC_ANALYSIS_ENABLED = true;

class FontFlags {
  static const int FixedPitch = 1;
  static const int Serif = 2;
  static const int Symbolic = 4;
  static const int Script = 8;
  static const int Nonsymbolic = 32;
  static const int Italic = 64;
  static const int AllCap = 65536;
  static const int SmallCap = 131072;
  static const int ForceBold = 262144;
}

const List<String> MacStandardGlyphOrdering = [
  ".notdef",
  ".null",
  "nonmarkingreturn",
  "space",
  "exclam",
  "quotedbl",
  "numbersign",
  "dollar",
  "percent",
  "ampersand",
  "quotesingle",
  "parenleft",
  "parenright",
  "asterisk",
  "plus",
  "comma",
  "hyphen",
  "period",
  "slash",
  "zero",
  "one",
  "two",
  "three",
  "four",
  "five",
  "six",
  "seven",
  "eight",
  "nine",
  "colon",
  "semicolon",
  "less",
  "equal",
  "greater",
  "question",
  "at",
  "A",
  "B",
  "C",
  "D",
  "E",
  "F",
  "G",
  "H",
  "I",
  "J",
  "K",
  "L",
  "M",
  "N",
  "O",
  "P",
  "Q",
  "R",
  "S",
  "T",
  "U",
  "V",
  "W",
  "X",
  "Y",
  "Z",
  "bracketleft",
  "backslash",
  "bracketright",
  "asciicircum",
  "underscore",
  "grave",
  "a",
  "b",
  "c",
  "d",
  "e",
  "f",
  "g",
  "h",
  "i",
  "j",
  "k",
  "l",
  "m",
  "n",
  "o",
  "p",
  "q",
  "r",
  "s",
  "t",
  "u",
  "v",
  "w",
  "x",
  "y",
  "z",
  "braceleft",
  "bar",
  "braceright",
  "asciitilde",
  "Adieresis",
  "Aring",
  "Ccedilla",
  "Eacute",
  "Ntilde",
  "Odieresis",
  "Udieresis",
  "aacute",
  "agrave",
  "acircumflex",
  "adieresis",
  "atilde",
  "aring",
  "ccedilla",
  "eacute",
  "egrave",
  "ecircumflex",
  "edieresis",
  "iacute",
  "igrave",
  "icircumflex",
  "idieresis",
  "ntilde",
  "oacute",
  "ograve",
  "ocircumflex",
  "odieresis",
  "otilde",
  "uacute",
  "ugrave",
  "ucircumflex",
  "udieresis",
  "dagger",
  "degree",
  "cent",
  "sterling",
  "section",
  "bullet",
  "paragraph",
  "germandbls",
  "registered",
  "copyright",
  "trademark",
  "acute",
  "dieresis",
  "notequal",
  "AE",
  "Oslash",
  "infinity",
  "plusminus",
  "lessequal",
  "greaterequal",
  "yen",
  "mu",
  "partialdiff",
  "summation",
  "product",
  "pi",
  "integral",
  "ordfeminine",
  "ordmasculine",
  "Omega",
  "ae",
  "oslash",
  "questiondown",
  "exclamdown",
  "logicalnot",
  "radical",
  "florin",
  "approxequal",
  "Delta",
  "guillemotleft",
  "guillemotright",
  "ellipsis",
  "nonbreakingspace",
  "Agrave",
  "Atilde",
  "Otilde",
  "OE",
  "oe",
  "endash",
  "emdash",
  "quotedblleft",
  "quotedblright",
  "quoteleft",
  "quoteright",
  "divide",
  "lozenge",
  "ydieresis",
  "Ydieresis",
  "fraction",
  "currency",
  "guilsinglleft",
  "guilsinglright",
  "fi",
  "fl",
  "daggerdbl",
  "periodcentered",
  "quotesinglbase",
  "quotedblbase",
  "perthousand",
  "Acircumflex",
  "Ecircumflex",
  "Aacute",
  "Edieresis",
  "Egrave",
  "Iacute",
  "Icircumflex",
  "Idieresis",
  "Igrave",
  "Oacute",
  "Ocircumflex",
  "apple",
  "Ograve",
  "Uacute",
  "Ucircumflex",
  "Ugrave",
  "dotlessi",
  "circumflex",
  "tilde",
  "macron",
  "breve",
  "dotaccent",
  "ring",
  "cedilla",
  "hungarumlaut",
  "ogonek",
  "caron",
  "Lslash",
  "lslash",
  "Scaron",
  "scaron",
  "Zcaron",
  "zcaron",
  "brokenbar",
  "Eth",
  "eth",
  "Yacute",
  "yacute",
  "Thorn",
  "thorn",
  "minus",
  "multiply",
  "onesuperior",
  "twosuperior",
  "threesuperior",
  "onehalf",
  "onequarter",
  "threequarters",
  "franc",
  "Gbreve",
  "gbreve",
  "Idotaccent",
  "Scedilla",
  "scedilla",
  "Cacute",
  "cacute",
  "Ccaron",
  "ccaron",
  "dcroat"
];

String recoverGlyphName(String name, Map<String, int> glyphsUnicodeMap) {
  if (glyphsUnicodeMap.containsKey(name)) {
    return name;
  }
  final unicode = getUnicodeForGlyph(name, glyphsUnicodeMap);
  if (unicode != -1) {
    for (final key in glyphsUnicodeMap.keys) {
      if (glyphsUnicodeMap[key] == unicode) {
        return key;
      }
    }
  }
  info("Unable to recover a standard glyph name for: \$name");
  return name;
}

Map<int, int> type1FontGlyphMapping(
    dynamic properties, dynamic builtInEncoding, List<String> glyphNames) {
  final charCodeToGlyphId = <int, int>{};
  int glyphId;
  List<String?> baseEncoding;
  final bool isSymbolicFont = (properties.flags & FontFlags.Symbolic) != 0;

  if (properties.isInternalFont == true) {
    baseEncoding =
        builtInEncoding is List ? List<String?>.from(builtInEncoding) : [];
    for (int charCode = 0; charCode < baseEncoding.length; charCode++) {
      glyphId = glyphNames.indexOf(baseEncoding[charCode] ?? '');
      charCodeToGlyphId[charCode] = glyphId >= 0 ? glyphId : 0;
    }
  } else if (properties.baseEncodingName != null) {
    baseEncoding = getEncoding(properties.baseEncodingName)?.cast<String?>() ??
        const <String?>[];
    for (int charCode = 0; charCode < baseEncoding.length; charCode++) {
      glyphId = glyphNames.indexOf(baseEncoding[charCode] ?? '');
      charCodeToGlyphId[charCode] = glyphId >= 0 ? glyphId : 0;
    }
  } else if (isSymbolicFont && builtInEncoding != null) {
    if (builtInEncoding is List) {
      for (int charCode = 0; charCode < builtInEncoding.length; charCode++) {
        charCodeToGlyphId[charCode] = builtInEncoding[charCode];
      }
    } else if (builtInEncoding is Map) {
      for (final charCode in builtInEncoding.keys) {
        charCodeToGlyphId[charCode as int] = builtInEncoding[charCode] as int;
      }
    }
  } else {
    baseEncoding = standardEncoding;
    for (int charCode = 0; charCode < baseEncoding.length; charCode++) {
      glyphId = glyphNames.indexOf(baseEncoding[charCode] ?? '');
      charCodeToGlyphId[charCode] = glyphId >= 0 ? glyphId : 0;
    }
  }

  final differences = properties.differences;
  Map<String, int>? glyphsUnicodeMap;
  if (differences != null) {
    if (differences is Map) {
      for (final charCode in differences.keys) {
        final glyphName = differences[charCode];
        glyphId = glyphNames.indexOf(glyphName);

        if (glyphId == -1) {
          glyphsUnicodeMap ??= getGlyphsUnicode();
          final standardGlyphName =
              recoverGlyphName(glyphName, glyphsUnicodeMap);
          if (standardGlyphName != glyphName) {
            glyphId = glyphNames.indexOf(standardGlyphName);
          }
        }
        charCodeToGlyphId[charCode as int] = glyphId >= 0 ? glyphId : 0;
      }
    } else if (differences is List) {
      for (int i = 0; i < differences.length; i++) {
        if (differences[i] == null) continue;
        final glyphName = differences[i];
        glyphId = glyphNames.indexOf(glyphName);

        if (glyphId == -1) {
          glyphsUnicodeMap ??= getGlyphsUnicode();
          final standardGlyphName =
              recoverGlyphName(glyphName, glyphsUnicodeMap);
          if (standardGlyphName != glyphName) {
            glyphId = glyphNames.indexOf(standardGlyphName);
          }
        }
        charCodeToGlyphId[i] = glyphId >= 0 ? glyphId : 0;
      }
    }
  }
  return charCodeToGlyphId;
}

String normalizeFontName(String name) {
  return name.replaceAll(RegExp(r'[,_]'), "-").replaceAll(RegExp(r'\s'), "");
}

final Map<int, int> _verticalPresentationFormTable =
    _createVerticalPresentationFormTable();

Map<int, int> _createVerticalPresentationFormTable() {
  final t = <int, int>{};
  t[0x2013] = 0xfe32;
  t[0x2014] = 0xfe31;
  t[0x2025] = 0xfe30;
  t[0x2026] = 0xfe19;
  t[0x3001] = 0xfe11;
  t[0x3002] = 0xfe12;
  t[0x3008] = 0xfe3f;
  t[0x3009] = 0xfe40;
  t[0x300a] = 0xfe3d;
  t[0x300b] = 0xfe3e;
  t[0x300c] = 0xfe41;
  t[0x300d] = 0xfe42;
  t[0x300e] = 0xfe43;
  t[0x300f] = 0xfe44;
  t[0x3010] = 0xfe3b;
  t[0x3011] = 0xfe3c;
  t[0x3014] = 0xfe39;
  t[0x3015] = 0xfe3a;
  t[0x3016] = 0xfe17;
  t[0x3017] = 0xfe18;
  t[0xfe4f] = 0xfe34;
  t[0xff01] = 0xfe15;
  t[0xff08] = 0xfe35;
  t[0xff09] = 0xfe36;
  t[0xff0c] = 0xfe10;
  t[0xff1a] = 0xfe13;
  t[0xff1b] = 0xfe14;
  t[0xff1f] = 0xfe16;
  t[0xff3b] = 0xfe47;
  t[0xff3d] = 0xfe48;
  t[0xff3f] = 0xfe33;
  t[0xff5b] = 0xfe37;
  t[0xff5d] = 0xfe38;
  return t;
}

int? getVerticalPresentationForm(int charCode) {
  return _verticalPresentationFormTable[charCode];
}

const int MAX_SIZE_TO_COMPILE = 1000;

List<dynamic>? compileType3Glyph(Map<String, dynamic> imgData) {
  final Uint8List img = imgData["data"];
  final int width = imgData["width"];
  final int height = imgData["height"];

  if (width > MAX_SIZE_TO_COMPILE || height > MAX_SIZE_TO_COMPILE) {
    return null;
  }

  const int POINT_TO_PROCESS_LIMIT = 1000;
  final Uint8List POINT_TYPES = Uint8List.fromList([
    0,
    2,
    4,
    0,
    1,
    0,
    5,
    4,
    8,
    10,
    0,
    8,
    0,
    2,
    1,
    0,
  ]);

  final int width1 = width + 1;
  final Uint8List points = Uint8List(width1 * (height + 1));
  int i, j, j0;

  final int lineSize = (width + 7) & ~7;
  final Uint8List data = Uint8List(lineSize * height);
  int pos = 0;
  for (final elem in img) {
    int mask = 128;
    while (mask > 0) {
      data[pos++] = (elem & mask) != 0 ? 0 : 255;
      mask >>= 1;
    }
  }

  int count = 0;
  pos = 0;
  if (data[pos] != 0) {
    points[0] = 1;
    ++count;
  }
  for (j = 1; j < width; j++) {
    if (data[pos] != data[pos + 1]) {
      points[j] = data[pos] != 0 ? 2 : 1;
      ++count;
    }
    pos++;
  }
  if (data[pos] != 0) {
    points[j] = 2;
    ++count;
  }
  for (i = 1; i < height; i++) {
    pos = i * lineSize;
    j0 = i * width1;
    if (data[pos - lineSize] != data[pos]) {
      points[j0] = data[pos] != 0 ? 1 : 8;
      ++count;
    }
    int sum = (data[pos] != 0 ? 4 : 0) + (data[pos - lineSize] != 0 ? 8 : 0);
    for (j = 1; j < width; j++) {
      sum = (sum >> 2) +
          (data[pos + 1] != 0 ? 4 : 0) +
          (data[pos - lineSize + 1] != 0 ? 8 : 0);
      if (POINT_TYPES[sum] != 0) {
        points[j0 + j] = POINT_TYPES[sum];
        ++count;
      }
      pos++;
    }
    if (data[pos - lineSize] != data[pos]) {
      points[j0 + j] = data[pos] != 0 ? 2 : 4;
      ++count;
    }

    if (count > POINT_TO_PROCESS_LIMIT) {
      return null;
    }
  }

  pos = lineSize * (height - 1);
  j0 = i * width1;
  if (data[pos] != 0) {
    points[j0] = 8;
    ++count;
  }
  for (j = 1; j < width; j++) {
    if (data[pos] != data[pos + 1]) {
      points[j0 + j] = data[pos] != 0 ? 4 : 8;
      ++count;
    }
    pos++;
  }
  if (data[pos] != 0) {
    points[j0 + j] = 4;
    ++count;
  }
  if (count > POINT_TO_PROCESS_LIMIT) {
    return null;
  }

  final Int32List steps =
      Int32List.fromList([0, width1, -1, 0, -width1, 0, 0, 0, 1]);
  final List<double> pathBuf = [];

  final double a = 1 / width;
  const double b = 0;
  const double c = 0;
  final double d = -1 / height;
  const double e = 0;
  const double f = 1;

  for (i = 0; count > 0 && i <= height; i++) {
    int p = i * width1;
    final int end = p + width;
    while (p < end && points[p] == 0) {
      p++;
    }
    if (p == end) {
      continue;
    }
    double x = (p % width1).toDouble();
    double y = i.toDouble();
    pathBuf.add(DrawOPS.moveTo.toDouble());
    pathBuf.add(a * x + c * y + e);
    pathBuf.add(b * x + d * y + f);

    final int p0 = p;
    int type = points[p];
    do {
      final step = steps[type];
      do {
        p += step;
      } while (points[p] == 0);

      final pp = points[p];
      if (pp != 5 && pp != 10) {
        type = pp;
        points[p] = 0;
      } else {
        type = pp & ((0x33 * type) >> 4);
        points[p] &= (type >> 2) | (type << 2);
      }
      x = (p % width1).toDouble();
      y = (p ~/ width1).toDouble();
      pathBuf.add(DrawOPS.lineTo.toDouble());
      pathBuf.add(a * x + c * y + e);
      pathBuf.add(b * x + d * y + f);

      if (points[p] == 0) {
        --count;
      }
    } while (p0 != p);
    --i;
  }

  return [
    OPS.rawFillPath,
    [Float32List.fromList(pathBuf)],
    Float32List.fromList([0, 0, width.toDouble(), height.toDouble()]),
  ];
}
