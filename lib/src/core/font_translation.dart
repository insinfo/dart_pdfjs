// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'base_stream.dart';
import 'cid_font_data.dart';
import 'encodings.dart';
import 'fonts.dart';
import 'fonts_utils.dart';
import 'glyphlist.dart';
import 'primitives.dart';
import 'to_unicode_map.dart';
import 'unicode.dart';

/// The display-side representation of one translated PDF font.
///
/// PDF.js normally sends this data through the worker's common-object channel.
/// Keeping it as a value object also makes the non-worker Dart API useful: text
/// operators can be converted to glyph records without requiring a browser.
class TranslatedFont {
  const TranslatedFont({
    required this.loadedName,
    required this.font,
    required this.source,
    required this.properties,
  });

  final String loadedName;
  final Font font;
  final Dict source;
  final Map<String, dynamic> properties;

  List<Map<String, dynamic>> glyphs(String text) => font
      .charsToGlyphs(text)
      .map((glyph) => glyphToMap(glyph))
      .toList(growable: false);

  Map<String, dynamic> exportData() {
    final exported = font.exportData();
    return <String, dynamic>{
      'loadedName': loadedName,
      'fontFamily': font.fallbackName,
      'name': font.name,
      'type': font.type,
      'subtype': font.subtype,
      'missingFile': font.missingFile,
      'vertical': font.vertical,
      'data': exported,
    };
  }
}

Map<String, dynamic> glyphToMap(Glyph glyph) => <String, dynamic>{
      'originalCharCode': glyph.originalCharCode,
      'fontChar': glyph.fontChar,
      'unicode': glyph.unicode,
      'accent': glyph.accent,
      'width': glyph.width,
      'vmetric': glyph.vmetric,
      'operatorListId': glyph.operatorListId,
      'isSpace': glyph.isSpace,
      'isInFont': glyph.isInFont,
    };

/// Translates Type1/TrueType font dictionaries into the existing [Font] model.
///
/// This is the synchronous subset required while parsing a page content stream.
/// It supports the standard simple-font encodings, Differences, widths,
/// descriptor metrics, embedded FontFile/FontFile2 streams, and the commonly
/// encountered textual `bfchar`/`bfrange` ToUnicode CMaps.
class FontTranslator {
  FontTranslator({this.options = const <String, dynamic>{}});

  final Map<String, dynamic> options;

  TranslatedFont translate(Dict dict, String loadedName) {
    final subtype = _name(dict.get('Subtype')) ?? 'Type1';
    final baseFont = _stripSubsetPrefix(
      _name(dict.get('BaseFont')) ?? _name(dict.get('Name')) ?? 'Unknown',
    );
    if (subtype == 'Type0') {
      return _translateComposite(dict, loadedName, baseFont);
    }
    return _translateSimple(dict, loadedName, baseFont, subtype);
  }

  TranslatedFont _translateSimple(
    Dict dict,
    String loadedName,
    String baseFont,
    String subtype,
  ) {
    final descriptor = _dict(dict.get('FontDescriptor'));
    final encoding = _readEncoding(dict.get('Encoding'), baseFont);
    final firstChar = _int(dict.get('FirstChar'), 0).clamp(0, 0xffff);
    final lastChar = _int(dict.get('LastChar'), 255).clamp(firstChar, 0xffff);
    final widths = _readSimpleWidths(dict, firstChar, lastChar);
    final missingWidth = _num(descriptor?.get('MissingWidth'), 0);
    final includedToUnicode = _readToUnicode(dict.get('ToUnicode'));
    final toUnicode = includedToUnicode.length > 0
        ? includedToUnicode
        : _encodingToUnicode(encoding.values, firstChar, lastChar);
    final file = _fontFile(descriptor);
    final properties = <String, dynamic>{
      'loadedName': loadedName,
      'type': subtype == 'TrueType' ? 'TrueType' : 'Type1',
      'subtype': subtype,
      'firstChar': firstChar,
      'lastChar': lastChar,
      'flags': _int(descriptor?.get('Flags'), FontFlags.Nonsymbolic),
      'differences': encoding.differences,
      'defaultEncoding': encoding.values,
      'baseEncodingName': encoding.baseName,
      'hasEncoding': dict.get('Encoding') != null,
      'hasIncludedToUnicodeMap': includedToUnicode.length > 0,
      'toUnicode': toUnicode,
      'widths': widths,
      'defaultWidth': missingWidth,
      'fontMatrix': _numbers(dict.getArray('FontMatrix')) ??
          const <double>[0.001, 0, 0, 0.001, 0, 0],
      'bbox': _numbers(descriptor?.getArray('FontBBox')) ??
          const <double>[0, 0, 0, 0],
      'ascent': _num(descriptor?.get('Ascent'), 800),
      'descent': _num(descriptor?.get('Descent'), -200),
      'capHeight': _num(descriptor?.get('CapHeight'), 0),
      'italicAngle': _num(descriptor?.get('ItalicAngle'), 0),
      'composite': false,
    };
    final font = Font(baseFont, file, properties, options);
    return TranslatedFont(
      loadedName: loadedName,
      font: font,
      source: dict,
      properties: properties,
    );
  }

  TranslatedFont _translateComposite(
    Dict dict,
    String loadedName,
    String baseFont,
  ) {
    final descendants = dict.getArray('DescendantFonts');
    final descendant = descendants is List && descendants.isNotEmpty
        ? _dict(descendants.first)
        : null;
    final descriptor = _dict(descendant?.get('FontDescriptor'));
    final subtype = _name(descendant?.get('Subtype')) ?? 'CIDFontType2';
    final cid = readCidFontData(dict, descendant, options);
    final toUnicode = _readToUnicode(dict.get('ToUnicode'));
    final effectiveToUnicode =
        toUnicode.length > 0 ? toUnicode : IdentityToUnicodeMap(0, 0xffff);
    final properties = <String, dynamic>{
      'loadedName': loadedName,
      'type': subtype,
      'subtype': subtype,
      'flags': _int(descriptor?.get('Flags'), FontFlags.Nonsymbolic),
      'toUnicode': effectiveToUnicode,
      'hasIncludedToUnicodeMap': toUnicode.length > 0,
      'widths': cid.widths,
      'defaultWidth': cid.defaultWidth,
      'vmetrics': cid.vmetrics,
      'defaultVMetrics': cid.defaultVMetrics,
      'cidToGidMap': cid.cidToGidMap,
      'cidSystemInfo': cid.cidSystemInfo,
      'cMap': cid.cMap,
      'fontMatrix': const <double>[0.001, 0, 0, 0.001, 0, 0],
      'bbox': _numbers(descriptor?.getArray('FontBBox')) ??
          const <double>[0, 0, 0, 0],
      'ascent': _num(descriptor?.get('Ascent'), 800),
      'descent': _num(descriptor?.get('Descent'), -200),
      'capHeight': _num(descriptor?.get('CapHeight'), 0),
      'composite': true,
      // A full predefined CMap is handled by cmap.dart. Identity encodings are
      // sufficient for the simple rendering path and retain two-byte codes.
      'cidEncoding': cid.cidEncoding,
      'vertical': cid.vertical,
    };
    final font = Font(baseFont, _fontFile(descriptor), properties, options);
    return TranslatedFont(
      loadedName: loadedName,
      font: font,
      source: dict,
      properties: properties,
    );
  }

  Map<int, num> _readSimpleWidths(Dict dict, int firstChar, int lastChar) {
    final result = <int, num>{};
    final array = dict.getArray('Widths');
    if (array is! List) return result;
    final count = lastChar - firstChar + 1;
    for (var i = 0; i < array.length && i < count; i++) {
      final value = array[i];
      if (value is num) result[firstChar + i] = value;
    }
    return result;
  }

  _EncodingData _readEncoding(dynamic value, String baseFont) {
    var baseName = _name(value);
    Dict? encodingDict;
    if (value is Dict) {
      encodingDict = value;
      baseName = _name(value.get('BaseEncoding'));
    }
    baseName ??= _defaultEncodingFor(baseFont);
    final values = List<String>.from(_encodingByName(baseName));
    final differences = <int, String>{};
    final entries = encodingDict?.getArray('Differences');
    if (entries is List) {
      var code = 0;
      for (final entry in entries) {
        if (entry is num) {
          code = entry.toInt();
        } else if (entry is Name) {
          if (code >= 0 && code < values.length) values[code] = entry.name;
          differences[code++] = entry.name;
        }
      }
    }
    return _EncodingData(baseName, values, differences);
  }

  BaseToUnicodeMap _encodingToUnicode(
    List<String> encoding,
    int firstChar,
    int lastChar,
  ) {
    final glyphs = getGlyphsUnicode();
    final map = <int, String>{};
    for (var code = firstChar;
        code <= lastChar && code < encoding.length;
        code++) {
      final unicode = getUnicodeForGlyph(encoding[code], glyphs);
      if (unicode >= 0 && unicode <= 0x10ffff) {
        map[code] = String.fromCharCode(unicode);
      }
    }
    return ToUnicodeMap(map);
  }

  BaseToUnicodeMap _readToUnicode(dynamic value) {
    if (value is BaseToUnicodeMap) return value;
    if (value is! BaseStream) return ToUnicodeMap();
    value.reset();
    final bytes = value.getBytes();
    value.reset();
    return parseToUnicodeCMap(bytes);
  }

  BaseStream? _fontFile(Dict? descriptor) {
    if (descriptor == null) return null;
    for (final key in const ['FontFile3', 'FontFile2', 'FontFile']) {
      final file = descriptor.get(key);
      if (file is BaseStream) {
        file.reset();
        return file;
      }
    }
    return null;
  }
}

/// Parses the mapping operators used by embedded ToUnicode CMaps.
BaseToUnicodeMap parseToUnicodeCMap(Uint8List bytes) {
  final source = String.fromCharCodes(bytes);
  final tokens = RegExp(r'<[0-9A-Fa-f]+>|\[|\]|-?\d+|\S+')
      .allMatches(source)
      .map((match) => match.group(0)!)
      .toList();
  final result = <int, String>{};
  var i = 0;
  while (i < tokens.length) {
    final count = int.tryParse(tokens[i]);
    if (count == null || i + 1 >= tokens.length) {
      i++;
      continue;
    }
    final operator = tokens[i + 1];
    if (operator == 'beginbfchar') {
      i += 2;
      for (var n = 0; n < count && i + 1 < tokens.length; n++) {
        final from = _hexInt(tokens[i++]);
        final to = _hexString(tokens[i++]);
        if (from != null && to != null) result[from] = to;
      }
      continue;
    }
    if (operator == 'beginbfrange') {
      i += 2;
      for (var n = 0; n < count && i + 2 < tokens.length; n++) {
        final low = _hexInt(tokens[i++]);
        final high = _hexInt(tokens[i++]);
        if (low == null || high == null || low > high) {
          i++;
          continue;
        }
        if (tokens[i] == '[') {
          i++;
          for (var code = low; code <= high && i < tokens.length; code++) {
            if (tokens[i] == ']') break;
            final text = _hexString(tokens[i++]);
            if (text != null) result[code] = text;
          }
          if (i < tokens.length && tokens[i] == ']') i++;
        } else {
          final startBytes = _hexBytes(tokens[i++]);
          if (startBytes == null) continue;
          for (var code = low; code <= high; code++) {
            result[code] = _utf16be(_incrementBytes(startBytes, code - low));
          }
        }
      }
      continue;
    }
    i++;
  }
  return ToUnicodeMap(result);
}

List<int>? _hexBytes(String token) {
  if (!token.startsWith('<') || !token.endsWith('>')) return null;
  var hex = token.substring(1, token.length - 1);
  if (hex.isEmpty) return <int>[];
  if (hex.length.isOdd) hex += '0';
  final result = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    final value = int.tryParse(hex.substring(i, i + 2), radix: 16);
    if (value == null) return null;
    result.add(value);
  }
  return result;
}

int? _hexInt(String token) {
  final bytes = _hexBytes(token);
  if (bytes == null || bytes.isEmpty) return null;
  var value = 0;
  for (final byte in bytes) value = (value << 8) | byte;
  return value;
}

String? _hexString(String token) {
  final bytes = _hexBytes(token);
  return bytes == null ? null : _utf16be(bytes);
}

String _utf16be(List<int> bytes) {
  if (bytes.isEmpty) return '';
  if (bytes.length == 1) return String.fromCharCode(bytes.first);
  final units = <int>[];
  for (var i = 0; i < bytes.length; i += 2) {
    units.add((bytes[i] << 8) | (i + 1 < bytes.length ? bytes[i + 1] : 0));
  }
  return String.fromCharCodes(units);
}

List<int> _incrementBytes(List<int> source, int amount) {
  final result = List<int>.from(source);
  var carry = amount;
  for (var i = result.length - 1; i >= 0 && carry > 0; i--) {
    final value = result[i] + (carry & 0xff);
    result[i] = value & 0xff;
    carry = (carry >> 8) + (value >> 8);
  }
  return result;
}

List<String> _encodingByName(String name) => switch (name) {
      'WinAnsiEncoding' => winAnsiEncoding,
      'MacRomanEncoding' => macRomanEncoding,
      'MacExpertEncoding' => macExpertEncoding,
      'SymbolSetEncoding' => symbolSetEncoding,
      'ZapfDingbatsEncoding' => zapfDingbatsEncoding,
      _ => standardEncoding,
    };

String _defaultEncodingFor(String fontName) {
  if (fontName.contains('Symbol')) return 'SymbolSetEncoding';
  if (fontName.contains('Dingbats')) return 'ZapfDingbatsEncoding';
  return 'StandardEncoding';
}

String _stripSubsetPrefix(String name) =>
    RegExp(r'^[A-Z]{6}\+').hasMatch(name) ? name.substring(7) : name;

String? _name(dynamic value) => value is Name ? value.name : null;
Dict? _dict(dynamic value) => value is Dict ? value : null;
int _int(dynamic value, int fallback) =>
    value is num ? value.toInt() : fallback;
num _num(dynamic value, num fallback) => value is num ? value : fallback;

List<double>? _numbers(dynamic value) {
  if (value is! List || value.any((entry) => entry is! num)) return null;
  return value.map((entry) => (entry as num).toDouble()).toList();
}

class _EncodingData {
  const _EncodingData(this.baseName, this.values, this.differences);

  final String baseName;
  final List<String> values;
  final Map<int, String> differences;
}
