// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'base_stream.dart';
import 'decode_stream.dart';
import 'primitives.dart';
import 'jbig2.dart';

class Jbig2Stream extends DecodeStream {
  int? maybeLength;
  dynamic params;

  Jbig2Stream(BaseStream str, int? maybeLength, dynamic paramsArg) : super(maybeLength ?? 0) {
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
    decodeImageFallback(null, null);
  }

  bool get isAsyncDecoder => true;
  bool get isImageStream => true;

  Future<Uint8List> decodeImage([Uint8List? bytesArg, int? length, dynamic decoderOptions]) async {
    if (isEof) {
      return buffer;
    }
    return decodeImageFallback(bytesArg, length);
  }

  Uint8List decodeImageFallback(Uint8List? bytesArg, int? length) {
    if (isEof) {
      return buffer;
    }
    
    bytesArg ??= bytes;
    final jbig2Image = Jbig2Image();

    final chunks = <Map<String, dynamic>>[];
    if (params is Dict) {
      final globalsStream = (params as Dict).get('JBIG2Globals');
      if (globalsStream is BaseStream) {
        final globals = globalsStream.getBytes();
        chunks.add({'data': globals, 'start': 0, 'end': globals.length});
      }
    }
    chunks.add({'data': bytesArg, 'start': 0, 'end': bytesArg.length});
    
    final data = jbig2Image.parseChunks(chunks);
    final dataLength = data.length;

    // JBIG2 had black as 1 and white as 0, inverting the colors
    for (int i = 0; i < dataLength; i++) {
      data[i] ^= 0xff;
    }
    buffer = data;
    bufferLength = dataLength;
    isEof = true;

    return buffer;
  }

  bool get canAsyncDecodeImageFromBuffer {
    return stream!.isAsync;
  }
}
