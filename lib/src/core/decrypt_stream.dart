// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'decode_stream.dart';
import 'base_stream.dart';

const int _chunkSize = 512;

/// Stream de decriptografia para conteúdo PDF cifrado.
class DecryptStream extends DecodeStream {
  final Uint8List Function(Uint8List data, bool finalize) _decrypt;
  Uint8List? _nextChunk;
  bool _initialized = false;

  DecryptStream(BaseStream str, int? maybeLength, this._decrypt)
      : super(maybeLength ?? 0) {
    stream = str;
    dict = (str as dynamic).dict;
  }

  @override
  void readBlock([dynamic decoderOptions]) {
    Uint8List? chunk;
    if (_initialized) {
      chunk = _nextChunk;
    } else {
      chunk = stream!.getBytes(_chunkSize);
      _initialized = true;
    }
    if (chunk == null || chunk.isEmpty) {
      isEof = true;
      return;
    }
    _nextChunk = stream!.getBytes(_chunkSize);
    final hasMoreData = _nextChunk != null && _nextChunk!.isNotEmpty;

    chunk = _decrypt(chunk, !hasMoreData);

    final bl = bufferLength;
    final newLength = bl + chunk.length;
    final buf = ensureBuffer(newLength);
    buf.setRange(bl, newLength, chunk);
    bufferLength = newLength;
  }

  @override
  BaseStream getOriginalStream() => this;
}
