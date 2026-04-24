// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

class _Word64 {
  int high = 0;
  int low = 0;

  _Word64(int highInteger, int lowInteger) {
    high = highInteger & 0xffffffff;
    low = lowInteger & 0xffffffff;
  }

  void and(_Word64 word) {
    high &= word.high;
    low &= word.low;
  }

  void xor(_Word64 word) {
    high ^= word.high;
    low ^= word.low;
  }

  void shiftRight(int places) {
    if (places >= 32) {
      low = (high >>> (places - 32)) & 0xffffffff;
      high = 0;
    } else {
      low = ((low >>> places) | (high << (32 - places))) & 0xffffffff;
      high = (high >>> places) & 0xffffffff;
    }
  }

  void rotateRight(int places) {
    int _low, _high;
    if ((places & 32) != 0) {
      _high = low;
      _low = high;
    } else {
      _low = low;
      _high = high;
    }
    places &= 31;
    low = ((_low >>> places) | (_high << (32 - places))) & 0xffffffff;
    high = ((_high >>> places) | (_low << (32 - places))) & 0xffffffff;
  }

  void not() {
    high = (~high) & 0xffffffff;
    low = (~low) & 0xffffffff;
  }

  void add(_Word64 word) {
    // Para garantir precisão sem erro no Dart Web/JS, emulamos soma de 32 bits
    // que nem em JS original
    final int lowAdd = (low >>> 0) + (word.low >>> 0);
    int highAdd = (high >>> 0) + (word.high >>> 0);
    // Emulando 32 bits uint limite
    if (lowAdd > 0xffffffff) {
      highAdd += 1;
    }
    low = lowAdd & 0xffffffff;
    high = highAdd & 0xffffffff;
  }

  void copyTo(Uint8List bytes, int offset) {
    bytes[offset] = (high >>> 24) & 0xff;
    bytes[offset + 1] = (high >> 16) & 0xff;
    bytes[offset + 2] = (high >> 8) & 0xff;
    bytes[offset + 3] = high & 0xff;
    bytes[offset + 4] = (low >>> 24) & 0xff;
    bytes[offset + 5] = (low >> 16) & 0xff;
    bytes[offset + 6] = (low >> 8) & 0xff;
    bytes[offset + 7] = low & 0xff;
  }

  void assign(_Word64 word) {
    high = word.high;
    low = word.low;
  }
}

// dart format off
// @formatter:off
final List<_Word64> _shaK = [
  _Word64(0x428a2f98, 0xd728ae22), _Word64(0x71374491, 0x23ef65cd),
  _Word64(0xb5c0fbcf, 0xec4d3b2f), _Word64(0xe9b5dba5, 0x8189dbbc),
  _Word64(0x3956c25b, 0xf348b538), _Word64(0x59f111f1, 0xb605d019),
  _Word64(0x923f82a4, 0xaf194f9b), _Word64(0xab1c5ed5, 0xda6d8118),
  _Word64(0xd807aa98, 0xa3030242), _Word64(0x12835b01, 0x45706fbe),
  _Word64(0x243185be, 0x4ee4b28c), _Word64(0x550c7dc3, 0xd5ffb4e2),
  _Word64(0x72be5d74, 0xf27b896f), _Word64(0x80deb1fe, 0x3b1696b1),
  _Word64(0x9bdc06a7, 0x25c71235), _Word64(0xc19bf174, 0xcf692694),
  _Word64(0xe49b69c1, 0x9ef14ad2), _Word64(0xefbe4786, 0x384f25e3),
  _Word64(0x0fc19dc6, 0x8b8cd5b5), _Word64(0x240ca1cc, 0x77ac9c65),
  _Word64(0x2de92c6f, 0x592b0275), _Word64(0x4a7484aa, 0x6ea6e483),
  _Word64(0x5cb0a9dc, 0xbd41fbd4), _Word64(0x76f988da, 0x831153b5),
  _Word64(0x983e5152, 0xee66dfab), _Word64(0xa831c66d, 0x2db43210),
  _Word64(0xb00327c8, 0x98fb213f), _Word64(0xbf597fc7, 0xbeef0ee4),
  _Word64(0xc6e00bf3, 0x3da88fc2), _Word64(0xd5a79147, 0x930aa725),
  _Word64(0x06ca6351, 0xe003826f), _Word64(0x14292967, 0x0a0e6e70),
  _Word64(0x27b70a85, 0x46d22ffc), _Word64(0x2e1b2138, 0x5c26c926),
  _Word64(0x4d2c6dfc, 0x5ac42aed), _Word64(0x53380d13, 0x9d95b3df),
  _Word64(0x650a7354, 0x8baf63de), _Word64(0x766a0abb, 0x3c77b2a8),
  _Word64(0x81c2c92e, 0x47edaee6), _Word64(0x92722c85, 0x1482353b),
  _Word64(0xa2bfe8a1, 0x4cf10364), _Word64(0xa81a664b, 0xbc423001),
  _Word64(0xc24b8b70, 0xd0f89791), _Word64(0xc76c51a3, 0x0654be30),
  _Word64(0xd192e819, 0xd6ef5218), _Word64(0xd6990624, 0x5565a910),
  _Word64(0xf40e3585, 0x5771202a), _Word64(0x106aa070, 0x32bbd1b8),
  _Word64(0x19a4c116, 0xb8d2d0c8), _Word64(0x1e376c08, 0x5141ab53),
  _Word64(0x2748774c, 0xdf8eeb99), _Word64(0x34b0bcb5, 0xe19b48a8),
  _Word64(0x391c0cb3, 0xc5c95a63), _Word64(0x4ed8aa4a, 0xe3418acb),
  _Word64(0x5b9cca4f, 0x7763e373), _Word64(0x682e6ff3, 0xd6b2b8a3),
  _Word64(0x748f82ee, 0x5defb2fc), _Word64(0x78a5636f, 0x43172f60),
  _Word64(0x84c87814, 0xa1f0ab72), _Word64(0x8cc70208, 0x1a6439ec),
  _Word64(0x90befffa, 0x23631e28), _Word64(0xa4506ceb, 0xde82bde9),
  _Word64(0xbef9a3f7, 0xb2c67915), _Word64(0xc67178f2, 0xe372532b),
  _Word64(0xca273ece, 0xea26619c), _Word64(0xd186b8c7, 0x21c0c207),
  _Word64(0xeada7dd6, 0xcde0eb1e), _Word64(0xf57d4f7f, 0xee6ed178),
  _Word64(0x06f067aa, 0x72176fba), _Word64(0x0a637dc5, 0xa2c898a6),
  _Word64(0x113f9804, 0xbef90dae), _Word64(0x1b710b35, 0x131c471b),
  _Word64(0x28db77f5, 0x23047d84), _Word64(0x32caab7b, 0x40c72493),
  _Word64(0x3c9ebe0a, 0x15c9bebc), _Word64(0x431d67c4, 0x9c100d4c),
  _Word64(0x4cc5d4be, 0xcb3e42b6), _Word64(0x597f299c, 0xfc657e2a),
  _Word64(0x5fcb6fab, 0x3ad6faec), _Word64(0x6c44198c, 0x4a475817),
];
// @formatter:on
// dart format on

void _ch(_Word64 result, _Word64 x, _Word64 y, _Word64 z, _Word64 tmp) {
  result.assign(x);
  result.and(y);
  tmp.assign(x);
  tmp.not();
  tmp.and(z);
  result.xor(tmp);
}

void _maj(_Word64 result, _Word64 x, _Word64 y, _Word64 z, _Word64 tmp) {
  result.assign(x);
  result.and(y);
  tmp.assign(x);
  tmp.and(z);
  result.xor(tmp);
  tmp.assign(y);
  tmp.and(z);
  result.xor(tmp);
}

void _sigma(_Word64 result, _Word64 x, _Word64 tmp) {
  result.assign(x);
  result.rotateRight(28);
  tmp.assign(x);
  tmp.rotateRight(34);
  result.xor(tmp);
  tmp.assign(x);
  tmp.rotateRight(39);
  result.xor(tmp);
}

void _sigmaPrime(_Word64 result, _Word64 x, _Word64 tmp) {
  result.assign(x);
  result.rotateRight(14);
  tmp.assign(x);
  tmp.rotateRight(18);
  result.xor(tmp);
  tmp.assign(x);
  tmp.rotateRight(41);
  result.xor(tmp);
}

void _littleSigma(_Word64 result, _Word64 x, _Word64 tmp) {
  result.assign(x);
  result.rotateRight(1);
  tmp.assign(x);
  tmp.rotateRight(8);
  result.xor(tmp);
  tmp.assign(x);
  tmp.shiftRight(7);
  result.xor(tmp);
}

void _littleSigmaPrime(_Word64 result, _Word64 x, _Word64 tmp) {
  result.assign(x);
  result.rotateRight(19);
  tmp.assign(x);
  tmp.rotateRight(61);
  result.xor(tmp);
  tmp.assign(x);
  tmp.shiftRight(6);
  result.xor(tmp);
}

Uint8List calculateSHA512(Uint8List data, int offset, int length, [bool mode384 = false]) {
  late _Word64 h0, h1, h2, h3, h4, h5, h6, h7;
  if (!mode384) {
    h0 = _Word64(0x6a09e667, 0xf3bcc908);
    h1 = _Word64(0xbb67ae85, 0x84caa73b);
    h2 = _Word64(0x3c6ef372, 0xfe94f82b);
    h3 = _Word64(0xa54ff53a, 0x5f1d36f1);
    h4 = _Word64(0x510e527f, 0xade682d1);
    h5 = _Word64(0x9b05688c, 0x2b3e6c1f);
    h6 = _Word64(0x1f83d9ab, 0xfb41bd6b);
    h7 = _Word64(0x5be0cd19, 0x137e2179);
  } else {
    h0 = _Word64(0xcbbb9d5d, 0xc1059ed8);
    h1 = _Word64(0x629a292a, 0x367cd507);
    h2 = _Word64(0x9159015a, 0x3070dd17);
    h3 = _Word64(0x152fecd8, 0xf70e5939);
    h4 = _Word64(0x67332667, 0xffc00b31);
    h5 = _Word64(0x8eb44a87, 0x68581511);
    h6 = _Word64(0xdb0c2e0d, 0x64f98fa7);
    h7 = _Word64(0x47b5481d, 0xbefa4fa4);
  }

  // pre-processing
  final paddedLength = ((length + 17 + 127) ~/ 128) * 128;
  final padded = Uint8List(paddedLength);
  int i, j;
  for (i = 0; i < length; ++i) {
    padded[i] = data[offset++];
  }
  padded[i++] = 0x80;
  final n = paddedLength - 16;
  if (i < n) {
    i = n;
  }
  i += 11;
  padded[i++] = (length >>> 29) & 0xff;
  padded[i++] = (length >> 21) & 0xff;
  padded[i++] = (length >> 13) & 0xff;
  padded[i++] = (length >> 5) & 0xff;
  padded[i++] = (length << 3) & 0xff;

  final w = List<_Word64>.generate(80, (_) => _Word64(0, 0), growable: false);
  final k = _shaK;

  var a = _Word64(0, 0), b = _Word64(0, 0), c = _Word64(0, 0);
  var d = _Word64(0, 0), e = _Word64(0, 0), f = _Word64(0, 0);
  var g = _Word64(0, 0), h = _Word64(0, 0);
  final t1 = _Word64(0, 0), t2 = _Word64(0, 0);
  final tmp1 = _Word64(0, 0), tmp2 = _Word64(0, 0);
  late _Word64 tmp3;

  for (i = 0; i < paddedLength;) {
    for (j = 0; j < 16; ++j) {
      w[j].high = (padded[i] << 24) |
          (padded[i + 1] << 16) |
          (padded[i + 2] << 8) |
          padded[i + 3];
      w[j].low = (padded[i + 4] << 24) |
          (padded[i + 5] << 16) |
          (padded[i + 6] << 8) |
          padded[i + 7];
      i += 8;
    }
    for (j = 16; j < 80; ++j) {
      tmp3 = w[j];
      _littleSigmaPrime(tmp3, w[j - 2], tmp2);
      tmp3.add(w[j - 7]);
      _littleSigma(tmp1, w[j - 15], tmp2);
      tmp3.add(tmp1);
      tmp3.add(w[j - 16]);
    }

    a.assign(h0);
    b.assign(h1);
    c.assign(h2);
    d.assign(h3);
    e.assign(h4);
    f.assign(h5);
    g.assign(h6);
    h.assign(h7);

    for (j = 0; j < 80; ++j) {
      t1.assign(h);
      _sigmaPrime(tmp1, e, tmp2);
      t1.add(tmp1);
      _ch(tmp1, e, f, g, tmp2);
      t1.add(tmp1);
      t1.add(k[j]);
      t1.add(w[j]);

      _sigma(t2, a, tmp2);
      _maj(tmp1, a, b, c, tmp2);
      t2.add(tmp1);

      tmp3 = h;
      h = g;
      g = f;
      f = e;
      d.add(t1);
      e = d;
      d = c;
      c = b;
      b = a;
      tmp3.assign(t1);
      tmp3.add(t2);
      a = tmp3;
    }
    h0.add(a);
    h1.add(b);
    h2.add(c);
    h3.add(d);
    h4.add(e);
    h5.add(f);
    h6.add(g);
    h7.add(h);
  }

  Uint8List result;
  if (!mode384) {
    result = Uint8List(64);
    h0.copyTo(result, 0);
    h1.copyTo(result, 8);
    h2.copyTo(result, 16);
    h3.copyTo(result, 24);
    h4.copyTo(result, 32);
    h5.copyTo(result, 40);
    h6.copyTo(result, 48);
    h7.copyTo(result, 56);
  } else {
    result = Uint8List(48);
    h0.copyTo(result, 0);
    h1.copyTo(result, 8);
    h2.copyTo(result, 16);
    h3.copyTo(result, 24);
    h4.copyTo(result, 32);
    h5.copyTo(result, 40);
  }
  return result;
}

Uint8List calculateSHA384(Uint8List data, int offset, int length) {
  return calculateSHA512(data, offset, length, true);
}
