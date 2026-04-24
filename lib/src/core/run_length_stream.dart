// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.


import 'decode_stream.dart';
import 'base_stream.dart';

/// Decodificador RunLength para streams PDF.
class RunLengthStream extends DecodeStream {
  RunLengthStream(BaseStream str, [int? maybeLength])
      : super(maybeLength ?? 0) {
    stream = str;
    dict = (str as dynamic).dict;
  }

  @override
  void readBlock([dynamic decoderOptions]) {
    final repeatHeader = stream!.getBytes(2);
    if (repeatHeader.isEmpty || repeatHeader.length < 2 || repeatHeader[0] == 128) {
      isEof = true;
      return;
    }

    var bl = bufferLength;
    int n = repeatHeader[0];

    if (n < 128) {
      final buf = ensureBuffer(bl + n + 1);
      buf[bl++] = repeatHeader[1];
      if (n > 0) {
        final source = stream!.getBytes(n);
        buf.setRange(bl, bl + source.length, source);
        bl += n;
      }
    } else {
      n = 257 - n;
      final buf = ensureBuffer(bl + n + 1);
      buf.fillRange(bl, bl + n, repeatHeader[1]);
      bl += n;
    }
    bufferLength = bl;
  }
}
