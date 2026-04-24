// Copyright 2026 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'base_stream.dart';
import 'decode_stream.dart';
import 'stream.dart';

class BrotliStream extends DecodeStream {
  bool _isAsync = true;

  BrotliStream(BaseStream str, int? maybeLength) : super(maybeLength ?? 0) {
    this.stream = str;
    this.dict = (str as dynamic).dict;
  }

  @override
  void readBlock([dynamic decoderOptions]) {
    // TODO: implement brotli decode natively or use a package
    // final bytes = stream!.getBytes();
    // const decodedData = BrotliDecode(new Int8Array(bytes.buffer, bytes.byteOffset, bytes.length));
    throw UnimplementedError('Brotli decoding is not yet implemented (Stub)');
    
    /*
    buffer = Uint8List.view(decodedData.buffer, decodedData.byteOffset, decodedData.length);
    bufferLength = buffer.length;
    isEof = true;
    */
  }

  Future<Uint8List> getImageData(int length, [dynamic decoderOptions]) async {
    final data = await asyncGetBytes();
    
    // if data was possible to be null, we would do: return getBytes(length);
    if (data.length <= length) {
      return data;
    }
    return data.sublist(0, length);
  }

  @override
  Future<Uint8List> asyncGetBytes() async {
    // TODO: implement DecompressionStream fallback logic if possible
    /*
    final { decompressed, compressed } = await this.asyncGetBytesFromDecompressionStream("brotli");
    if (decompressed != null) {
      return decompressed;
    }
    */
    
    _isAsync = false;
    final compressed = stream!.getBytes();
    stream = Stream(compressed, 0, compressed.length, dict);
    reset();
    return Uint8List(0);
  }

  @override
  bool get isAsync => _isAsync;
}
