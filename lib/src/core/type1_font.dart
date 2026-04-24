// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'cff_parser.dart';
import '../shared/util.dart';
import 'fonts_utils.dart';
import 'core_utils.dart';
import 'stream.dart';
import 'type1_parser.dart';

class _BlockResult {
  final bool found;
  final int length;
  _BlockResult(this.found, this.length);
}

_BlockResult _findBlock(Uint8List streamBytes, List<int> signature, int startIndex) {
  final streamBytesLength = streamBytes.length;
  final signatureLength = signature.length;
  final scanLength = streamBytesLength - signatureLength;

  int i = startIndex;
  bool found = false;
  while (i < scanLength) {
    int j = 0;
    while (j < signatureLength && streamBytes[i + j] == signature[j]) {
      j++;
    }
    if (j >= signatureLength) {
      i += j;
      while (i < streamBytesLength && isWhiteSpace(streamBytes[i])) {
        i++;
      }
      found = true;
      break;
    }
    i++;
  }
  return _BlockResult(found, i);
}

class _StreamBlock {
  final Stream stream;
  final int length;
  _StreamBlock(this.stream, this.length);
}

_StreamBlock _getHeaderBlock(Stream stream, int suggestedLength) {
  final List<int> EEXEC_SIGNATURE = [0x65, 0x65, 0x78, 0x65, 0x63];

  final streamStartPos = stream.pos;
  Uint8List? headerBytes;
  int headerBytesLength = 0;
  _BlockResult? block;
  try {
    headerBytes = stream.getBytes(suggestedLength);
    headerBytesLength = headerBytes.length;
  } catch (_) {
    // Ignore errors
  }

  if (headerBytesLength == suggestedLength && headerBytes != null) {
    block = _findBlock(
      headerBytes,
      EEXEC_SIGNATURE,
      suggestedLength - 2 * EEXEC_SIGNATURE.length
    );

    if (block.found && block.length == suggestedLength) {
      return _StreamBlock(Stream(headerBytes), suggestedLength);
    }
  }
  warn('Invalid "Length1" property in Type1 font -- trying to recover.');
  stream.pos = streamStartPos;

  const SCAN_BLOCK_LENGTH = 2048;
  int? actualLength;
  while (true) {
    final scanBytes = stream.peekBytes(SCAN_BLOCK_LENGTH);
    block = _findBlock(scanBytes, EEXEC_SIGNATURE, 0);

    if (block.length == 0) {
      break;
    }
    stream.pos += block.length;

    if (block.found) {
      actualLength = stream.pos - streamStartPos;
      break;
    }
  }
  stream.pos = streamStartPos;

  if (actualLength != null) {
    return _StreamBlock(Stream(stream.getBytes(actualLength)), actualLength);
  }
  warn('Unable to recover "Length1" property in Type1 font -- using as is.');
  return _StreamBlock(Stream(stream.getBytes(suggestedLength)), suggestedLength);
}

_StreamBlock _getEexecBlock(Stream stream, int suggestedLength) {
  final eexecBytes = stream.getBytes();
  if (eexecBytes.isEmpty) {
    throw FormatException("getEexecBlock - no font program found.");
  }
  return _StreamBlock(Stream(eexecBytes), eexecBytes.length);
}

class FontProperties {
  int length1 = 0;
  int length2 = 0;
  List<double> fontMatrix = [];
  List<double> bbox = [];
  Map<String, dynamic> privateData = {};
  dynamic cMap;
  bool composite = false;
  Map<int, String>? builtInEncoding;
  
  // Decoded from type1 parser properties
  double ascent = 0;
  double descent = 0;
  bool ascentScaled = false;
  int firstChar = 0;
  int lastChar = 0;
  Map<int, double> widths = {};
}

class Type1Font {
  int _rawFileLength = 0;
  late List<Map<String, dynamic>> charstrings;
  late Uint8List data;
  late List<dynamic> seacs;

  Type1Font(String name, Stream file, dynamic properties) {
    const PFB_HEADER_SIZE = 6;
    int headerBlockLength = properties.length1 ?? 0;
    int eexecBlockLength = properties.length2 ?? 0;
    Uint8List pfbHeader = file.peekBytes(PFB_HEADER_SIZE);
    final pfbHeaderPresent = pfbHeader.length == PFB_HEADER_SIZE && 
                             pfbHeader[0] == 0x80 && pfbHeader[1] == 0x01;
    if (pfbHeaderPresent) {
      file.skip(PFB_HEADER_SIZE);
      headerBlockLength =
        (pfbHeader[5] << 24) |
        (pfbHeader[4] << 16) |
        (pfbHeader[3] << 8) |
        pfbHeader[2];
    }

    final headerBlock = _getHeaderBlock(file, headerBlockLength);
    final headerBlockParser = Type1Parser(
      headerBlock.stream,
      false,
      SEAC_ANALYSIS_ENABLED
    );
    headerBlockParser.extractFontHeader(properties);

    if (pfbHeaderPresent) {
      pfbHeader = file.getBytes(PFB_HEADER_SIZE);
      eexecBlockLength =
        (pfbHeader[5] << 24) |
        (pfbHeader[4] << 16) |
        (pfbHeader[3] << 8) |
        pfbHeader[2];
    }

    final eexecBlock = _getEexecBlock(file, eexecBlockLength);
    final eexecBlockParser = Type1Parser(
      eexecBlock.stream,
      true,
      SEAC_ANALYSIS_ENABLED
    );
    final parsedData = eexecBlockParser.extractFontProgram(properties);
    final parsedProperties = parsedData["properties"];
    if (parsedProperties is Map) {
      for (final key in parsedProperties.keys) {
        if (properties is Map) {
          properties[key] = parsedProperties[key];
        } else {
           try {
             // dynamic injection
             if (key == 'privateData') {
                properties.privateData = parsedProperties[key];
             }
           } catch (_) {}
        }
      }
    }
    _rawFileLength = headerBlock.length + eexecBlock.length;

    charstrings = List<Map<String, dynamic>>.from(parsedData["charstrings"] as List);
    final type2Charstrings = _getType2Charstrings(charstrings);
    final subrs = _getType2Subrs(List<Uint8List>.from(parsedData["subrs"] as List));

    this.charstrings = charstrings;
    data = _wrap(
      name,
      type2Charstrings,
      this.charstrings,
      subrs,
      properties
    );
    seacs = _getSeacs(charstrings);
  }

  int get numGlyphs => charstrings.length + 1;

  List<String> getCharset() {
    final charset = <String>[".notdef"];
    for (final charstring in charstrings) {
      charset.add(charstring["glyphName"] as String);
    }
    return charset;
  }

  Map<int, int> getGlyphMapping(dynamic properties) {
    if (properties.composite == true) {
      final charCodeToGlyphId = <int, int>{};
      for (int glyphId = 0, charstringsLen = charstrings.length; glyphId < charstringsLen; glyphId++) {
        final charCode = properties.cMap.charCodeOf(glyphId);
        charCodeToGlyphId[charCode] = glyphId + 1;
      }
      return charCodeToGlyphId;
    }

    final glyphNames = <String>[".notdef"];
    int glyphId;
    for (glyphId = 0; glyphId < charstrings.length; glyphId++) {
      glyphNames.add(charstrings[glyphId]["glyphName"] as String);
    }
    Map<int, int>? builtInEncoding;
    final encoding = properties.builtInEncoding;
    if (encoding != null && encoding is List) {
      builtInEncoding = <int, int>{};
      for (int charCode = 0; charCode < encoding.length; charCode++) {
         if (encoding[charCode] == null) continue;
         glyphId = glyphNames.indexOf(encoding[charCode] as String);
         if (glyphId >= 0) {
            builtInEncoding[charCode] = glyphId;
         }
      }
    } else if (encoding != null && encoding is Map) {
      builtInEncoding = <int, int>{};
      for (final charCode in encoding.keys) {
         glyphId = glyphNames.indexOf(encoding[charCode] as String);
         if (glyphId >= 0) {
            builtInEncoding[charCode as int] = glyphId;
         }
      }
    }

    return type1FontGlyphMapping(properties, builtInEncoding, glyphNames);
  }

  bool hasGlyphId(int id) {
    if (id < 0 || id >= numGlyphs) {
      return false;
    }
    if (id == 0) {
      return true;
    }
    final glyph = charstrings[id - 1];
    final charstring = glyph["charstring"] as List<int>;
    return charstring.isNotEmpty;
  }

  List<dynamic> _getSeacs(List<Map<String, dynamic>> charstrings) {
    final seacMap = List<dynamic>.filled(charstrings.length + 1, null);
    for (int i = 0, ii = charstrings.length; i < ii; i++) {
      final charstring = charstrings[i];
      if (charstring["seac"] != null) {
        seacMap[i + 1] = charstring["seac"];
      }
    }
    return seacMap;
  }

  List<List<int>> _getType2Charstrings(List<Map<String, dynamic>> type1Charstrings) {
    final type2Charstrings = <List<int>>[];
    for (final type1Charstring in type1Charstrings) {
      type2Charstrings.add(List<int>.from(type1Charstring["charstring"] as List));
    }
    return type2Charstrings;
  }

  List<List<int>> _getType2Subrs(List<Uint8List> type1Subrs) {
    int bias = 0;
    final count = type1Subrs.length;
    if (count < 1133) {
      bias = 107;
    } else if (count < 33769) {
      bias = 1131;
    } else {
      bias = 32768;
    }

    final type2Subrs = <List<int>>[];
    for (int i = 0; i < bias; i++) {
      type2Subrs.add([0x0b]);
    }

    for (int i = 0; i < count; i++) {
      type2Subrs.add(type1Subrs[i]);
    }

    return type2Subrs;
  }

  Uint8List _wrap(String name, List<List<int>> glyphs, List<Map<String, dynamic>> charstrings, List<List<int>> subrs, dynamic properties) {
    final cff = CFF(_rawFileLength);
    cff.header = CFFHeader(1, 0, 4, 4);
    cff.names = [name];

    final topDict = CFFTopDict(cff.strings);
    topDict.setByName("version", 391);
    topDict.setByName("Notice", 392);
    topDict.setByName("FullName", 393);
    topDict.setByName("FamilyName", 394);
    topDict.setByName("Weight", 395);
    
    // Using 0 as placeholder instead of null because setByName drops empty. 
    // And actually compiler treats 0 as special or ignores if it's offset type.
    topDict.setByName("FontMatrix", properties.fontMatrix ?? []);
    try { topDict.setByName("FontBBox", properties.bbox ?? []); } catch(_) {}
    
    cff.topDict = topDict;

    final strings = cff.strings;
    strings.add("Version 0.11");
    strings.add("See original notice");
    strings.add(name);
    strings.add(name);
    strings.add("Medium");

    cff.globalSubrIndex = CFFIndex();

    final count = glyphs.length;
    final charsetArray = <String>[".notdef"];
    for (int i = 0; i < count; i++) {
      final glyphName = charstrings[i]["glyphName"] as String;
      final index = CFFStandardStrings.indexOf(glyphName);
      if (index == -1) {
        strings.add(glyphName);
      }
      charsetArray.add(glyphName);
    }
    cff.charset = CFFCharset(false, 0, charsetArray);

    final charStringsIndex = CFFIndex();
    charStringsIndex.add([0x8b, 0x0e]);
    for (int i = 0; i < count; i++) {
      charStringsIndex.add(glyphs[i]);
    }
    cff.charStrings = charStringsIndex;

    final privateDict = CFFPrivateDict(cff.strings);
    final fields = [
      "BlueValues",
      "OtherBlues",
      "FamilyBlues",
      "FamilyOtherBlues",
      "StemSnapH",
      "StemSnapV",
      "BlueShift",
      "BlueFuzz",
      "BlueScale",
      "LanguageGroup",
      "ExpansionFactor",
      "ForceBold",
      "StdHW",
      "StdVW",
    ];
    for (final field in fields) {
      if (properties.privateData == null || !properties.privateData.containsKey(field)) {
        continue;
      }
      final value = properties.privateData[field];
      if (value is List) {
        for (int j = value.length - 1; j > 0; j--) {
          value[j] -= value[j - 1];
        }
      }
      privateDict.setByName(field, value);
    }
    cff.topDict!.privateDict = privateDict;

    final subrIndex = CFFIndex();
    for (final subr in subrs) {
      subrIndex.add(subr);
    }
    privateDict.subrsIndex = subrIndex;

    final compiler = CFFCompiler(cff);
    return compiler.compile();
  }
}
