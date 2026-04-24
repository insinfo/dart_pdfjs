import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfjs/src/core/glyf.dart';

void main() {
  group('GlyfTable', () {
    test('parses and writes simple glyphs with short loca offsets', () {
      final glyf = _simpleTriangleGlyph();
      final loca = _shortLoca([0, glyf.length, glyf.length]);

      final table = GlyfTable(
        glyfTable: glyf,
        isGlyphLocationsLong: false,
        locaTable: loca,
        numGlyphs: 2,
      );

      expect(table.glyphs, hasLength(2));
      expect(table.glyphs[0].header!.numberOfContours, 1);
      expect(table.glyphs[0].header!.xMax, 10);
      expect(table.glyphs[0].simple!.contours.single.xCoordinates, [0, 10, 0]);
      expect(table.glyphs[0].simple!.contours.single.yCoordinates, [0, 0, 10]);
      expect(table.glyphs[1].header, isNull);

      final written = table.write();
      expect(written.isLocationLong, isFalse);
      expect(written.loca, _shortLoca([0, 20, 20]));
      expect(written.glyf, glyf);
    });

    test('scales glyph x coordinates around the glyph midpoint', () {
      final glyf = _simpleTriangleGlyph();
      final table = GlyfTable(
        glyfTable: glyf,
        isGlyphLocationsLong: false,
        locaTable: _shortLoca([0, glyf.length]),
        numGlyphs: 1,
      );

      table.scale([2]);
      final written = table.write();
      final scaled = GlyfTable(
        glyfTable: written.glyf,
        isGlyphLocationsLong: written.isLocationLong,
        locaTable: written.loca,
        numGlyphs: 1,
      );

      expect(scaled.glyphs[0].header!.xMin, -5);
      expect(scaled.glyphs[0].header!.xMax, 15);
      expect(
        scaled.glyphs[0].simple!.contours.single.xCoordinates,
        [-5, 15, -5],
      );
      expect(
        scaled.glyphs[0].simple!.contours.single.yCoordinates,
        [0, 0, 10],
      );
    });

    test('parses and writes composite glyphs', () {
      final glyf = _compositeGlyph();
      final table = GlyfTable(
        glyfTable: glyf,
        isGlyphLocationsLong: false,
        locaTable: _shortLoca([0, glyf.length]),
        numGlyphs: 1,
      );

      final glyph = table.glyphs.single;
      expect(glyph.header!.numberOfContours, -1);
      expect(glyph.composites, hasLength(1));
      expect(glyph.composites!.single.glyphIndex, 3);
      expect(glyph.composites!.single.argument1, 5);
      expect(glyph.composites!.single.argument2, -3);

      final written = table.write();
      expect(written.glyf, glyf);
      expect(written.loca, _shortLoca([0, 16]));
    });
  });
}

Uint8List _simpleTriangleGlyph() {
  final bytes = Uint8List(20);
  final data = ByteData.view(bytes.buffer);
  data.setInt16(0, 1); // numberOfContours
  data.setInt16(2, 0); // xMin
  data.setInt16(4, 0); // yMin
  data.setInt16(6, 10); // xMax
  data.setInt16(8, 10); // yMax
  data.setUint16(10, 2); // endPtsOfContours
  data.setUint16(12, 0); // instructionLength
  bytes[14] = onCurvePoint |
      xIsSameOrPositiveXShortVector |
      yIsSameOrPositiveYShortVector;
  bytes[15] = onCurvePoint |
      xShortVector |
      xIsSameOrPositiveXShortVector |
      yIsSameOrPositiveYShortVector;
  bytes[16] = onCurvePoint |
      xShortVector |
      yShortVector |
      yIsSameOrPositiveYShortVector;
  bytes[17] = 10; // second point x delta
  bytes[18] = 10; // third point x delta
  bytes[19] = 10; // third point y delta
  return bytes;
}

Uint8List _compositeGlyph() {
  final bytes = Uint8List(16);
  final data = ByteData.view(bytes.buffer);
  data.setInt16(0, -1); // numberOfContours
  data.setInt16(2, 0); // xMin
  data.setInt16(4, 0); // yMin
  data.setInt16(6, 10); // xMax
  data.setInt16(8, 10); // yMax
  data.setUint16(10, argsAreXyValues);
  data.setUint16(12, 3); // glyphIndex
  data.setInt8(14, 5);
  data.setInt8(15, -3);
  return bytes;
}

Uint8List _shortLoca(List<int> offsets) {
  final bytes = Uint8List(offsets.length * 2);
  final data = ByteData.view(bytes.buffer);
  for (var i = 0; i < offsets.length; i++) {
    data.setUint16(i * 2, offsets[i] >> 1);
  }
  return bytes;
}
