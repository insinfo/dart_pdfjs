// Copyright 2022 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'util.dart';

Map<String, int>? convertToRGBA(Map<String, dynamic> params) {
  final kind = params['kind'] as int;
  switch (kind) {
    case ImageKind.grayscale1bpp:
      return convertBlackAndWhiteToRGBA(
        src: params['src'],
        srcPos: params['srcPos'] ?? 0,
        dest: params['dest'],
        width: params['width'],
        height: params['height'],
        nonBlackColor: params['nonBlackColor'] ?? 0xffffffff,
        inverseDecode: params['inverseDecode'] ?? false,
      );
    case ImageKind.rgb24bpp:
      return convertRGBToRGBA(
        src: params['src'],
        srcPos: params['srcPos'] ?? 0,
        dest: params['dest'],
        destPos: params['destPos'] ?? 0,
        width: params['width'],
        height: params['height'],
      );
  }

  return null;
}

Map<String, int> convertBlackAndWhiteToRGBA({
  required Uint8List src,
  int srcPos = 0,
  required Uint32List dest,
  required int width,
  required int height,
  int nonBlackColor = 0xffffffff,
  bool inverseDecode = false,
}) {
  final isLittleEndian = Endian.host == Endian.little;
  final black = isLittleEndian ? 0xff000000 : 0x000000ff;
  
  final zeroMapping = inverseDecode ? nonBlackColor : black;
  final oneMapping = inverseDecode ? black : nonBlackColor;
  
  final widthInSource = width >> 3;
  final widthRemainder = width & 7;
  final xorMask = zeroMapping ^ oneMapping;
  final srcLength = src.length;
  
  int destPos = 0;

  for (int i = 0; i < height; ++i) {
    for (int max = srcPos + widthInSource; srcPos < max; ++srcPos, destPos += 8) {
      final elem = src[srcPos];
      dest[destPos] = zeroMapping ^ (-((elem >> 7) & 1) & xorMask);
      dest[destPos + 1] = zeroMapping ^ (-((elem >> 6) & 1) & xorMask);
      dest[destPos + 2] = zeroMapping ^ (-((elem >> 5) & 1) & xorMask);
      dest[destPos + 3] = zeroMapping ^ (-((elem >> 4) & 1) & xorMask);
      dest[destPos + 4] = zeroMapping ^ (-((elem >> 3) & 1) & xorMask);
      dest[destPos + 5] = zeroMapping ^ (-((elem >> 2) & 1) & xorMask);
      dest[destPos + 6] = zeroMapping ^ (-((elem >> 1) & 1) & xorMask);
      dest[destPos + 7] = zeroMapping ^ (-(elem & 1) & xorMask);
    }
    if (widthRemainder == 0) {
      continue;
    }
    final elem = srcPos < srcLength ? src[srcPos++] : 255;
    for (int j = 0; j < widthRemainder; ++j, ++destPos) {
      dest[destPos] = zeroMapping ^ (-((elem >> (7 - j)) & 1) & xorMask);
    }
  }

  return {'srcPos': srcPos, 'destPos': destPos};
}

Map<String, int> convertRGBToRGBA({
  required Uint8List src,
  int srcPos = 0,
  required Uint32List dest,
  int destPos = 0,
  required int width,
  required int height,
}) {
  int i = 0;
  final len = width * height * 3;
  final len32 = len >> 2;
  final src32 = Uint32List.view(src.buffer, src.offsetInBytes + srcPos, len32);
  
  final isLittleEndian = Endian.host == Endian.little;
  final alphaMask = isLittleEndian ? 0xff000000 : 0xff;

  if (isLittleEndian) {
    for (; i < len32 - 2; i += 3, destPos += 4) {
      final s1 = src32[i]; // R2B1G1R1
      final s2 = src32[i + 1]; // G3R3B2G2
      final s3 = src32[i + 2]; // B4G4R4B3

      dest[destPos] = s1 | alphaMask;
      dest[destPos + 1] = (s1 >>> 24) | (s2 << 8) | alphaMask;
      dest[destPos + 2] = (s2 >>> 16) | (s3 << 16) | alphaMask;
      dest[destPos + 3] = (s3 >>> 8) | alphaMask;
    }

    for (int j = i * 4, jj = len; j < jj; j += 3) {
      dest[destPos++] =
          src[srcPos + j] | (src[srcPos + j + 1] << 8) | (src[srcPos + j + 2] << 16) | alphaMask;
    }
  } else {
    for (; i < len32 - 2; i += 3, destPos += 4) {
      final s1 = src32[i]; // R1G1B1R2
      final s2 = src32[i + 1]; // G2B2R3G3
      final s3 = src32[i + 2]; // B3R4G4B4

      dest[destPos] = s1 | alphaMask;
      dest[destPos + 1] = (s1 << 24) | (s2 >>> 8) | alphaMask;
      dest[destPos + 2] = (s2 << 16) | (s3 >>> 16) | alphaMask;
      dest[destPos + 3] = (s3 << 8) | alphaMask;
    }

    for (int j = i * 4, jj = len; j < jj; j += 3) {
      dest[destPos++] =
          (src[srcPos + j] << 24) | (src[srcPos + j + 1] << 16) | (src[srcPos + j + 2] << 8) | alphaMask;
    }
  }

  return {'srcPos': srcPos + len, 'destPos': destPos};
}

void grayToRGBA(Uint8List src, Uint32List dest) {
  final isLittleEndian = Endian.host == Endian.little;
  if (isLittleEndian) {
    for (int i = 0, ii = src.length; i < ii; i++) {
      dest[i] = (src[i] * 0x10101) | 0xff000000;
    }
  } else {
    for (int i = 0, ii = src.length; i < ii; i++) {
      dest[i] = (src[i] * 0x1010100) | 0x000000ff;
    }
  }
}
