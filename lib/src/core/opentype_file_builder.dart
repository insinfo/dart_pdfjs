// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import '../shared/util.dart';

const int _otfHeaderSize = 12;
const int _otfTableEntrySize = 16;

class OpenTypeSearchParams {
  const OpenTypeSearchParams({
    required this.range,
    required this.entry,
    required this.rangeShift,
  });

  final int range;
  final int entry;
  final int rangeShift;
}

class OpenTypeFileBuilder {
  OpenTypeFileBuilder(this.sfnt);

  String sfnt;
  final Map<String, Uint8List> _tables = <String, Uint8List>{};

  static OpenTypeSearchParams getSearchParams(int entriesCount, int entrySize) {
    int maxPower2 = 1;
    int log2 = 0;
    while ((maxPower2 ^ entriesCount) > maxPower2) {
      maxPower2 <<= 1;
      log2++;
    }
    final searchRange = maxPower2 * entrySize;
    return OpenTypeSearchParams(
      range: searchRange,
      entry: log2,
      rangeShift: entrySize * entriesCount - searchRange,
    );
  }

  Uint8List toArray() {
    var localSfnt = sfnt;

    final tableNames = _tables.keys.toList()..sort();
    final numTables = tableNames.length;

    var offset = _otfHeaderSize + numTables * _otfTableEntrySize;
    final tableOffsets = <int>[offset];
    for (final tableName in tableNames) {
      final table = _tables[tableName]!;
      final paddedLength = (table.length + 3) & ~3;
      offset += paddedLength;
      tableOffsets.add(offset);
    }

    final file = Uint8List(offset);
    final view = ByteData.view(file.buffer);

    for (var i = 0; i < numTables; i++) {
      final table = _tables[tableNames[i]]!;
      file.setRange(tableOffsets[i], tableOffsets[i] + table.length, table);
    }

    if (localSfnt == 'true') {
      // Windows hates the Mac TrueType sfnt version number.
      localSfnt = '\x00\x01\x00\x00';
    }
    final sfntBytes = stringToBytes(localSfnt);
    file.setRange(0, sfntBytes.length, sfntBytes);

    view.setUint16(4, numTables);

    final searchParams = getSearchParams(numTables, _otfTableEntrySize);
    view.setUint16(6, searchParams.range);
    view.setUint16(8, searchParams.entry);
    view.setUint16(10, searchParams.rangeShift);

    offset = _otfHeaderSize;
    for (var i = 0; i < numTables; i++) {
      final tableName = tableNames[i];
      final tableNameBytes = stringToBytes(tableName);
      file.setRange(offset, offset + tableNameBytes.length, tableNameBytes);

      var checksum = 0;
      for (var j = tableOffsets[i], end = tableOffsets[i + 1];
          j < end;
          j += 4) {
        checksum = (checksum + view.getUint32(j)) & 0xffffffff;
      }
      view.setUint32(offset + 4, checksum);
      view.setUint32(offset + 8, tableOffsets[i]);
      view.setUint32(offset + 12, _tables[tableName]!.length);

      offset += _otfTableEntrySize;
    }

    _tables.clear();
    return file;
  }

  void addTable(String tag, Uint8List data) {
    if (_tables.containsKey(tag)) {
      throw Exception('Table $tag already exists');
    }
    _tables[tag] = data;
  }
}
