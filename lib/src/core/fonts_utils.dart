// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'dart:html';

import '../shared/util.dart';
import 'encodings.dart';
import 'glyphlist.dart';
import 'unicode.dart';

const bool seacAnalysisEnabled = true;

abstract class FontFlags {
  static const int fixedPitch = 1;
  static const int serif = 2;
  static const int symbolic = 4;
  static const int script = 8;
  static const int nonsymbolic = 32;
  static const int italic = 64;
  static const int allCap = 65536;
  static const int smallCap = 131072;
  static const int forceBold = 262144;
}

const List<String> macStandardGlyphOrdering = [
  ".notdef", ".null", "nonmarkingreturn", "space", "exclam", "quotedbl",
  "numbersign", "dollar", "percent", "ampersand", "quotesingle", "parenleft",
  "parenright", "asterisk", "plus", "comma", "hyphen", "period", "slash",
  "zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
  "nine", "colon", "semicolon", "less", "equal", "greater", "question", "at",
  "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
  "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "bracketleft",
  "backslash", "bracketright", "asciicircum", "underscore", "grave", "a", "b",
  "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q",
  "r", "s", "t", "u", "v", "w", "x", "y", "z", "braceleft", "bar", "braceright",
  "asciitilde", "Adieresis", "Aring", "Ccedilla", "Eacute", "Ntilde",
  "Odieresis", "Udieresis", "aacute", "agrave", "acircumflex", "adieresis",
  "atilde", "aring", "ccedilla", "eacute", "egrave", "ecircumflex", "edieresis",
  "iacute", "igrave", "icircumflex", "idieresis", "ntilde", "oacute", "ograve",
  "ocircumflex", "odieresis", "otilde", "uacute", "ugrave", "ucircumflex",
  "udieresis", "dagger", "degree", "cent", "sterling", "section", "bullet",
  "paragraph", "germandbls", "registered", "copyright", "trademark", "acute",
  "dieresis", "notequal", "AE", "Oslash", "infinity", "plusminus", "lessequal",
  "greaterequal", "yen", "mu", "partialdiff", "summation", "product", "pi",
  "integral", "ordfeminine", "ordmasculine", "Omega", "ae", "oslash",
  "questiondown", "exclamdown", "logicalnot", "radical", "florin",
  "approxequal", "Delta", "guillemotleft", "guillemotright", "ellipsis",
  "nonbreakingspace", "Agrave", "Atilde", "Otilde", "OE", "oe", "endash",
  "emdash", "quotedblleft", "quotedblright", "quoteleft", "quoteright",
  "divide", "lozenge", "ydieresis", "Ydieresis", "fraction", "currency",
  "guilsinglleft", "guilsinglright", "fi", "fl", "daggerdbl", "periodcentered",
  "quotesinglbase", "quotedblbase", "perthousand", "Acircumflex",
  "Ecircumflex", "Aacute", "Edieresis", "Egrave", "Iacute", "Icircumflex",
  "Idieresis", "Igrave", "Oacute", "Ocircumflex", "apple", "Ograve", "Uacute",
  "Ucircumflex", "Ugrave", "dotlessi", "circumflex", "tilde", "macron",
  "breve", "dotaccent", "ring", "cedilla", "hungarumlaut", "ogonek", "caron",
  "Lslash", "lslash", "Scaron", "scaron", "Zcaron", "zcaron", "brokenbar",
  "Eth", "eth", "Yacute", "yacute", "Thorn", "thorn", "minus", "multiply",
  "onesuperior", "twosuperior", "threesuperior", "onehalf", "onequarter",
  "threequarters", "franc", "Gbreve", "gbreve", "Idotaccent", "Scedilla",
  "scedilla", "Cacute", "cacute", "Ccaron", "ccaron", "dcroat"
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
  info('Unable to recover a standard glyph name for: \$name');
  return name;
}

Map<int, int> type1FontGlyphMapping(dynamic properties, List<String> builtInEncoding, List<String> glyphNames) {
  final Map<int, int> charCodeToGlyphId = {};
  int glyphId;
  List<String> baseEncoding;
  final bool isSymbolicFont = (properties.flags & FontFlags.symbolic) != 0;

  if (properties.isInternalFont) {
    baseEncoding = builtInEncoding;
    for (int charCode = 0; charCode < baseEncoding.length; charCode++) {
      glyphId = glyphNames.indexOf(baseEncoding[charCode]);
      charCodeToGlyphId[charCode] = glyphId >= 0 ? glyphId : 0; // 0 = notdef
    }
  } else if (properties.baseEncodingName != null) {
    baseEncoding = getEncoding(properties.baseEncodingName) ?? standardEncoding;
    for (int charCode = 0; charCode < baseEncoding.length; charCode++) {
      glyphId = glyphNames.indexOf(baseEncoding[charCode]);
      charCodeToGlyphId[charCode] = glyphId >= 0 ? glyphId : 0;
    }
  } else if (isSymbolicFont) {
    for (int charCode = 0; charCode < builtInEncoding.length; charCode++) {
      // ignore: unnecessary_null_comparison
      if (builtInEncoding[charCode] != null) {
        // Need to know what builtInEncoding structure actually is. JS uses `for (charCode in builtInEncoding)`
        // If it's a map in JS, we should treat it as map or iterate differently.
        // Assuming charCode is index and value is the int mapping if it's an array of ints.
        // JS logic: charCodeToGlyphId[charCode] = builtInEncoding[charCode];
        // So builtInEncoding is likely a Map<int, int> when isSymbolicFont. 
        // We will mock this behaviour since Dart is typed.
        charCodeToGlyphId[charCode] = builtInEncoding[charCode] as dynamic; 
      }
    }
  } else {
    baseEncoding = standardEncoding;
    for (int charCode = 0; charCode < baseEncoding.length; charCode++) {
      glyphId = glyphNames.indexOf(baseEncoding[charCode]);
      charCodeToGlyphId[charCode] = glyphId >= 0 ? glyphId : 0;
    }
  }

  final Map<dynamic, dynamic>? differences = properties.differences;
  Map<String, int>? glyphsUnicodeMap;
  if (differences != null) {
    differences.forEach((charCode, glyphName) {
      glyphId = glyphNames.indexOf(glyphName);
      if (glyphId == -1) {
        glyphsUnicodeMap ??= getGlyphsUnicode();
        final standardGlyphName = recoverGlyphName(glyphName, glyphsUnicodeMap!);
        if (standardGlyphName != glyphName) {
          glyphId = glyphNames.indexOf(standardGlyphName);
        }
      }
      charCodeToGlyphId[charCode] = glyphId >= 0 ? glyphId : 0;
    });
  }
  return charCodeToGlyphId;
}

String normalizeFontName(String name) {
  return name.replaceAll(RegExp(r'[,_]'), '-').replaceAll(RegExp(r'\s'), '');
}

final Map<int, int> _verticalPresentationForm = () {
  final Map<int, int> t = {};
  t[0x2013] = 0xfe32; // EN DASH
  t[0x2014] = 0xfe31; // EM DASH
  t[0x2025] = 0xfe30; // TWO DOT LEADER
  t[0x2026] = 0xfe19; // HORIZONTAL ELLIPSIS
  t[0x3001] = 0xfe11; // IDEOGRAPHIC COMMA
  t[0x3002] = 0xfe12; // IDEOGRAPHIC FULL STOP
  t[0x3008] = 0xfe3f; // LEFT ANGLE BRACKET
  t[0x3009] = 0xfe40; // RIGHT ANGLE BRACKET
  t[0x300a] = 0xfe3d; // LEFT DOUBLE ANGLE BRACKET
  t[0x300b] = 0xfe3e; // RIGHT DOUBLE ANGLE BRACKET
  t[0x300c] = 0xfe41; // LEFT CORNER BRACKET
  t[0x300d] = 0xfe42; // RIGHT CORNER BRACKET
  t[0x300e] = 0xfe43; // LEFT WHITE CORNER BRACKET
  t[0x300f] = 0xfe44; // RIGHT WHITE CORNER BRACKET
  t[0x3010] = 0xfe3b; // LEFT BLACK LENTICULAR BRACKET
  t[0x3011] = 0xfe3c; // RIGHT BLACK LENTICULAR BRACKET
  t[0x3014] = 0xfe39; // LEFT TORTOISE SHELL BRACKET
  t[0x3015] = 0xfe3a; // RIGHT TORTOISE SHELL BRACKET
  t[0x3016] = 0xfe17; // LEFT WHITE LENTICULAR BRACKET
  t[0x3017] = 0xfe18; // RIGHT WHITE LENTICULAR BRACKET
  t[0xfe4f] = 0xfe34; // WAVY LOW LINE
  t[0xff01] = 0xfe15; // FULLWIDTH EXCLAMATION MARK
  t[0xff08] = 0xfe35; // FULLWIDTH LEFT PARENTHESIS
  t[0xff09] = 0xfe36; // FULLWIDTH RIGHT PARENTHESIS
  t[0xff0c] = 0xfe10; // FULLWIDTH COMMA
  t[0xff1a] = 0xfe13; // FULLWIDTH COLON
  t[0xff1b] = 0xfe14; // FULLWIDTH SEMICOLON
  t[0xff1f] = 0xfe16; // FULLWIDTH QUESTION MARK
  t[0xff3b] = 0xfe47; // FULLWIDTH LEFT SQUARE BRACKET
  t[0xff3d] = 0xfe48; // FULLWIDTH RIGHT SQUARE BRACKET
  t[0xff3f] = 0xfe33; // FULLWIDTH LOW LINE
  t[0xff5b] = 0xfe37; // FULLWIDTH LEFT CURLY BRACKET
  t[0xff5d] = 0xfe38; // FULLWIDTH RIGHT CURLY BRACKET
  return t;
}();

int? getVerticalPresentationForm(int charCode) => _verticalPresentationForm[charCode];

const int maxSizeToCompile = 1000;

List<dynamic>? compileType3Glyph(dynamic glyphData) {
  final img = glyphData['data'] as Uint8List;
  final width = glyphData['width'] as int;
  final height = glyphData['height'] as int;

  if (width > maxSizeToCompile || height > maxSizeToCompile) {
    return null;
  }

  const int pointToProcessLimit = 1000;
  final pointTypes = Uint8List.fromList([
    0, 2, 4, 0, 1, 0, 5, 4, 8, 10, 0, 8, 0, 2, 1, 0,
  ]);

  final width1 = width + 1;
  final points = Uint8List(width1 * (height + 1));
  int i, j, j0;

  final lineSize = (width + 7) & ~7;
  final data = Uint8List(lineSize * height);
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
      if (pointTypes[sum] != 0) {
        points[j0 + j] = pointTypes[sum];
        ++count;
      }
      pos++;
    }
    if (data[pos - lineSize] != data[pos]) {
      points[j0 + j] = data[pos] != 0 ? 2 : 4;
      ++count;
    }
    if (count > pointToProcessLimit) {
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
  if (count > pointToProcessLimit) {
    return null;
  }

  final steps = Int32List.fromList([0, width1, -1, 0, -width1, 0, 0, 0, 1]);
  final List<double> pathBuf = [];

  // Matrix equivalents for DOMMatrix scaleSelf(1 / width, -1 / height).translateSelf(0, -height);
  final matrix = DomMatrix()
    .scale(1 / width, -1 / height)
    .translate(0, -height);
    
  final double a = matrix.a!.toDouble();
  final double b = matrix.b!.toDouble();
  final double c = matrix.c!.toDouble();
  final double d = matrix.d!.toDouble();
  final double e = matrix.e!.toDouble();
  final double f = matrix.f!.toDouble();

  for (i = 0; count > 0 && i <= height; i++) {
    int p = i * width1;
    final end = p + width;
    while (p < end && points[p] == 0) {
      p++;
    }
    if (p == end) {
      continue;
    }
    int x = p % width1;
    int y = i;
    pathBuf.add(DrawOPS.moveTo.toDouble());
    pathBuf.add(a * x + c * y + e);
    pathBuf.add(b * x + d * y + f);

    final p0 = p;
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
      x = p % width1;
      y = p ~/ width1;
      
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
