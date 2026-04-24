// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import '../shared/math_clamp.dart';
import '../shared/util.dart';
import 'base_stream.dart';
import 'cmap.dart';
import 'encodings.dart';
import 'fonts_utils.dart';
import 'glyphlist.dart';
import 'opentype_file_builder.dart';
import 'standard_fonts.dart';
import 'stream.dart';
import 'to_unicode_map.dart';
import 'unicode.dart';

const List<List<int>> privateUseAreas = [
  [0xe000, 0xf8ff],
  [0x100000, 0x10fffd],
];

const int pdfGlyphSpaceUnits = 1000;

const List<String> exportDataProperties = [
  'ascent',
  'bbox',
  'black',
  'bold',
  'cssFontInfo',
  'data',
  'defaultVMetrics',
  'defaultWidth',
  'descent',
  'disableFontFace',
  'fallbackName',
  'fontExtraProperties',
  'fontMatrix',
  'isInvalidPDFjsFont',
  'isType3Font',
  'italic',
  'loadedName',
  'mimetype',
  'missingFile',
  'name',
  'remeasure',
  'systemFontInfo',
  'vertical',
];

const List<String> exportDataExtraProperties = [
  'cMap',
  'composite',
  'defaultEncoding',
  'differences',
  'isMonospace',
  'isSerifFont',
  'isSymbolicFont',
  'seacMap',
  'subtype',
  'toFontChar',
  'toUnicode',
  'type',
  'vmetrics',
  'widths',
];

class Glyph {
  Glyph(
    this.originalCharCode,
    this.fontChar,
    this.unicode,
    this.accent,
    this.width,
    this.vmetric,
    this.operatorListId,
    this.isSpace,
    this.isInFont,
  );

  final int originalCharCode;
  final String fontChar;
  final String unicode;
  final dynamic accent;
  final num width;
  final dynamic vmetric;
  final dynamic operatorListId;
  final bool isSpace;
  final bool isInFont;
  UnicodeCategory? _category;

  UnicodeCategory get category => _category ??= getCharUnicodeCategory(unicode);
}

int int16(int b0, int b1) => (b0 << 8) + b1;

void writeSignedInt16(Uint8List bytes, int index, int value) {
  bytes[index + 1] = value & 0xff;
  bytes[index] = (value >> 8) & 0xff;
}

int signedInt16(int b0, int b1) {
  final value = (b0 << 8) + b1;
  return (value & (1 << 15)) != 0 ? value - 0x10000 : value;
}

void writeUint32(Uint8List bytes, int index, int value) {
  bytes[index + 3] = value & 0xff;
  bytes[index + 2] = (value >> 8) & 0xff;
  bytes[index + 1] = (value >> 16) & 0xff;
  bytes[index] = (value >> 24) & 0xff;
}

class TrueTypeTableBuilder {
  TrueTypeTableBuilder({int? exactLength, int? minLength}) {
    _hasExactLength = exactLength != null;
    _initBuf(exactLength ?? minLength ?? _bufLength);
  }

  late Uint8List _buf;
  late ByteData _view;
  int _bufLength = 1024;
  bool _hasExactLength = false;
  int _pos = 0;

  void _initBuf(int minLength) {
    if (_hasExactLength) {
      _bufLength = minLength;
    } else {
      while (_bufLength < minLength) {
        _bufLength *= 2;
      }
    }
    final newBuf = Uint8List(_bufLength);
    if (_pos > 0) {
      newBuf.setRange(0, _pos, _buf);
    }
    _buf = newBuf;
    _view = ByteData.view(newBuf.buffer);
  }

  Uint8List get data => _buf.sublist(0, _pos);
  int get length => _pos;

  void skip(int n) {
    _ensure(_pos + n);
    _pos += n;
  }

  void setArray(List<int> arr) {
    final newPos = _pos + arr.length;
    _ensure(newPos);
    _buf.setRange(_pos, newPos, arr);
    _pos = newPos;
  }

  void setInt16(int val) {
    final newPos = _pos + 2;
    _ensure(newPos);
    if (val > 0x7fff) {
      val -= 0x10000;
    }
    _view.setInt16(_pos, val);
    _pos = newPos;
  }

  void setSafeInt16(num val) {
    final newPos = _pos + 2;
    _ensure(newPos);
    _view.setInt16(_pos, mathClamp(val, -0x8000, 0x7fff).toInt());
    _pos = newPos;
  }

  void setInt32(int val) {
    final newPos = _pos + 4;
    _ensure(newPos);
    if (val > 0x7fffffff) {
      val -= 0x100000000;
    }
    _view.setInt32(_pos, val);
    _pos = newPos;
  }

  void _ensure(int newPos) {
    if (_hasExactLength) {
      if (newPos > _bufLength) {
        throw RangeError('TrueTypeTableBuilder exact length exceeded.');
      }
      return;
    }
    if (newPos > _bufLength) {
      _initBuf(newPos);
    }
  }
}

bool isTrueTypeFile(BaseStream file) {
  final str = bytesToString(file.peekBytes(4));
  return str == '\x00\x01\x00\x00' || str == 'true';
}

bool isTrueTypeCollectionFile(BaseStream file) {
  return bytesToString(file.peekBytes(4)) == 'ttcf';
}

bool isOpenTypeFile(BaseStream file) {
  return bytesToString(file.peekBytes(4)) == 'OTTO';
}

bool isType1File(BaseStream file) {
  final header = file.peekBytes(2);
  return (header[0] == 0x25 && header[1] == 0x21) ||
      (header[0] == 0x80 && header[1] == 0x01);
}

bool isCFFFile(BaseStream file) {
  final header = file.peekBytes(4);
  return header[0] >= 1 && header[3] >= 1 && header[3] <= 4;
}

class FontFileType {
  const FontFileType(this.type, this.subtype);

  final String? type;
  final String? subtype;
}

class OpenTypeHeader {
  const OpenTypeHeader({
    required this.version,
    required this.numTables,
    required this.searchRange,
    required this.entrySelector,
    required this.rangeShift,
  });

  final String version;
  final int numTables;
  final int searchRange;
  final int entrySelector;
  final int rangeShift;
}

class OpenTypeTable {
  OpenTypeTable({
    required this.tag,
    required this.checksum,
    required this.length,
    required this.offset,
    required this.data,
  }) : view = ByteData.view(data.buffer, data.offsetInBytes, data.length);

  final String tag;
  final int checksum;
  final int length;
  final int offset;
  final Uint8List data;
  final ByteData view;
}

class NameRecord {
  const NameRecord({
    required this.platform,
    required this.encoding,
    required this.language,
    required this.name,
    required this.length,
    required this.offset,
  });

  final int platform;
  final int encoding;
  final int language;
  final int name;
  final int length;
  final int offset;
}

class NameTableData {
  const NameTableData(this.names, this.records);

  final List<List<String?>> names;
  final List<NameRecord> records;
}

class TrueTypeCollectionHeader {
  TrueTypeCollectionHeader({
    required this.ttcTag,
    required this.majorVersion,
    required this.minorVersion,
    required this.numFonts,
    required this.offsetTable,
    this.dsigTag,
    this.dsigLength,
    this.dsigOffset,
  });

  final String ttcTag;
  final int majorVersion;
  final int minorVersion;
  final int numFonts;
  final List<int> offsetTable;
  final int? dsigTag;
  final int? dsigLength;
  final int? dsigOffset;
}

class TrueTypeCollectionFontData {
  const TrueTypeCollectionFontData({
    required this.header,
    required this.tables,
  });

  final OpenTypeHeader header;
  final Map<String, OpenTypeTable?> tables;
}

FontFileType getFontFileType(
  BaseStream file, {
  String? type,
  String? subtype,
  bool composite = false,
}) {
  String? fileType;
  String? fileSubtype;

  if (isTrueTypeFile(file) || isTrueTypeCollectionFile(file)) {
    fileType = composite ? 'CIDFontType2' : 'TrueType';
  } else if (isOpenTypeFile(file)) {
    fileType = composite ? 'CIDFontType2' : 'OpenType';
  } else if (isType1File(file)) {
    fileType =
        composite ? 'CIDFontType0' : (type == 'MMType1' ? 'MMType1' : 'Type1');
  } else if (isCFFFile(file)) {
    if (composite) {
      fileType = 'CIDFontType0';
      fileSubtype = 'CIDFontType0C';
    } else {
      fileType = type == 'MMType1' ? 'MMType1' : 'Type1';
      fileSubtype = 'Type1C';
    }
  } else {
    warn('getFontFileType: Unable to detect correct font file Type/Subtype.');
    fileType = type;
    fileSubtype = subtype;
  }

  return FontFileType(fileType, fileSubtype);
}

const List<String> validOpenTypeTables = [
  'OS/2',
  'cmap',
  'head',
  'hhea',
  'hmtx',
  'maxp',
  'name',
  'post',
  'loca',
  'glyf',
  'fpgm',
  'prep',
  'cvt ',
  'CFF ',
];

OpenTypeHeader readOpenTypeHeader(BaseStream ttf) {
  return OpenTypeHeader(
    version: ttf.getString(4),
    numTables: ttf.getUint16(),
    searchRange: ttf.getUint16(),
    entrySelector: ttf.getUint16(),
    rangeShift: ttf.getUint16(),
  );
}

OpenTypeTable readTableEntry(BaseStream file) {
  final tag = file.getString(4);
  final checksum = _readUint32(file);
  final offset = _readUint32(file);
  final length = _readUint32(file);

  final previousPosition = file.pos;
  file.pos = _streamStart(file) + offset;
  final data = file.getBytes(length);
  file.pos = previousPosition;

  if (tag == 'head' && data.length > 17) {
    data[8] = data[9] = data[10] = data[11] = 0;
    data[17] |= 0x20;
  }

  return OpenTypeTable(
    tag: tag,
    checksum: checksum,
    length: length,
    offset: offset,
    data: data,
  );
}

Map<String, OpenTypeTable?> readOpenTypeTables(
  BaseStream file,
  int numTables,
) {
  final tables = <String, OpenTypeTable?>{
    'OS/2': null,
    'cmap': null,
    'head': null,
    'hhea': null,
    'hmtx': null,
    'maxp': null,
    'name': null,
    'post': null,
  };

  for (var i = 0; i < numTables; i++) {
    final table = readTableEntry(file);
    if (!validOpenTypeTables.contains(table.tag) || table.length == 0) {
      continue;
    }
    tables[table.tag] = table;
  }
  return tables;
}

TrueTypeCollectionHeader readTrueTypeCollectionHeader(BaseStream ttc) {
  final ttcTag = ttc.getString(4);
  if (ttcTag != 'ttcf') {
    throw FormatError('Must be a TrueType Collection font.');
  }

  final majorVersion = ttc.getUint16();
  final minorVersion = ttc.getUint16();
  final numFonts = _readUint32(ttc);
  final offsetTable = <int>[];
  for (var i = 0; i < numFonts; i++) {
    offsetTable.add(_readUint32(ttc));
  }

  if (majorVersion == 1) {
    return TrueTypeCollectionHeader(
      ttcTag: ttcTag,
      majorVersion: majorVersion,
      minorVersion: minorVersion,
      numFonts: numFonts,
      offsetTable: offsetTable,
    );
  }
  if (majorVersion == 2) {
    return TrueTypeCollectionHeader(
      ttcTag: ttcTag,
      majorVersion: majorVersion,
      minorVersion: minorVersion,
      numFonts: numFonts,
      offsetTable: offsetTable,
      dsigTag: _readUint32(ttc),
      dsigLength: _readUint32(ttc),
      dsigOffset: _readUint32(ttc),
    );
  }
  throw FormatError('Invalid TrueType Collection majorVersion: $majorVersion.');
}

TrueTypeCollectionFontData readTrueTypeCollectionData(
  BaseStream ttc,
  String fontName,
) {
  final header = readTrueTypeCollectionHeader(ttc);
  final fontNameParts = fontName.split('+');
  TrueTypeCollectionFontData? fallbackData;
  String? fallbackName;

  for (var i = 0; i < header.numFonts; i++) {
    ttc.pos = _streamStart(ttc) + header.offsetTable[i];
    final potentialHeader = readOpenTypeHeader(ttc);
    final potentialTables = readOpenTypeTables(ttc, potentialHeader.numTables);
    final nameTable = potentialTables['name'];

    if (nameTable == null) {
      throw FormatError(
          'TrueType Collection font must contain a "name" table.');
    }
    final nameData = readNameTable(ttc, nameTable);

    for (final platformNames in nameData.names) {
      for (final entry in platformNames) {
        final nameEntry = entry?.replaceAll(RegExp(r'\s'), '');
        if (nameEntry == null || nameEntry.isEmpty) {
          continue;
        }
        if (nameEntry == fontName) {
          return TrueTypeCollectionFontData(
            header: potentialHeader,
            tables: potentialTables,
          );
        }
        if (fontNameParts.length < 2) {
          continue;
        }
        for (final part in fontNameParts) {
          if (nameEntry == part) {
            fallbackName = part;
            fallbackData = TrueTypeCollectionFontData(
              header: potentialHeader,
              tables: potentialTables,
            );
          }
        }
      }
    }
  }

  if (fallbackData != null) {
    warn(
      'TrueType Collection does not contain "$fontName" font, '
      'falling back to "$fallbackName" font instead.',
    );
    return fallbackData;
  }
  throw FormatError('TrueType Collection does not contain "$fontName" font.');
}

NameTableData readNameTable(BaseStream font, OpenTypeTable nameTable) {
  final start = _streamStart(font) + nameTable.offset;
  font.pos = start;

  final names = <List<String?>>[<String?>[], <String?>[]];
  final records = <NameRecord>[];
  final length = nameTable.length;
  final end = start + length;
  final format = font.getUint16();
  const format0HeaderLength = 6;
  if (format != 0 || length < format0HeaderLength) {
    return NameTableData(names, records);
  }

  final numRecords = font.getUint16();
  final stringsStart = font.getUint16();
  const nameRecordLength = 12;

  for (var i = 0; i < numRecords && font.pos + nameRecordLength <= end; i++) {
    final record = NameRecord(
      platform: font.getUint16(),
      encoding: font.getUint16(),
      language: font.getUint16(),
      name: font.getUint16(),
      length: font.getUint16(),
      offset: font.getUint16(),
    );
    if (isMacNameRecord(record) || isWinNameRecord(record)) {
      records.add(record);
    }
  }

  for (final record in records) {
    if (record.length <= 0) {
      continue;
    }
    final pos = start + stringsStart + record.offset;
    if (pos + record.length > end) {
      continue;
    }
    font.pos = pos;
    final nameIndex = record.name;
    if (record.encoding != 0) {
      final buffer = StringBuffer();
      for (var j = 0; j < record.length; j += 2) {
        buffer.writeCharCode(font.getUint16());
      }
      _setListAt(names[1], nameIndex, buffer.toString());
    } else {
      _setListAt(names[0], nameIndex, font.getString(record.length));
    }
  }

  return NameTableData(names, records);
}

void adjustWidths(dynamic properties) {
  final fontMatrix = _get(properties, 'fontMatrix');
  if (fontMatrix == null || fontMatrix[0] == fontIdentityMatrix[0]) {
    return;
  }
  final scale = 0.001 / fontMatrix[0];
  final widths = _get(properties, 'widths');
  if (widths is Map) {
    for (final key in widths.keys.toList()) {
      widths[key] = widths[key] * scale;
    }
  }
  _set(properties, 'defaultWidth', _get(properties, 'defaultWidth') * scale);
}

void adjustTrueTypeToUnicode(
  dynamic properties,
  bool isSymbolicFont,
  List<dynamic> nameRecords,
) {
  if (_truthy(_get(properties, 'isInternalFont')) ||
      _truthy(_get(properties, 'hasIncludedToUnicodeMap')) ||
      _truthy(_get(properties, 'hasEncoding')) ||
      _get(properties, 'toUnicode') is IdentityToUnicodeMap ||
      !isSymbolicFont ||
      nameRecords.isEmpty) {
    return;
  }
  if (identical(_get(properties, 'defaultEncoding'), winAnsiEncoding)) {
    return;
  }
  for (final record in nameRecords) {
    if (!isWinNameRecord(record)) {
      return;
    }
  }

  final toUnicode = <int, String>{};
  final glyphsUnicodeMap = getGlyphsUnicode();
  for (var charCode = 0; charCode < winAnsiEncoding.length; charCode++) {
    final glyphName = winAnsiEncoding[charCode];
    if (glyphName.isEmpty) {
      continue;
    }
    final unicode = glyphsUnicodeMap[glyphName];
    if (unicode != null) {
      toUnicode[charCode] = String.fromCharCode(unicode);
    }
  }
  if (toUnicode.isNotEmpty) {
    (_get(properties, 'toUnicode') as BaseToUnicodeMap).amend(toUnicode);
  }
}

void adjustType1ToUnicode(dynamic properties, dynamic builtInEncoding) {
  if (_truthy(_get(properties, 'isInternalFont')) ||
      _truthy(_get(properties, 'hasIncludedToUnicodeMap')) ||
      identical(builtInEncoding, _get(properties, 'defaultEncoding')) ||
      _get(properties, 'toUnicode') is IdentityToUnicodeMap) {
    return;
  }

  final toUnicode = <int, String>{};
  final glyphsUnicodeMap = getGlyphsUnicode();
  if (builtInEncoding is List) {
    for (var charCode = 0; charCode < builtInEncoding.length; charCode++) {
      if (_truthy(_get(properties, 'hasEncoding'))) {
        final differences = _get(properties, 'differences');
        if (_get(properties, 'baseEncodingName') != null ||
            (differences is Map && differences.containsKey(charCode))) {
          continue;
        }
      }
      final glyphName = builtInEncoding[charCode];
      if (glyphName is! String) {
        continue;
      }
      final unicode = getUnicodeForGlyph(glyphName, glyphsUnicodeMap);
      if (unicode != -1) {
        toUnicode[charCode] = String.fromCharCode(unicode);
      }
    }
  }
  if (toUnicode.isNotEmpty) {
    (_get(properties, 'toUnicode') as BaseToUnicodeMap).amend(toUnicode);
  }
}

void amendFallbackToUnicode(dynamic properties) {
  final fallback = _get(properties, 'fallbackToUnicode');
  if (fallback == null ||
      _get(properties, 'toUnicode') is IdentityToUnicodeMap) {
    return;
  }
  final map = <int, String>{};
  final toUnicode = _get(properties, 'toUnicode') as BaseToUnicodeMap;
  if (fallback is Map) {
    for (final entry in fallback.entries) {
      final charCode =
          entry.key is int ? entry.key as int : int.parse(entry.key.toString());
      if (!toUnicode.has(charCode)) {
        map[charCode] = entry.value.toString();
      }
    }
  }
  if (map.isNotEmpty) {
    toUnicode.amend(map);
  }
}

void applyStandardFontGlyphMap(Map<int, int> map, Map<int, int> glyphMap) {
  for (final entry in glyphMap.entries) {
    map[entry.key] = entry.value;
  }
}

Map<int, int> buildToFontChar(
  List<String> encoding,
  Map<String, int> glyphsUnicodeMap,
  dynamic differences,
) {
  final toFontChar = <int, int>{};
  for (var i = 0; i < encoding.length; i++) {
    final unicode = getUnicodeForGlyph(encoding[i], glyphsUnicodeMap);
    if (unicode != -1) {
      toFontChar[i] = unicode;
    }
  }
  if (differences is Map) {
    for (final entry in differences.entries) {
      final charCode =
          entry.key is int ? entry.key as int : int.parse(entry.key.toString());
      final unicode =
          getUnicodeForGlyph(entry.value.toString(), glyphsUnicodeMap);
      if (unicode != -1) {
        toFontChar[charCode] = unicode;
      }
    }
  }
  return toFontChar;
}

bool isMacNameRecord(dynamic record) {
  return _get(record, 'platform') == 1 &&
      _get(record, 'encoding') == 0 &&
      _get(record, 'language') == 0;
}

bool isWinNameRecord(dynamic record) {
  return _get(record, 'platform') == 3 &&
      _get(record, 'encoding') == 1 &&
      _get(record, 'language') == 0x409;
}

dynamic convertCidString(int charCode, String cid, [bool shouldThrow = false]) {
  switch (cid.length) {
    case 1:
      return cid.codeUnitAt(0);
    case 2:
      return (cid.codeUnitAt(0) << 8) | cid.codeUnitAt(1);
  }
  final msg = 'Unsupported CID string (charCode $charCode): "$cid".';
  if (shouldThrow) {
    throw FormatError(msg);
  }
  warn(msg);
  return cid;
}

class AdjustMappingResult {
  const AdjustMappingResult({
    required this.toFontChar,
    required this.charCodeToGlyphId,
    required this.toUnicodeExtraMap,
    required this.nextAvailableFontCharCode,
  });

  final Map<int, int> toFontChar;
  final Map<int, int> charCodeToGlyphId;
  final Map<int, int> toUnicodeExtraMap;
  final int nextAvailableFontCharCode;
}

AdjustMappingResult adjustMapping(
  Map<int, int> charCodeToGlyphId,
  bool Function(int glyphId) hasGlyph,
  int newGlyphZeroId,
  BaseToUnicodeMap toUnicode,
) {
  final newMap = <int, int>{};
  final toUnicodeExtraMap = <int, int>{};
  final toFontChar = <int, int>{};
  final usedGlyphIds = <int>{};
  var privateUseAreaIndex = 0;
  var nextAvailableFontCharCode = privateUseAreas[privateUseAreaIndex][0];
  var privateUseOffsetEnd = privateUseAreas[privateUseAreaIndex][1];

  bool isInPrivateArea(int code) =>
      (privateUseAreas[0][0] <= code && code <= privateUseAreas[0][1]) ||
      (privateUseAreas[1][0] <= code && code <= privateUseAreas[1][1]);

  for (final entry in charCodeToGlyphId.entries) {
    final originalCharCode = entry.key;
    var glyphId = entry.value;
    if (!hasGlyph(glyphId)) {
      continue;
    }
    if (nextAvailableFontCharCode > privateUseOffsetEnd) {
      privateUseAreaIndex++;
      if (privateUseAreaIndex >= privateUseAreas.length) {
        warn('Ran out of space in font private use area.');
        break;
      }
      nextAvailableFontCharCode = privateUseAreas[privateUseAreaIndex][0];
      privateUseOffsetEnd = privateUseAreas[privateUseAreaIndex][1];
    }
    final fontCharCode = nextAvailableFontCharCode++;
    if (glyphId == 0) {
      glyphId = newGlyphZeroId;
    }

    final unicodeString = toUnicode.get(originalCharCode);
    int? unicode;
    if (unicodeString != null && unicodeString.isNotEmpty) {
      unicode = unicodeString.runes.first;
    }
    if (unicode != null &&
        !isInPrivateArea(unicode) &&
        !usedGlyphIds.contains(glyphId)) {
      toUnicodeExtraMap[unicode] = glyphId;
      usedGlyphIds.add(glyphId);
    }

    newMap[fontCharCode] = glyphId;
    toFontChar[originalCharCode] = fontCharCode;
  }

  return AdjustMappingResult(
    toFontChar: toFontChar,
    charCodeToGlyphId: newMap,
    toUnicodeExtraMap: toUnicodeExtraMap,
    nextAvailableFontCharCode: nextAvailableFontCharCode,
  );
}

class CmapRange {
  CmapRange(this.start, this.end, this.codeIndices);

  int start;
  int end;
  final List<int> codeIndices;
}

List<CmapRange> getRanges(
  Map<int, int> glyphs,
  Map<int, int>? toUnicodeExtraMap,
  int numGlyphs,
) {
  final codes = <({int fontCharCode, int glyphId})>[];
  for (final entry in glyphs.entries) {
    if (entry.value >= numGlyphs) {
      continue;
    }
    codes.add((fontCharCode: entry.key, glyphId: entry.value));
  }
  if (toUnicodeExtraMap != null) {
    for (final entry in toUnicodeExtraMap.entries) {
      if (entry.value >= numGlyphs) {
        continue;
      }
      codes.add((fontCharCode: entry.key, glyphId: entry.value));
    }
  }
  if (codes.isEmpty) {
    codes.add((fontCharCode: 0, glyphId: 0));
  }
  codes.sort((a, b) => a.fontCharCode - b.fontCharCode);

  final ranges = <CmapRange>[];
  var n = 0;
  while (n < codes.length) {
    final start = codes[n].fontCharCode;
    final codeIndices = <int>[codes[n].glyphId];
    n++;
    var end = start;
    while (n < codes.length && end + 1 == codes[n].fontCharCode) {
      codeIndices.add(codes[n].glyphId);
      end++;
      n++;
      if (end == 0xffff) {
        break;
      }
    }
    ranges.add(CmapRange(start, end, codeIndices));
  }
  return ranges;
}

Uint8List createCmapTable(
  Map<int, int> glyphs,
  Map<int, int>? toUnicodeExtraMap,
  int numGlyphs,
) {
  final ranges = getRanges(glyphs, toUnicodeExtraMap, numGlyphs);
  final numTables = ranges.last.end > 0xffff ? 2 : 1;

  final cmap = TrueTypeTableBuilder(exactLength: 12);
  cmap.skip(2);
  cmap.setInt16(numTables);
  cmap.setArray([0x00, 0x03]);
  cmap.setArray([0x00, 0x01]);
  cmap.setInt32(4 + numTables * 8);

  var i = ranges.length - 1;
  for (; i >= 0; i--) {
    if (ranges[i].start <= 0xffff) {
      break;
    }
  }
  final bmpLength = i + 1;

  if (ranges[i].start < 0xffff && ranges[i].end == 0xffff) {
    ranges[i].end = 0xfffe;
  }
  final trailingRangesCount = ranges[i].end < 0xffff ? 1 : 0;
  final segCount = bmpLength + trailingRangesCount;
  final searchParams = OpenTypeFileBuilder.getSearchParams(segCount, 2);

  final segmentsLength = bmpLength * 2 + trailingRangesCount * 2;
  final startCount = TrueTypeTableBuilder(exactLength: segmentsLength);
  final endCount = TrueTypeTableBuilder(exactLength: segmentsLength);
  final idDeltas = TrueTypeTableBuilder(exactLength: segmentsLength);
  final idRangeOffsets = TrueTypeTableBuilder(exactLength: segmentsLength);
  final glyphsIds = TrueTypeTableBuilder();
  var bias = 0;

  for (i = 0; i < bmpLength; i++) {
    final range = ranges[i];
    final start = range.start;
    final end = range.end;
    final codes = range.codeIndices;
    startCount.setInt16(start);
    endCount.setInt16(end);
    var contiguous = true;
    for (var j = 1; j < codes.length; j++) {
      if (codes[j] != codes[j - 1] + 1) {
        contiguous = false;
        break;
      }
    }
    if (!contiguous) {
      final offset = (segCount - i) * 2 + bias * 2;
      bias += end - start + 1;

      idDeltas.skip(2);
      idRangeOffsets.setInt16(offset);
      for (final code in codes) {
        glyphsIds.setInt16(code);
      }
    } else {
      final startCode = codes[0];
      idDeltas.setInt16((startCode - start) & 0xffff);
      idRangeOffsets.skip(2);
    }
  }

  if (trailingRangesCount > 0) {
    endCount.setArray([0xff, 0xff]);
    startCount.setArray([0xff, 0xff]);
    idDeltas.setArray([0x00, 0x01]);
    idRangeOffsets.skip(2);
  }

  final format314 = TrueTypeTableBuilder(
    exactLength: 12 +
        startCount.length +
        endCount.length +
        idDeltas.length +
        idRangeOffsets.length +
        glyphsIds.length,
  );
  format314.skip(2);
  format314.setInt16(2 * segCount);
  format314.setInt16(searchParams.range);
  format314.setInt16(searchParams.entry);
  format314.setInt16(searchParams.rangeShift);
  format314.setArray(endCount.data);
  format314.skip(2);
  format314.setArray(startCount.data);
  format314.setArray(idDeltas.data);
  format314.setArray(idRangeOffsets.data);
  format314.setArray(glyphsIds.data);

  TrueTypeTableBuilder? cmap31012;
  TrueTypeTableBuilder? format31012;
  TrueTypeTableBuilder? header31012;
  if (numTables > 1) {
    cmap31012 = TrueTypeTableBuilder(exactLength: 8);
    cmap31012.setArray([0x00, 0x03]);
    cmap31012.setArray([0x00, 0x0a]);
    cmap31012.setInt32(4 + numTables * 8 + 4 + format314.length);

    format31012 = TrueTypeTableBuilder();
    for (final range in ranges) {
      var start = range.start;
      final codes = range.codeIndices;
      var code = codes[0];
      for (var j = 1; j < codes.length; j++) {
        if (codes[j] != codes[j - 1] + 1) {
          final end = range.start + j - 1;
          format31012.setInt32(start);
          format31012.setInt32(end);
          format31012.setInt32(code);
          start = end + 1;
          code = codes[j];
        }
      }
      format31012.setInt32(start);
      format31012.setInt32(range.end);
      format31012.setInt32(code);
    }

    header31012 = TrueTypeTableBuilder(exactLength: 16);
    header31012.setArray([0x00, 0x0c]);
    header31012.skip(2);
    header31012.setInt32(format31012.length + 16);
    header31012.skip(4);
    header31012.setInt32(format31012.length ~/ 12);
  }

  final table = TrueTypeTableBuilder(
    exactLength: 4 +
        cmap.length +
        (cmap31012?.length ?? 0) +
        format314.length +
        (header31012?.length ?? 0) +
        (format31012?.length ?? 0),
  );
  table.setArray(cmap.data);
  table.setArray(cmap31012?.data ?? const <int>[]);
  table.setArray([0x00, 0x04]);
  table.setInt16(format314.length + 4);
  table.setArray(format314.data);
  table.setArray(header31012?.data ?? const <int>[]);
  table.setArray(format31012?.data ?? const <int>[]);
  return table.data;
}

bool validateOS2Table(dynamic os2, BaseStream file) {
  final offset = _get(os2, 'offset') as int;
  final data = _get(os2, 'data') as Uint8List;
  final start = _get(file, 'start') as int? ?? 0;
  file.pos = start + offset;
  final version = file.getUint16();
  file.skip(60);
  final selection = file.getUint16();
  if (version < 4 && (selection & 0x0300) != 0) {
    return false;
  }
  final firstChar = file.getUint16();
  final lastChar = file.getUint16();
  if (firstChar > lastChar) {
    return false;
  }
  file.skip(6);
  final usWinAscent = file.getUint16();
  if (usWinAscent == 0) {
    return false;
  }

  data[8] = 0;
  data[9] = 0;
  return true;
}

Uint8List createOS2Table(
  dynamic properties,
  Map<int, dynamic>? charstrings, [
  Map<String, num>? override,
]) {
  override ??= {
    'unitsPerEm': 0,
    'yMax': 0,
    'yMin': 0,
    'ascent': 0,
    'descent': 0,
  };

  var ulUnicodeRange1 = 0;
  var ulUnicodeRange2 = 0;
  var ulUnicodeRange3 = 0;
  var ulUnicodeRange4 = 0;
  int? firstCharIndex;
  var lastCharIndex = 0;
  var position = -1;

  if (charstrings != null) {
    for (final code in charstrings.keys) {
      if (firstCharIndex == null || firstCharIndex > code) {
        firstCharIndex = code;
      }
      if (lastCharIndex < code) {
        lastCharIndex = code;
      }

      position = getUnicodeRangeFor(code, position);
      if (position < 32) {
        ulUnicodeRange1 |= 1 << position;
      } else if (position < 64) {
        ulUnicodeRange2 |= 1 << (position - 32);
      } else if (position < 96) {
        ulUnicodeRange3 |= 1 << (position - 64);
      } else if (position < 123) {
        ulUnicodeRange4 |= 1 << (position - 96);
      } else {
        throw FormatError(
          'Unicode ranges Bits > 123 are reserved for internal usage',
        );
      }
    }
    firstCharIndex ??= 0;
    if (lastCharIndex > 0xffff) {
      lastCharIndex = 0xffff;
    }
  } else {
    firstCharIndex = 0;
    lastCharIndex = 255;
  }

  final bbox = (_get(properties, 'bbox') as List?) ?? const [0, 0, 0, 0];
  final fontMatrix = _get(properties, 'fontMatrix') as List?;
  final unitsPerEm = override['unitsPerEm'] != 0
      ? override['unitsPerEm']!
      : fontMatrix != null
          ? 1 /
              fontMatrix
                  .sublist(0, 4)
                  .map((value) => (value as num).abs())
                  .reduce((a, b) => a > b ? a : b)
          : 1000;
  final scale = _truthy(_get(properties, 'ascentScaled'))
      ? 1.0
      : unitsPerEm / pdfGlyphSpaceUnits;
  final ascent = (_get(properties, 'ascent') as num?) ?? bbox[3] as num;
  final descent = (_get(properties, 'descent') as num?) ?? bbox[1] as num;
  final typoAscent = override['ascent'] != 0
      ? override['ascent']!.round()
      : (scale * ascent).round();
  var typoDescent = override['descent'] != 0
      ? override['descent']!.round()
      : (scale * descent).round();
  if (typoDescent > 0 && descent > 0 && (bbox[1] as num) < 0) {
    typoDescent = -typoDescent;
  }
  final winAscent =
      override['yMax'] != 0 ? override['yMax']!.round() : typoAscent;
  final winDescent =
      override['yMin'] != 0 ? -override['yMin']!.round() : -typoDescent;

  final os2 = TrueTypeTableBuilder(exactLength: 96);
  os2.setArray([0x00, 0x03]);
  os2.setArray([0x02, 0x24]);
  os2.setArray([0x01, 0xf4]);
  os2.setArray([0x00, 0x05]);
  os2.skip(2);
  os2.setArray([0x02, 0x8a]);
  os2.setArray([0x02, 0xbb]);
  os2.skip(2);
  os2.setArray([0x00, 0x8c]);
  os2.setArray([0x02, 0x8a]);
  os2.setArray([0x02, 0xbb]);
  os2.skip(2);
  os2.setArray([0x01, 0xdf]);
  os2.setArray([0x00, 0x31]);
  os2.setArray([0x01, 0x02]);
  os2.skip(2);
  os2.setArray([
    0x00,
    0x00,
    0x06,
    _truthy(_get(properties, 'fixedPitch')) ? 0x09 : 0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
  ]);
  os2.setInt32(ulUnicodeRange1);
  os2.setInt32(ulUnicodeRange2);
  os2.setInt32(ulUnicodeRange3);
  os2.setInt32(ulUnicodeRange4);
  os2.setArray([0x2a, 0x32, 0x31, 0x2a]);
  os2.setInt16(_truthy(_get(properties, 'italicAngle')) ? 1 : 0);
  os2.setInt16(firstCharIndex);
  os2.setInt16(lastCharIndex != 0
      ? lastCharIndex
      : (_get(properties, 'lastChar') as int? ?? 0));
  os2.setInt16(typoAscent);
  os2.setInt16(typoDescent);
  os2.setArray([0x00, 0x64]);
  os2.setInt16(winAscent);
  os2.setInt16(winDescent);
  os2.skip(8);
  os2.setInt16((_get(properties, 'xHeight') as num?)?.round() ?? 0);
  os2.setInt16((_get(properties, 'capHeight') as num?)?.round() ?? 0);
  os2.skip(2);
  os2.setInt16(firstCharIndex);
  os2.setArray([0x00, 0x03]);
  return os2.data;
}

Uint8List createPostTable(dynamic properties) {
  final post = TrueTypeTableBuilder(exactLength: 32);
  post.setArray([0x00, 0x03, 0x00, 0x00]);
  final italicAngle = ((_get(properties, 'italicAngle') as num?) ?? 0) * 65536;
  post.setInt32(italicAngle.floor());
  post.skip(4);
  post.setInt32(_truthy(_get(properties, 'fixedPitch')) ? 1 : 0);
  post.skip(16);
  return post.data;
}

String createPostscriptName(String name) {
  return name.replaceAll(RegExp(r'[^\x21-\x7E]|[\[\](){}<>/%]'), '').substring(
        0,
        name.replaceAll(RegExp(r'[^\x21-\x7E]|[\[\](){}<>/%]'), '').length > 63
            ? 63
            : name
                .replaceAll(RegExp(r'[^\x21-\x7E]|[\[\](){}<>/%]'), '')
                .length,
      );
}

Uint8List createNameTable(String name, [List<List<String?>>? proto]) {
  proto ??= [<String?>[], <String?>[]];
  final asciiProto = proto[0];
  final unicodeProto = proto[1];
  final strings = <String>[
    asciiProto.isNotEmpty
        ? asciiProto[0] ?? 'Original licence'
        : 'Original licence',
    asciiProto.length > 1 ? asciiProto[1] ?? name : name,
    asciiProto.length > 2 ? asciiProto[2] ?? 'Unknown' : 'Unknown',
    asciiProto.length > 3 ? asciiProto[3] ?? 'uniqueID' : 'uniqueID',
    asciiProto.length > 4 ? asciiProto[4] ?? name : name,
    asciiProto.length > 5 ? asciiProto[5] ?? 'Version 0.11' : 'Version 0.11',
    asciiProto.length > 6
        ? asciiProto[6] ?? createPostscriptName(name)
        : createPostscriptName(name),
    asciiProto.length > 7 ? asciiProto[7] ?? 'Unknown' : 'Unknown',
    asciiProto.length > 8 ? asciiProto[8] ?? 'Unknown' : 'Unknown',
    asciiProto.length > 9 ? asciiProto[9] ?? 'Unknown' : 'Unknown',
  ];
  final stringsBytes = strings.map(stringToBytes).toList();
  final stringsUnicodeBytes = <Uint8List>[];
  for (var i = 0; i < strings.length; i++) {
    final str =
        unicodeProto.length > i ? unicodeProto[i] ?? strings[i] : strings[i];
    final builder = TrueTypeTableBuilder(exactLength: str.length * 2);
    for (var j = 0; j < str.length; j++) {
      builder.setInt16(str.codeUnitAt(j));
    }
    stringsUnicodeBytes.add(builder.data);
  }

  final namesBytes = [stringsBytes, stringsUnicodeBytes];
  const platformsBytes = [
    [0x00, 0x01],
    [0x00, 0x03],
  ];
  const encodingsBytes = [
    [0x00, 0x00],
    [0x00, 0x01],
  ];
  const languagesBytes = [
    [0x00, 0x00],
    [0x04, 0x09],
  ];

  final nameRecords = <Uint8List>[];
  var strOffset = 0;
  for (var i = 0; i < platformsBytes.length; i++) {
    final strs = namesBytes[i];
    for (var j = 0; j < strs.length; j++) {
      final str = strs[j];
      final record = TrueTypeTableBuilder(exactLength: 12);
      record.setArray(platformsBytes[i]);
      record.setArray(encodingsBytes[i]);
      record.setArray(languagesBytes[i]);
      record.setInt16(j);
      record.setInt16(str.length);
      record.setInt16(strOffset);
      nameRecords.add(record.data);
      strOffset += str.length;
    }
  }

  final namesRecordCount = stringsBytes.length * platformsBytes.length;
  final totalLength = 6 +
      nameRecords.fold<int>(0, (sum, arr) => sum + arr.length) +
      stringsBytes.fold<int>(0, (sum, arr) => sum + arr.length) +
      stringsUnicodeBytes.fold<int>(0, (sum, arr) => sum + arr.length);
  final nameTable = TrueTypeTableBuilder(exactLength: totalLength);
  nameTable.skip(2);
  nameTable.setInt16(namesRecordCount);
  nameTable.setInt16(namesRecordCount * 12 + 6);
  for (final arr in nameRecords) {
    nameTable.setArray(arr);
  }
  for (final arr in stringsBytes) {
    nameTable.setArray(arr);
  }
  for (final arr in stringsUnicodeBytes) {
    nameTable.setArray(arr);
  }
  return nameTable.data;
}

class Font {
  Font(this.name, this.file, this.properties, [dynamic evaluatorOptions]) {
    disableFontFace = _get(evaluatorOptions, 'disableFontFace') == true;
    fontExtraProperties = _get(evaluatorOptions, 'fontExtraProperties') == true;
    loadedName = _get(properties, 'loadedName')?.toString();
    isType3Font = _get(properties, 'isType3Font') == true;
    cssFontInfo = _get(properties, 'cssFontInfo');

    var isSerif = ((_get(properties, 'flags') ?? 0) & FontFlags.Serif) != 0;
    if (!isSerif && _get(properties, 'isSimulatedFlags') != true) {
      final stdFontMap = getStdFontMap();
      final nonStdFontMap = getNonStdFontMap();
      final serifFonts = getSerifFonts();
      for (final namePart in name.split('+')) {
        var fontName = normalizeFontName(namePart);
        fontName = stdFontMap[fontName] ?? nonStdFontMap[fontName] ?? fontName;
        fontName = fontName.split('-').first;
        if (serifFonts[fontName] == true) {
          isSerif = true;
          break;
        }
      }
    }
    isSerifFont = isSerif;
    isSymbolicFont =
        ((_get(properties, 'flags') ?? 0) & FontFlags.Symbolic) != 0;
    isMonospace =
        ((_get(properties, 'flags') ?? 0) & FontFlags.FixedPitch) != 0;

    type = _get(properties, 'type')?.toString();
    subtype = _get(properties, 'subtype')?.toString();
    systemFontInfo = _get(properties, 'systemFontInfo');

    final invalidMatch =
        RegExp(r'^InvalidPDFjsFont_(.*)_\d+$').firstMatch(name);
    isInvalidPDFjsFont = invalidMatch != null;
    if (isInvalidPDFjsFont) {
      fallbackName = invalidMatch!.group(1)!;
    } else if (isMonospace) {
      fallbackName = 'monospace';
    } else if (isSerifFont) {
      fallbackName = 'serif';
    } else {
      fallbackName = 'sans-serif';
    }
    if (systemFontInfo is Map && systemFontInfo['guessFallback'] == true) {
      systemFontInfo['guessFallback'] = false;
      systemFontInfo['css'] = '${systemFontInfo['css']},$fallbackName';
    }

    differences = _get(properties, 'differences') ?? <int, String>{};
    widths = (_get(properties, 'widths') as Map?) ?? <int, num>{};
    defaultWidth = (_get(properties, 'defaultWidth') as num?) ?? 0;
    composite = _get(properties, 'composite') == true;
    cMap = _get(properties, 'cMap') as CMap?;
    capHeight =
        ((_get(properties, 'capHeight') as num?) ?? 0) / pdfGlyphSpaceUnits;
    ascent = ((_get(properties, 'ascent') as num?) ?? double.nan) /
        pdfGlyphSpaceUnits;
    descent = ((_get(properties, 'descent') as num?) ?? double.nan) /
        pdfGlyphSpaceUnits;
    lineHeight = ascent - descent;
    fontMatrix = _get(properties, 'fontMatrix');
    bbox = _get(properties, 'bbox');
    defaultEncoding =
        (_get(properties, 'defaultEncoding') as List?) ?? standardEncoding;
    toUnicode =
        (_get(properties, 'toUnicode') as BaseToUnicodeMap?) ?? ToUnicodeMap();

    if (type == 'Type3') {
      for (var charCode = 0; charCode < 256; charCode++) {
        toFontChar[charCode] =
            _mapGet(differences, charCode) ?? defaultEncoding[charCode];
      }
      return;
    }

    cidEncoding = _get(properties, 'cidEncoding')?.toString() ?? '';
    vertical = _get(properties, 'vertical') == true;
    if (vertical) {
      vmetrics = _get(properties, 'vmetrics');
      defaultVMetrics = _get(properties, 'defaultVMetrics');
    }

    final fontFile = file;
    if (fontFile == null || fontFile.isEmpty) {
      if (fontFile != null) {
        warn('Font file is empty in "$name" ($loadedName)');
      }
      fallbackToSystemFont(properties);
      return;
    }

    final detectedType = getFontFileType(
      fontFile,
      type: type,
      subtype: subtype,
      composite: composite,
    );
    if (detectedType.type != type || detectedType.subtype != subtype) {
      info(
        'Inconsistent font file Type/SubType, expected: '
        '$type/$subtype but found: ${detectedType.type}/${detectedType.subtype}.',
      );
    }

    try {
      switch (detectedType.type) {
        case 'OpenType':
        case 'TrueType':
        case 'CIDFontType2':
          mimetype = 'font/opentype';
          data = checkAndRepair(name, fontFile, properties);
          adjustWidths(properties);
          type = isOpenType == true ? 'OpenType' : detectedType.type;
          subtype = detectedType.subtype;
          break;
        default:
          throw FormatError('Font ${detectedType.type} is not supported');
      }
    } catch (ex) {
      warn(ex.toString());
      fallbackToSystemFont(properties);
      return;
    }

    amendFallbackToUnicode(properties);
    this.type = type;
    this.subtype = subtype;
    fontMatrix = _get(properties, 'fontMatrix');
    widths = (_get(properties, 'widths') as Map?) ?? widths;
    defaultWidth = (_get(properties, 'defaultWidth') as num?) ?? defaultWidth;
    toUnicode =
        (_get(properties, 'toUnicode') as BaseToUnicodeMap?) ?? toUnicode;
    seacMap = _get(properties, 'seacMap');
  }

  final String name;
  final BaseStream? file;
  final dynamic properties;
  final Map<String, List<Glyph>> _charsCache = <String, List<Glyph>>{};
  final Map<int, Glyph> _glyphCache = <int, Glyph>{};

  String? psName;
  String? mimetype;
  bool disableFontFace = false;
  bool fontExtraProperties = false;
  String? loadedName;
  bool isType3Font = false;
  bool missingFile = false;
  dynamic cssFontInfo;
  bool isSerifFont = false;
  bool isSymbolicFont = false;
  bool isMonospace = false;
  String? type;
  String? subtype;
  dynamic systemFontInfo;
  bool isInvalidPDFjsFont = false;
  String fallbackName = 'sans-serif';
  dynamic differences = const <int, String>{};
  Map<dynamic, dynamic> widths = <dynamic, dynamic>{};
  num defaultWidth = 0;
  bool composite = false;
  CMap? cMap;
  num capHeight = 0;
  num ascent = double.nan;
  num descent = double.nan;
  num lineHeight = double.nan;
  dynamic fontMatrix;
  dynamic bbox;
  List<dynamic> defaultEncoding = standardEncoding;
  BaseToUnicodeMap toUnicode = ToUnicodeMap();
  Map<int, dynamic> toFontChar = <int, dynamic>{};
  String cidEncoding = '';
  bool vertical = false;
  dynamic vmetrics;
  dynamic defaultVMetrics;
  dynamic seacMap;
  dynamic charProcOperatorList;
  dynamic data;
  bool? bold;
  bool? italic;
  bool? black;
  bool? remeasure;
  bool? isOpenType;

  Map<String, dynamic> _getExportData(List<String> props) {
    final data = <String, dynamic>{};
    for (final prop in props) {
      final value = _fontGet(prop);
      if (value != null) {
        data[prop] = value;
      }
    }
    return data;
  }

  Map<String, dynamic> exportData() {
    return {
      'buffer': _getExportData(exportDataProperties),
      'charProcOperatorList': charProcOperatorList,
      if (fontExtraProperties)
        'extra': _getExportData(exportDataExtraProperties),
    };
  }

  Uint8List checkAndRepair(String name, BaseStream font, dynamic properties) {
    final fontBytes = font.getByteRange(_streamStart(font), font.end);
    final stream = Stream(Uint8List.fromList(fontBytes));

    late OpenTypeHeader header;
    late Map<String, OpenTypeTable?> tables;
    if (isTrueTypeCollectionFile(stream)) {
      final ttcData = readTrueTypeCollectionData(stream, this.name);
      header = ttcData.header;
      tables = ttcData.tables;
    } else {
      header = readOpenTypeHeader(stream);
      tables = readOpenTypeTables(stream, header.numTables);
    }

    final isTrueType = tables['CFF '] == null;
    if (!isTrueType) {
      tables.remove('glyf');
      tables.remove('loca');
      tables.remove('fpgm');
      tables.remove('prep');
      tables.remove('cvt ');
      isOpenType = true;
    } else {
      if (tables['loca'] == null) {
        throw FormatError('Required "loca" table is not found');
      }
      if (tables['glyf'] == null) {
        warn('Required "glyf" table is not found -- trying to recover.');
        tables['glyf'] = OpenTypeTable(
          tag: 'glyf',
          checksum: 0,
          length: 0,
          offset: 0,
          data: Uint8List(0),
        );
      }
      isOpenType = false;
    }

    if (tables['maxp'] == null) {
      throw FormatError('Required "maxp" table is not found');
    }

    final nameTable = tables['name'];
    if (nameTable == null) {
      tables['name'] = OpenTypeTable(
        tag: 'name',
        checksum: 0,
        length: 0,
        offset: 0,
        data: createNameTable(this.name),
      );
    } else {
      final nameData = readNameTable(stream, nameTable);
      tables['name'] = OpenTypeTable(
        tag: 'name',
        checksum: 0,
        length: 0,
        offset: 0,
        data: createNameTable(name, nameData.names),
      );
      psName = nameData.names[0].length > 6 ? nameData.names[0][6] : null;
      if (composite != true) {
        adjustTrueTypeToUnicode(properties, isSymbolicFont, nameData.records);
      }
    }

    final builder = OpenTypeFileBuilder(header.version);
    for (final entry in tables.entries) {
      final table = entry.value;
      if (table == null) {
        continue;
      }
      builder.addTable(entry.key, table.data);
    }
    return builder.toArray();
  }

  void fallbackToSystemFont(dynamic properties) {
    missingFile = true;
    var fontName = normalizeFontName(name);
    final stdFontMap = getStdFontMap();
    final nonStdFontMap = getNonStdFontMap();
    final isStandardFont = stdFontMap[fontName] != null;
    final isMappedToStandardFont = nonStdFontMap[fontName] != null &&
        stdFontMap[nonStdFontMap[fontName]] != null;

    fontName = stdFontMap[fontName] ?? nonStdFontMap[fontName] ?? fontName;
    bold = RegExp('bold', caseSensitive: false).hasMatch(fontName);
    italic = RegExp('oblique|italic', caseSensitive: false).hasMatch(fontName);
    black = RegExp('Black').hasMatch(name);
    final isNarrow = RegExp('Narrow').hasMatch(name);
    remeasure = (!isStandardFont || isNarrow) && widths.isNotEmpty;

    if (RegExp('Symbol', caseSensitive: false).hasMatch(fontName)) {
      toFontChar = buildToFontChar(
        symbolSetEncoding,
        getGlyphsUnicode(),
        differences,
      ).map((key, value) => MapEntry(key, value));
    } else if (RegExp('Dingbats', caseSensitive: false).hasMatch(fontName)) {
      toFontChar = buildToFontChar(
        zapfDingbatsEncoding,
        getGlyphsUnicode(),
        differences,
      ).map((key, value) => MapEntry(key, value));
    } else if (isStandardFont || isMappedToStandardFont) {
      toFontChar = buildToFontChar(
        defaultEncoding.cast<String>(),
        getGlyphsUnicode(),
        differences,
      ).map((key, value) => MapEntry(key, value));
    } else {
      final glyphsUnicodeMap = getGlyphsUnicode();
      final map = <int, dynamic>{};
      toUnicode.forEach((charCode, unicodeCharCode) {
        var code = unicodeCharCode;
        if (!composite) {
          final glyphName = _mapGet(differences, charCode) ??
              (charCode < defaultEncoding.length
                  ? defaultEncoding[charCode]
                  : '');
          final unicode =
              getUnicodeForGlyph(glyphName.toString(), glyphsUnicodeMap);
          if (unicode != -1) {
            code = unicode;
          }
        }
        map[charCode] = code;
      });
      if (composite && toUnicode is IdentityToUnicodeMap) {
        if (RegExp('Tahoma|Verdana', caseSensitive: false).hasMatch(name)) {
          applyStandardFontGlyphMap(
              map.cast<int, int>(), getGlyphMapForStandardFonts());
        }
      }
      toFontChar = map;
    }

    amendFallbackToUnicode(properties);
    loadedName = fontName.split('-').first;
  }

  num get spaceWidth {
    var width = defaultWidth;
    const possibleSpaceReplacements = ['space', 'minus', 'one', 'i', 'I'];
    for (final glyphName in possibleSpaceReplacements) {
      final glyphUnicode = getUnicodeForGlyph(glyphName, getGlyphsUnicode());
      var charcode = 0;
      final cmap = cMap;
      if (composite && cmap != null && cmap.contains(glyphUnicode)) {
        final lookedUp = cmap.lookup(glyphUnicode);
        charcode = lookedUp is String
            ? convertCidString(glyphUnicode, lookedUp) as int
            : lookedUp as int;
      }
      if (charcode == 0) {
        charcode = toUnicode.charCodeOf(String.fromCharCode(glyphUnicode));
      }
      if (charcode <= 0) {
        charcode = glyphUnicode;
      }
      final candidate = widths[charcode];
      if (candidate is num && candidate != 0) {
        width = candidate;
        break;
      }
    }
    return width;
  }

  Glyph charToGlyph(int charcode, [bool isSpace = false]) {
    var glyph = _glyphCache[charcode];
    if (glyph != null && glyph.isSpace == isSpace) {
      return glyph;
    }

    var widthCode = charcode;
    final cmap = cMap;
    if (cmap != null && cmap.contains(charcode)) {
      final lookedUp = cmap.lookup(charcode);
      widthCode = lookedUp is String
          ? convertCidString(charcode, lookedUp) as int
          : lookedUp as int;
    }
    var width = widths[widthCode];
    if (width is! num) {
      width = defaultWidth;
    }
    final vmetric = _mapGet(vmetrics, widthCode) ?? defaultVMetrics;

    dynamic unicode = toUnicode.get(charcode) ?? charcode;
    if (unicode is int) {
      unicode = String.fromCharCode(unicode);
    }

    var isInFont = toFontChar.containsKey(charcode);
    dynamic fontCharCode = toFontChar[charcode] ?? charcode;
    if (missingFile) {
      final glyphName = _mapGet(differences, charcode) ??
          (charcode < defaultEncoding.length ? defaultEncoding[charcode] : '');
      if ((glyphName == '.notdef' || glyphName == '') && type == 'Type1') {
        fontCharCode = 0x20;
        if (glyphName == '') {
          width = width == 0 ? spaceWidth : width;
          unicode = String.fromCharCode(fontCharCode);
        }
      }
      if (fontCharCode is int) {
        fontCharCode = mapSpecialUnicodeValues(fontCharCode);
      }
    }

    dynamic operatorListId;
    if (isType3Font) {
      operatorListId = fontCharCode;
    }

    dynamic accent;
    final seac = _mapGet(seacMap, charcode);
    if (seac != null) {
      isInFont = true;
      final base = _get(seac, 'baseFontCharCode');
      final accentCode = _get(seac, 'accentFontCharCode');
      fontCharCode = base;
      accent = {
        'fontChar': String.fromCharCode(accentCode),
        'offset': _get(seac, 'accentOffset'),
      };
    }

    var fontChar = '';
    if (fontCharCode is int) {
      if (fontCharCode <= 0x10ffff) {
        fontChar = String.fromCharCode(fontCharCode);
      } else {
        warn('charToGlyph - invalid fontCharCode: $fontCharCode');
      }
    } else if (fontCharCode is String) {
      fontChar = fontCharCode;
    }

    if (missingFile && vertical && fontChar.length == 1) {
      final verticalChar = getVerticalPresentationForm(fontChar.codeUnitAt(0));
      if (verticalChar != null) {
        fontChar = unicode = String.fromCharCode(verticalChar);
      }
    }

    glyph = Glyph(
      charcode,
      fontChar,
      unicode.toString(),
      accent,
      width,
      vmetric,
      operatorListId,
      isSpace,
      isInFont,
    );
    _glyphCache[charcode] = glyph;
    return glyph;
  }

  List<Glyph> charsToGlyphs(String chars) {
    final cached = _charsCache[chars];
    if (cached != null) {
      return cached;
    }
    final glyphs = <Glyph>[];
    final cmap = cMap;
    if (cmap != null) {
      final c = CharCodeOut();
      var i = 0;
      while (i < chars.length) {
        cmap.readCharCode(chars, i, c);
        final charcode = c.charcode;
        final length = c.length;
        i += length;
        glyphs.add(charToGlyph(
          charcode,
          length == 1 && chars.codeUnitAt(i - 1) == 0x20,
        ));
      }
    } else {
      for (var i = 0; i < chars.length; i++) {
        final charcode = chars.codeUnitAt(i);
        glyphs.add(charToGlyph(charcode, charcode == 0x20));
      }
    }
    _charsCache[chars] = glyphs;
    return glyphs;
  }

  List<List<int>> getCharPositions(String chars) {
    final positions = <List<int>>[];
    final cmap = cMap;
    if (cmap != null) {
      final c = CharCodeOut();
      var i = 0;
      while (i < chars.length) {
        cmap.readCharCode(chars, i, c);
        final length = c.length;
        positions.add([i, i + length]);
        i += length;
      }
    } else {
      for (var i = 0; i < chars.length; i++) {
        positions.add([i, i + 1]);
      }
    }
    return positions;
  }

  Iterable<Glyph> get glyphCacheValues => _glyphCache.values;

  List<String> encodeString(String str) {
    final buffers = <String>[];
    final currentBuf = StringBuffer();

    bool hasCurrentBufErrors() => buffers.length.isOdd;
    void flush() {
      buffers.add(currentBuf.toString());
      currentBuf.clear();
    }

    for (final unicode in str.runes) {
      final charCode = toUnicode is IdentityToUnicodeMap
          ? toUnicode.charCodeOf(unicode)
          : toUnicode.charCodeOf(String.fromCharCode(unicode));
      if (charCode != -1) {
        if (hasCurrentBufErrors()) {
          flush();
        }
        final charCodeLength = cMap?.getCharCodeLength(charCode) ?? 1;
        for (var j = charCodeLength - 1; j >= 0; j--) {
          currentBuf.writeCharCode((charCode >> (8 * j)) & 0xff);
        }
        continue;
      }

      if (!hasCurrentBufErrors()) {
        flush();
      }
      currentBuf.writeCharCode(unicode);
    }
    flush();
    return buffers;
  }

  dynamic _fontGet(String prop) {
    switch (prop) {
      case 'ascent':
        return ascent;
      case 'bbox':
        return bbox;
      case 'black':
        return black;
      case 'bold':
        return bold;
      case 'cssFontInfo':
        return cssFontInfo;
      case 'data':
        return data;
      case 'defaultVMetrics':
        return defaultVMetrics;
      case 'defaultWidth':
        return defaultWidth;
      case 'descent':
        return descent;
      case 'disableFontFace':
        return disableFontFace;
      case 'fallbackName':
        return fallbackName;
      case 'fontExtraProperties':
        return fontExtraProperties;
      case 'fontMatrix':
        return fontMatrix;
      case 'isInvalidPDFjsFont':
        return isInvalidPDFjsFont;
      case 'isType3Font':
        return isType3Font;
      case 'italic':
        return italic;
      case 'loadedName':
        return loadedName;
      case 'mimetype':
        return mimetype;
      case 'missingFile':
        return missingFile;
      case 'name':
        return name;
      case 'remeasure':
        return remeasure;
      case 'systemFontInfo':
        return systemFontInfo;
      case 'vertical':
        return vertical;
      case 'cMap':
        return cMap;
      case 'composite':
        return composite;
      case 'defaultEncoding':
        return defaultEncoding;
      case 'differences':
        return differences;
      case 'isMonospace':
        return isMonospace;
      case 'isSerifFont':
        return isSerifFont;
      case 'isSymbolicFont':
        return isSymbolicFont;
      case 'seacMap':
        return seacMap;
      case 'subtype':
        return subtype;
      case 'toFontChar':
        return toFontChar;
      case 'toUnicode':
        return toUnicode;
      case 'type':
        return type;
      case 'vmetrics':
        return vmetrics;
      case 'widths':
        return widths;
    }
    return null;
  }
}

class ErrorFont {
  ErrorFont(this.error)
      : loadedName = 'g_font_error',
        missingFile = true;

  final dynamic error;
  final String loadedName;
  final bool missingFile;

  List<dynamic> charsToGlyphs([String chars = '']) => const [];
  List<String> encodeString(String chars) => [chars];
  Map<String, dynamic> exportData() => {'error': error};
}

dynamic _get(dynamic obj, String key) {
  if (obj is Map) {
    return obj[key];
  }
  try {
    switch (key) {
      case 'fontMatrix':
        return obj.fontMatrix;
      case 'widths':
        return obj.widths;
      case 'defaultWidth':
        return obj.defaultWidth;
      case 'isInternalFont':
        return obj.isInternalFont;
      case 'hasIncludedToUnicodeMap':
        return obj.hasIncludedToUnicodeMap;
      case 'hasEncoding':
        return obj.hasEncoding;
      case 'toUnicode':
        return obj.toUnicode;
      case 'defaultEncoding':
        return obj.defaultEncoding;
      case 'baseEncodingName':
        return obj.baseEncodingName;
      case 'differences':
        return obj.differences;
      case 'fallbackToUnicode':
        return obj.fallbackToUnicode;
      case 'platform':
        return obj.platform;
      case 'encoding':
        return obj.encoding;
      case 'language':
        return obj.language;
    }
  } catch (_) {}
  return null;
}

void _set(dynamic obj, String key, dynamic value) {
  if (obj is Map) {
    obj[key] = value;
    return;
  }
  try {
    switch (key) {
      case 'defaultWidth':
        obj.defaultWidth = value;
        return;
    }
  } catch (_) {}
}

bool _truthy(dynamic value) => value == true;

int _readUint32(BaseStream stream) => stream.getInt32() & 0xffffffff;

int _streamStart(BaseStream stream) {
  try {
    return (stream as dynamic).start as int? ?? 0;
  } catch (_) {
    return 0;
  }
}

void _setListAt<T>(List<T?> list, int index, T value) {
  while (list.length <= index) {
    list.add(null);
  }
  list[index] = value;
}

dynamic _mapGet(dynamic obj, dynamic key) {
  if (obj is Map) {
    return obj[key] ?? obj[key.toString()];
  }
  try {
    return obj[key];
  } catch (_) {
    return null;
  }
}
