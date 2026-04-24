// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

class JpegOptions {
  Int32List? decodeTransform;
  int? colorTransform;

  JpegOptions({this.decodeTransform, this.colorTransform});
}

class JpegImage {
  final JpegOptions options;

  JpegImage([JpegOptions? options]) : options = options ?? JpegOptions();

  void parse(Uint8List data) {
    // TODO: implement
    throw UnimplementedError('JpegImage.parse');
  }

  Uint8List getData(Map<String, dynamic> params) {
    // TODO: implement
    throw UnimplementedError('JpegImage.getData');
  }

  static dynamic canUseImageDecoder(Uint8List data, int? colorTransform) {
    // Retorna false ou objeto com exifStart/exifEnd. Em Dart Native cross-platform, geralmente false.
    return false;
  }
}
