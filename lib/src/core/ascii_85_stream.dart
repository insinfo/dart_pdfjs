// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'decode_stream.dart';
import 'base_stream.dart';
import 'core_utils.dart';

/// Decodificador de stream ASCII85 (Base-85).
class Ascii85Stream extends DecodeStream {
  final Uint8List _input = Uint8List(5);

  Ascii85Stream(BaseStream str, [int? maybeLength])
      : super(maybeLength != null ? (maybeLength * 0.8).toInt() : 0) {
    stream = str;
    dict = (str as dynamic).dict;
  }

  @override
  void readBlock([dynamic decoderOptions]) {
    const tildaChar = 0x7e; // '~'
    const zLowerChar = 0x7a; // 'z'
    const eofVal = -1;

    final str = stream!;
    int c = str.getByte();
    while (isWhiteSpace(c)) {
      c = str.getByte();
    }

    if (c == eofVal || c == tildaChar) {
      isEof = true;
      return;
    }

    final bl = bufferLength;
    int i;

    if (c == zLowerChar) {
      final buf = ensureBuffer(bl + 4);
      buf.fillRange(bl, bl + 4, 0);
      bufferLength += 4;
    } else {
      final input = _input;
      input[0] = c;
      for (i = 1; i < 5; ++i) {
        c = str.getByte();
        while (isWhiteSpace(c)) {
          c = str.getByte();
        }
        input[i] = c;
        if (c == eofVal || c == tildaChar) break;
      }
      final buf = ensureBuffer(bl + i - 1);
      bufferLength += i - 1;

      // partial ending
      if (i < 5) {
        input.fillRange(i, 5, 0x21 + 84);
        isEof = true;
      }
      int t = 0;
      for (i = 0; i < 5; ++i) {
        t = t * 85 + (input[i] - 0x21);
      }
      for (i = 3; i >= 0; --i) {
        buf[bl + i] = t & 0xff;
        t >>= 8;
      }
    }
  }
}
