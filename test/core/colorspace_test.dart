import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfjs/src/core/colorspace.dart';

void main() {
  group('ColorSpace device conversions', () {
    test('converts DeviceGray values and buffers', () {
      final cs = DeviceGrayCS();
      final item = Uint8List(3);
      cs.getRgbItem([0.5], 0, item, 0);
      expect(item, [128, 128, 128]);

      final buffer = Uint8List(8);
      cs.getRgbBuffer([0, 1], 0, 2, buffer, 0, 1, 1);
      expect(buffer, [0, 0, 0, 0, 255, 255, 255, 0]);
      expect(cs.getOutputLength(2, 1), 8);
      expect(cs.getRgbHex([1], 0), '#ffffff');
    });

    test('converts DeviceRGB buffers and fillRgb passthrough', () {
      final cs = DeviceRgbCS();
      final item = Uint8List(3);
      cs.getRgbItem([1, 0.5, 0], 0, item, 0);
      expect(item, [255, 128, 0]);

      final buffer = Uint8List(6);
      cs.getRgbBuffer([255, 0, 10, 20, 30, 40], 0, 2, buffer, 0, 8, 0);
      expect(buffer, [255, 0, 10, 20, 30, 40]);

      final filled = Uint8List(8);
      cs.fillRgb(filled, 2, 1, 2, 1, 1, 8, [1, 2, 3, 4, 5, 6], 1);
      expect(filled, [1, 2, 3, 0, 4, 5, 6, 0]);
    });

    test('copies and resizes DeviceRGBA images dropping alpha', () {
      final cs = DeviceRgbaCS();
      final copied = Uint8List(6);
      cs.fillRgb(copied, 2, 1, 2, 1, 1, 8, [1, 2, 3, 255, 4, 5, 6, 128], 0);
      expect(copied, [1, 2, 3, 4, 5, 6]);

      final resized = Uint8List(3);
      cs.fillRgb(
        resized,
        2,
        1,
        1,
        1,
        1,
        8,
        [10, 20, 30, 255, 40, 50, 60, 255],
        0,
      );
      expect(resized, [10, 20, 30]);
    });

    test('converts DeviceCMYK representative colors', () {
      final cs = DeviceCmykCS();
      final white = Uint8List(3);
      final black = Uint8List(3);

      cs.getRgbItem([0, 0, 0, 0], 0, white, 0);
      cs.getRgbItem([0, 0, 0, 1], 0, black, 0);

      expect(white, [255, 255, 255]);
      expect(black[0], lessThan(70));
      expect(black[1], lessThan(70));
      expect(black[2], lessThan(80));
    });
  });

  group('ColorSpace composed conversions', () {
    test('maps Indexed values through the base color space', () {
      final cs = IndexedCS(
          DeviceRgbCS(),
          1,
          String.fromCharCodes([
            255,
            0,
            0,
            0,
            255,
            0,
          ]));
      final dest = Uint8List(9);

      cs.getRgbBuffer([0, 1, 3], 0, 3, dest, 0, 8, 0);

      expect(dest, [255, 0, 0, 0, 255, 0, 0, 255, 0]);
      expect(cs.getRgb([1], 0), [0, 255, 0]);
      expect(cs.isDefaultDecode([0, 255], 8), isTrue);
    });

    test('applies Alternate tint function before base conversion', () {
      final cs = AlternateCS(1, DeviceRgbCS(), (
        src,
        srcOffset,
        dest,
        destOffset,
      ) {
        final tint = src[srcOffset].toDouble();
        dest[destOffset] = tint;
        dest[destOffset + 1] = 0.0;
        dest[destOffset + 2] = 1 - tint;
      });
      final dest = Uint8List(6);

      cs.getRgbBuffer([0, 255], 0, 2, dest, 0, 8, 0);

      expect(dest, [0, 0, 255, 255, 0, 0]);
    });
  });
}
