// Copyright 2014 Opera Software ASA (original JS)
// Ported to Dart, 2026. Apache License 2.0.
// Based on https://code.google.com/p/smhasher/wiki/MurmurHash3

import 'dart:typed_data';

const int _seed = 0xc3d2e1f0;
const int _maskHigh = 0xffff0000;
const int _maskLow = 0xffff;

/// Implementação do MurmurHash3 de 64 bits.
class MurmurHash3_64 {
  int h1;
  int h2;

  MurmurHash3_64([int? seed])
      : h1 = seed ?? _seed,
        h2 = seed ?? _seed;

  /// Alimenta o hash com [input] (String ou Uint8List).
  void update(dynamic input) {
    Uint8List data;
    int length;

    if (input is String) {
      final tmp = Uint8List(input.length * 2);
      length = 0;
      for (int i = 0; i < input.length; i++) {
        final code = input.codeUnitAt(i);
        if (code <= 0xff) {
          tmp[length++] = code;
        } else {
          tmp[length++] = code >> 8;
          tmp[length++] = code & 0xff;
        }
      }
      data = tmp.sublist(0, length);
    } else if (input is Uint8List) {
      data = Uint8List.fromList(input);
      length = data.length;
    } else {
      throw ArgumentError('Invalid data format, must be a String or Uint8List.');
    }

    final blockCounts = length >> 2;
    final tailLength = length - blockCounts * 4;
    final dataUint32 = data.buffer.asUint32List(0, blockCounts);

    int k1 = 0, k2 = 0;
    int lh1 = h1, lh2 = h2;
    const c1 = 0xcc9e2d51, c2 = 0x1b873593;
    const c1Low = c1 & _maskLow, c2Low = c2 & _maskLow;

    for (int i = 0; i < blockCounts; i++) {
      if ((i & 1) != 0) {
        k1 = dataUint32[i];
        k1 = ((k1 * c1) & _maskHigh) | ((k1 * c1Low) & _maskLow);
        k1 = ((k1 << 15) | (k1 >> 17)) & 0xffffffff;
        k1 = ((k1 * c2) & _maskHigh) | ((k1 * c2Low) & _maskLow);
        lh1 ^= k1;
        lh1 = ((lh1 << 13) | (lh1 >> 19)) & 0xffffffff;
        lh1 = (lh1 * 5 + 0xe6546b64) & 0xffffffff;
      } else {
        k2 = dataUint32[i];
        k2 = ((k2 * c1) & _maskHigh) | ((k2 * c1Low) & _maskLow);
        k2 = ((k2 << 15) | (k2 >> 17)) & 0xffffffff;
        k2 = ((k2 * c2) & _maskHigh) | ((k2 * c2Low) & _maskLow);
        lh2 ^= k2;
        lh2 = ((lh2 << 13) | (lh2 >> 19)) & 0xffffffff;
        lh2 = (lh2 * 5 + 0xe6546b64) & 0xffffffff;
      }
    }

    k1 = 0;
    final base = blockCounts * 4;
    if (tailLength >= 3) k1 ^= data[base + 2] << 16;
    if (tailLength >= 2) k1 ^= data[base + 1] << 8;
    if (tailLength >= 1) {
      k1 ^= data[base];
      k1 = ((k1 * c1) & _maskHigh) | ((k1 * c1Low) & _maskLow);
      k1 = ((k1 << 15) | (k1 >> 17)) & 0xffffffff;
      k1 = ((k1 * c2) & _maskHigh) | ((k1 * c2Low) & _maskLow);
      if ((blockCounts & 1) != 0) {
        lh1 ^= k1;
      } else {
        lh2 ^= k1;
      }
    }

    h1 = lh1;
    h2 = lh2;
  }

  /// Retorna o hash como string hexadecimal de 16 caracteres.
  String hexdigest() {
    int lh1 = h1, lh2 = h2;
    lh1 ^= (lh2 >> 1) & 0x7fffffff;
    lh1 = ((lh1 * 0xed558ccd) & _maskHigh) | ((lh1 * 0x8ccd) & _maskLow);
    lh2 = ((lh2 * 0xff51afd7) & _maskHigh) |
        (((((lh2 << 16) | ((lh1 >> 16) & 0xffff)) * 0xafd7ed55) & _maskHigh) >> 16);
    lh1 ^= (lh2 >> 1) & 0x7fffffff;
    lh1 = ((lh1 * 0x1a85ec53) & _maskHigh) | ((lh1 * 0xec53) & _maskLow);
    lh2 = ((lh2 * 0xc4ceb9fe) & _maskHigh) |
        (((((lh2 << 16) | ((lh1 >> 16) & 0xffff)) * 0xb9fe1a85) & _maskHigh) >> 16);
    lh1 ^= (lh2 >> 1) & 0x7fffffff;

    return '${(lh1 & 0xffffffff).toRadixString(16).padLeft(8, '0')}'
        '${(lh2 & 0xffffffff).toRadixString(16).padLeft(8, '0')}';
  }
}
