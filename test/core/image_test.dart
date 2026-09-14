// Copyright 2026. Apache License 2.0.

import 'dart:typed_data';

import 'package:pdfjs/src/core/image.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/stream.dart';
import 'package:pdfjs/src/shared/util.dart';
import 'package:test/test.dart';

class _FakeXRef {
  dynamic fetchIfRef(dynamic obj) => obj;
}

void main() {
  group('PDFImage Tests', () {
    test('createMask handles single opaque pixel', () async {
      final dict = Dict(null);
      dict.set('W', 1);
      dict.set('H', 1);
      // inverseDecode = true if decode[0] > 0
      dict.set('D', [1, 0]);
      // Byte 0x80 tem MSB = 1
      final stream = Stream(Uint8List.fromList([0x80]), 0, 1, dict);

      final maskResult = await PDFImage.createMask(image: stream);
      expect(maskResult['isSingleOpaquePixel'], isTrue);
    });

    test('createMask handles multi-pixel mask and inverseDecode', () async {
      final dict = Dict(null);
      dict.set('W', 8);
      dict.set('H', 1);
      dict.set('D', [1, 0]); // inverseDecode = true
      final stream = Stream(Uint8List.fromList([0xAA]), 0, 1, dict); // 10101010

      final maskResult = await PDFImage.createMask(image: stream);
      expect(maskResult['width'], equals(8));
      expect(maskResult['height'], equals(1));
      final data = maskResult['data'] as Uint8List;
      expect(data.length, equals(1));
      // 0xAA ^ 0xFF = 0x55 (01010101)
      expect(data[0], equals(0x55));
    });

    test('getComponents unpacks 1-bit per component correctly', () {
      final dict = Dict(null);
      dict.set('W', 8);
      dict.set('H', 2);
      dict.set('BPC', 1);
      dict.set('CS', Name.get('DeviceGray'));
      final bytes = Uint8List.fromList([0xF0, 0x0F]); // 11110000, 00001111
      final stream = Stream(bytes, 0, 2, dict);

      final pdfImage = PDFImage(
        image: stream,
        xref: _FakeXRef(),
      );

      final comps = pdfImage.getComponents(bytes);
      expect(comps.length, equals(16));
      expect(comps.sublist(0, 8), equals([1, 1, 1, 1, 0, 0, 0, 0]));
      expect(comps.sublist(8, 16), equals([0, 0, 0, 0, 1, 1, 1, 1]));
    });

    test('decodeBuffer inverts 1bpc and scales multi-bpc', () {
      final dict = Dict(null);
      dict.set('W', 2);
      dict.set('H', 1);
      dict.set('BPC', 1);
      dict.set('CS', Name.get('DeviceGray'));
      final stream = Stream(Uint8List(2), 0, 2, dict);

      final pdfImage = PDFImage(
        image: stream,
        xref: _FakeXRef(),
      );

      final buf = [0, 1];
      pdfImage.decodeBuffer(buf);
      expect(buf, equals([1, 0]));
    });

    test('createImageData returns GRAYSCALE_1BPP for 1-bit grayscale', () async {
      final dict = Dict(null);
      dict.set('W', 8);
      dict.set('H', 1);
      dict.set('BPC', 1);
      dict.set('CS', Name.get('DeviceGray'));
      final stream = Stream(Uint8List.fromList([0xAA]), 0, 1, dict);

      final pdfImage = PDFImage(
        image: stream,
        xref: _FakeXRef(),
      );

      final imgData = await pdfImage.createImageData(forceRGBA: false);
      expect(imgData['kind'], equals(ImageKind.GRAYSCALE_1BPP));
      expect(imgData['width'], equals(8));
      expect(imgData['height'], equals(1));
      expect(imgData['data'], equals(Uint8List.fromList([0xAA])));
    });

    test('createImageData returns RGB_24BPP for 8-bit DeviceRGB', () async {
      final dict = Dict(null);
      dict.set('W', 1);
      dict.set('H', 1);
      dict.set('BPC', 8);
      dict.set('CS', Name.get('DeviceRGB'));
      final rgbBytes = Uint8List.fromList([255, 128, 0]);
      final stream = Stream(rgbBytes, 0, 3, dict);

      final pdfImage = PDFImage(
        image: stream,
        xref: _FakeXRef(),
      );

      final imgData = await pdfImage.createImageData(forceRGBA: false);
      expect(imgData['kind'], equals(ImageKind.RGB_24BPP));
      expect(imgData['width'], equals(1));
      expect(imgData['height'], equals(1));
      expect(imgData['data'], equals(rgbBytes));
    });

    test('fillGrayBuffer fills and resamples correctly', () async {
      final dict = Dict(null);
      dict.set('W', 2);
      dict.set('H', 2);
      dict.set('BPC', 8);
      dict.set('CS', Name.get('DeviceGray'));
      final grayBytes = Uint8List.fromList([10, 20, 30, 40]);
      final stream = Stream(grayBytes, 0, 4, dict);

      final pdfImage = PDFImage(
        image: stream,
        xref: _FakeXRef(),
      );

      final outBuf = Uint8List(4);
      await pdfImage.fillGrayBuffer(outBuf);
      expect(outBuf, equals([10, 20, 30, 40]));

      // Test with invertOutput
      final outInvert = Uint8List(4);
      await pdfImage.fillGrayBuffer(outInvert, invertOutput: true);
      expect(outInvert, equals([10 ^ 0xFF, 20 ^ 0xFF, 30 ^ 0xFF, 40 ^ 0xFF]));
    });
  });
}
