import 'dart:typed_data';

import 'package:pdfjs/src/core/jpg.dart';
import 'package:test/test.dart';

void main() {
  group('JpegImage structural parser', () {
    test('reads dimensions, JFIF metadata and components from SOF0', () {
      final image = JpegImage();

      image.parse(Uint8List.fromList([
        0xff, 0xd8, // SOI
        0xff, 0xe0, // APP0
        0x00, 0x10, // length
        0x4a, 0x46, 0x49, 0x46, 0x00, // JFIF\0
        0x01, 0x02, // version
        0x01, // density units
        0x00, 0x48, // x density
        0x00, 0x48, // y density
        0x00, 0x00, // thumbnail
        0xff, 0xc0, // SOF0
        0x00, 0x11, // length
        0x08, // precision
        0x00, 0x02, // height
        0x00, 0x03, // width
        0x03, // components
        0x01, 0x11, 0x00,
        0x02, 0x11, 0x00,
        0x03, 0x11, 0x00,
        0xff, 0xd9, // EOI
      ]));

      expect(image.width, 3);
      expect(image.height, 2);
      expect(image.numComponents, 3);
      expect(image.jfif?['densityUnits'], 1);
      expect(image.jfif?['xDensity'], 72);
      expect(image.components.map((component) => component.index), [1, 2, 3]);
    });

    test('reads Adobe transform marker', () {
      final image = JpegImage();

      image.parse(Uint8List.fromList([
        0xff, 0xd8, // SOI
        0xff, 0xee, // APP14
        0x00, 0x0e, // length
        0x41, 0x64, 0x6f, 0x62, 0x65, // Adobe
        0x00, 0x64, // version
        0x00, 0x00, // flags0
        0x00, 0x00, // flags1
        0x02, // transform
        0xff, 0xc0, // SOF0
        0x00, 0x0b, // length
        0x08,
        0x00, 0x01,
        0x00, 0x01,
        0x01,
        0x01, 0x11, 0x00,
        0xff, 0xd9,
      ]));

      expect(image.adobe?['version'], 100);
      expect(image.adobe?['transformCode'], 2);
      expect(image.numComponents, 1);
    });

    test('throws JPEG errors for invalid input and unimplemented raster decode',
        () {
      expect(() => JpegImage().parse(Uint8List.fromList([0x00, 0x00])),
          throwsA(isA<JpegError>()));

      expect(() => JpegImage().getData({}), throwsA(isA<JpegError>()));
    });
  });
}
