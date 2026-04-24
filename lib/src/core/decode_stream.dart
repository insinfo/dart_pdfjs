// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'base_stream.dart';
import 'stream.dart';

final Uint8List _emptyBuffer = Uint8List(0);

/// Super classe para streams de decodificação.
class DecodeStream extends BaseStream {
  final int _rawMinBufferLength;
  int bufferLength = 0;
  bool isEof = false;
  Uint8List buffer = _emptyBuffer;
  int minBufferLength = 512;
  BaseStream? stream;
  dynamic dict;

  DecodeStream([int maybeMinBufferLength = 0])
      : _rawMinBufferLength = maybeMinBufferLength {
    pos = 0;
    if (maybeMinBufferLength > 0) {
      while (minBufferLength < maybeMinBufferLength) {
        minBufferLength *= 2;
      }
    }
  }

  @override
  bool get isEmpty {
    while (!isEof && bufferLength == 0) {
      readBlock();
    }
    return bufferLength == 0;
  }

  Uint8List ensureBuffer(int requested) {
    if (requested <= buffer.length) return buffer;
    int size = minBufferLength;
    while (size < requested) {
      size *= 2;
    }
    final buffer2 = Uint8List(size);
    buffer2.setAll(0, buffer);
    buffer = buffer2;
    return buffer2;
  }

  @override
  int getByte() {
    final p = pos;
    while (bufferLength <= p) {
      if (isEof) return -1;
      readBlock();
    }
    return buffer[pos++];
  }

  @override
  Uint8List getBytes([int? length, dynamic decoderOptions]) {
    final p = pos;
    int end;

    if (length != null && length > 0) {
      ensureBuffer(p + length);
      end = p + length;
      while (!isEof && bufferLength < end) {
        readBlock(decoderOptions);
      }
      if (end > bufferLength) end = bufferLength;
    } else {
      while (!isEof) {
        readBlock(decoderOptions);
      }
      end = bufferLength;
    }

    pos = end;
    return buffer.sublist(p, end);
  }

  /// Subclasses devem sobrescrever para decodificar dados.
  void readBlock([dynamic decoderOptions]) {
    // Implementado pelas subclasses
    isEof = true;
  }

  @override
  void reset() {
    pos = 0;
  }

  @override
  BaseStream makeSubStream(int start, [int? length, dynamic dict]) {
    if (length == null) {
      while (!isEof) {
        readBlock();
      }
    } else {
      final end = start + length;
      while (bufferLength <= end && !isEof) {
        readBlock();
      }
    }
    return Stream(buffer, start, length, dict);
  }

  @override
  List<BaseStream>? getBaseStreams() {
    return stream?.getBaseStreams();
  }
}

/// Stream que concatena múltiplos streams em sequência.
class StreamsSequenceStream extends DecodeStream {
  final List<BaseStream> streams;
  final void Function(dynamic reason, String? objId)? _onError;

  StreamsSequenceStream(List<BaseStream> inputStreams,
      [this._onError])
      : streams = inputStreams
            .where((s) => !s.isImageStream)
            .toList(),
        super(_calcLength(inputStreams));

  static int _calcLength(List<BaseStream> streams) {
    int len = 0;
    for (final s in streams) {
      if (s is DecodeStream) {
        len += s._rawMinBufferLength;
      } else {
        len += s.length;
      }
    }
    return len;
  }

  @override
  void readBlock([dynamic decoderOptions]) {
    if (streams.isEmpty) {
      isEof = true;
      return;
    }
    final stream = streams.removeAt(0);
    Uint8List chunk;
    try {
      chunk = stream.getBytes();
    } catch (reason) {
      if (_onError != null) {
        _onError(reason, (stream as dynamic).dict?.objId);
        return;
      }
      rethrow;
    }
    final bl = bufferLength;
    final newLength = bl + chunk.length;
    final buf = ensureBuffer(newLength);
    buf.setRange(bl, newLength, chunk);
    bufferLength = newLength;
  }

  @override
  List<BaseStream>? getBaseStreams() {
    final baseStreamsBuf = <BaseStream>[];
    for (final stream in streams) {
      final baseStreams = stream.getBaseStreams();
      if (baseStreams != null) {
        baseStreamsBuf.addAll(baseStreams);
      }
    }
    return baseStreamsBuf.isNotEmpty ? baseStreamsBuf : null;
  }
}
