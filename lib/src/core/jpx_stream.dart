// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import '../shared/util.dart';
import 'base_stream.dart';
import 'decode_stream.dart';
import 'jpx.dart';

class JpxStream extends DecodeStream {
  int? maybeLength;
  dynamic params;

  JpxStream(BaseStream str, int? maybeLength, dynamic paramsArg) : super(maybeLength ?? 0) {
    this.stream = str;
    this.dict = (str as dynamic).dict;
    this.maybeLength = maybeLength;
    this.params = paramsArg;
  }

  Uint8List get bytes {
    return stream!.getBytes(maybeLength);
  }

  @override
  Uint8List ensureBuffer(int requested) {
    // No-op, since `this.readBlock` will always parse the entire image and
    // directly insert all of its data into `this.buffer`.
    return super.ensureBuffer(requested);
  }

  @override
  void readBlock([dynamic decoderOptions]) {
    unreachable('JpxStream.readBlock');
  }

  @override
  bool get isAsyncDecoder => true;

  Future<Uint8List> decodeImage([Uint8List? bytesArg, int? length, dynamic decoderOptions]) async {
    if (isEof) {
      return buffer;
    }
    bytesArg ??= bytes;
    buffer = await JpxImage.decode(bytesArg, decoderOptions);
    bufferLength = buffer.length;
    isEof = true;

    return buffer;
  }

  bool get canAsyncDecodeImageFromBuffer {
    return stream!.isAsync;
  }

  @override
  bool get isImageStream => true;
}
