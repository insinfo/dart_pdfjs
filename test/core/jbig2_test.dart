import 'dart:typed_data';

import 'package:pdfjs/src/core/jbig2.dart';
import 'package:test/test.dart';

void main() {
  group('JBIG2 segment parsing', () {
    test('reads a segment header', () {
      final data = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x01, // segment number
        0x30, // PageInformation
        0x00, // referred-to flags
        0x01, // page association
        0x00, 0x00, 0x00, 0x13, // segment length
        ...List<int>.filled(19, 0),
      ]);

      final header = readSegmentHeader(data, 0);

      expect(header.number, 1);
      expect(header.type, 48);
      expect(header.typeName, 'PageInformation');
      expect(header.pageAssociation, 1);
      expect(header.length, 19);
      expect(header.headerEnd, 11);
    });

    test('parses page information and allocates the page buffer', () {
      final data = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x01, // segment number
        0x30, // PageInformation
        0x00, // referred-to flags
        0x01, // page association
        0x00, 0x00, 0x00, 0x13, // segment length
        0x00, 0x00, 0x00, 0x09, // width
        0x00, 0x00, 0x00, 0x02, // height
        0x00, 0x00, 0x00, 0x48, // resolutionX
        0x00, 0x00, 0x00, 0x48, // resolutionY
        0x04, // defaultPixelValue = 1
        0x00, 0x00, // page striping information
        0x00, 0x00, 0x00, 0x02, // segment number
        0x33, // EndOfFile
        0x00, // referred-to flags
        0x01, // page association
        0x00, 0x00, 0x00, 0x00, // segment length
      ]);

      final parsed = parseJbig2Chunks([
        {'data': data, 'start': 0, 'end': data.length}
      ]);

      expect(parsed, Uint8List.fromList([0xff, 0xff, 0xff, 0xff]));
    });

    test('reads uncompressed bitmaps with row byte alignment', () {
      final reader = Reader(
        Uint8List.fromList([
          0xa0,
          0x40,
        ]),
        0,
        2,
      );

      final bitmap = readUncompressedBitmap(reader, 3, 2);

      expect(bitmap[0], Uint8List.fromList([1, 0, 1]));
      expect(bitmap[1], Uint8List.fromList([0, 1, 0]));
    });

    test('decodes standard Huffman table entries', () {
      final table = getStandardTable(1);

      expect(table.decode(Reader(Uint8List.fromList([0x28]), 0, 1)), 5);
      expect(
          table.decode(Reader(Uint8List.fromList([0x84, 0x00]), 0, 2)), 0x20);
    });

    test('decodes Huffman out-of-band lines', () {
      final table = getStandardTable(2);

      expect(table.decode(Reader(Uint8List.fromList([0xfc]), 0, 1)), isNull);
    });

    test('decodes custom Huffman table segments', () {
      final table = decodeTablesSegment(
        Uint8List.fromList([
          0x02, // prefix size: 2 bits, range size: 1 bit
          0x00, 0x00, 0x00, 0x00, // lowest value
          0x00, 0x00, 0x00, 0x02, // highest value
          0x74, // line: prefix=1/range=1, lower=2, upper=2
        ]),
        0,
        10,
      );

      expect(table.decode(Reader(Uint8List.fromList([0x40]), 0, 1)), 1);
    });

    test('processes table segments into the visitor cache', () {
      final data = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x01, // segment number
        0x35, // Tables
        0x00, // referred-to flags
        0x01, // page association
        0x00, 0x00, 0x00, 0x0a, // segment length
        0x02, // prefix size: 2 bits, range size: 1 bit
        0x00, 0x00, 0x00, 0x00, // lowest value
        0x00, 0x00, 0x00, 0x02, // highest value
        0x74,
      ]);
      final visitor = SimpleSegmentVisitor();

      processSegments(
          readSegments(<String, dynamic>{}, data, 0, data.length), visitor);

      expect(visitor.customTables, contains(1));
      expect(
        visitor.customTables[1]!
            .decode(Reader(Uint8List.fromList([0x40]), 0, 1)),
        1,
      );
    });

    test('processes empty symbol dictionaries', () {
      final data = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x01, // segment number
        0x00, // SymbolDictionary
        0x00, // referred-to flags
        0x01, // page association
        0x00, 0x00, 0x00, 0x0c, // segment length
        0x04, 0x00, // flags: template 1, arithmetic
        0x00, 0x00, // one AT entry
        0x00, 0x00, 0x00, 0x00, // exported symbols
        0x00, 0x00, 0x00, 0x00, // new symbols
      ]);
      final visitor = SimpleSegmentVisitor();

      processSegments(
          readSegments(<String, dynamic>{}, data, 0, data.length), visitor);

      expect(visitor.symbols[1], isEmpty);
    });

    test('renders a halftone region with a single pattern', () {
      final bitmap = decodeHalftoneRegion(
        false,
        [
          [
            Uint8List.fromList([1, 0]),
            Uint8List.fromList([0, 1]),
          ],
        ],
        0,
        3,
        3,
        0,
        false,
        0,
        1,
        1,
        0,
        0,
        0,
        0,
        DecodingContext(Uint8List(0), 0, 0),
      );

      expect(bitmap[0], Uint8List.fromList([1, 0, 0]));
      expect(bitmap[1], Uint8List.fromList([0, 1, 0]));
      expect(bitmap[2], Uint8List.fromList([0, 0, 0]));
    });

    test('processes zero-sized pattern dictionary segments', () {
      final data = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x01, // segment number
        0x10, // PatternDictionary
        0x00, // referred-to flags
        0x01, // page association
        0x00, 0x00, 0x00, 0x07, // segment length
        0x00, // flags
        0x00, // pattern width
        0x00, // pattern height
        0x00, 0x00, 0x00, 0x00, // max pattern index
      ]);
      final visitor = SimpleSegmentVisitor();

      processSegments(
          readSegments(<String, dynamic>{}, data, 0, data.length), visitor);

      expect(visitor.patterns[1], hasLength(1));
      expect(visitor.patterns[1]!.first, isEmpty);
    });
  });
}
