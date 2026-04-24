// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

// dart format off
// @formatter:off
final Uint32List _sha256K = Uint32List.fromList([
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]);
// @formatter:on
// dart format on

int _rotr(int x, int n) {
  x &= 0xffffffff;
  return ((x >>> n) | (x << (32 - n))) & 0xffffffff;
}

int _ch(int x, int y, int z) {
  return ((x & y) ^ (~x & z)) & 0xffffffff;
}

int _maj(int x, int y, int z) {
  return ((x & y) ^ (x & z) ^ (y & z)) & 0xffffffff;
}

int _sigma(int x) {
  return _rotr(x, 2) ^ _rotr(x, 13) ^ _rotr(x, 22);
}

int _sigmaPrime(int x) {
  return _rotr(x, 6) ^ _rotr(x, 11) ^ _rotr(x, 25);
}

int _littleSigma(int x) {
  return _rotr(x, 7) ^ _rotr(x, 18) ^ ((x & 0xffffffff) >>> 3);
}

int _littleSigmaPrime(int x) {
  return _rotr(x, 17) ^ _rotr(x, 19) ^ ((x & 0xffffffff) >>> 10);
}

Uint8List calculateSHA256(Uint8List data, int offset, int length) {
  int h0 = 0x6a09e667,
      h1 = 0xbb67ae85,
      h2 = 0x3c6ef372,
      h3 = 0xa54ff53a,
      h4 = 0x510e527f,
      h5 = 0x9b05688c,
      h6 = 0x1f83d9ab,
      h7 = 0x5be0cd19;

  // pre-processing
  final paddedLength = ((length + 9 + 63) ~/ 64) * 64;
  final padded = Uint8List(paddedLength);
  int i, j;
  for (i = 0; i < length; ++i) {
    padded[i] = data[offset++];
  }
  padded[i++] = 0x80;
  final n = paddedLength - 8;
  if (i < n) {
    i = n;
  }
  i += 3;
  padded[i++] = (length >>> 29) & 0xff;
  padded[i++] = (length >> 21) & 0xff;
  padded[i++] = (length >> 13) & 0xff;
  padded[i++] = (length >> 5) & 0xff;
  padded[i++] = (length << 3) & 0xff;

  final w = Uint32List(64);
  final k = _sha256K;

  // for each 512 bit block
  for (i = 0; i < paddedLength;) {
    for (j = 0; j < 16; ++j) {
      w[j] = (padded[i] << 24) |
          (padded[i + 1] << 16) |
          (padded[i + 2] << 8) |
          padded[i + 3];
      i += 4;
    }

    for (j = 16; j < 64; ++j) {
      w[j] = (_littleSigmaPrime(w[j - 2]) +
              w[j - 7] +
              _littleSigma(w[j - 15]) +
              w[j - 16]) &
          0xffffffff;
    }
    int a = h0,
        b = h1,
        c = h2,
        d = h3,
        e = h4,
        f = h5,
        g = h6,
        h = h7,
        t1,
        t2;
    for (j = 0; j < 64; ++j) {
      t1 = (h + _sigmaPrime(e) + _ch(e, f, g) + k[j] + w[j]) & 0xffffffff;
      t2 = (_sigma(a) + _maj(a, b, c)) & 0xffffffff;
      h = g;
      g = f;
      f = e;
      e = (d + t1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xffffffff;
    }
    h0 = (h0 + a) & 0xffffffff;
    h1 = (h1 + b) & 0xffffffff;
    h2 = (h2 + c) & 0xffffffff;
    h3 = (h3 + d) & 0xffffffff;
    h4 = (h4 + e) & 0xffffffff;
    h5 = (h5 + f) & 0xffffffff;
    h6 = (h6 + g) & 0xffffffff;
    h7 = (h7 + h) & 0xffffffff;
  }

  // dart format off
  // @formatter:off
  return Uint8List.fromList([
    (h0 >> 24) & 0xFF, (h0 >> 16) & 0xFF, (h0 >> 8) & 0xFF, h0 & 0xFF,
    (h1 >> 24) & 0xFF, (h1 >> 16) & 0xFF, (h1 >> 8) & 0xFF, h1 & 0xFF,
    (h2 >> 24) & 0xFF, (h2 >> 16) & 0xFF, (h2 >> 8) & 0xFF, h2 & 0xFF,
    (h3 >> 24) & 0xFF, (h3 >> 16) & 0xFF, (h3 >> 8) & 0xFF, h3 & 0xFF,
    (h4 >> 24) & 0xFF, (h4 >> 16) & 0xFF, (h4 >> 8) & 0xFF, h4 & 0xFF,
    (h5 >> 24) & 0xFF, (h5 >> 16) & 0xFF, (h5 >> 8) & 0xFF, h5 & 0xFF,
    (h6 >> 24) & 0xFF, (h6 >> 16) & 0xFF, (h6 >> 8) & 0xFF, h6 & 0xFF,
    (h7 >> 24) & 0xFF, (h7 >> 16) & 0xFF, (h7 >> 8) & 0xFF, h7 & 0xFF
  ]);
  // @formatter:on
  // dart format on
}
