// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import '../shared/util.dart';
import 'base_stream.dart';
import 'image.dart';
import 'primitives.dart';

/// Decodes PDF image streams into the self-contained pixel payload consumed by
/// the display layer.
///
/// PDF.js normally transfers large image objects through a worker-side object
/// cache. The Dart implementation can also run core and display in the same
/// isolate, so keeping the pixels in the operator list makes image rendering
/// deterministic without requiring a message-handler implementation.
class ImageEvaluator {
  const ImageEvaluator._();

  static Future<Map<String, dynamic>> decode({
    required dynamic xref,
    required Dict resources,
    required BaseStream image,
    bool isInline = false,
  }) async {
    final dict = image.dict;
    if (dict is! Dict) {
      throw FormatError('Image stream is missing its dictionary.');
    }

    if (dict.get('IM', 'ImageMask') == true) {
      return _decodeImageMask(image, dict);
    }

    image.reset();
    final pdfImage = await PDFImage.buildImage(
      xref: xref,
      res: resources,
      image: image,
      isInline: isInline,
    );
    final dynamic decoded = await pdfImage.createImageData(forceRGBA: true);
    if (decoded is! Map) {
      throw FormatError('Image decoder returned an invalid payload.');
    }

    final width = (decoded['width'] as num?)?.toInt() ?? pdfImage.drawWidth;
    final height = (decoded['height'] as num?)?.toInt() ?? pdfImage.drawHeight;
    final pixels = _asBytes(decoded['data']);
    final requiredLength = width * height * 4;
    if (width <= 0 || height <= 0 || pixels.length < requiredLength) {
      throw FormatError(
        'Image decoder returned ${pixels.length} bytes for a '
        '${width}x$height RGBA image.',
      );
    }

    return <String, dynamic>{
      'width': width,
      'height': height,
      'data': pixels.length == requiredLength
          ? pixels
          : Uint8List.sublistView(pixels, 0, requiredLength),
      'kind': ImageKind.RGBA_32BPP,
      'interpolate': decoded['interpolate'] == true,
    };
  }

  static Future<Map<String, dynamic>> _decodeImageMask(
    BaseStream image,
    Dict dict,
  ) async {
    image.reset();
    final mask = await PDFImage.createMask(image: image);
    final width = (dict.get('W', 'Width') as num?)?.toInt() ?? 0;
    final height = (dict.get('H', 'Height') as num?)?.toInt() ?? 0;
    if (mask['isSingleOpaquePixel'] == true) {
      return <String, dynamic>{
        'width': 1,
        'height': 1,
        'data': Uint8List.fromList(<int>[0, 0, 0, 255]),
        'kind': ImageKind.RGBA_32BPP,
        'interpolate': false,
        'isImageMask': true,
      };
    }

    final packed = _asBytes(mask['data']);
    final rowBytes = (width + 7) >> 3;
    final rgba = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final byteIndex = y * rowBytes + (x >> 3);
        final sample = byteIndex < packed.length
            ? (packed[byteIndex] >> (7 - (x & 7))) & 1
            : 1;
        final offset = (y * width + x) * 4;
        rgba[offset] = 0;
        rgba[offset + 1] = 0;
        rgba[offset + 2] = 0;
        rgba[offset + 3] = sample == 0 ? 255 : 0;
      }
    }
    return <String, dynamic>{
      'width': width,
      'height': height,
      'data': rgba,
      'kind': ImageKind.RGBA_32BPP,
      'interpolate': mask['interpolate'] == true,
      'isImageMask': true,
    };
  }

  static Uint8List _asBytes(dynamic value) {
    if (value is Uint8List) return value;
    if (value is Iterable<int>) return Uint8List.fromList(value.toList());
    throw FormatError('Image decoder did not return byte data.');
  }
}
