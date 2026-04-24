import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfjs/src/core/encodings.dart';
import 'package:pdfjs/src/core/fonts.dart';
import 'package:pdfjs/src/core/glyphlist.dart';
import 'package:pdfjs/src/core/opentype_file_builder.dart';
import 'package:pdfjs/src/core/stream.dart';
import 'package:pdfjs/src/core/to_unicode_map.dart';
import 'package:pdfjs/src/core/cmap.dart';

void main() {
  group('fonts binary helpers', () {
    test('reads and writes big-endian integers', () {
      final bytes = Uint8List(8);

      writeSignedInt16(bytes, 0, -2);
      writeUint32(bytes, 2, 0x12345678);

      expect(int16(0x12, 0x34), 0x1234);
      expect(signedInt16(bytes[0], bytes[1]), -2);
      expect(bytes.sublist(2, 6), [0x12, 0x34, 0x56, 0x78]);
    });

    test('grows TrueTypeTableBuilder and clamps safe int16 values', () {
      final builder = TrueTypeTableBuilder(minLength: 2)
        ..setArray([1, 2, 3])
        ..setInt16(-4)
        ..setSafeInt16(0x9000)
        ..setInt32(0x01020304);

      expect(builder.length, 11);
      expect(builder.data, [1, 2, 3, 0xff, 0xfc, 0x7f, 0xff, 1, 2, 3, 4]);
    });
  });

  group('font file type detection', () {
    test('detects TrueType, collections, OpenType, Type1 and CFF', () {
      expect(getFontFileType(Stream(Uint8List.fromList([0, 1, 0, 0]))).type,
          'TrueType');
      expect(getFontFileType(Stream(Uint8List.fromList('ttcf'.codeUnits))).type,
          'TrueType');
      expect(getFontFileType(Stream(Uint8List.fromList('OTTO'.codeUnits))).type,
          'OpenType');
      expect(getFontFileType(Stream(Uint8List.fromList('%!PS'.codeUnits))).type,
          'Type1');

      final cff = getFontFileType(Stream(Uint8List.fromList([1, 0, 4, 4])),
          composite: true);
      expect(cff.type, 'CIDFontType0');
      expect(cff.subtype, 'CIDFontType0C');
    });

    test('falls back to declared type when detection fails', () {
      final type = getFontFileType(
        Stream(Uint8List.fromList([0, 0, 0, 0])),
        type: 'Declared',
        subtype: 'DeclaredSub',
      );

      expect(type.type, 'Declared');
      expect(type.subtype, 'DeclaredSub');
    });
  });

  group('font mapping helpers', () {
    test('adjusts widths using fontMatrix scale', () {
      final props = {
        'fontMatrix': [0.002, 0, 0, 0.002, 0, 0],
        'widths': {65: 500.0},
        'defaultWidth': 1000.0,
      };

      adjustWidths(props);

      expect(props['widths'], {65: 250.0});
      expect(props['defaultWidth'], 500.0);
    });

    test('builds toFontChar from encoding and differences', () {
      final map = buildToFontChar(
        standardEncoding,
        getGlyphsUnicode(),
        {65: 'B'},
      );

      expect(map[32], 0x20);
      expect(map[65], 0x42);
    });

    test('amends Type1 ToUnicode from built-in encoding', () {
      final toUnicode = ToUnicodeMap();
      final props = {
        'isInternalFont': false,
        'hasIncludedToUnicodeMap': false,
        'hasEncoding': false,
        'toUnicode': toUnicode,
        'defaultEncoding': standardEncoding,
      };

      adjustType1ToUnicode(props, winAnsiEncoding);

      expect(toUnicode.get(65), 'A');
      expect(toUnicode.get(32), ' ');
    });

    test('amends fallback ToUnicode without replacing existing mappings', () {
      final toUnicode = ToUnicodeMap({65: 'A'});
      final props = {
        'toUnicode': toUnicode,
        'fallbackToUnicode': {65: 'X', 66: 'B'},
      };

      amendFallbackToUnicode(props);

      expect(toUnicode.get(65), 'A');
      expect(toUnicode.get(66), 'B');
    });

    test('moves glyphs to private-use char codes', () {
      final toUnicode = ToUnicodeMap({65: 'A', 66: 'B'});

      final result = adjustMapping(
        {65: 0, 66: 2, 67: 99},
        (glyphId) => glyphId != 99,
        5,
        toUnicode,
      );

      expect(result.toFontChar[65], 0xe000);
      expect(result.toFontChar[66], 0xe001);
      expect(result.charCodeToGlyphId[0xe000], 5);
      expect(result.charCodeToGlyphId[0xe001], 2);
      expect(result.toUnicodeExtraMap, {0x41: 5, 0x42: 2});
    });
  });

  group('OpenType table helpers', () {
    test('reads OpenType headers, table entries and name tables', () {
      final head = Uint8List(20);
      head[8] = head[9] = head[10] = head[11] = 0xff;
      final builder = OpenTypeFileBuilder('true')
        ..addTable('head', head)
        ..addTable('name', createNameTable('Unit Test Font'))
        ..addTable('zzzz', Uint8List.fromList([1, 2, 3]));
      final stream = Stream(builder.toArray());

      final header = readOpenTypeHeader(stream);
      expect(header.version, '\x00\x01\x00\x00');
      expect(header.numTables, 3);

      final tables = readOpenTypeTables(stream, header.numTables);
      expect(tables['zzzz'], isNull);
      expect(tables['head'], isNotNull);
      expect(tables['head']!.data.sublist(8, 12), [0, 0, 0, 0]);
      expect(tables['head']!.data[17] & 0x20, 0x20);

      final nameData = readNameTable(stream, tables['name']!);
      expect(nameData.records, isNotEmpty);
      expect(nameData.names[0][1], 'Unit Test Font');
      expect(nameData.names[1][1], 'Unit Test Font');
      expect(isMacNameRecord(nameData.records.first), isTrue);
    });

    test('selects fonts from TrueType collections by name', () {
      final fontBuilder = OpenTypeFileBuilder('true')
        ..addTable('name', createNameTable('CollectionFont'))
        ..addTable('head', Uint8List(20));
      final fontBytes = fontBuilder.toArray();
      final ttc = Uint8List(16 + fontBytes.length);
      final view = ByteData.view(ttc.buffer);
      ttc.setRange(0, 4, 'ttcf'.codeUnits);
      view.setUint16(4, 1);
      view.setUint16(6, 0);
      view.setUint32(8, 1);
      view.setUint32(12, 16);
      ttc.setRange(16, 16 + fontBytes.length, fontBytes);
      final numTables = ByteData.sublistView(fontBytes).getUint16(4);
      for (var i = 0; i < numTables; i++) {
        final offsetPosition = 16 + 12 + i * 16 + 8;
        view.setUint32(offsetPosition, view.getUint32(offsetPosition) + 16);
      }

      final data = readTrueTypeCollectionData(Stream(ttc), 'CollectionFont');

      expect(data.header.numTables, 2);
      expect(data.tables['name'], isNotNull);
    });

    test('builds sorted cmap ranges and filters invalid glyph ids', () {
      final ranges = getRanges({66: 2, 65: 1, 70: 99}, {0x10000: 3}, 10);

      expect(ranges, hasLength(2));
      expect(ranges[0].start, 65);
      expect(ranges[0].end, 66);
      expect(ranges[0].codeIndices, [1, 2]);
      expect(ranges[1].start, 0x10000);
      expect(ranges[1].end, 0x10000);
      expect(ranges[1].codeIndices, [3]);
    });

    test('creates a cmap table with BMP and supplementary subtables', () {
      final cmap = createCmapTable({65: 1, 66: 2}, {0x10000: 3}, 4);
      final view = ByteData.view(cmap.buffer);

      expect(view.getUint16(0), 0); // version
      expect(view.getUint16(2), 2); // numTables
      expect(view.getUint16(4), 3); // platformID
      expect(view.getUint16(6), 1); // BMP encodingID
      expect(view.getUint32(8), 20); // first subtable offset
      expect(view.getUint16(12), 3); // platformID
      expect(view.getUint16(14), 10); // format 12 encodingID

      final format4Offset = view.getUint32(8);
      expect(view.getUint16(format4Offset), 4);
      final format12Offset = view.getUint32(16);
      expect(view.getUint16(format12Offset), 12);
      expect(view.getUint32(format12Offset + 12), 2); // nGroups
    });

    test('creates post and name tables', () {
      final post = createPostTable({
        'italicAngle': -12.5,
        'fixedPitch': true,
      });
      final postView = ByteData.view(post.buffer);

      expect(post.length, 32);
      expect(postView.getUint32(0), 0x00030000);
      expect(postView.getInt32(4), (-12.5 * 65536).floor());
      expect(postView.getUint32(12), 1);

      expect(createPostscriptName('Bad Font/[Name]% with spaces'),
          'BadFontNamewithspaces');

      final nameTable = createNameTable('My Font');
      final nameView = ByteData.view(nameTable.buffer);
      expect(nameView.getUint16(0), 0);
      expect(nameView.getUint16(2), 20);
      expect(nameView.getUint16(4), 246);
      expect(String.fromCharCodes(nameTable.sublist(246, 262)),
          'Original licence');
    });

    test('creates and validates OS/2 tables', () {
      final os2 = createOS2Table({
        'bbox': [0, -200, 1000, 900],
        'fontMatrix': [0.001, 0, 0, 0.001, 0, 0],
        'ascent': 800,
        'descent': -200,
        'fixedPitch': false,
        'italicAngle': 0,
        'xHeight': 450,
        'capHeight': 700,
      }, {
        65: null,
        66: null,
      });
      final view = ByteData.view(os2.buffer);

      expect(os2.length, 96);
      expect(view.getUint16(0), 3);
      expect(view.getUint16(64), 65);
      expect(view.getUint16(66), 66);
      expect(view.getInt16(68), 800);
      expect(view.getInt16(70), -200);
      expect(view.getUint16(74), 800);
      expect(view.getUint16(76), 200);

      final file = Stream(os2);
      final table = {'offset': 0, 'data': Uint8List.fromList(os2)};
      expect(validateOS2Table(table, file), isTrue);
      expect((table['data'] as Uint8List).sublist(8, 10), [0, 0]);
    });
  });

  group('font exported shell classes', () {
    test('ErrorFont mirrors pdf.js error behavior', () {
      final font = ErrorFont('boom');

      expect(font.loadedName, 'g_font_error');
      expect(font.missingFile, isTrue);
      expect(font.charsToGlyphs('abc'), isEmpty);
      expect(font.encodeString('abc'), ['abc']);
      expect(font.exportData(), {'error': 'boom'});
    });

    test('Glyph lazily exposes unicode category', () {
      final glyph = Glyph(32, ' ', ' ', null, 500, null, null, true, true);

      expect(glyph.category.isWhitespace, isTrue);
    });
  });

  group('Font text mapping surface', () {
    test('falls back to system font and maps standard font glyphs', () {
      final font = Font('Helvetica', null, {
        'loadedName': 'h1',
        'flags': 0,
        'type': 'Type1',
        'differences': <int, String>{},
        'widths': {65: 600, 32: 250},
        'defaultWidth': 500,
        'capHeight': 700,
        'ascent': 800,
        'descent': -200,
        'defaultEncoding': standardEncoding,
        'toUnicode': ToUnicodeMap({65: 'A', 32: ' '}),
      }, {
        'fontExtraProperties': true,
      });

      expect(font.missingFile, isTrue);
      expect(font.loadedName, 'Helvetica');
      expect(font.fallbackName, 'sans-serif');
      expect(font.toFontChar[65], 65);

      final glyphs = font.charsToGlyphs('A ');
      expect(glyphs, hasLength(2));
      expect(glyphs[0].fontChar, 'A');
      expect(glyphs[0].unicode, 'A');
      expect(glyphs[0].width, 600);
      expect(glyphs[1].isSpace, isTrue);
      expect(identical(font.charsToGlyphs('A '), glyphs), isTrue);
      expect(font.glyphCacheValues.length, 2);

      final exported = font.exportData();
      expect(exported['buffer'], isA<Map<String, dynamic>>());
      expect((exported['buffer'] as Map)['missingFile'], isTrue);
      expect(exported['extra'], isA<Map<String, dynamic>>());
    });

    test('encodes strings into encoded and non-encoded runs', () {
      final font = Font('Custom', null, {
        'loadedName': 'c1',
        'flags': 0,
        'type': 'Type1',
        'differences': <int, String>{},
        'widths': <int, int>{},
        'defaultWidth': 500,
        'capHeight': 0,
        'ascent': 0,
        'descent': 0,
        'defaultEncoding': standardEncoding,
        'toUnicode': ToUnicodeMap({65: 'A', 66: 'B'}),
      });

      expect(font.encodeString('ABé'), ['AB', 'é']);
      expect(font.getCharPositions('AB'), [
        [0, 1],
        [1, 2],
      ]);
    });

    test('uses CMap for multibyte chars and char positions', () {
      final cmap = CMap()
        ..addCodespaceRange(2, 0x0100, 0x01ff)
        ..mapOne(0x0120, 65);
      final font = Font('Composite', null, {
        'loadedName': 'cmp',
        'flags': 0,
        'type': 'CIDFontType2',
        'composite': true,
        'cMap': cmap,
        'differences': <int, String>{},
        'widths': {65: 700},
        'defaultWidth': 500,
        'capHeight': 0,
        'ascent': 0,
        'descent': 0,
        'defaultEncoding': standardEncoding,
        'toUnicode': ToUnicodeMap({0x0120: 'A'}),
      });

      final chars = String.fromCharCodes([0x01, 0x20]);
      final glyphs = font.charsToGlyphs(chars);

      expect(glyphs.single.originalCharCode, 0x0120);
      expect(glyphs.single.width, 700);
      expect(font.getCharPositions(chars), [
        [0, 2],
      ]);
      expect(font.encodeString('A'), [chars]);
    });

    test('initializes Type3 toFontChar from differences/default encoding', () {
      final font = Font('Type3Font', null, {
        'loadedName': 't3',
        'flags': 0,
        'type': 'Type3',
        'isType3Font': true,
        'differences': {65: 'CustomGlyph'},
        'widths': {65: 400},
        'defaultWidth': 500,
        'capHeight': 0,
        'ascent': 0,
        'descent': 0,
        'defaultEncoding': standardEncoding,
        'toUnicode': ToUnicodeMap({65: 'A'}),
      });

      final glyph = font.charsToGlyphs('A').single;

      expect(font.toFontChar[65], 'CustomGlyph');
      expect(glyph.operatorListId, 'CustomGlyph');
      expect(glyph.fontChar, 'CustomGlyph');
    });

    test('repairs minimal TrueType files through the Font constructor', () {
      final builder = OpenTypeFileBuilder('true')
        ..addTable('head', Uint8List(20))
        ..addTable('loca', Uint8List.fromList([0, 0]))
        ..addTable('maxp', Uint8List.fromList([0, 1, 0, 0, 0, 1]))
        ..addTable('name', createNameTable('Tiny TrueType'));

      final font = Font('TinyTrueType', Stream(builder.toArray()), {
        'loadedName': 'tiny',
        'flags': 0,
        'type': 'TrueType',
        'subtype': null,
        'differences': <int, String>{},
        'widths': {65: 600},
        'defaultWidth': 500,
        'capHeight': 700,
        'ascent': 800,
        'descent': -200,
        'defaultEncoding': standardEncoding,
        'toUnicode': ToUnicodeMap({65: 'A'}),
      });

      expect(font.missingFile, isFalse);
      expect(font.mimetype, 'font/opentype');
      expect(font.isOpenType, isFalse);
      expect(font.data, isA<Uint8List>());
      expect(isTrueTypeFile(Stream(font.data as Uint8List)), isTrue);
      expect(font.charsToGlyphs('A').single.width, 600);
    });
  });
}
