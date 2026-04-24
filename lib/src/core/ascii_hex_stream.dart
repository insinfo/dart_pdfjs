// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.


import 'decode_stream.dart';
import 'base_stream.dart';

/// Decodificador de stream ASCII Hexadecimal.
class AsciiHexStream extends DecodeStream {
  int _firstDigit = -1;

  AsciiHexStream(BaseStream str, [int? maybeLength])
      : super(maybeLength != null ? (maybeLength * 0.5).toInt() : 0) {
    stream = str;
    dict = (str as dynamic).dict;
  }

  @override
  void readBlock([dynamic decoderOptions]) {
    const upstreamBlockSize = 8000;
    final bytes = stream!.getBytes(upstreamBlockSize);
    if (bytes.isEmpty) {
      isEof = true;
      return;
    }

    final maxDecodeLength = (bytes.length + 1) >> 1;
    final buf = ensureBuffer(bufferLength + maxDecodeLength);
    var bl = bufferLength;
    var firstDigit = _firstDigit;

    for (final ch in bytes) {
      int digit;
      if (ch >= 0x30 && ch <= 0x39) {
        digit = ch & 0x0f;
      } else if ((ch >= 0x41 && ch <= 0x46) || (ch >= 0x61 && ch <= 0x66)) {
        digit = (ch & 0x0f) + 9;
      } else if (ch == 0x3e) {
        // '>'
        isEof = true;
        break;
      } else {
        continue; // whitespace
      }
      if (firstDigit < 0) {
        firstDigit = digit;
      } else {
        buf[bl++] = (firstDigit << 4) | digit;
        firstDigit = -1;
      }
    }
    if (firstDigit >= 0 && isEof) {
      buf[bl++] = firstDigit << 4;
      firstDigit = -1;
    }
    _firstDigit = firstDigit;
    bufferLength = bl;
  }
}
