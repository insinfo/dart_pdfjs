// Copyright 2014 Opera Software ASA
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

const int _seed = 0xc3d2e1f0;
// Workaround for missing math precision in JS (not necessarily needed in Dart, but kept for exact behavior)
const int _maskHigh = 0xffff0000;
const int _maskLow = 0xffff;

class MurmurHash3_64 {
  late int h1;
  late int h2;

  MurmurHash3_64([int? seed]) {
    h1 = seed != null ? seed & 0xffffffff : _seed;
    h2 = seed != null ? seed & 0xffffffff : _seed;
  }

  void update(dynamic input) {
    Uint8List data;
    int length;

    if (input is String) {
      data = Uint8List(input.length * 2);
      length = 0;
      for (int i = 0, ii = input.length; i < ii; i++) {
        final code = input.codeUnitAt(i);
        if (code <= 0xff) {
          data[length++] = code;
        } else {
          data[length++] = code >>> 8;
          data[length++] = code & 0xff;
        }
      }
    } else if (input is Uint8List) {
      data = Uint8List.fromList(input);
      length = data.lengthInBytes;
    } else {
      throw ArgumentError('Invalid data format, must be a String or Uint8List.');
    }

    final int blockCounts = length >> 2;
    final int tailLength = length - blockCounts * 4;
    // We don't care about endianness here.
    final dataUint32 = Uint32List.view(data.buffer, data.offsetInBytes, blockCounts);
    int k1 = 0, k2 = 0;
    int currentH1 = h1, currentH2 = h2;
    const int c1 = 0xcc9e2d51;
    const int c2 = 0x1b873593;
    const int c1Low = c1 & _maskLow;
    const int c2Low = c2 & _maskLow;

    for (int i = 0; i < blockCounts; i++) {
      if ((i & 1) != 0) {
        k1 = dataUint32[i];
        k1 = ((k1 * c1) & _maskHigh) | ((k1 * c1Low) & _maskLow);
        k1 = (k1 << 15) | (k1 >>> 17);
        k1 = ((k1 * c2) & _maskHigh) | ((k1 * c2Low) & _maskLow);
        currentH1 ^= k1;
        currentH1 = (currentH1 << 13) | (currentH1 >>> 19);
        currentH1 = (currentH1 * 5 + 0xe6546b64) & 0xffffffff;
      } else {
        k2 = dataUint32[i];
        k2 = ((k2 * c1) & _maskHigh) | ((k2 * c1Low) & _maskLow);
        k2 = (k2 << 15) | (k2 >>> 17);
        k2 = ((k2 * c2) & _maskHigh) | ((k2 * c2Low) & _maskLow);
        currentH2 ^= k2;
        currentH2 = (currentH2 << 13) | (currentH2 >>> 19);
        currentH2 = (currentH2 * 5 + 0xe6546b64) & 0xffffffff;
      }
    }

    k1 = 0;

    switch (tailLength) {
      case 3:
        k1 ^= data[blockCounts * 4 + 2] << 16;
        continue case2;
      case2:
      case 2:
        k1 ^= data[blockCounts * 4 + 1] << 8;
        continue case1;
      case1:
      case 1:
        k1 ^= data[blockCounts * 4];
        k1 = ((k1 * c1) & _maskHigh) | ((k1 * c1Low) & _maskLow);
        k1 = ((k1 << 15) | (k1 >>> 17)) & 0xffffffff;
        k1 = ((k1 * c2) & _maskHigh) | ((k1 * c2Low) & _maskLow);
        if ((blockCounts & 1) != 0) {
          currentH1 ^= k1;
        } else {
          currentH2 ^= k1;
        }
    }

    h1 = currentH1 & 0xffffffff;
    h2 = currentH2 & 0xffffffff;
  }

  String hexdigest() {
    int currentH1 = h1, currentH2 = h2;

    currentH1 ^= currentH2 >>> 1;
    currentH1 = ((currentH1 * 0xed558ccd) & _maskHigh) | ((currentH1 * 0x8ccd) & _maskLow);
    currentH2 = ((currentH2 * 0xff51afd7) & _maskHigh) |
        (((((currentH2 << 16) | (currentH1 >>> 16)) * 0xafd7ed55) & _maskHigh) >>> 16);
    currentH1 ^= currentH2 >>> 1;
    currentH1 = ((currentH1 * 0x1a85ec53) & _maskHigh) | ((currentH1 * 0xec53) & _maskLow);
    currentH2 = ((currentH2 * 0xc4ceb9fe) & _maskHigh) |
        (((((currentH2 << 16) | (currentH1 >>> 16)) * 0xb9fe1a85) & _maskHigh) >>> 16);
    currentH1 ^= currentH2 >>> 1;

    currentH1 = currentH1 >>> 0; // force unsigned string behavior
    currentH2 = currentH2 >>> 0;
    
    return currentH1.toRadixString(16).padLeft(8, '0') +
        currentH2.toRadixString(16).padLeft(8, '0');
  }
}
