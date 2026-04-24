import 'dart:typed_data';

import 'package:pdfjs/src/core/jpx.dart';
import 'package:test/test.dart';

void main() {
  group('JpxImage', () {
    test('parseImageProperties reads SIZ marker', () {
      final data = Uint8List.fromList([
        0xff, 0x4f, // SOC
        0xff, 0x51, // SIZ
        0x00, 0x2f, // Lsiz
        0x00, 0x00, // Rsiz
        0x00, 0x00, 0x02, 0x80, // Xsiz = 640
        0x00, 0x00, 0x01, 0xf4, // Ysiz = 500
        0x00, 0x00, 0x00, 0x10, // XOsiz = 16
        0x00, 0x00, 0x00, 0x14, // YOsiz = 20
        0x00, 0x00, 0x02, 0x80, // XTsiz
        0x00, 0x00, 0x01, 0xf4, // YTsiz
        0x00, 0x00, 0x00, 0x00, // XTOsiz
        0x00, 0x00, 0x00, 0x00, // YTOsiz
        0x00, 0x03, // Csiz
      ]);

      final properties = JpxImage.parseImageProperties(data);

      expect(properties.width, 624);
      expect(properties.height, 480);
      expect(properties.bitsPerComponent, 8);
      expect(properties.componentsCount, 3);
      expect(properties.serializable, {
        'width': 624,
        'height': 480,
        'bitsPerComponent': 8,
        'componentsCount': 3,
      });
    });

    test('parseImageProperties rejects streams without SIZ marker', () {
      expect(
        () => JpxImage.parseImageProperties(Uint8List.fromList([0xff, 0x4f])),
        throwsA(isA<JpxError>()),
      );
    });
  });
}
