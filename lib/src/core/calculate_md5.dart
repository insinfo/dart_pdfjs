// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

// dart format off
// @formatter:off
final Uint8List _md5R = Uint8List.fromList([
  7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14,
  20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16,
  23, 4, 11, 16, 23, 4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10,
  15, 21, 6, 10, 15, 21,
]);

final Int32List _md5K = Int32List.fromList([
  -680876936, -389564586, 606105819, -1044525330, -176418897, 1200080426,
  -1473231341, -45705983, 1770035416, -1958414417, -42063, -1990404162,
  1804603682, -40341101, -1502002290, 1236535329, -165796510, -1069501632,
  643717713, -373897302, -701558691, 38016083, -660478335, -405537848,
  568446438, -1019803690, -187363961, 1163531501, -1444681467, -51403784,
  1735328473, -1926607734, -378558, -2022574463, 1839030562, -35309556,
  -1530992060, 1272893353, -155497632, -1094730640, 681279174, -358537222,
  -722521979, 76029189, -640364487, -421815835, 530742520, -995338651,
  -198630844, 1126891415, -1416354905, -57434055, 1700485571, -1894986606,
  -1051523, -2054922799, 1873313359, -30611744, -1560198380, 1309151649,
  -145523070, -1120210379, 718787259, -343485551,
]);
// @formatter:on
// dart format on

/// Calcula o hash MD5 (usado por PDFs antigos).
Uint8List calculateMD5(Uint8List data, int offset, int length) {
  int h0 = 1732584193, h1 = -271733879, h2 = -1732584194, h3 = 271733878;

  // pré-processamento
  final int paddedLength = (length + 72) & ~63; // data + 9 extra bytes
  final Uint8List padded = Uint8List(paddedLength);
  int i, j;
  for (i = 0; i < length; ++i) {
    padded[i] = data[offset++];
  }
  padded[i++] = 0x80;
  final int n = paddedLength - 8;
  if (i < n) {
    i = n;
  }
  padded[i++] = (length << 3) & 0xff;
  padded[i++] = (length >> 5) & 0xff;
  padded[i++] = (length >> 13) & 0xff;
  padded[i++] = (length >> 21) & 0xff;
  padded[i++] = (length >>> 29) & 0xff;
  i += 3;

  final Int32List w = Int32List(16);
  final k = _md5K;
  final r = _md5R;

  for (i = 0; i < paddedLength;) {
    for (j = 0; j < 16; ++j, i += 4) {
      w[j] = padded[i] |
          (padded[i + 1] << 8) |
          (padded[i + 2] << 16) |
          (padded[i + 3] << 24);
    }
    int a = h0, b = h1, c = h2, d = h3, f = 0, g = 0;
    for (j = 0; j < 64; ++j) {
      if (j < 16) {
        f = (b & c) | (~b & d);
        g = j;
      } else if (j < 32) {
        f = (d & b) | (~d & c);
        g = (5 * j + 1) & 15;
      } else if (j < 48) {
        f = b ^ c ^ d;
        g = (3 * j + 5) & 15;
      } else {
        f = c ^ (b | ~d);
        g = (7 * j) & 15;
      }
      final int tmp = d;
      final int rotateArg = (a + f + k[j] + w[g]) & 0xffffffff;
      // Precisamos tratar rotateArg como um int de 32bits no shift logico da direita pra garantir o mesmo bit a bit
      // Dart trata int como 64-bit e o JS bitwise op atua em 32-bits (>>> atua unsigned)
      final int rotateArgSigned = rotateArg > 0x7fffffff ? rotateArg - 0x100000000 : rotateArg;
      final int rotate = r[j];
      d = c;
      c = b;

      final int shiftedRight = (rotateArgSigned >>> (32 - rotate)) & 0xffffffff;
      b = (b + ((rotateArg << rotate) | shiftedRight)) & 0xffffffff;
      b = b > 0x7fffffff ? b - 0x100000000 : b;
      a = tmp;
    }
    h0 = (h0 + a) & 0xffffffff; h0 = h0 > 0x7fffffff ? h0 - 0x100000000 : h0;
    h1 = (h1 + b) & 0xffffffff; h1 = h1 > 0x7fffffff ? h1 - 0x100000000 : h1;
    h2 = (h2 + c) & 0xffffffff; h2 = h2 > 0x7fffffff ? h2 - 0x100000000 : h2;
    h3 = (h3 + d) & 0xffffffff; h3 = h3 > 0x7fffffff ? h3 - 0x100000000 : h3;
  }

  // dart format off
  // @formatter:off
  return Uint8List.fromList([
    h0 & 0xFF, (h0 >> 8) & 0xFF, (h0 >> 16) & 0xFF, (h0 >>> 24) & 0xFF,
    h1 & 0xFF, (h1 >> 8) & 0xFF, (h1 >> 16) & 0xFF, (h1 >>> 24) & 0xFF,
    h2 & 0xFF, (h2 >> 8) & 0xFF, (h2 >> 16) & 0xFF, (h2 >>> 24) & 0xFF,
    h3 & 0xFF, (h3 >> 8) & 0xFF, (h3 >> 16) & 0xFF, (h3 >>> 24) & 0xFF
  ]);
  // @formatter:on
  // dart format on
}
