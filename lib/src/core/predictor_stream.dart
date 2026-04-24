// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import '../shared/util.dart';
import 'decode_stream.dart';
import 'base_stream.dart';
import 'primitives.dart';

/// Decodificador com predição (TIFF/PNG) para streams PDF.
class PredictorStream extends DecodeStream {
  int _predictor = 1;
  int _colors = 1;
  int _bits = 8;
  int _columns = 1;
  int _pixBytes = 0;
  int _rowBytes = 0;
  bool _usePng = false;

  PredictorStream(BaseStream str, [int? maybeLength, Dict? params])
      : super(maybeLength ?? 0) {
    if (params == null) {
      stream = str;
      return;
    }

    _predictor = (params.get('Predictor') as int?) ?? 1;
    if (_predictor <= 1) {
      stream = str;
      return;
    }
    if (_predictor != 2 && (_predictor < 10 || _predictor > 15)) {
      throw FormatError('Unsupported predictor: $_predictor');
    }

    _usePng = _predictor != 2;
    stream = str;
    dict = (str as dynamic).dict;

    _colors = (params.get('Colors') as int?) ?? 1;
    _bits = (params.get('BPC', 'BitsPerComponent') as int?) ?? 8;
    _columns = (params.get('Columns') as int?) ?? 1;

    _pixBytes = (_colors * _bits + 7) >> 3;
    _rowBytes = (_columns * _colors * _bits + 7) >> 3;
  }

  @override
  void readBlock([dynamic decoderOptions]) {
    if (_usePng) {
      _readBlockPng();
    } else {
      _readBlockTiff();
    }
  }

  void _readBlockTiff() {
    final rowBytes = _rowBytes;
    final bl = bufferLength;
    final buf = ensureBuffer(bl + rowBytes);
    final bits = _bits;
    final colors = _colors;

    final rawBytes = stream!.getBytes(rowBytes);
    if (rawBytes.isEmpty) {
      isEof = true;
      return;
    }

    int inbuf = 0, outbuf = 0;
    int inbits = 0, outbits = 0;
    int pos = bl;
    int i;

    if (bits == 1 && colors == 1) {
      for (i = 0; i < rowBytes; ++i) {
        int c = rawBytes[i] ^ inbuf;
        c ^= c >> 1;
        c ^= c >> 2;
        c ^= c >> 4;
        inbuf = (c & 1) << 7;
        buf[pos++] = c;
      }
    } else if (bits == 8) {
      for (i = 0; i < colors; ++i) {
        buf[pos++] = rawBytes[i];
      }
      for (; i < rowBytes; ++i) {
        buf[pos] = (buf[pos - colors] + rawBytes[i]) & 0xff;
        pos++;
      }
    } else if (bits == 16) {
      final bytesPerPixel = colors * 2;
      for (i = 0; i < bytesPerPixel; ++i) {
        buf[pos++] = rawBytes[i];
      }
      for (; i < rowBytes; i += 2) {
        final sum = ((rawBytes[i] & 0xff) << 8) +
            (rawBytes[i + 1] & 0xff) +
            ((buf[pos - bytesPerPixel] & 0xff) << 8) +
            (buf[pos - bytesPerPixel + 1] & 0xff);
        buf[pos++] = (sum >> 8) & 0xff;
        buf[pos++] = sum & 0xff;
      }
    } else {
      final compArray = Uint8List(colors + 1);
      final bitMask = (1 << bits) - 1;
      int j = 0, k = bl;
      final columns = _columns;
      for (i = 0; i < columns; ++i) {
        for (int kk = 0; kk < colors; ++kk) {
          if (inbits < bits) {
            inbuf = (inbuf << 8) | (rawBytes[j++] & 0xff);
            inbits += 8;
          }
          compArray[kk] = (compArray[kk] + (inbuf >> (inbits - bits))) & bitMask;
          inbits -= bits;
          outbuf = (outbuf << bits) | compArray[kk];
          outbits += bits;
          if (outbits >= 8) {
            buf[k++] = (outbuf >> (outbits - 8)) & 0xff;
            outbits -= 8;
          }
        }
      }
      if (outbits > 0) {
        buf[k++] = (outbuf << (8 - outbits)) + (inbuf & ((1 << (8 - outbits)) - 1));
      }
    }
    bufferLength += rowBytes;
  }

  void _readBlockPng() {
    final rowBytes = _rowBytes;
    final pixBytes = _pixBytes;

    final predictor = stream!.getByte();
    final rawBytes = stream!.getBytes(rowBytes);
    if (rawBytes.isEmpty) {
      isEof = true;
      return;
    }

    final bl = bufferLength;
    final buf = ensureBuffer(bl + rowBytes);

    Uint8List prevRow;
    if (bl >= rowBytes) {
      prevRow = buf.sublist(bl - rowBytes, bl);
    } else {
      prevRow = Uint8List(rowBytes);
    }

    int i;
    int j = bl;

    switch (predictor) {
      case 0:
        for (i = 0; i < rowBytes; ++i) {
          buf[j++] = rawBytes[i];
        }
        break;
      case 1:
        for (i = 0; i < pixBytes; ++i) {
          buf[j++] = rawBytes[i];
        }
        for (; i < rowBytes; ++i) {
          buf[j] = (buf[j - pixBytes] + rawBytes[i]) & 0xff;
          j++;
        }
        break;
      case 2:
        for (i = 0; i < rowBytes; ++i) {
          buf[j++] = (prevRow[i] + rawBytes[i]) & 0xff;
        }
        break;
      case 3:
        for (i = 0; i < pixBytes; ++i) {
          buf[j++] = ((prevRow[i] >> 1) + rawBytes[i]) & 0xff;
        }
        for (; i < rowBytes; ++i) {
          buf[j] = (((prevRow[i] + buf[j - pixBytes]) >> 1) + rawBytes[i]) & 0xff;
          j++;
        }
        break;
      case 4:
        for (i = 0; i < pixBytes; ++i) {
          buf[j++] = (prevRow[i] + rawBytes[i]) & 0xff;
        }
        for (; i < rowBytes; ++i) {
          final up = prevRow[i];
          final upLeft = prevRow[i - pixBytes];
          final left = buf[j - pixBytes];
          final p = left + up - upLeft;
          int pa = (p - left).abs();
          int pb = (p - up).abs();
          int pc = (p - upLeft).abs();
          final c = rawBytes[i];
          if (pa <= pb && pa <= pc) {
            buf[j++] = (left + c) & 0xff;
          } else if (pb <= pc) {
            buf[j++] = (up + c) & 0xff;
          } else {
            buf[j++] = (upLeft + c) & 0xff;
          }
        }
        break;
      default:
        throw FormatError('Unsupported predictor: $predictor');
    }
    bufferLength += rowBytes;
  }
}
