// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import '../shared/util.dart';
import 'base_stream.dart';
import 'stream.dart';

class JpxError extends BaseException {
  JpxError(String msg) : super(msg, 'JpxError');
}

class JpxImageProperties {
  const JpxImageProperties({
    required this.width,
    required this.height,
    required this.bitsPerComponent,
    required this.componentsCount,
  });

  final int width;
  final int height;
  final int bitsPerComponent;
  final int componentsCount;

  Map<String, int> get serializable => {
        'width': width,
        'height': height,
        'bitsPerComponent': bitsPerComponent,
        'componentsCount': componentsCount,
      };
}

class JpxImage {
  static dynamic _handler;
  static bool _useWasm = true;
  static bool _useWorkerFetch = true;
  static String? _wasmUrl;

  static void setOptions({
    dynamic handler,
    bool useWasm = true,
    bool useWorkerFetch = true,
    String? wasmUrl,
  }) {
    _useWasm = useWasm;
    _useWorkerFetch = useWorkerFetch;
    _wasmUrl = wasmUrl;
    _handler = useWorkerFetch ? null : handler;
  }

  static Future<Uint8List> decode(
      Uint8List data, dynamic decoderOptions) async {
    final backendDescription = _useWasm
        ? 'wasmUrl=${_wasmUrl ?? ''}, workerFetch=$_useWorkerFetch'
        : 'JavaScript fallback';
    if (!_useWorkerFetch && _handler == null) {
      warn('JpxImage.decode: handler is missing for $backendDescription.');
    }
    throw JpxError(
      'JPX decoding requires the OpenJPEG backend, which is not wired in this Dart port yet.',
    );
  }

  static void cleanup() {
    _handler = null;
  }

  static JpxImageProperties parseImageProperties(dynamic stream) {
    if (stream is Uint8List || stream is ByteBuffer) {
      stream = Stream(stream);
    }
    if (stream is! BaseStream) {
      throw JpxError('Invalid data format, must be a stream or typed data.');
    }

    var newByte = stream.getByte();
    while (newByte >= 0) {
      final oldByte = newByte;
      newByte = stream.getByte();
      if (newByte < 0) {
        break;
      }
      final code = (oldByte << 8) | newByte;

      if (code == 0xff51) {
        stream.skip(4);
        final xSize = stream.getInt32() & 0xffffffff;
        final ySize = stream.getInt32() & 0xffffffff;
        final xOffset = stream.getInt32() & 0xffffffff;
        final yOffset = stream.getInt32() & 0xffffffff;
        stream.skip(16);
        final componentsCount = stream.getUint16();
        return JpxImageProperties(
          width: xSize - xOffset,
          height: ySize - yOffset,
          bitsPerComponent: 8,
          componentsCount: componentsCount,
        );
      }
    }
    throw JpxError('No size marker found in JPX stream');
  }
}
