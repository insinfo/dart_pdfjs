// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;
import 'dart:typed_data';
import 'decode_stream.dart';
import 'base_stream.dart';

/// Estado interno do decodificador LZW.
class _LzwState {
  int earlyChange;
  int codeLength = 9;
  int nextCode = 258;
  int? prevCode;
  final Uint8List dictionaryValues;
  final Uint16List dictionaryLengths;
  final Uint16List dictionaryPrevCodes;
  final Uint8List currentSequence;
  int currentSequenceLength = 0;

  _LzwState(this.earlyChange)
      : dictionaryValues = Uint8List(4096),
        dictionaryLengths = Uint16List(4096),
        dictionaryPrevCodes = Uint16List(4096),
        currentSequence = Uint8List(4096) {
    for (int i = 0; i < 256; ++i) {
      dictionaryValues[i] = i;
      dictionaryLengths[i] = 1;
    }
  }
}

/// Decodificador LZW para streams PDF.
class LZWStream extends DecodeStream {
  int _cachedData = 0;
  int _bitsCached = 0;
  _LzwState? _lzwState;

  LZWStream(BaseStream str, [int? maybeLength, int earlyChange = 1])
      : super(maybeLength ?? 0) {
    stream = str;
    dict = (str as dynamic).dict;
    _lzwState = _LzwState(earlyChange);
  }

  int? _readBits(int n) {
    var bitsCached = _bitsCached;
    var cachedData = _cachedData;
    while (bitsCached < n) {
      final c = stream!.getByte();
      if (c == -1) {
        isEof = true;
        return null;
      }
      cachedData = (cachedData << 8) | c;
      bitsCached += 8;
    }
    bitsCached -= n;
    _bitsCached = bitsCached;
    _cachedData = cachedData;
    return (cachedData >> bitsCached) & ((1 << n) - 1);
  }

  @override
  void readBlock([dynamic decoderOptions]) {
    const blockSize = 512;
    const decodedSizeDelta = blockSize;
    var estimatedDecodedSize = blockSize * 2;

    final lzwState = _lzwState;
    if (lzwState == null) return;

    final earlyChange = lzwState.earlyChange;
    var nextCode = lzwState.nextCode;
    final dictionaryValues = lzwState.dictionaryValues;
    final dictionaryLengths = lzwState.dictionaryLengths;
    final dictionaryPrevCodes = lzwState.dictionaryPrevCodes;
    var codeLength = lzwState.codeLength;
    var prevCode = lzwState.prevCode;
    final currentSequence = lzwState.currentSequence;
    var currentSequenceLength = lzwState.currentSequenceLength;

    var decodedLength = 0;
    var currentBufferLength = bufferLength;
    var buf = ensureBuffer(bufferLength + estimatedDecodedSize);

    for (int i = 0; i < blockSize; i++) {
      final code = _readBits(codeLength);
      if (code == null) break;
      final hasPrev = currentSequenceLength > 0;

      if (code < 256) {
        currentSequence[0] = code;
        currentSequenceLength = 1;
      } else if (code >= 258) {
        if (code < nextCode) {
          currentSequenceLength = dictionaryLengths[code];
          var q = code;
          for (int j = currentSequenceLength - 1; j >= 0; j--) {
            currentSequence[j] = dictionaryValues[q];
            q = dictionaryPrevCodes[q];
          }
        } else {
          currentSequence[currentSequenceLength++] = currentSequence[0];
        }
      } else if (code == 256) {
        codeLength = 9;
        nextCode = 258;
        currentSequenceLength = 0;
        continue;
      } else {
        isEof = true;
        _lzwState = null;
        break;
      }

      if (hasPrev && prevCode != null) {
        dictionaryPrevCodes[nextCode] = prevCode;
        dictionaryLengths[nextCode] = dictionaryLengths[prevCode] + 1;
        dictionaryValues[nextCode] = currentSequence[0];
        nextCode++;
        final nec = nextCode + earlyChange;
        codeLength = (nec & (nec - 1)) != 0
            ? codeLength
            : math.min(
                (math.log(nec) / 0.6931471805599453 + 1).toInt(),
                12,
              );
      }
      prevCode = code;

      decodedLength += currentSequenceLength;
      if (estimatedDecodedSize < decodedLength) {
        do {
          estimatedDecodedSize += decodedSizeDelta;
        } while (estimatedDecodedSize < decodedLength);
        buf = ensureBuffer(bufferLength + estimatedDecodedSize);
      }
      for (int j = 0; j < currentSequenceLength; j++) {
        buf[currentBufferLength++] = currentSequence[j];
      }
    }

    lzwState.nextCode = nextCode;
    lzwState.codeLength = codeLength;
    lzwState.prevCode = prevCode;
    lzwState.currentSequenceLength = currentSequenceLength;
    bufferLength = currentBufferLength;
  }
}
