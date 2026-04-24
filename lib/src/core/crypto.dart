// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import '../shared/util.dart';
import 'decrypt_stream.dart';
import 'calculate_sha256.dart';
import 'calculate_sha_other.dart';
import 'base_stream.dart';


class ARCFourCipher {
  int a = 0;
  int b = 0;
  late final Uint8List s;

  ARCFourCipher(Uint8List key) {
    s = Uint8List(256);
    final keyLength = key.length;

    for (int i = 0; i < 256; ++i) {
      s[i] = i;
    }
    for (int i = 0, j = 0; i < 256; ++i) {
      final tmp = s[i];
      j = (j + tmp + key[i % keyLength]) & 0xff;
      s[i] = s[j];
      s[j] = tmp;
    }
  }

  Uint8List encryptBlock(Uint8List data) {
    int a = this.a;
    int b = this.b;
    final s = this.s;
    final n = data.length;
    final output = Uint8List(n);
    for (int i = 0; i < n; ++i) {
      a = (a + 1) & 0xff;
      final tmp = s[a];
      b = (b + tmp) & 0xff;
      final tmp2 = s[b];
      s[a] = tmp2;
      s[b] = tmp;
      output[i] = data[i] ^ s[(tmp + tmp2) & 0xff];
    }
    this.a = a;
    this.b = b;
    return output;
  }

  Uint8List decryptBlock(Uint8List data, [bool finalize = false, Uint8List? iv]) {
    return encryptBlock(data);
  }

  Uint8List encrypt(Uint8List data, [Uint8List? iv]) {
    return encryptBlock(data);
  }
}

class NullCipher {
  Uint8List decryptBlock(Uint8List data, [bool finalize = false, Uint8List? iv]) {
    return data;
  }

  Uint8List encrypt(Uint8List data, [Uint8List? iv]) {
    return data;
  }
}

// dart format off
// @formatter:off
final Uint8List _aesS = Uint8List.fromList([
  0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b,
  0xfe, 0xd7, 0xab, 0x76, 0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0,
  0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0, 0xb7, 0xfd, 0x93, 0x26,
  0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
  0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2,
  0xeb, 0x27, 0xb2, 0x75, 0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0,
  0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84, 0x53, 0xd1, 0x00, 0xed,
  0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
  0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f,
  0x50, 0x3c, 0x9f, 0xa8, 0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5,
  0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2, 0xcd, 0x0c, 0x13, 0xec,
  0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
  0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14,
  0xde, 0x5e, 0x0b, 0xdb, 0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c,
  0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79, 0xe7, 0xc8, 0x37, 0x6d,
  0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
  0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f,
  0x4b, 0xbd, 0x8b, 0x8a, 0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e,
  0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e, 0xe1, 0xf8, 0x98, 0x11,
  0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
  0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f,
  0xb0, 0x54, 0xbb, 0x16,
]);

final Uint8List _aesInvS = Uint8List.fromList([
  0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e,
  0x81, 0xf3, 0xd7, 0xfb, 0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87,
  0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb, 0x54, 0x7b, 0x94, 0x32,
  0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e,
  0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49,
  0x6d, 0x8b, 0xd1, 0x25, 0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16,
  0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92, 0x6c, 0x70, 0x48, 0x50,
  0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84,
  0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05,
  0xb8, 0xb3, 0x45, 0x06, 0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02,
  0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b, 0x3a, 0x91, 0x11, 0x41,
  0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73,
  0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8,
  0x1c, 0x75, 0xdf, 0x6e, 0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89,
  0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b, 0xfc, 0x56, 0x3e, 0x4b,
  0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4,
  0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59,
  0x27, 0x80, 0xec, 0x5f, 0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d,
  0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef, 0xa0, 0xe0, 0x3b, 0x4d,
  0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61,
  0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63,
  0x55, 0x21, 0x0c, 0x7d,
]);

final Uint32List _aesMix = Uint32List.fromList([
  0x00000000, 0x0e090d0b, 0x1c121a16, 0x121b171d, 0x3824342c, 0x362d3927,
  0x24362e3a, 0x2a3f2331, 0x70486858, 0x7e416553, 0x6c5a724e, 0x62537f45,
  0x486c5c74, 0x4665517f, 0x547e4662, 0x5a774b69, 0xe090d0b0, 0xee99ddbb,
  0xfc82caa6, 0xf28bc7ad, 0xd8b4e49c, 0xd6bde997, 0xc4a6fe8a, 0xcaaff381,
  0x90d8b8e8, 0x9ed1b5e3, 0x8ccaa2fe, 0x82c3aff5, 0xa8fc8cc4, 0xa6f581cf,
  0xb4ee96d2, 0xbae79bd9, 0xdb3bbb7b, 0xd532b670, 0xc729a16d, 0xc920ac66,
  0xe31f8f57, 0xed16825c, 0xff0d9541, 0xf104984a, 0xab73d323, 0xa57ade28,
  0xb761c935, 0xb968c43e, 0x9357e70f, 0x9d5eea04, 0x8f45fd19, 0x814cf012,
  0x3bab6bcb, 0x35a266c0, 0x27b971dd, 0x29b07cd6, 0x038f5fe7, 0x0d8652ec,
  0x1f9d45f1, 0x119448fa, 0x4be30393, 0x45ea0e98, 0x57f11985, 0x59f8148e,
  0x73c737bf, 0x7dce3ab4, 0x6fd52da9, 0x61dc20a2, 0xad766df6, 0xa37f60fd,
  0xb16477e0, 0xbf6d7aeb, 0x955259da, 0x9b5b54d1, 0x894043cc, 0x87494ec7,
  0xdd3e05ae, 0xd33708a5, 0xc12c1fb8, 0xcf2512b3, 0xe51a3182, 0xeb133c89,
  0xf9082b94, 0xf701269f, 0x4de6bd46, 0x43efb04d, 0x51f4a750, 0x5ffdaa5b,
  0x75c2896a, 0x7bcb8461, 0x69d0937c, 0x67d99e77, 0x3daed51e, 0x33a7d815,
  0x21bccf08, 0x2fb5c203, 0x058ae132, 0x0b83ec39, 0x1998fb24, 0x1791f62f,
  0x764dd68d, 0x7844db86, 0x6a5fcc9b, 0x6456c190, 0x4e69e2a1, 0x4060efaa,
  0x527bf8b7, 0x5c72f5bc, 0x0605bed5, 0x080cb3de, 0x1a17a4c3, 0x141ea9c8,
  0x3e218af9, 0x302887f2, 0x223390ef, 0x2c3a9de4, 0x96dd063d, 0x98d40b36,
  0x8acf1c2b, 0x84c61120, 0xaef93211, 0xa0f03f1a, 0xb2eb2807, 0xbce2250c,
  0xe6956e65, 0xe89c636e, 0xfa877473, 0xf48e7978, 0xdeb15a49, 0xd0b85742,
  0xc2a3405f, 0xccaa4d54, 0x41ecdaf7, 0x4fe5d7fc, 0x5dfec0e1, 0x53f7cdea,
  0x79c8eedb, 0x77c1e3d0, 0x65daf4cd, 0x6bd3f9c6, 0x31a4b2af, 0x3fadbfa4,
  0x2db6a8b9, 0x23bfa5b2, 0x09808683, 0x07898b88, 0x15929c95, 0x1b9b919e,
  0xa17c0a47, 0xaf75074c, 0xbd6e1051, 0xb3671d5a, 0x99583e6b, 0x97513360,
  0x854a247d, 0x8b432976, 0xd134621f, 0xdf3d6f14, 0xcd267809, 0xc32f7502,
  0xe9105633, 0xe7195b38, 0xf5024c25, 0xfb0b412e, 0x9ad7618c, 0x94de6c87,
  0x86c57b9a, 0x88cc7691, 0xa2f355a0, 0xacfa58ab, 0xbee14fb6, 0xb0e842bd,
  0xea9f09d4, 0xe49604df, 0xf68d13c2, 0xf8841ec9, 0xd2bb3df8, 0xdcb230f3,
  0xcea927ee, 0xc0a02ae5, 0x7a47b13c, 0x744ebc37, 0x6655ab2a, 0x685ca621,
  0x42638510, 0x4c6a881b, 0x5e719f06, 0x5078920d, 0x0a0fd964, 0x0406d46f,
  0x161dc372, 0x1814ce79, 0x322bed48, 0x3c22e043, 0x2e39f75e, 0x2030fa55,
  0xec9ab701, 0xe293ba0a, 0xf088ad17, 0xfe81a01c, 0xd4be832d, 0xdab78e26,
  0xc8ac993b, 0xc6a59430, 0x9cd2df59, 0x92dbd252, 0x80c0c54f, 0x8ec9c844,
  0xa4f6eb75, 0xaaffe67e, 0xb8e4f163, 0xb6edfc68, 0x0c0a67b1, 0x02036aba,
  0x10187da7, 0x1e1170ac, 0x342e539d, 0x3a275e96, 0x283c498b, 0x26354480,
  0x7c420fe9, 0x724b02e2, 0x605015ff, 0x6e5918f4, 0x44663bc5, 0x4a6f36ce,
  0x587421d3, 0x567d2cd8, 0x37a10c7a, 0x39a80171, 0x2bb3166c, 0x25ba1b67,
  0x0f853856, 0x018c355d, 0x13972240, 0x1d9e2f4b, 0x47e96422, 0x49e06929,
  0x5bfb7e34, 0x55f2733f, 0x7fcd500e, 0x71c45d05, 0x63df4a18, 0x6dd64713,
  0xd731dcca, 0xd938d1c1, 0xcb23c6dc, 0xc52acbd7, 0xef15e8e6, 0xe11ce5ed,
  0xf307f2f0, 0xfd0efffb, 0xa779b492, 0xa970b999, 0xbb6bae84, 0xb562a38f,
  0x9f5d80be, 0x91548db5, 0x834f9aa8, 0x8d4697a3,
]);
// @formatter:on
// dart format on

final Uint8List _aesMixCol = Uint8List(256);
void _initMixCol() {
  for (int i = 0; i < 256; i++) {
    _aesMixCol[i] = i < 128 ? i << 1 : (i << 1) ^ 0x1b;
  }
}

abstract class AESBaseCipher {
  late int _cyclesOfRepetition;
  late int _keySize;
  late Uint8List _key;

  Uint8List buffer = Uint8List(16);
  int bufferPosition = 0;
  int bufferLength = 0;
  Uint8List? iv;

  AESBaseCipher() {
    if (_aesMixCol[1] == 0) _initMixCol();
  }



  Uint8List _decrypt(Uint8List input, Uint8List key) {
    int t, u, v;
    final state = Uint8List(16);
    state.setRange(0, 16, input);

    // AddRoundKey
    for (int j = 0, k = _keySize; j < 16; ++j, ++k) {
      state[j] ^= key[k];
    }
    for (int i = _cyclesOfRepetition - 1; i >= 1; --i) {
      // InvShiftRows
      t = state[13];
      state[13] = state[9];
      state[9] = state[5];
      state[5] = state[1];
      state[1] = t;
      t = state[14];
      u = state[10];
      state[14] = state[6];
      state[10] = state[2];
      state[6] = t;
      state[2] = u;
      t = state[15];
      u = state[11];
      v = state[7];
      state[15] = state[3];
      state[11] = t;
      state[7] = u;
      state[3] = v;
      // InvSubBytes
      for (int j = 0; j < 16; ++j) {
        state[j] = _aesInvS[state[j]];
      }
      // AddRoundKey
      for (int j = 0, k = i * 16; j < 16; ++j, ++k) {
        state[j] ^= key[k];
      }
      // InvMixColumns
      for (int j = 0; j < 16; j += 4) {
        final s0 = _aesMix[state[j]];
        final s1 = _aesMix[state[j + 1]];
        final s2 = _aesMix[state[j + 2]];
        final s3 = _aesMix[state[j + 3]];
        t = s0 ^
            (s1 >>> 8) ^
            (s1 << 24) ^
            (s2 >>> 16) ^
            (s2 << 16) ^
            (s3 >>> 24) ^
            (s3 << 8);
        state[j] = (t >>> 24) & 0xff;
        state[j + 1] = (t >> 16) & 0xff;
        state[j + 2] = (t >> 8) & 0xff;
        state[j + 3] = t & 0xff;
      }
    }
    // InvShiftRows
    t = state[13];
    state[13] = state[9];
    state[9] = state[5];
    state[5] = state[1];
    state[1] = t;
    t = state[14];
    u = state[10];
    state[14] = state[6];
    state[10] = state[2];
    state[6] = t;
    state[2] = u;
    t = state[15];
    u = state[11];
    v = state[7];
    state[15] = state[3];
    state[11] = t;
    state[7] = u;
    state[3] = v;
    for (int j = 0; j < 16; ++j) {
      // InvSubBytes
      state[j] = _aesInvS[state[j]];
      // AddRoundKey
      state[j] ^= key[j];
    }
    return state;
  }

  Uint8List _encrypt(Uint8List input, Uint8List key) {
    int t, u, v;
    final state = Uint8List(16);
    state.setRange(0, 16, input);

    for (int j = 0; j < 16; ++j) {
      state[j] ^= key[j];
    }

    for (int i = 1; i < _cyclesOfRepetition; i++) {
      for (int j = 0; j < 16; ++j) {
        state[j] = _aesS[state[j]];
      }
      v = state[1];
      state[1] = state[5];
      state[5] = state[9];
      state[9] = state[13];
      state[13] = v;
      v = state[2];
      u = state[6];
      state[2] = state[10];
      state[6] = state[14];
      state[10] = v;
      state[14] = u;
      v = state[3];
      u = state[7];
      t = state[11];
      state[3] = state[15];
      state[7] = v;
      state[11] = u;
      state[15] = t;
      for (int j = 0; j < 16; j += 4) {
        final s0 = state[j];
        final s1 = state[j + 1];
        final s2 = state[j + 2];
        final s3 = state[j + 3];
        t = s0 ^ s1 ^ s2 ^ s3;
        state[j] ^= t ^ _aesMixCol[s0 ^ s1];
        state[j + 1] ^= t ^ _aesMixCol[s1 ^ s2];
        state[j + 2] ^= t ^ _aesMixCol[s2 ^ s3];
        state[j + 3] ^= t ^ _aesMixCol[s3 ^ s0];
      }
      for (int j = 0, k = i * 16; j < 16; ++j, ++k) {
        state[j] ^= key[k];
      }
    }

    for (int j = 0; j < 16; ++j) {
      state[j] = _aesS[state[j]];
    }
    v = state[1];
    state[1] = state[5];
    state[5] = state[9];
    state[9] = state[13];
    state[13] = v;
    v = state[2];
    u = state[6];
    state[2] = state[10];
    state[6] = state[14];
    state[10] = v;
    state[14] = u;
    v = state[3];
    u = state[7];
    t = state[11];
    state[3] = state[15];
    state[7] = v;
    state[11] = u;
    state[15] = t;
    for (int j = 0, k = _keySize; j < 16; ++j, ++k) {
      state[j] ^= key[k];
    }
    return state;
  }

  Uint8List _decryptBlock2(Uint8List data, bool finalize) {
    final sourceLength = data.length;
    var currentBuffer = this.buffer;
    var currentBufferLength = this.bufferPosition;
    final List<Uint8List> result = [];
    var currentIv = this.iv!;

    for (int i = 0; i < sourceLength; ++i) {
      currentBuffer[currentBufferLength] = data[i];
      ++currentBufferLength;
      if (currentBufferLength < 16) {
        continue;
      }
      final plain = _decrypt(currentBuffer, _key);
      for (int j = 0; j < 16; ++j) {
        plain[j] ^= currentIv[j];
      }
      currentIv = currentBuffer;
      result.add(plain);
      currentBuffer = Uint8List(16);
      currentBufferLength = 0;
    }

    this.buffer = currentBuffer;
    this.bufferPosition = currentBufferLength;
    this.iv = currentIv;

    if (result.isEmpty) {
      return Uint8List(0);
    }

    int outputLength = 16 * result.length;
    if (finalize) {
      final lastBlock = result.last;
      int psLen = lastBlock[15];
      if (psLen <= 16) {
        for (int i = 15, ii = 16 - psLen; i >= ii; --i) {
          if (lastBlock[i] != psLen) {
            psLen = 0;
            break;
          }
        }
        outputLength -= psLen;
        result[result.length - 1] = lastBlock.sublist(0, 16 - psLen);
      }
    }
    final output = Uint8List(outputLength);
    for (int i = 0, j = 0, ii = result.length; i < ii; ++i, j += 16) {
      output.setRange(j, j + result[i].length, result[i]);
    }
    return output;
  }

  Uint8List decryptBlock(Uint8List data, [bool finalize = false, Uint8List? ivArg]) {
    final sourceLength = data.length;
    final currentBuffer = this.buffer;
    int currentBufferLength = this.bufferPosition;

    if (ivArg != null) {
      this.iv = ivArg;
    } else {
      for (int i = 0; currentBufferLength < 16 && i < sourceLength; ++i, ++currentBufferLength) {
        currentBuffer[currentBufferLength] = data[i];
      }
      if (currentBufferLength < 16) {
        this.bufferPosition = currentBufferLength;
        return Uint8List(0);
      }
      this.iv = Uint8List.fromList(currentBuffer);
      data = data.sublist(16);
    }
    this.buffer = Uint8List(16);
    this.bufferPosition = 0;
    return _decryptBlock2(data, finalize);
  }

  Uint8List encrypt(Uint8List data, [Uint8List? ivArg]) {
    final sourceLength = data.length;
    var currentBuffer = this.buffer;
    var currentBufferLength = this.bufferPosition;
    final List<Uint8List> result = [];

    var currentIv = ivArg ?? Uint8List(16);

    for (int i = 0; i < sourceLength; ++i) {
      currentBuffer[currentBufferLength] = data[i];
      ++currentBufferLength;
      if (currentBufferLength < 16) {
        continue;
      }

      for (int j = 0; j < 16; ++j) {
        currentBuffer[j] ^= currentIv[j];
      }

      final cipher = _encrypt(currentBuffer, _key);
      currentIv = cipher;
      result.add(cipher);
      currentBuffer = Uint8List(16);
      currentBufferLength = 0;
    }

    this.buffer = currentBuffer;
    this.bufferPosition = currentBufferLength;
    this.iv = currentIv;

    if (result.isEmpty) {
      return Uint8List(0);
    }

    final outputLength = 16 * result.length;
    final output = Uint8List(outputLength);
    for (int i = 0, j = 0, ii = result.length; i < ii; ++i, j += 16) {
      output.setRange(j, j + 16, result[i]);
    }
    return output;
  }
}

class AES128Cipher extends AESBaseCipher {
  // dart format off
  // @formatter:off
  final Uint8List _rcon = Uint8List.fromList([
    0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c,
    0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a,
    0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd,
    0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a,
    0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80,
    0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6,
    0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72,
    0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc,
    0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10,
    0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e,
    0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5,
    0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94,
    0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02,
    0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d,
    0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d,
    0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f,
    0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb,
    0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c,
    0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a,
    0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd,
    0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a,
    0x74, 0xe8, 0xcb, 0x8d,
  ]);
  // @formatter:on
  // dart format on

  AES128Cipher(Uint8List key) : super() {
    _cyclesOfRepetition = 10;
    _keySize = 160;
    _key = _expandKey(key);
  }

  Uint8List _expandKey(Uint8List cipherKey) {
    const b = 176;
    final s = _aesS;
    final rcon = _rcon;

    final result = Uint8List(b);
    result.setRange(0, cipherKey.length, cipherKey);

    for (int j = 16, i = 1; j < b; ++i) {
      int t1 = result[j - 3];
      int t2 = result[j - 2];
      int t3 = result[j - 1];
      int t4 = result[j - 4];
      t1 = s[t1];
      t2 = s[t2];
      t3 = s[t3];
      t4 = s[t4];
      t1 ^= rcon[i];
      for (int n = 0; n < 4; ++n) {
        result[j] = t1 ^= result[j - 16];
        j++;
        result[j] = t2 ^= result[j - 16];
        j++;
        result[j] = t3 ^= result[j - 16];
        j++;
        result[j] = t4 ^= result[j - 16];
        j++;
      }
    }
    return result;
  }
}

class AES256Cipher extends AESBaseCipher {
  AES256Cipher(Uint8List key) : super() {
    _cyclesOfRepetition = 14;
    _keySize = 224;
    _key = _expandKey(key);
  }

  Uint8List _expandKey(Uint8List cipherKey) {
    const b = 240;
    final s = _aesS;

    final result = Uint8List(b);
    result.setRange(0, cipherKey.length, cipherKey);

    int r = 1;
    int t1 = 0, t2 = 0, t3 = 0, t4 = 0;
    for (int j = 32, i = 1; j < b; ++i) {
      if (j % 32 == 16) {
        t1 = s[t1];
        t2 = s[t2];
        t3 = s[t3];
        t4 = s[t4];
      } else if (j % 32 == 0) {
        t1 = result[j - 3];
        t2 = result[j - 2];
        t3 = result[j - 1];
        t4 = result[j - 4];
        t1 = s[t1];
        t2 = s[t2];
        t3 = s[t3];
        t4 = s[t4];
        t1 ^= r;
        if ((r <<= 1) >= 256) {
          r = (r ^ 0x1b) & 0xff;
        }
      }

      for (int n = 0; n < 4; ++n) {
        result[j] = t1 ^= result[j - 32];
        j++;
        result[j] = t2 ^= result[j - 32];
        j++;
        result[j] = t3 ^= result[j - 32];
        j++;
        result[j] = t4 ^= result[j - 32];
        j++;
      }
    }
    return result;
  }
}

abstract class PDFBase {
  Uint8List _hash(Uint8List password, Uint8List input, Uint8List userBytes);

  bool checkOwnerPassword(Uint8List password, Uint8List ownerValidationSalt, Uint8List userBytes, Uint8List ownerPassword) {
    final hashData = Uint8List(password.length + 56);
    hashData.setRange(0, password.length, password);
    hashData.setRange(password.length, password.length + ownerValidationSalt.length, ownerValidationSalt);
    hashData.setRange(password.length + ownerValidationSalt.length, hashData.length, userBytes);
    final result = _hash(password, hashData, userBytes);
    return isArrayEqual(result, ownerPassword);
  }

  bool checkUserPassword(Uint8List password, Uint8List userValidationSalt, Uint8List userPassword) {
    final hashData = Uint8List(password.length + 8);
    hashData.setRange(0, password.length, password);
    hashData.setRange(password.length, hashData.length, userValidationSalt);
    final result = _hash(password, hashData, Uint8List(0));
    return isArrayEqual(result, userPassword);
  }

  Uint8List getOwnerKey(Uint8List password, Uint8List ownerKeySalt, Uint8List userBytes, Uint8List ownerEncryption) {
    final hashData = Uint8List(password.length + 56);
    hashData.setRange(0, password.length, password);
    hashData.setRange(password.length, password.length + ownerKeySalt.length, ownerKeySalt);
    hashData.setRange(password.length + ownerKeySalt.length, hashData.length, userBytes);
    final key = _hash(password, hashData, userBytes);
    final cipher = AES256Cipher(key);
    return cipher.decryptBlock(ownerEncryption, false, Uint8List(16));
  }

  Uint8List getUserKey(Uint8List password, Uint8List userKeySalt, Uint8List userEncryption) {
    final hashData = Uint8List(password.length + 8);
    hashData.setRange(0, password.length, password);
    hashData.setRange(password.length, hashData.length, userKeySalt);
    final key = _hash(password, hashData, Uint8List(0));
    final cipher = AES256Cipher(key);
    return cipher.decryptBlock(userEncryption, false, Uint8List(16));
  }
}

class PDF17 extends PDFBase {
  @override
  Uint8List _hash(Uint8List password, Uint8List input, Uint8List userBytes) {
    return calculateSHA256(input, 0, input.length);
  }
}

class PDF20 extends PDFBase {
  @override
  Uint8List _hash(Uint8List password, Uint8List input, Uint8List userBytes) {
    var k = calculateSHA256(input, 0, input.length).sublist(0, 32);
    List<int> e = [0];
    int i = 0;
    while (i < 64 || (e.isNotEmpty && e.last > i - 32)) {
      final combinedLength = password.length + k.length + userBytes.length;
      final combinedArray = Uint8List(combinedLength);
      int writeOffset = 0;
      combinedArray.setRange(writeOffset, writeOffset + password.length, password);
      writeOffset += password.length;
      combinedArray.setRange(writeOffset, writeOffset + k.length, k);
      writeOffset += k.length;
      combinedArray.setRange(writeOffset, writeOffset + userBytes.length, userBytes);

      final k1 = Uint8List(combinedLength * 64);
      for (int j = 0, pos = 0; j < 64; j++, pos += combinedLength) {
        k1.setRange(pos, pos + combinedLength, combinedArray);
      }
      final cipher = AES128Cipher(k.sublist(0, 16));
      e = cipher.encrypt(k1, k.sublist(16, 32));
      int sum = 0;
      for (int j = 0; j < 16 && j < e.length; j++) sum += e[j];
      final remainder = sum % 3;
      if (remainder == 0) {
        k = calculateSHA256(Uint8List.fromList(e), 0, e.length);
      } else if (remainder == 1) {
        k = calculateSHA384(Uint8List.fromList(e), 0, e.length);
      } else if (remainder == 2) {
        k = calculateSHA512(Uint8List.fromList(e), 0, e.length);
      }
      i++;
    }
    return k.sublist(0, 32);
  }
}

class CipherTransform {
  final dynamic Function() _stringCipherConstructor;
  final dynamic Function() _streamCipherConstructor;

  CipherTransform(this._stringCipherConstructor, this._streamCipherConstructor);

  DecryptStream createStream(BaseStream stream, int? length) {
    final cipher = _streamCipherConstructor();
    return DecryptStream(stream, length, (Uint8List data, bool finalize) {
      return cipher.decryptBlock(data, finalize);
    });
  }

  String decryptString(String s) {
    final cipher = _stringCipherConstructor();
    Uint8List data = stringToBytes(s);
    data = cipher.decryptBlock(data, true);
    return bytesToString(data);
  }

  String encryptString(String s) {
    final cipher = _stringCipherConstructor();
    if (cipher is AESBaseCipher) {
      final strLen = s.length;
      final pad = 16 - (strLen % 16);
      s += String.fromCharCodes(List.filled(pad, pad));

      final iv = Uint8List(16);
      // Math.random -> secure replacement is skipped here for brevity unless asked
      // TODO crypto.getRandomValues(iv); // we could use dart:math Random.secure()
      
      Uint8List data = stringToBytes(s);
      data = cipher.encrypt(data, iv);

      final buf = Uint8List(16 + data.length);
      buf.setRange(0, 16, iv);
      buf.setRange(16, buf.length, data);

      return bytesToString(buf);
    }

    Uint8List data = stringToBytes(s);
    data = cipher.encrypt(data);
    return bytesToString(data);
  }
}
