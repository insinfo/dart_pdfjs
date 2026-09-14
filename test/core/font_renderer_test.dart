import 'dart:typed_data';

import 'package:pdfjs/src/core/font_renderer.dart';
import 'package:pdfjs/src/shared/util.dart';
import 'package:test/test.dart';

void main() {
  group('FontRenderer', () {
    test('Commands tracks draw operations, transforms and produces float path', () {
      final cmds = Commands();
      expect(cmds.getPath().isEmpty, isTrue);

      cmds.add(DrawOPS.moveTo, [10.0, 20.0]);
      cmds.add(DrawOPS.lineTo, [30.0, 40.0]);
      cmds.add(DrawOPS.closePath);

      final path = cmds.getPath();
      expect(path.length, equals(1 + 2 + 1 + 2 + 1));
      expect(path[0], equals(DrawOPS.moveTo.toDouble()));
      expect(path[1], equals(10.0));
      expect(path[2], equals(20.0));
      expect(path[3], equals(DrawOPS.lineTo.toDouble()));
      expect(path[4], equals(30.0));
      expect(path[5], equals(40.0));
      expect(path[6], equals(DrawOPS.closePath.toDouble()));
    });

    test('Commands handles save, restore and transforms correctly', () {
      final cmds = Commands();
      cmds.save();
      cmds.translate(5.0, 10.0);
      cmds.add(DrawOPS.moveTo, [2.0, 3.0]);
      cmds.restore();
      cmds.add(DrawOPS.moveTo, [2.0, 3.0]);

      final path = cmds.getPath();
      // First moveTo translated: (2+5, 3+10) = (7, 13)
      expect(path[1], equals(7.0));
      expect(path[2], equals(13.0));
      // Second moveTo after restore: (2, 3)
      expect(path[4], equals(2.0));
      expect(path[5], equals(3.0));
    });

    test('TrueTypeCompiled compiles simple glyph to vector ops', () {
      // Build a minimal TrueType simple glyph byte buffer:
      // numberOfContours = 1
      // xMin, yMin, xMax, yMax (8 bytes)
      // endPtsOfContours[0] = 2 (3 points: 0, 1, 2)
      // instructionLength = 0
      // flags: 3 points with ON_CURVE (0x01) and x-is-byte (0x02), y-is-byte (0x04)
      final bb = BytesBuilder();
      final header = ByteData(10);
      header.setInt16(0, 1); // 1 contour
      header.setInt16(2, 0); // xMin
      header.setInt16(4, 0); // yMin
      header.setInt16(6, 100); // xMax
      header.setInt16(8, 100); // yMax
      bb.add(header.buffer.asUint8List());

      // endPtsOfContours
      final endPts = ByteData(2);
      endPts.setUint16(0, 2); // 3 points: indices 0..2
      bb.add(endPts.buffer.asUint8List());

      // instruction length = 0
      final instLen = ByteData(2);
      instLen.setUint16(0, 0);
      bb.add(instLen.buffer.asUint8List());

      // Flags for 3 points: on-curve (1)
      bb.add([1, 1, 1]);

      // X coordinates (delte format: using flags & 0x00, 2-byte ints)
      final xCoords = ByteData(6);
      xCoords.setInt16(0, 10);
      xCoords.setInt16(2, 20);
      xCoords.setInt16(4, 30);
      bb.add(xCoords.buffer.asUint8List());

      // Y coordinates
      final yCoords = ByteData(6);
      yCoords.setInt16(0, 5);
      yCoords.setInt16(2, 15);
      yCoords.setInt16(4, 25);
      bb.add(yCoords.buffer.asUint8List());

      final glyphBytes = bb.toBytes();

      final cmap = [
        CmapRange(start: 65, end: 65, idDelta: 0, ids: [0]),
      ];

      final tt = TrueTypeCompiled([glyphBytes], cmap);
      final path = tt.getPathJs('A');
      expect(path, isNotEmpty);
      expect(tt.hasBuiltPath('A'), isTrue);
    });

    test('CompiledFont.noop returns empty Float32List for empty or missing glyph', () {
      final cmap = [CmapRange(start: 65, end: 65, idDelta: 0, ids: [0])];
      final tt = TrueTypeCompiled([Uint8List(0)], cmap);
      final path = tt.getPathJs('A');
      expect(path.isEmpty, isTrue);
    });
  });
}
