part of 'jpeg_decoder.dart';

extension _HierarchicalDecoder on _Decoder {
  int? _firstFrameMarker() {
    for (var i = offset; i + 1 < data.length; i++) {
      if (data[i] != 0xff) continue;
      final marker = data[i + 1];
      if ((marker >= 0xc0 && marker <= 0xcf) &&
          marker != 0xc4 &&
          marker != 0xc8 &&
          marker != 0xcc) {
        return marker;
      }
    }
    return null;
  }

  JpegImage _decodeHierarchical() {
    throw const JpegDecodeException(
      'Hierarchical JPEG requires the Annex J decoder module.',
    );
  }
}
