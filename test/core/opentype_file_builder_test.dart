import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfjs/src/core/opentype_file_builder.dart';

void main() {
  group('OpenTypeFileBuilder', () {
    test('writes an sfnt header and sorted table records', () {
      final builder = OpenTypeFileBuilder('true')
        ..addTable('head', Uint8List.fromList([1, 2, 3, 4]))
        ..addTable('cmap', Uint8List.fromList([5, 6, 7]));

      final file = builder.toArray();
      final view = ByteData.view(file.buffer);

      expect(file.length, 52);
      expect(file.sublist(0, 4), [0, 1, 0, 0]);
      expect(view.getUint16(4), 2);
      expect(view.getUint16(6), 32);
      expect(view.getUint16(8), 1);
      expect(view.getUint16(10), 0);

      expect(String.fromCharCodes(file.sublist(12, 16)), 'cmap');
      expect(view.getUint32(16), 0x05060700);
      expect(view.getUint32(20), 44);
      expect(view.getUint32(24), 3);

      expect(String.fromCharCodes(file.sublist(28, 32)), 'head');
      expect(view.getUint32(32), 0x01020304);
      expect(view.getUint32(36), 48);
      expect(view.getUint32(40), 4);

      expect(file.sublist(44, 48), [5, 6, 7, 0]);
      expect(file.sublist(48, 52), [1, 2, 3, 4]);
    });

    test('rejects duplicate table tags', () {
      final builder = OpenTypeFileBuilder('OTTO')
        ..addTable('name', Uint8List(0));

      expect(
        () => builder.addTable('name', Uint8List(0)),
        throwsException,
      );
    });
  });
}
