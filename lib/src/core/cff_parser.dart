// Copyright 2016 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'package:pdfjs/src/shared/util.dart';
import 'charsets.dart';
import 'encodings.dart';

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

  Uint8List get data => Uint8List.sublistView(_buf, 0, _pos);
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
      int charsetIndex =
          charset.charset.isNotEmpty && charset.charset.first == '.notdef'
              ? 1
              : 0;
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
    final cff = CFF(bytes.length);
    final headerResult = parseHeader();
    final nameResult = parseIndex(headerResult.endPos);
    final topDictResult = parseIndex(nameResult.endPos);
    final stringResult = parseIndex(topDictResult.endPos);
    final globalSubrResult = parseIndex(stringResult.endPos);
    if (topDictResult.obj.count == 0) {
      throw const FormatException('CFF top dictionary is missing');
    }

    cff.header = headerResult.obj;
    cff.names = parseNameIndex(nameResult.obj);
    cff.strings = parseStringIndex(stringResult.obj);
    cff.globalSubrIndex = globalSubrResult.obj;
    final topDict = createTopDict(
      parseDict(topDictResult.obj.get(0)),
      cff.strings,
    );
    cff.topDict = topDict;
    parsePrivateDict(topDict);
    cff.isCIDFont = topDict.hasName('ROS');

    final charStringOffset = topDict.getByName('CharStrings');
    if (charStringOffset is! num ||
        charStringOffset < 0 ||
        charStringOffset >= bytes.length) {
      throw const FormatException('Invalid CFF CharStrings offset');
    }
    final charStrings = parseIndex(charStringOffset.toInt()).obj;
    cff.charStringCount = charStrings.count;
    _applyFontMetrics(topDict);

    if (cff.isCIDFont) {
      final fdArrayOffset = topDict.getByName('FDArray');
      final fdSelectOffset = topDict.getByName('FDSelect');
      if (fdArrayOffset is! num || fdSelectOffset is! num) {
        throw const FormatException('Invalid CID font dictionary offsets');
      }
      final fdArrayIndex = parseIndex(fdArrayOffset.toInt()).obj;
      for (var i = 0; i < fdArrayIndex.count; i++) {
        final fontDict = createTopDict(
          parseDict(fdArrayIndex.get(i)),
          cff.strings,
        );
        parsePrivateDict(fontDict);
        cff.fdArray.add(fontDict);
      }
      cff.charset = parseCharsets(
        (topDict.getByName('charset') as num).toInt(),
        charStrings.count,
        cff.strings,
        true,
      );
      cff.fdSelect = parseFDSelect(fdSelectOffset.toInt(), charStrings.count);
    } else {
      cff.charset = parseCharsets(
        (topDict.getByName('charset') as num).toInt(),
        charStrings.count,
        cff.strings,
        false,
      );
      cff.encoding = parseEncoding(
        (topDict.getByName('Encoding') as num).toInt(),
        cff.strings,
        cff.charset!.charset,
      );
    }

    final result = parseCharStrings(
      charStrings: charStrings,
      localSubrIndex: topDict.privateDict?.subrsIndex,
      globalSubrIndex: cff.globalSubrIndex,
      fdSelect: cff.fdSelect,
      fdArray: cff.fdArray,
      privateDict: topDict.privateDict!,
    );
    cff.charStrings = result.charStrings;
    cff.seacs = result.seacs;
    cff.widths = result.widths;
    return cff;
  }

  CFFObjectResult<CFFHeader> parseHeader() {
    var offset = 0;
    while (offset < bytes.length && bytes[offset] != 1) {
      offset++;
    }
    if (offset >= bytes.length || bytes.length - offset < 4) {
      throw const FormatException('Invalid CFF header');
    }
    if (offset != 0) {
      info('CFF data is shifted');
      bytes = Uint8List.sublistView(bytes, offset);
    }
    final header = CFFHeader(bytes[0], bytes[1], bytes[2], bytes[3]);
    if (header.hdrSize < 4 || header.hdrSize > bytes.length) {
      throw const FormatException('Invalid CFF header size');
    }
    if (header.offSize < 1 || header.offSize > 4) {
      throw const FormatException('Invalid CFF header offset size');
    }
    return CFFObjectResult(header, header.hdrSize);
  }

  List<List<dynamic>> parseDict(Uint8List dict) {
    final entries = <List<dynamic>>[];
    var operands = <num>[];
    var pos = 0;
    void requireDictBytes(int position, int count, String context) {
      if (position < 0 || count < 0 || position + count > dict.length) {
        throw FormatException('Truncated CFF data while reading $context');
      }
    }

    num parseOperand() {
      final value = dict[pos++];
      if (value == 30) {
        final buffer = StringBuffer();
        const lookup = <String?>[
          '0',
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          '.',
          'E',
          'E-',
          null,
          '-',
        ];
        while (pos < dict.length) {
          final byte = dict[pos++];
          for (final nibble in [byte >> 4, byte & 15]) {
            if (nibble == 15) {
              return double.tryParse(buffer.toString()) ?? double.nan;
            }
            final token = lookup[nibble];
            if (token == null) {
              return double.nan;
            }
            buffer.write(token);
          }
        }
        return double.tryParse(buffer.toString()) ?? double.nan;
      }
      if (value == 28) {
        requireDictBytes(pos, 2, 'DICT short integer');
        final result = ByteData.sublistView(dict).getInt16(pos);
        pos += 2;
        return result;
      }
      if (value == 29) {
        requireDictBytes(pos, 4, 'DICT long integer');
        final result = ByteData.sublistView(dict).getInt32(pos);
        pos += 4;
        return result;
      }
      if (value >= 32 && value <= 246) return value - 139;
      if (value >= 247 && value <= 250) {
        requireDictBytes(pos, 1, 'DICT positive integer');
        return (value - 247) * 256 + dict[pos++] + 108;
      }
      if (value >= 251 && value <= 254) {
        requireDictBytes(pos, 1, 'DICT negative integer');
        return -((value - 251) * 256) - dict[pos++] - 108;
      }
      warn('CFFParser.parseDict: "$value" is a reserved command.');
      return double.nan;
    }

    while (pos < dict.length) {
      var value = dict[pos];
      if (value <= 21) {
        if (value == 12) {
          requireDictBytes(pos + 1, 1, 'DICT escaped operator');
          value = (value << 8) | dict[++pos];
        }
        entries.add(<dynamic>[value, operands]);
        operands = <num>[];
        pos++;
      } else {
        operands.add(parseOperand());
      }
    }
    return entries;
  }

  CFFObjectResult<CFFIndex> parseIndex(int position) {
    var pos = position;
    _requireBytes(pos, 2, 'INDEX count');
    final count = (bytes[pos++] << 8) | bytes[pos++];
    final index = CFFIndex();
    if (count == 0) return CFFObjectResult(index, pos);
    _requireBytes(pos, 1, 'INDEX offset size');
    final offsetSize = bytes[pos++];
    if (offsetSize < 1 || offsetSize > 4) {
      throw FormatException('Invalid CFF INDEX offset size: $offsetSize');
    }
    _requireBytes(pos, (count + 1) * offsetSize, 'INDEX offsets');
    final offsets = <int>[];
    for (var i = 0; i <= count; i++) {
      var offset = 0;
      for (var j = 0; j < offsetSize; j++) {
        offset = (offset << 8) | bytes[pos++];
      }
      offsets.add(offset);
    }
    if (offsets.first != 1) {
      throw const FormatException('Invalid CFF INDEX first offset');
    }
    final dataStart = pos;
    var previous = 1;
    for (var i = 0; i < count; i++) {
      final start = offsets[i];
      final end = offsets[i + 1];
      if (start < previous || end < start) {
        throw const FormatException('Invalid CFF INDEX offset ordering');
      }
      final absoluteStart = dataStart + start - 1;
      final absoluteEnd = dataStart + end - 1;
      if (absoluteStart < dataStart || absoluteEnd > bytes.length) {
        throw const FormatException('CFF INDEX points outside font data');
      }
      index.add(Uint8List.sublistView(bytes, absoluteStart, absoluteEnd));
      previous = end;
    }
    return CFFObjectResult(index, dataStart + offsets.last - 1);
  }

  List<String> parseNameIndex(CFFIndex index) => [
        for (var i = 0; i < index.count; i++)
          String.fromCharCodes(index.get(i)),
      ];

  CFFStrings parseStringIndex(CFFIndex index) {
    final strings = CFFStrings();
    for (var i = 0; i < index.count; i++) {
      strings.add(String.fromCharCodes(index.get(i)));
    }
    return strings;
  }

  CFFTopDict createTopDict(
    List<List<dynamic>> entries,
    CFFStrings strings,
  ) {
    final dict = CFFTopDict(strings);
    for (final entry in entries) {
      dict.setByKey(entry[0] as int, entry[1]);
    }
    return dict;
  }

  CFFPrivateDict createPrivateDict(
    List<List<dynamic>> entries,
    CFFStrings strings,
  ) {
    final dict = CFFPrivateDict(strings);
    for (final entry in entries) {
      dict.setByKey(entry[0] as int, entry[1]);
    }
    return dict;
  }

  void emptyPrivateDictionary(CFFTopDict parentDict) {
    parentDict.setByKey(18, [0, 0]);
    parentDict.privateDict = CFFPrivateDict(parentDict.strings);
  }

  void parsePrivateDict(CFFTopDict parentDict) {
    if (!parentDict.hasName('Private')) {
      emptyPrivateDictionary(parentDict);
      return;
    }
    final privateLocation = parentDict.getByName('Private');
    if (privateLocation is! List || privateLocation.length != 2) {
      parentDict.removeByName('Private');
      emptyPrivateDictionary(parentDict);
      return;
    }
    final sizeValue = privateLocation[0];
    final offsetValue = privateLocation[1];
    if (sizeValue is! num || offsetValue is! num) {
      emptyPrivateDictionary(parentDict);
      return;
    }
    final size = sizeValue.toInt();
    final offset = offsetValue.toInt();
    if (size <= 0 || offset < 0 || offset >= bytes.length) {
      emptyPrivateDictionary(parentDict);
      return;
    }
    final end = offset + size;
    if (end > bytes.length) {
      emptyPrivateDictionary(parentDict);
      return;
    }
    final privateDict = createPrivateDict(
      parseDict(Uint8List.sublistView(bytes, offset, end)),
      parentDict.strings,
    );
    parentDict.privateDict = privateDict;
    if (privateDict.getByName('ExpansionFactor') == 0) {
      privateDict.setByName('ExpansionFactor', 0.06);
    }
    final subrs = privateDict.getByName('Subrs');
    if (subrs is! num) return;
    final relativeOffset = offset + subrs.toInt();
    if (subrs == 0 || relativeOffset < 0 || relativeOffset >= bytes.length) {
      emptyPrivateDictionary(parentDict);
      return;
    }
    privateDict.subrsIndex = parseIndex(relativeOffset).obj;
  }

  CFFCharset parseCharsets(
    int position,
    int length,
    CFFStrings? strings,
    bool cid,
  ) {
    if (position == 0) return CFFCharset(true, 0, isoAdobeCharset);
    if (position == 1) return CFFCharset(true, 1, expertCharset);
    if (position == 2) return CFFCharset(true, 2, expertSubsetCharset);
    var pos = position;
    _requireBytes(pos, 1, 'charset format');
    final start = pos;
    final format = bytes[pos++];
    final charset = <dynamic>[cid ? 0 : '.notdef'];
    final remaining = length - 1;
    void addRange(int id, int count) {
      if (count < 0 || charset.length + count > length) {
        throw const FormatException('Invalid CFF charset range');
      }
      for (var i = 0; i < count; i++) {
        charset.add(cid ? id + i : strings!.get(id + i));
      }
    }

    switch (format) {
      case 0:
        for (var i = 0; i < remaining; i++) {
          _requireBytes(pos, 2, 'charset SID');
          final id = (bytes[pos++] << 8) | bytes[pos++];
          addRange(id, 1);
        }
        break;
      case 1:
        while (charset.length < length) {
          _requireBytes(pos, 3, 'charset range');
          final id = (bytes[pos++] << 8) | bytes[pos++];
          addRange(id, bytes[pos++] + 1);
        }
        break;
      case 2:
        while (charset.length < length) {
          _requireBytes(pos, 4, 'charset range');
          final id = (bytes[pos++] << 8) | bytes[pos++];
          final count = ((bytes[pos++] << 8) | bytes[pos++]) + 1;
          addRange(id, count);
        }
        break;
      default:
        throw FormatException('Unknown CFF charset format: $format');
    }
    return CFFCharset(
      false,
      format,
      charset,
      Uint8List.sublistView(bytes, start, pos),
    );
  }

  CFFEncoding parseEncoding(
    int position,
    CFFStrings strings,
    List<dynamic>? charset,
  ) {
    final encoding = <int, int>{};
    if (position == 0 || position == 1) {
      final base = position == 0 ? standardEncoding : expertEncoding;
      final glyphs = charset ?? const <dynamic>[];
      for (var glyphId = 0; glyphId < glyphs.length; glyphId++) {
        final charCode = base.indexOf(glyphs[glyphId]);
        if (charCode >= 0) encoding[charCode] = glyphId;
      }
      return CFFEncoding(true, position, encoding);
    }
    var pos = position;
    final start = pos;
    _requireBytes(pos, 1, 'encoding format');
    var format = bytes[pos++];
    switch (format & 0x7f) {
      case 0:
        _requireBytes(pos, 1, 'encoding glyph count');
        final count = bytes[pos++];
        _requireBytes(pos, count, 'encoding codes');
        for (var glyphId = 1; glyphId <= count; glyphId++) {
          encoding[bytes[pos++]] = glyphId;
        }
        break;
      case 1:
        _requireBytes(pos, 1, 'encoding range count');
        final count = bytes[pos++];
        var glyphId = 1;
        for (var i = 0; i < count; i++) {
          _requireBytes(pos, 2, 'encoding range');
          final first = bytes[pos++];
          final left = bytes[pos++];
          if (first + left > 255) {
            throw const FormatException('Invalid CFF encoding range');
          }
          for (var code = first; code <= first + left; code++) {
            encoding[code] = glyphId++;
          }
        }
        break;
      default:
        throw FormatException('Unknown CFF encoding format: $format');
    }
    final dataEnd = pos;
    if ((format & 0x80) != 0) {
      bytes[start] &= 0x7f;
      _requireBytes(pos, 1, 'encoding supplement count');
      final supplementCount = bytes[pos++];
      for (var i = 0; i < supplementCount; i++) {
        _requireBytes(pos, 3, 'encoding supplement');
        final code = bytes[pos++];
        final sid = (bytes[pos++] << 8) | bytes[pos++];
        encoding[code] = charset?.indexOf(strings.get(sid)) ?? -1;
      }
    }
    format &= 0x7f;
    return CFFEncoding(
      false,
      format,
      encoding,
      Uint8List.sublistView(bytes, start, dataEnd),
    );
  }

  CFFFDSelect parseFDSelect(int position, int length) {
    var pos = position;
    _requireBytes(pos, 1, 'FDSelect format');
    final format = bytes[pos++];
    final fdSelect = <int>[];
    switch (format) {
      case 0:
        _requireBytes(pos, length, 'FDSelect entries');
        for (var i = 0; i < length; i++) fdSelect.add(bytes[pos++]);
        break;
      case 3:
        _requireBytes(pos, 2, 'FDSelect range count');
        final ranges = (bytes[pos++] << 8) | bytes[pos++];
        if (ranges == 0) {
          throw const FormatException('FDSelect must contain a range');
        }
        for (var i = 0; i < ranges; i++) {
          _requireBytes(pos, 5, 'FDSelect range and sentinel');
          var first = (bytes[pos++] << 8) | bytes[pos++];
          if (i == 0 && first != 0) {
            warn('FDSelect first range must begin with glyph zero');
            first = 0;
          }
          final fdIndex = bytes[pos++];
          final next = (bytes[pos] << 8) | bytes[pos + 1];
          if (next < first || next > length) {
            throw const FormatException('Invalid FDSelect range');
          }
          for (var glyph = first; glyph < next; glyph++) {
            fdSelect.add(fdIndex);
          }
        }
        pos += 2;
        break;
      default:
        throw FormatException('Unknown FDSelect format: $format');
    }
    if (fdSelect.length != length) {
      throw const FormatException('Invalid FDSelect glyph count');
    }
    return CFFFDSelect(format, fdSelect);
  }

  CFFCharStringsResult parseCharStrings({
    required CFFIndex charStrings,
    CFFIndex? localSubrIndex,
    CFFIndex? globalSubrIndex,
    CFFFDSelect? fdSelect,
    List<CFFTopDict> fdArray = const [],
    required CFFPrivateDict privateDict,
  }) {
    final seacs = <dynamic>[];
    final widths = <num>[];
    for (var i = 0; i < charStrings.count; i++) {
      final data = charStrings.get(i);
      var selectedPrivate = privateDict;
      var selectedSubrs = localSubrIndex;
      var valid = true;
      if (fdSelect != null && fdArray.isNotEmpty) {
        final fdIndex = fdSelect.getFDIndex(i);
        if (fdIndex < 0 || fdIndex >= fdArray.length) {
          valid = false;
        } else {
          selectedPrivate = fdArray[fdIndex].privateDict!;
          selectedSubrs = selectedPrivate.subrsIndex;
        }
      }
      final state = _CharStringState();
      if (valid) {
        valid = _parseCharString(
          state,
          data,
          selectedSubrs,
          globalSubrIndex,
        );
      }
      widths.add(
        state.width == null
            ? (selectedPrivate.getByName('defaultWidthX') as num)
            : (selectedPrivate.getByName('nominalWidthX') as num) +
                state.width!,
      );
      if (state.seac != null) {
        while (seacs.length <= i) seacs.add(null);
        seacs[i] = state.seac;
      }
      if (!valid) charStrings.set(i, [14]);
    }
    return CFFCharStringsResult(charStrings, seacs, widths);
  }

  bool _parseCharString(
    _CharStringState state,
    Uint8List data,
    CFFIndex? localSubrs,
    CFFIndex? globalSubrs,
  ) {
    if (state.callDepth > MAX_SUBR_NESTING) return false;
    final view = ByteData.sublistView(data);
    var pos = 0;
    while (pos < data.length) {
      final operatorPosition = pos;
      final value = data[pos++];
      if (value == 28) {
        if (pos + 2 > data.length) return false;
        state.stack.add(view.getInt16(pos));
        pos += 2;
        continue;
      }
      if (value >= 32 && value <= 246) {
        state.stack.add(value - 139);
        continue;
      }
      if (value >= 247 && value <= 254) {
        if (pos >= data.length) return false;
        state.stack.add(value < 251
            ? ((value - 247) << 8) + data[pos++] + 108
            : -((value - 251) << 8) - data[pos++] - 108);
        continue;
      }
      if (value == 255) {
        if (pos + 4 > data.length) return false;
        state.stack.add(view.getInt32(pos) / 65536);
        pos += 4;
        continue;
      }
      if (value == 12) {
        if (pos >= data.length) return false;
        final escaped = data[pos++];
        if (escaped == 0) {
          data[operatorPosition] = 139;
          data[operatorPosition + 1] = 22;
          state.stack.clear();
          continue;
        }
        if (!_applyEscapedOperator(escaped, state.stack)) return false;
        continue;
      }
      if (value == 10 || value == 29) {
        final subrs = value == 10 ? localSubrs : globalSubrs;
        if (subrs == null || state.stack.isEmpty) return false;
        final operand = state.stack.removeLast();
        final bias = subrs.count < 1240
            ? 107
            : subrs.count < 33900
                ? 1131
                : 32768;
        final subrNumber = operand.toInt() + bias;
        if (subrNumber < 0 || subrNumber >= subrs.count) return false;
        state.callDepth++;
        final valid = _parseCharString(
          state,
          subrs.get(subrNumber),
          localSubrs,
          globalSubrs,
        );
        state.callDepth--;
        if (!valid) return false;
        continue;
      }
      if (value == 11) return true;
      if (value == 9) {
        _removeByte(data, operatorPosition);
        pos--;
        continue;
      }
      if ((value == 19 || value == 20)) {
        state.hints += state.stack.length >> 1;
        if (state.hints == 0) {
          _removeByte(data, operatorPosition);
          pos--;
          continue;
        }
        pos += (state.hints + 7) >> 3;
        if (pos > data.length) return false;
      }
      final rule = _charStringRules[value];
      if (rule == null) {
        if (value == 0 && pos == data.length) {
          data[operatorPosition] = 14;
          state.stack.clear();
          return true;
        }
        return false;
      }
      if (rule.stem) {
        state.hints += state.stack.length >> 1;
        if (value == 3 || value == 23) state.hasVStems = true;
        if (state.hasVStems && (value == 1 || value == 18)) {
          data[operatorPosition] = value == 1 ? 3 : 23;
        }
      }
      if (state.stack.length < rule.minimum) return false;
      if (state.firstStackClearing && rule.stackClearing) {
        state.firstStackClearing = false;
        var optional = state.stack.length - rule.minimum;
        if (optional >= 2 && rule.stem) optional %= 2;
        if (optional > 0) state.width = state.stack[optional - 1];
      }
      if (value == 14 && state.stack.length >= 4) {
        final start = state.stack.length - 4;
        if (seacAnalysisEnabled) {
          state.seac = state.stack.sublist(start);
          charStringsSafeEnd(data);
          return false;
        }
      }
      if (rule.stackClearing || rule.resetStack) state.stack.clear();
    }
    return true;
  }

  bool _applyEscapedOperator(int operator, List<num> stack) {
    int require(int count) => stack.length >= count ? stack.length : -1;
    switch (operator) {
      case 3:
        if (require(2) < 0) return false;
        stack[stack.length - 2] =
            stack[stack.length - 2] != 0 && stack.removeLast() != 0 ? 1 : 0;
        return true;
      case 4:
        if (require(2) < 0) return false;
        stack[stack.length - 2] =
            stack[stack.length - 2] != 0 || stack.removeLast() != 0 ? 1 : 0;
        return true;
      case 5:
        if (require(1) < 0) return false;
        stack.last = stack.last == 0 ? 1 : 0;
        return true;
      case 9:
        if (require(1) < 0) return false;
        stack.last = stack.last.abs();
        return true;
      case 10:
      case 11:
      case 12:
        if (require(2) < 0) return false;
        final right = stack.removeLast();
        if (operator == 10) stack.last += right;
        if (operator == 11) stack.last -= right;
        if (operator == 12) stack.last /= right;
        return true;
      case 14:
        if (require(1) < 0) return false;
        stack.last = -stack.last;
        return true;
      case 15:
        if (require(2) < 0) return false;
        final right = stack.removeLast();
        stack.last = stack.last == right ? 1 : 0;
        return true;
      case 18:
        if (require(1) < 0) return false;
        stack.removeLast();
        return true;
      case 20:
        if (require(2) < 0) return false;
        stack.removeLast();
        stack.removeLast();
        return true;
      case 21:
        if (require(1) < 0) return false;
        return true;
      case 22:
        if (require(4) < 0) return false;
        final second = stack.removeLast();
        final first = stack.removeLast();
        final v2 = stack.removeLast();
        final v1 = stack.removeLast();
        stack.add(v1 <= v2 ? first : second);
        return true;
      case 23:
        stack.add(0.5);
        return true;
      case 26:
        if (require(1) < 0) return false;
        stack.last = stack.last < 0 ? double.nan : _sqrt(stack.last.toDouble());
        return true;
      case 27:
        if (require(1) < 0) return false;
        stack.add(stack.last);
        return true;
      case 28:
        if (require(2) < 0) return false;
        final last = stack.last;
        stack[stack.length - 1] = stack[stack.length - 2];
        stack[stack.length - 2] = last;
        return true;
      case 29:
        if (require(1) < 0) return false;
        final index = stack.removeLast().toInt();
        if (index < 0 || index >= stack.length) return false;
        stack.add(stack[stack.length - 1 - index]);
        return true;
      case 30:
        if (require(2) < 0) return false;
        final shift = stack.removeLast().toInt();
        final count = stack.removeLast().toInt();
        if (count <= 0 || count > stack.length) return false;
        final start = stack.length - count;
        final values = stack.sublist(start);
        for (var i = 0; i < count; i++) {
          stack[start + ((i + shift) % count + count) % count] = values[i];
        }
        return true;
      case 34:
      case 35:
      case 36:
      case 37:
        final minimum = operator == 34
            ? 7
            : operator == 35
                ? 13
                : operator == 36
                    ? 9
                    : 11;
        if (require(minimum) < 0) return false;
        stack.clear();
        return true;
      default:
        return false;
    }
  }

  void _applyFontMetrics(CFFTopDict dict) {
    final matrix = dict.getByName('FontMatrix');
    final bbox = dict.getByName('FontBBox');
    if (properties is Map) {
      if (matrix != null) properties['fontMatrix'] = matrix;
      if (bbox is List && bbox.length >= 4) {
        properties['ascent'] =
            (bbox[3] as num) > (bbox[1] as num) ? bbox[3] : bbox[1];
        properties['descent'] =
            (bbox[1] as num) < (bbox[3] as num) ? bbox[1] : bbox[3];
        properties['ascentScaled'] = true;
      }
      return;
    }
    try {
      if (matrix != null) properties.fontMatrix = matrix;
      if (bbox is List && bbox.length >= 4) {
        properties.ascent =
            (bbox[3] as num) > (bbox[1] as num) ? bbox[3] : bbox[1];
        properties.descent =
            (bbox[1] as num) < (bbox[3] as num) ? bbox[1] : bbox[3];
        properties.ascentScaled = true;
      }
    } catch (_) {}
  }

  void _requireBytes(int position, int count, String context) {
    if (position < 0 || count < 0 || position + count > bytes.length) {
      throw FormatException('Truncated CFF data while reading $context');
    }
  }

  static void _removeByte(Uint8List data, int index) {
    for (var i = index; i + 1 < data.length; i++) data[i] = data[i + 1];
    data[data.length - 1] = 14;
  }

  static void charStringsSafeEnd(Uint8List data) {
    for (var i = 0; i < data.length; i++) data[i] = 14;
  }

  static double _sqrt(double value) {
    if (value == 0) return 0;
    var estimate = value < 1 ? 1.0 : value;
    for (var i = 0; i < 20; i++) {
      estimate = (estimate + value / estimate) / 2;
    }
    return estimate;
  }
}

class CFFObjectResult<T> {
  final T obj;
  final int endPos;

  const CFFObjectResult(this.obj, this.endPos);
}

class CFFCharStringsResult {
  final CFFIndex charStrings;
  final List<dynamic> seacs;
  final List<num> widths;

  const CFFCharStringsResult(this.charStrings, this.seacs, this.widths);
}

class _CharStringState {
  int callDepth = 0;
  final List<num> stack = [];
  int hints = 0;
  bool firstStackClearing = true;
  List<num>? seac;
  num? width;
  bool hasVStems = false;
}

class _CharStringRule {
  final int minimum;
  final bool stackClearing;
  final bool resetStack;
  final bool stem;

  const _CharStringRule(
    this.minimum, {
    this.stackClearing = false,
    this.resetStack = false,
    this.stem = false,
  });
}

const Map<int, _CharStringRule> _charStringRules = {
  1: _CharStringRule(2, stackClearing: true, stem: true),
  3: _CharStringRule(2, stackClearing: true, stem: true),
  4: _CharStringRule(1, stackClearing: true),
  5: _CharStringRule(2, resetStack: true),
  6: _CharStringRule(1, resetStack: true),
  7: _CharStringRule(1, resetStack: true),
  8: _CharStringRule(6, resetStack: true),
  14: _CharStringRule(0, stackClearing: true),
  18: _CharStringRule(2, stackClearing: true, stem: true),
  19: _CharStringRule(0, stackClearing: true),
  20: _CharStringRule(0, stackClearing: true),
  21: _CharStringRule(2, stackClearing: true),
  22: _CharStringRule(1, stackClearing: true),
  23: _CharStringRule(2, stackClearing: true, stem: true),
  24: _CharStringRule(8, resetStack: true),
  25: _CharStringRule(8, resetStack: true),
  26: _CharStringRule(4, resetStack: true),
  27: _CharStringRule(4, resetStack: true),
  30: _CharStringRule(4, resetStack: true),
  31: _CharStringRule(4, resetStack: true),
};
