// Copyright 2016 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'package:pdfjs/src/shared/util.dart';

const int MAX_SUBR_NESTING = 10;

const List<String> CFFStandardStrings = [
  ".notdef",
  "space",
  "exclam",
  "quotedbl",
  "numbersign",
  "dollar",
  "percent",
  "ampersand",
  "quoteright",
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
  "quoteleft",
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
  "exclamdown",
  "cent",
  "sterling",
  "fraction",
  "yen",
  "florin",
  "section",
  "currency",
  "quotesingle",
  "quotedblleft",
  "guillemotleft",
  "guilsinglleft",
  "guilsinglright",
  "fi",
  "fl",
  "endash",
  "dagger",
  "daggerdbl",
  "periodcentered",
  "paragraph",
  "bullet",
  "quotesinglbase",
  "quotedblbase",
  "quotedblright",
  "guillemotright",
  "ellipsis",
  "perthousand",
  "questiondown",
  "grave",
  "acute",
  "circumflex",
  "tilde",
  "macron",
  "breve",
  "dotaccent",
  "dieresis",
  "ring",
  "cedilla",
  "hungarumlaut",
  "ogonek",
  "caron",
  "emdash",
  "AE",
  "ordfeminine",
  "Lslash",
  "Oslash",
  "OE",
  "ordmasculine",
  "ae",
  "dotlessi",
  "lslash",
  "oslash",
  "oe",
  "germandbls",
  "onesuperior",
  "logicalnot",
  "mu",
  "trademark",
  "Eth",
  "onehalf",
  "plusminus",
  "Thorn",
  "onequarter",
  "divide",
  "brokenbar",
  "degree",
  "thorn",
  "threequarters",
  "twosuperior",
  "registered",
  "minus",
  "eth",
  "multiply",
  "threesuperior",
  "copyright",
  "Aacute",
  "Acircumflex",
  "Adieresis",
  "Agrave",
  "Aring",
  "Atilde",
  "Ccedilla",
  "Eacute",
  "Ecircumflex",
  "Edieresis",
  "Egrave",
  "Iacute",
  "Icircumflex",
  "Idieresis",
  "Igrave",
  "Ntilde",
  "Oacute",
  "Ocircumflex",
  "Odieresis",
  "Ograve",
  "Otilde",
  "Scaron",
  "Uacute",
  "Ucircumflex",
  "Udieresis",
  "Ugrave",
  "Yacute",
  "Ydieresis",
  "Zcaron",
  "aacute",
  "acircumflex",
  "adieresis",
  "agrave",
  "aring",
  "atilde",
  "ccedilla",
  "eacute",
  "ecircumflex",
  "edieresis",
  "egrave",
  "iacute",
  "icircumflex",
  "idieresis",
  "igrave",
  "ntilde",
  "oacute",
  "ocircumflex",
  "odieresis",
  "ograve",
  "otilde",
  "scaron",
  "uacute",
  "ucircumflex",
  "udieresis",
  "ugrave",
  "yacute",
  "ydieresis",
  "zcaron",
  "exclamsmall",
  "Hungarumlautsmall",
  "dollaroldstyle",
  "dollarsuperior",
  "ampersandsmall",
  "Acutesmall",
  "parenleftsuperior",
  "parenrightsuperior",
  "twodotenleader",
  "onedotenleader",
  "zerooldstyle",
  "oneoldstyle",
  "twooldstyle",
  "threeoldstyle",
  "fouroldstyle",
  "fiveoldstyle",
  "sixoldstyle",
  "sevenoldstyle",
  "eightoldstyle",
  "nineoldstyle",
  "commasuperior",
  "threequartersemdash",
  "periodsuperior",
  "questionsmall",
  "asuperior",
  "bsuperior",
  "centsuperior",
  "dsuperior",
  "esuperior",
  "isuperior",
  "lsuperior",
  "msuperior",
  "nsuperior",
  "osuperior",
  "rsuperior",
  "ssuperior",
  "tsuperior",
  "ff",
  "ffi",
  "ffl",
  "parenleftinferior",
  "parenrightinferior",
  "Circumflexsmall",
  "hyphensuperior",
  "Gravesmall",
  "Asmall",
  "Bsmall",
  "Csmall",
  "Dsmall",
  "Esmall",
  "Fsmall",
  "Gsmall",
  "Hsmall",
  "Ismall",
  "Jsmall",
  "Ksmall",
  "Lsmall",
  "Msmall",
  "Nsmall",
  "Osmall",
  "Psmall",
  "Qsmall",
  "Rsmall",
  "Ssmall",
  "Tsmall",
  "Usmall",
  "Vsmall",
  "Wsmall",
  "Xsmall",
  "Ysmall",
  "Zsmall",
  "colonmonetary",
  "onefitted",
  "rupiah",
  "Tildesmall",
  "exclamdownsmall",
  "centoldstyle",
  "Lslashsmall",
  "Scaronsmall",
  "Zcaronsmall",
  "Dieresissmall",
  "Brevesmall",
  "Caronsmall",
  "Dotaccentsmall",
  "Macronsmall",
  "figuredash",
  "hypheninferior",
  "Ogoneksmall",
  "Ringsmall",
  "Cedillasmall",
  "questiondownsmall",
  "oneeighth",
  "threeeighths",
  "fiveeighths",
  "seveneighths",
  "onethird",
  "twothirds",
  "zerosuperior",
  "foursuperior",
  "fivesuperior",
  "sixsuperior",
  "sevensuperior",
  "eightsuperior",
  "ninesuperior",
  "zeroinferior",
  "oneinferior",
  "twoinferior",
  "threeinferior",
  "fourinferior",
  "fiveinferior",
  "sixinferior",
  "seveninferior",
  "eightinferior",
  "nineinferior",
  "centinferior",
  "dollarinferior",
  "periodinferior",
  "commainferior",
  "Agravesmall",
  "Aacutesmall",
  "Acircumflexsmall",
  "Atildesmall",
  "Adieresissmall",
  "Aringsmall",
  "AEsmall",
  "Ccedillasmall",
  "Egravesmall",
  "Eacutesmall",
  "Ecircumflexsmall",
  "Edieresissmall",
  "Igravesmall",
  "Iacutesmall",
  "Icircumflexsmall",
  "Idieresissmall",
  "Ethsmall",
  "Ntildesmall",
  "Ogravesmall",
  "Oacutesmall",
  "Ocircumflexsmall",
  "Otildesmall",
  "Odieresissmall",
  "OEsmall",
  "Oslashsmall",
  "Ugravesmall",
  "Uacutesmall",
  "Ucircumflexsmall",
  "Udieresissmall",
  "Yacutesmall",
  "Thornsmall",
  "Ydieresissmall",
  "001.000",
  "001.001",
  "001.002",
  "001.003",
  "Black",
  "Bold",
  "Book",
  "Light",
  "Medium",
  "Regular",
  "Roman",
  "Semibold"
];

const int NUM_STANDARD_CFF_STRINGS = 391;

class CFFHeader {
  int major;
  int minor;
  int hdrSize;
  int offSize;
  CFFHeader(this.major, this.minor, this.hdrSize, this.offSize);
}

class CFFStrings {
  List<String> strings = [];

  String get(int index) {
    if (index >= 0 && index <= NUM_STANDARD_CFF_STRINGS - 1) {
      return CFFStandardStrings[index];
    }
    if (index - NUM_STANDARD_CFF_STRINGS <= strings.length) {
      return strings[index - NUM_STANDARD_CFF_STRINGS];
    }
    return CFFStandardStrings[0];
  }

  int getSID(String str) {
    int index = CFFStandardStrings.indexOf(str);
    if (index != -1) return index;
    index = strings.indexOf(str);
    if (index != -1) return index + NUM_STANDARD_CFF_STRINGS;
    return -1;
  }

  void add(String value) {
    strings.add(value);
  }

  int get count => strings.length;
}

class CFFIndex {
  List<Uint8List> objects = [];
  int length = 0;

  void add(List<int> data) {
    Uint8List b = data is Uint8List ? data : Uint8List.fromList(data);
    length += b.length;
    objects.add(b);
  }

  void set(int index, List<int> data) {
    Uint8List b = data is Uint8List ? data : Uint8List.fromList(data);
    length += b.length - objects[index].length;
    objects[index] = b;
  }

  Uint8List get(int index) => objects[index];
  int get count => objects.length;
}

class CFFTables {
  Map<int, String> keyToNameMap = {};
  Map<String, int> nameToKeyMap = {};
  Map<int, dynamic> defaults = {};
  Map<int, dynamic> types = {};
  Map<int, List<int>> opcodes = {};
  List<int> order = [];

  CFFTables(List<dynamic> layout) {
    for (final entry in layout) {
      final k = entry[0];
      final int key = k is List ? (k[0] << 8) + k[1] : k as int;
      final String name = entry[1];
      keyToNameMap[key] = name;
      nameToKeyMap[name] = key;
      types[key] = entry[2];
      defaults[key] = entry[3];
      opcodes[key] = k is List ? List<int>.from(k) : [k];
      order.add(key);
    }
  }
}

class CFFDict {
  late Map<int, String> keyToNameMap;
  late Map<String, int> nameToKeyMap;
  late Map<int, dynamic> defaults;
  late Map<int, dynamic> types;
  late Map<int, List<int>> opcodes;
  late List<int> order;
  CFFStrings strings;
  Map<int, dynamic> values = {};

  CFFDict(CFFTables tables, this.strings) {
    keyToNameMap = tables.keyToNameMap;
    nameToKeyMap = tables.nameToKeyMap;
    defaults = tables.defaults;
    types = tables.types;
    opcodes = tables.opcodes;
    order = tables.order;
  }

  bool setByKey(int key, dynamic value) {
    if (!keyToNameMap.containsKey(key)) return false;
    List<dynamic> valList = value is List ? value : [value];
    if (valList.isEmpty) return true;
    for (final val in valList) {
      if (val is double && val.isNaN) {
        warn('Invalid CFFDict value: "\$value" for key "\$key".');
        return true;
      }
    }
    final type = types[key];
    if (type == "num" || type == "sid" || type == "offset") {
      value = valList[0];
    }
    values[key] = value;
    return true;
  }

  void setByName(String name, dynamic value) {
    if (!nameToKeyMap.containsKey(name)) {
      throw FormatException('Invalid dictionary name "\$name"');
    }
    values[nameToKeyMap[name]!] = value;
  }

  bool hasName(String name) => values.containsKey(nameToKeyMap[name]);

  dynamic getByName(String name) {
    if (!nameToKeyMap.containsKey(name)) {
      throw FormatException('Invalid dictionary name "\$name"');
    }
    final key = nameToKeyMap[name]!;
    if (!values.containsKey(key)) return defaults[key];
    return values[key];
  }

  void removeByName(String name) {
    values.remove(nameToKeyMap[name]);
  }
}

final CFFTables cffTopDictTables = CFFTables([
  [
    [12, 30],
    "ROS",
    ["sid", "sid", "num"],
    null
  ],
  [
    [12, 20],
    "SyntheticBase",
    "num",
    null
  ],
  [0, "version", "sid", null],
  [1, "Notice", "sid", null],
  [
    [12, 0],
    "Copyright",
    "sid",
    null
  ],
  [2, "FullName", "sid", null],
  [3, "FamilyName", "sid", null],
  [4, "Weight", "sid", null],
  [
    [12, 1],
    "isFixedPitch",
    "num",
    0
  ],
  [
    [12, 2],
    "ItalicAngle",
    "num",
    0
  ],
  [
    [12, 3],
    "UnderlinePosition",
    "num",
    -100
  ],
  [
    [12, 4],
    "UnderlineThickness",
    "num",
    50
  ],
  [
    [12, 5],
    "PaintType",
    "num",
    0
  ],
  [
    [12, 6],
    "CharstringType",
    "num",
    2
  ],
  [
    [12, 7],
    "FontMatrix",
    ["num", "num", "num", "num", "num", "num"],
    [0.001, 0, 0, 0.001, 0, 0]
  ],
  [13, "UniqueID", "num", null],
  [
    5,
    "FontBBox",
    ["num", "num", "num", "num"],
    [0, 0, 0, 0]
  ],
  [
    [12, 8],
    "StrokeWidth",
    "num",
    0
  ],
  [14, "XUID", "array", null],
  [15, "charset", "offset", 0],
  [16, "Encoding", "offset", 0],
  [17, "CharStrings", "offset", 0],
  [
    18,
    "Private",
    ["offset", "offset"],
    null
  ],
  [
    [12, 21],
    "PostScript",
    "sid",
    null
  ],
  [
    [12, 22],
    "BaseFontName",
    "sid",
    null
  ],
  [
    [12, 23],
    "BaseFontBlend",
    "delta",
    null
  ],
  [
    [12, 31],
    "CIDFontVersion",
    "num",
    0
  ],
  [
    [12, 32],
    "CIDFontRevision",
    "num",
    0
  ],
  [
    [12, 33],
    "CIDFontType",
    "num",
    0
  ],
  [
    [12, 34],
    "CIDCount",
    "num",
    8720
  ],
  [
    [12, 35],
    "UIDBase",
    "num",
    null
  ],
  [
    [12, 37],
    "FDSelect",
    "offset",
    null
  ],
  [
    [12, 36],
    "FDArray",
    "offset",
    null
  ],
  [
    [12, 38],
    "FontName",
    "sid",
    null
  ],
]);

class CFFTopDict extends CFFDict {
  CFFPrivateDict? privateDict;
  CFFTopDict(CFFStrings strings) : super(cffTopDictTables, strings);
}

final CFFTables cffPrivateDictTables = CFFTables([
  [6, "BlueValues", "delta", null],
  [7, "OtherBlues", "delta", null],
  [8, "FamilyBlues", "delta", null],
  [9, "FamilyOtherBlues", "delta", null],
  [
    [12, 9],
    "BlueScale",
    "num",
    0.039625
  ],
  [
    [12, 10],
    "BlueShift",
    "num",
    7
  ],
  [
    [12, 11],
    "BlueFuzz",
    "num",
    1
  ],
  [10, "StdHW", "num", null],
  [11, "StdVW", "num", null],
  [
    [12, 12],
    "StemSnapH",
    "delta",
    null
  ],
  [
    [12, 13],
    "StemSnapV",
    "delta",
    null
  ],
  [
    [12, 14],
    "ForceBold",
    "num",
    0
  ],
  [
    [12, 17],
    "LanguageGroup",
    "num",
    0
  ],
  [
    [12, 18],
    "ExpansionFactor",
    "num",
    0.06
  ],
  [
    [12, 19],
    "initialRandomSeed",
    "num",
    0
  ],
  [20, "defaultWidthX", "num", 0],
  [21, "nominalWidthX", "num", 0],
  [19, "Subrs", "offset", null],
]);

class CFFPrivateDict extends CFFDict {
  CFFIndex? subrsIndex;
  CFFPrivateDict(CFFStrings strings) : super(cffPrivateDictTables, strings);
}

class CFFCharset {
  bool predefined;
  int format;
  List<dynamic> charset;
  Uint8List? raw;
  CFFCharset(this.predefined, this.format, this.charset, [this.raw]);
}

class CFFEncoding {
  bool predefined;
  int format;
  Map<int, int> encoding;
  Uint8List? raw;
  CFFEncoding(this.predefined, this.format, this.encoding, [this.raw]);
}

class CFFFDSelect {
  int format;
  List<int> fdSelect;
  CFFFDSelect(this.format, this.fdSelect);

  int getFDIndex(int glyphIndex) {
    if (glyphIndex < 0 || glyphIndex >= fdSelect.length) return -1;
    return fdSelect[glyphIndex];
  }
}

class CFF {
  int rawFileLength;
  CFFHeader? header;
  List<String> names = [];
  CFFTopDict? topDict;
  CFFStrings strings = CFFStrings();
  CFFIndex? globalSubrIndex;
  CFFEncoding? encoding;
  CFFCharset? charset;
  CFFIndex? charStrings;
  List<CFFTopDict> fdArray = [];
  CFFFDSelect? fdSelect;
  bool isCIDFont = false;
  int charStringCount = 0;
  List<dynamic> seacs = [];
  List<num> widths = [];

  CFF([this.rawFileLength = 0]);

  void duplicateFirstGlyph() {
    if (charStrings!.count >= 65535) {
      warn("Not enough space in charstrings to duplicate first glyph.");
      return;
    }
    final glyphZero = charStrings!.get(0);
    charStrings!.add(glyphZero);
    if (isCIDFont && fdSelect != null) {
      fdSelect!.fdSelect.add(fdSelect!.fdSelect[0]);
    }
  }

  bool hasGlyphId(int id) {
    if (id < 0 || id >= charStrings!.count) return false;
    final glyph = charStrings!.get(id);
    return glyph.isNotEmpty;
  }
}

class CFFOffsetTracker {
  Map<String, int> offsets = {};

  bool isTracking(String key) => offsets.containsKey(key);

  void track(String key, int location) {
    if (offsets.containsKey(key))
      throw FormatException("Already tracking location of \$key");
    offsets[key] = location;
  }

  void offset(int value) {
    offsets.forEach((key, val) {
      offsets[key] = val + value;
    });
  }

  void setEntryLocation(String key, List<int> values, CompilerOutput output) {
    if (!offsets.containsKey(key))
      throw FormatException("Not tracking location of \$key");
    final data = output.data;
    final dataOffset = offsets[key]!;
    const size = 5;
    for (int i = 0, ii = values.length; i < ii; ++i) {
      final offset0 = i * size + dataOffset;
      final offset1 = offset0 + 1;
      final offset2 = offset0 + 2;
      final offset3 = offset0 + 3;
      final offset4 = offset0 + 4;
      if (data[offset0] != 0x1d ||
          data[offset1] != 0 ||
          data[offset2] != 0 ||
          data[offset3] != 0 ||
          data[offset4] != 0) {
        throw FormatException("writing to an offset that is not empty");
      }
      final value = values[i];
      data[offset0] = 0x1d;
      data[offset1] = (value >> 24) & 0xff;
      data[offset2] = (value >> 16) & 0xff;
      data[offset3] = (value >> 8) & 0xff;
      data[offset4] = value & 0xff;
    }
  }
}

class CompilerOutput {
  late Uint8List _buf;
  int _bufLength = 1024;
  int _pos = 0;

  CompilerOutput(int minLength) {
    _initBuf(minLength);
  }

  void _initBuf(int minLength) {
    while (_bufLength < minLength) {
      _bufLength *= 2;
    }
    final newBuf = Uint8List(_bufLength);
    // ignores since we construct via 'late' which gets initialized here.
    try {
      if (_buf.isNotEmpty) newBuf.setAll(0, _buf);
    } catch (_) {}
    _buf = newBuf;
  }

  Uint8List get data => _buf.sublist(0, _pos);
  Uint8List get finalData => _buf.sublist(0, _pos);
  int get length => _pos;

  void add(List<int> dataToAdd) {
    final newPos = _pos + dataToAdd.length;
    if (newPos > _bufLength) _initBuf(newPos);
    _buf.setAll(_pos, dataToAdd);
    _pos = newPos;
  }
}

class CFFCompiler {
  CFF cff;
  CFFCompiler(this.cff);

  Uint8List compile() {
    final output = CompilerOutput(cff.rawFileLength);
    final header = compileHeader(cff.header!);
    output.add(header);

    final nameIndex = compileNameIndex(cff.names);
    output.add(nameIndex);

    if (cff.isCIDFont) {
      if (cff.topDict!.hasName("FontMatrix")) {
        final base = cff.topDict!.getByName("FontMatrix") as List<dynamic>;
        cff.topDict!.removeByName("FontMatrix");
        for (final subDict in cff.fdArray) {
          List<dynamic> matrix = List.from(base);
          if (subDict.hasName("FontMatrix")) {
            final subMatrix = subDict.getByName("FontMatrix");
            if (subMatrix is List && subMatrix.length == 6) {
              matrix = PdfJsUtil.transform(
                matrix.map((value) => (value as num).toDouble()).toList(),
                subMatrix.map((value) => (value as num).toDouble()).toList(),
              );
            }
          }
          subDict.setByName("FontMatrix", matrix);
        }
      }
    }

    final xuid = cff.topDict!.getByName("XUID");
    if (xuid is List && xuid.length > 16) {
      cff.topDict!.removeByName("XUID");
    }

    cff.topDict!.setByName("charset", 0);
    var compiled =
        compileTopDicts([cff.topDict!], output.length, cff.isCIDFont);
    output.add(compiled["output"]);
    final topDictTracker = compiled["trackers"][0] as CFFOffsetTracker;

    final stringIndex = compileStringIndex(cff.strings.strings);
    output.add(stringIndex);

    final globalSubrIndex = compileIndex(cff.globalSubrIndex!);
    output.add(globalSubrIndex);

    if (cff.encoding != null && cff.topDict!.hasName("Encoding")) {
      if (cff.encoding!.predefined) {
        topDictTracker.setEntryLocation(
            "Encoding", [cff.encoding!.format], output);
      } else {
        final encoding = compileEncoding(cff.encoding!);
        topDictTracker.setEntryLocation("Encoding", [output.length], output);
        output.add(encoding);
      }
    }

    final charset = compileCharset(
        cff.charset!, cff.charStrings!.count, cff.strings, cff.isCIDFont);
    topDictTracker.setEntryLocation("charset", [output.length], output);
    output.add(charset);

    final charStrings = compileCharStrings(cff.charStrings!);
    topDictTracker.setEntryLocation("CharStrings", [output.length], output);
    output.add(charStrings);

    if (cff.isCIDFont) {
      topDictTracker.setEntryLocation("FDSelect", [output.length], output);
      final fdSelect = compileFDSelect(cff.fdSelect!);
      output.add(fdSelect);
      compiled = compileTopDicts(cff.fdArray, output.length, true);
      topDictTracker.setEntryLocation("FDArray", [output.length], output);
      output.add(compiled["output"]);
      final fontDictTrackers = compiled["trackers"] as List<CFFOffsetTracker>;
      compilePrivateDicts(cff.fdArray, fontDictTrackers, output);
    }

    compilePrivateDicts([cff.topDict!], [topDictTracker], output);
    output.add([0]);

    return output.finalData;
  }

  List<int> encodeNumber(num value) {
    if (value is int || value.toInt() == value) {
      return encodeInteger(value.toInt());
    }
    return encodeFloat(value.toDouble());
  }

  List<int> encodeFloat(double numVal) {
    String value = numVal.toString();
    String nibbles = "";
    for (int i = 0; i < value.length; i++) {
      final String a = value[i];
      if (a == "e") {
        nibbles += value[++i] == "-" ? "c" : "b";
      } else if (a == ".") {
        nibbles += "a";
      } else if (a == "-") {
        nibbles += "e";
      } else {
        nibbles += a;
      }
    }
    nibbles += nibbles.length % 2 != 0 ? "f" : "ff";
    final out = [30];
    for (int i = 0; i < nibbles.length; i += 2) {
      out.add(int.parse(nibbles.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  List<int> encodeInteger(int value) {
    if (value >= -107 && value <= 107) {
      return [value + 139];
    } else if (value >= 108 && value <= 1131) {
      value -= 108;
      return [(value >> 8) + 247, value & 0xff];
    } else if (value >= -1131 && value <= -108) {
      value = -value - 108;
      return [(value >> 8) + 251, value & 0xff];
    } else if (value >= -32768 && value <= 32767) {
      return [0x1c, (value >> 8) & 0xff, value & 0xff];
    } else {
      return [
        0x1d,
        (value >> 24) & 0xff,
        (value >> 16) & 0xff,
        (value >> 8) & 0xff,
        value & 0xff
      ];
    }
  }

  List<int> compileHeader(CFFHeader header) {
    return [header.major, header.minor, 4, header.offSize];
  }

  Uint8List compileNameIndex(List<String> names) {
    final nameIndex = CFFIndex();
    for (String name in names) {
      int length = name.length > 127 ? 127 : name.length;
      String sanitizedName = "";
      for (int j = 0; j < length; j++) {
        String charStr = name[j];
        if (charStr.compareTo("!") < 0 ||
            charStr.compareTo("~") > 0 ||
            "[](){}<>/%".contains(charStr)) {
          charStr = "_";
        }
        sanitizedName += charStr;
      }
      if (sanitizedName.isEmpty) sanitizedName = "Bad_Font_Name";
      nameIndex.add(sanitizedName.codeUnits);
    }
    return compileIndex(nameIndex);
  }

  Map<String, dynamic> compileTopDicts(
      List<CFFTopDict> dicts, int length, bool removeCidKeys) {
    final fontDictTrackers = <CFFOffsetTracker>[];
    CFFIndex fdArrayIndex = CFFIndex();
    for (final fontDict in dicts) {
      if (removeCidKeys) {
        fontDict.removeByName("CIDFontVersion");
        fontDict.removeByName("CIDFontRevision");
        fontDict.removeByName("CIDFontType");
        fontDict.removeByName("CIDCount");
        fontDict.removeByName("UIDBase");
      }
      final fontDictTracker = CFFOffsetTracker();
      final fontDictData = compileDict(fontDict, fontDictTracker);
      fontDictTrackers.add(fontDictTracker);
      fdArrayIndex.add(fontDictData);
      fontDictTracker.offset(length);
    }
    return {
      "trackers": fontDictTrackers,
      "output": compileIndex(fdArrayIndex, fontDictTrackers),
    };
  }

  void compilePrivateDicts(List<CFFDict> dicts, List<CFFOffsetTracker> trackers,
      CompilerOutput output) {
    for (int i = 0; i < dicts.length; i++) {
      final fontDict = dicts[i] as dynamic; // CFFTopDict has privateDict
      final privateDict = fontDict.privateDict as CFFPrivateDict?;
      if (privateDict == null || !fontDict.hasName("Private")) {
        throw FormatException("There must be a private dictionary.");
      }
      final privateDictTracker = CFFOffsetTracker();
      final privateDictData = compileDict(privateDict, privateDictTracker);

      int outputLength = output.length;
      privateDictTracker.offset(outputLength);
      if (privateDictData.isEmpty) {
        outputLength = 0;
      }

      trackers[i].setEntryLocation(
          "Private", [privateDictData.length, outputLength], output);
      output.add(privateDictData);

      if (privateDict.subrsIndex != null && privateDict.hasName("Subrs")) {
        final subrs = compileIndex(privateDict.subrsIndex!);
        privateDictTracker.setEntryLocation(
            "Subrs", [privateDictData.length], output);
        output.add(subrs);
      }
    }
  }

  List<int> compileDict(CFFDict dict, CFFOffsetTracker offsetTracker) {
    final out = <int>[];
    for (final key in dict.order) {
      if (!dict.values.containsKey(key)) continue;
      dynamic vals = dict.values[key];
      dynamic t = dict.types[key];
      List<dynamic> types = t is List ? t : [t];
      List<dynamic> values = vals is List ? vals : [vals];
      if (values.isEmpty) continue;

      for (int j = 0; j < types.length; j++) {
        final String type = types[j];
        final dynamic value = values[j];
        switch (type) {
          case "num":
          case "sid":
            out.addAll(encodeNumber(value));
            break;
          case "offset":
            final name = dict.keyToNameMap[key]!;
            if (!offsetTracker.isTracking(name)) {
              offsetTracker.track(name, out.length);
            }
            out.addAll([0x1d, 0, 0, 0, 0]);
            break;
          case "array":
          case "delta":
            out.addAll(encodeNumber(value));
            for (int k = 1; k < values.length; k++) {
              out.addAll(encodeNumber(values[k]));
            }
            break;
        }
      }
      out.addAll(dict.opcodes[key]!);
    }
    return out;
  }

  Uint8List compileStringIndex(List<String> strings) {
    final stringIndex = CFFIndex();
    for (final string in strings) {
      stringIndex.add(string.codeUnits);
    }
    return compileIndex(stringIndex);
  }

  Uint8List compileCharStrings(CFFIndex charStrings) {
    final charStringsIndex = CFFIndex();
    for (int i = 0; i < charStrings.count; i++) {
      final glyph = charStrings.get(i);
      if (glyph.isEmpty) {
        charStringsIndex.add([0x8b, 0x0e]);
        continue;
      }
      charStringsIndex.add(glyph);
    }
    return compileIndex(charStringsIndex);
  }

  Uint8List compileCharset(
      CFFCharset charset, int numGlyphs, CFFStrings strings, bool isCIDFont) {
    List<int> out;
    final int numGlyphsLessNotDef = numGlyphs - 1;
    if (isCIDFont) {
      final nLeft = numGlyphsLessNotDef - 1;
      out = [2, 0, 1, (nLeft >> 8) & 0xff, nLeft & 0xff];
    } else {
      final length = 1 + numGlyphsLessNotDef * 2;
      out = List<int>.filled(length, 0);
      out[0] = 0; // format
      int charsetIndex = 0;
      final numCharsets = charset.charset.length;
      for (int i = 1; i < out.length; i += 2) {
        int sid = 0;
        if (charsetIndex < numCharsets) {
          final name = charset.charset[charsetIndex++];
          sid = strings.getSID(name);
          if (sid == -1) {
            sid = 0;
          }
        }
        out[i] = (sid >> 8) & 0xff;
        out[i + 1] = sid & 0xff;
      }
    }
    return Uint8List.fromList(out);
  }

  Uint8List compileEncoding(CFFEncoding encoding) {
    return encoding.raw ?? Uint8List(0);
  }

  Uint8List compileFDSelect(CFFFDSelect fdSelect) {
    final format = fdSelect.format;
    List<int> out = [];
    switch (format) {
      case 0:
        out = List<int>.filled(1 + fdSelect.fdSelect.length, 0);
        out[0] = format;
        for (int i = 0; i < fdSelect.fdSelect.length; i++) {
          out[i + 1] = fdSelect.fdSelect[i];
        }
        break;
      case 3:
        const start = 0;
        int lastFD = fdSelect.fdSelect[0];
        final ranges = [
          format,
          0,
          0,
          (start >> 8) & 0xff,
          start & 0xff,
          lastFD
        ];
        int i;
        for (i = 1; i < fdSelect.fdSelect.length; i++) {
          final currentFD = fdSelect.fdSelect[i];
          if (currentFD != lastFD) {
            ranges.addAll([(i >> 8) & 0xff, i & 0xff, currentFD]);
            lastFD = currentFD;
          }
        }
        final numRanges = (ranges.length - 3) ~/ 3;
        ranges[1] = (numRanges >> 8) & 0xff;
        ranges[2] = numRanges & 0xff;
        ranges.addAll([(i >> 8) & 0xff, i & 0xff]);
        out = ranges;
        break;
    }
    return Uint8List.fromList(out);
  }

  Uint8List compileIndex(CFFIndex index, [List<CFFOffsetTracker>? trackers]) {
    final objects = index.objects;
    final count = objects.length;
    if (count == 0) return Uint8List(2);

    int lastOffset = 1;
    for (int i = 0; i < count; ++i) {
      lastOffset += objects[i].length;
    }

    int offsetSize;
    if (lastOffset < 0x100) {
      offsetSize = 1;
    } else if (lastOffset < 0x10000) {
      offsetSize = 2;
    } else if (lastOffset < 0x1000000) {
      offsetSize = 3;
    } else {
      offsetSize = 4;
    }

    final data = Uint8List(2 + offsetSize * (count + 1) + lastOffset);
    int pos = 0;

    data[pos++] = (count >> 8) & 0xff;
    data[pos++] = count & 0xff;
    data[pos++] = offsetSize;

    int relativeOffset = 1;
    for (int i = 0; i < count + 1; i++) {
      if (offsetSize == 1) {
        data[pos++] = relativeOffset & 0xff;
      } else if (offsetSize == 2) {
        data[pos++] = (relativeOffset >> 8) & 0xff;
        data[pos++] = relativeOffset & 0xff;
      } else if (offsetSize == 3) {
        data[pos++] = (relativeOffset >> 16) & 0xff;
        data[pos++] = (relativeOffset >> 8) & 0xff;
        data[pos++] = relativeOffset & 0xff;
      } else {
        data[pos++] = (relativeOffset >>> 24) & 0xff;
        data[pos++] = (relativeOffset >> 16) & 0xff;
        data[pos++] = (relativeOffset >> 8) & 0xff;
        data[pos++] = relativeOffset & 0xff;
      }
      if (i < objects.length) {
        relativeOffset += objects[i].length;
      }
    }

    for (int i = 0; i < count; i++) {
      trackers?[i].offset(pos);
      data.setAll(pos, objects[i]);
      pos += objects[i].length;
    }
    return data;
  }
}

class CFFParser {
  Uint8List bytes;
  dynamic properties;
  bool seacAnalysisEnabled;
  CFFParser(this.bytes, this.properties, this.seacAnalysisEnabled);

  CFF parse() {
    throw UnimplementedError("CFFParser.parse() depends on fonts.js");
  }
}
