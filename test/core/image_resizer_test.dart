// Copyright 2023 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'package:pdfjs/src/core/image_resizer.dart';
import 'package:pdfjs/src/shared/util.dart';
import 'package:test/test.dart';

void main() {
  group('ImageResizer', () {
    test('needsToBeResized detects dimensions exceeding threshold', () {
      expect(ImageResizer.needsToBeResized(100, 100), isFalse);
      expect(ImageResizer.needsToBeResized(2000, 2000), isFalse);
      expect(ImageResizer.needsToBeResized(40000, 100), isTrue);
      expect(ImageResizer.needsToBeResized(100, 40000), isTrue);
    });

    test('getReducePowerForJPX calculates scaling power', () {
      // Small image doesn't need scaling
      expect(ImageResizer.getReducePowerForJPX(100, 100, 3), equals(0));

      // Very large image needs scaling
      final power = ImageResizer.getReducePowerForJPX(10000, 10000, 3);
      expect(power, greaterThan(0));
    });

    test('encodeBMP produces valid BMP header for 1bpp monochrome image', () {
      final imgData = {
        'width': 8,
        'height': 2,
        'kind': ImageKind.GRAYSCALE_1BPP,
        'data': Uint8List.fromList([0xaa, 0x55]),
      };

      final resizer = ImageResizer(imgData, false);
      final bmp = resizer.encodeBMP();
      final view = ByteData.sublistView(bmp);

      // Signature 'BM' (0x4d42)
      expect(view.getUint16(0, Endian.little), equals(0x4d42));

      // Header size: 14 byte file header + 40 byte DIB header
      final dataOffset = view.getUint32(10, Endian.little);
      expect(dataOffset, greaterThan(54));

      // Dimensions
      expect(view.getInt32(18, Endian.little), equals(8));
      expect(view.getInt32(22, Endian.little), equals(-2)); // Top-down

      // Bit count
      expect(view.getUint16(28, Endian.little), equals(1));
    });

    test('encodeBMP produces valid BMP header for 24bpp RGB image', () {
      // 2x2 image, 3 bytes per pixel = 6 bytes raw, padded row = 8 bytes
      final imgData = {
        'width': 2,
        'height': 2,
        'kind': ImageKind.RGB_24BPP,
        'data': Uint8List.fromList([
          255, 0, 0,  0, 255, 0,
          0, 0, 255,  255, 255, 255,
        ]),
      };

      final resizer = ImageResizer(imgData, false);
      final bmp = resizer.encodeBMP();
      final view = ByteData.sublistView(bmp);

      expect(view.getUint16(0, Endian.little), equals(0x4d42));
      expect(view.getInt32(18, Endian.little), equals(2));
      expect(view.getInt32(22, Endian.little), equals(-2));
      expect(view.getUint16(28, Endian.little), equals(24));
    });

    test('encodeBMP produces valid BMP header for 32bpp RGBA image', () {
      final imgData = {
        'width': 2,
        'height': 2,
        'kind': ImageKind.RGBA_32BPP,
        'data': Uint8List(16),
      };

      final resizer = ImageResizer(imgData, false);
      final bmp = resizer.encodeBMP();
      final view = ByteData.sublistView(bmp);

      expect(view.getUint16(0, Endian.little), equals(0x4d42));
      expect(view.getInt32(18, Endian.little), equals(2));
      expect(view.getInt32(22, Endian.little), equals(-2));
      expect(view.getUint16(28, Endian.little), equals(32));
      // Compression method 3 (BI_BITFIELDS)
      expect(view.getUint32(30, Endian.little), equals(3));
    });
  });
}
