import 'dart:typed_data';

import 'package:pdfjs/src/core/jpeg_arithmetic_decoder.dart';
import 'package:pdfjs/src/core/jpeg_decoder.dart';
import 'package:test/test.dart';

Uint8List frame(int marker,
    {int width = 3, int height = 2, int components = 1}) {
  final bytes = <int>[
    0xff,
    0xd8,
    0xff,
    marker,
    0,
    8 + components * 3,
    8,
    height >> 8,
    height & 255,
    width >> 8,
    width & 255,
    components
  ];
  for (var i = 0; i < components; i++) {
    bytes.addAll([i + 1, 0x11, 0]);
  }
  bytes.addAll([0xff, 0xd9]);
  return Uint8List.fromList(bytes);
}

void main() {
  group('JpegDecoder probe', () {
    test('reads baseline dimensions', () {
      final info = JpegDecoder.probe(frame(0xc0));
      expect(info.width, 3);
      expect(info.height, 2);
      expect(info.components, 1);
      expect(info.pixelCount, 6);
      expect(info.decodable, isTrue);
    });
    test('reads progressive RGB dimensions', () {
      final info = JpegDecoder.probe(
          frame(0xc2, width: 640, height: 480, components: 3));
      expect((info.width, info.height, info.components), (640, 480, 3));
      expect(info.decodable, isTrue);
    });
    test('recognizes lossless Huffman frames', () {
      expect(JpegDecoder.probe(frame(0xc3)).decodable, isTrue);
    });
    test('recognizes arithmetic sequential frames', () {
      expect(JpegDecoder.probe(frame(0xc9)).decodable, isTrue);
    });
    test('recognizes arithmetic progressive frames', () {
      expect(JpegDecoder.probe(frame(0xca)).decodable, isTrue);
    });
    test('recognizes arithmetic lossless frames', () {
      expect(JpegDecoder.probe(frame(0xcb)).decodable, isTrue);
    });
    test('rejects differential DCT Huffman frames', () {
      final info = JpegDecoder.probe(frame(0xc5));
      expect(info.decodable, isFalse);
      expect(info.reason, contains('Differential DCT'));
    });
    test('rejects differential DCT arithmetic frames', () {
      final info = JpegDecoder.probe(frame(0xcd));
      expect(info.decodable, isFalse);
      expect(info.reason, contains('differential DCT'));
    });
    test('rejects non-JPEG input', () {
      expect(() => JpegDecoder.probe(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<JpegDecodeException>()));
    });
    test('rejects truncated markers', () {
      expect(() => JpegDecoder.probe(Uint8List.fromList([0xff, 0xd8, 0xff])),
          throwsA(isA<JpegDecodeException>()));
    });
  });

  group('JPEG arithmetic probability table', () {
    test('contains 113 state rows', () {
      expect(JpegArithmeticDecoder.stateRow(0), hasLength(4));
      expect(JpegArithmeticDecoder.stateRow(112), hasLength(4));
    });
    test('starts with the Annex D initial state', () {
      expect(JpegArithmeticDecoder.stateRow(0), [0x5a1d, 1, 1, 1]);
    });
    test('rejects state indexes outside the table', () {
      expect(() => JpegArithmeticDecoder.stateRow(-1), throwsRangeError);
      expect(() => JpegArithmeticDecoder.stateRow(113), throwsRangeError);
    });
    test('decodes fixed-probability decisions', () {
      final decoder =
          JpegArithmeticDecoder(Uint8List.fromList([0, 0, 0, 0]), 0);
      final decisions = [for (var i = 0; i < 16; i++) decoder.decodeFixed()];
      expect(decisions, everyElement(anyOf(0, 1)));
    });
  });

  group('JpegImage value object', () {
    test('reports grayscale bytes per pixel', () {
      final image = JpegImage(
          width: 1,
          height: 1,
          format: JpegPixelFormat.grayscale,
          pixels: Uint8List(1));
      expect(image.bytesPerPixel, 1);
      expect(image.toString(), contains('1x1'));
    });
    test('reports RGB bytes per pixel', () {
      final image = JpegImage(
          width: 1,
          height: 1,
          format: JpegPixelFormat.rgb,
          pixels: Uint8List(3));
      expect(image.bytesPerPixel, 3);
    });
    test('reports CMYK bytes per pixel and Adobe inversion', () {
      final image = JpegImage(
          width: 1,
          height: 1,
          format: JpegPixelFormat.cmyk,
          pixels: Uint8List(4),
          adobeInverted: true);
      expect(image.bytesPerPixel, 4);
      expect(image.adobeInverted, isTrue);
    });
  });
}
