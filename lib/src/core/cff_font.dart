// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'cff_parser.dart';
import '../shared/util.dart';
import 'fonts_utils.dart';
import 'stream.dart';

class CFFFont {
  dynamic properties;
  late CFF cff;
  late List<dynamic> seacs;
  late Uint8List data;

  CFFFont(Stream file, this.properties) {
    final parser = CFFParser(file.getBytes(), properties, SEAC_ANALYSIS_ENABLED);
    
    // Note: parser.parse() is a complex implementation from CFFParser. 
    cff = parser.parse();
    cff.duplicateFirstGlyph();
    final compiler = CFFCompiler(cff);
    seacs = cff.seacs;
    try {
      data = compiler.compile();
    } catch (_) {
      warn("Failed to compile font \${properties.loadedName}");
      data = file.getBytes();
    }
    _createBuiltInEncoding();
  }

  int get numGlyphs => cff.charStrings!.count;

  List<dynamic> getCharset() {
    return cff.charset!.charset;
  }

  Map<int, int> getGlyphMapping() {
    final cMap = properties.cMap;
    final charsets = cff.charset!.charset;
    Map<int, int> charCodeToGlyphId;
    int glyphId;

    if (properties.composite == true) {
      Map<int, int>? invCidToGidMap;
      final cidToGidMap = properties.cidToGidMap;
      if (cidToGidMap != null && cidToGidMap is List && cidToGidMap.isNotEmpty) {
        invCidToGidMap = <int, int>{};
        for (int i = 0, ii = cidToGidMap.length; i < ii; i++) {
          final gid = cidToGidMap[i];
          if (gid != null) {
            invCidToGidMap[gid as int] = i;
          }
        }
      }

      charCodeToGlyphId = <int, int>{};
      int charCode;
      if (cff.isCIDFont) {
        for (glyphId = 0; glyphId < charsets.length; glyphId++) {
          final cid = charsets[glyphId] as int;
          charCode = cMap.charCodeOf(cid) as int;

          if (invCidToGidMap != null && invCidToGidMap.containsKey(charCode)) {
            charCode = invCidToGidMap[charCode]!;
          }
          charCodeToGlyphId[charCode] = glyphId;
        }
      } else {
        for (glyphId = 0; glyphId < cff.charStrings!.count; glyphId++) {
          charCode = cMap.charCodeOf(glyphId) as int;
          charCodeToGlyphId[charCode] = glyphId;
        }
      }
      return charCodeToGlyphId;
    }

    dynamic encoding = cff.encoding?.encoding;
    if (properties.isInternalFont == true) {
      encoding = properties.defaultEncoding;
    }
    charCodeToGlyphId = type1FontGlyphMapping(properties, encoding, List<String>.from(charsets));
    return charCodeToGlyphId;
  }

  bool hasGlyphId(int id) {
    return cff.hasGlyphId(id);
  }

  void _createBuiltInEncoding() {
    final charset = cff.charset;
    final encoding = cff.encoding;
    if (charset == null || encoding == null) {
      return;
    }
    final charsets = charset.charset;
    final encodings = encoding.encoding;
    final map = <int, String>{};

    for (final charCode in encodings.keys) {
      final glyphId = encodings[charCode]!;
      if (glyphId >= 0) {
        final glyphName = charsets[glyphId];
        if (glyphName != null && glyphName is String) {
          map[charCode] = glyphName;
        }
      }
    }
    if (map.isNotEmpty) {
      properties.builtInEncoding = map;
    }
  }
}
