// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.
/* Copyright 1996-2003 Glyph & Cog, LLC
 *
 * The CCITT stream implementation contained in this file is a JavaScript port
 * of XPDF's implementation, made available under the Apache 2.0 open source
 * license.
 */

import 'dart:typed_data';
import '../shared/util.dart';

abstract class CCITTFaxDecoderSource {
  int next();
}

const int ccittEOL = -2;
const int ccittEOF = -1;
const int twoDimPass = 0;
const int twoDimHoriz = 1;
const int twoDimVert0 = 2;
const int twoDimVertR1 = 3;
const int twoDimVertL1 = 4;
const int twoDimVertR2 = 5;
const int twoDimVertL2 = 6;
const int twoDimVertR3 = 7;
const int twoDimVertL3 = 8;

// dart format off
// @formatter:off
const List<List<int>> twoDimTable = [
  [-1, -1], [-1, -1],
  [7, twoDimVertL3],
  [7, twoDimVertR3],
  [6, twoDimVertL2], [6, twoDimVertL2],
  [6, twoDimVertR2], [6, twoDimVertR2],
  [4, twoDimPass], [4, twoDimPass],
  [4, twoDimPass], [4, twoDimPass],
  [4, twoDimPass], [4, twoDimPass],
  [4, twoDimPass], [4, twoDimPass],
  [3, twoDimHoriz], [3, twoDimHoriz],
  [3, twoDimHoriz], [3, twoDimHoriz],
  [3, twoDimHoriz], [3, twoDimHoriz],
  [3, twoDimHoriz], [3, twoDimHoriz],
  [3, twoDimHoriz], [3, twoDimHoriz],
  [3, twoDimHoriz], [3, twoDimHoriz],
  [3, twoDimHoriz], [3, twoDimHoriz],
  [3, twoDimHoriz], [3, twoDimHoriz],
  [3, twoDimVertL1], [3, twoDimVertL1],
  [3, twoDimVertL1], [3, twoDimVertL1],
  [3, twoDimVertL1], [3, twoDimVertL1],
  [3, twoDimVertL1], [3, twoDimVertL1],
  [3, twoDimVertL1], [3, twoDimVertL1],
  [3, twoDimVertL1], [3, twoDimVertL1],
  [3, twoDimVertL1], [3, twoDimVertL1],
  [3, twoDimVertL1], [3, twoDimVertL1],
  [3, twoDimVertR1], [3, twoDimVertR1],
  [3, twoDimVertR1], [3, twoDimVertR1],
  [3, twoDimVertR1], [3, twoDimVertR1],
  [3, twoDimVertR1], [3, twoDimVertR1],
  [3, twoDimVertR1], [3, twoDimVertR1],
  [3, twoDimVertR1], [3, twoDimVertR1],
  [3, twoDimVertR1], [3, twoDimVertR1],
  [3, twoDimVertR1], [3, twoDimVertR1],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0],
  [1, twoDimVert0], [1, twoDimVert0]
];

const List<List<int>> whiteTable1 = [
  [-1, -1],
  [12, ccittEOL],
  [-1, -1], [-1, -1],
  [-1, -1], [-1, -1], [-1, -1], [-1, -1],
  [-1, -1], [-1, -1], [-1, -1], [-1, -1],
  [-1, -1], [-1, -1], [-1, -1], [-1, -1],
  [11, 1792], [11, 1792],
  [12, 1984],
  [12, 2048],
  [12, 2112],
  [12, 2176],
  [12, 2240],
  [12, 2304],
  [11, 1856], [11, 1856],
  [11, 1920], [11, 1920],
  [12, 2368],
  [12, 2432],
  [12, 2496],
  [12, 2560]
];

const List<List<int>> whiteTable2 = [
  [-1, -1], [-1, -1], [-1, -1], [-1, -1],
  [8, 29], [8, 29],
  [8, 30], [8, 30],
  [8, 45], [8, 45],
  [8, 46], [8, 46],
  [7, 22], [7, 22], [7, 22], [7, 22],
  [7, 23], [7, 23], [7, 23], [7, 23],
  [8, 47], [8, 47],
  [8, 48], [8, 48],
  [6, 13], [6, 13], [6, 13], [6, 13],
  [6, 13], [6, 13], [6, 13], [6, 13],
  [7, 20], [7, 20], [7, 20], [7, 20],
  [8, 33], [8, 33],
  [8, 34], [8, 34],
  [8, 35], [8, 35],
  [8, 36], [8, 36],
  [8, 37], [8, 37],
  [8, 38], [8, 38],
  [7, 19], [7, 19], [7, 19], [7, 19],
  [8, 31], [8, 31],
  [8, 32], [8, 32],
  [6, 1], [6, 1], [6, 1], [6, 1],
  [6, 1], [6, 1], [6, 1], [6, 1],
  [6, 12], [6, 12], [6, 12], [6, 12],
  [6, 12], [6, 12], [6, 12], [6, 12],
  [8, 53], [8, 53],
  [8, 54], [8, 54],
  [7, 26], [7, 26], [7, 26], [7, 26],
  [8, 39], [8, 39],
  [8, 40], [8, 40],
  [8, 41], [8, 41],
  [8, 42], [8, 42],
  [8, 43], [8, 43],
  [8, 44], [8, 44],
  [7, 21], [7, 21], [7, 21], [7, 21],
  [7, 28], [7, 28], [7, 28], [7, 28],
  [8, 61], [8, 61],
  [8, 62], [8, 62],
  [8, 63], [8, 63],
  [8, 0], [8, 0],
  [8, 320], [8, 320],
  [8, 384], [8, 384],
  [5, 10], [5, 10], [5, 10], [5, 10],
  [5, 10], [5, 10], [5, 10], [5, 10],
  [5, 10], [5, 10], [5, 10], [5, 10],
  [5, 10], [5, 10], [5, 10], [5, 10],
  [5, 11], [5, 11], [5, 11], [5, 11],
  [5, 11], [5, 11], [5, 11], [5, 11],
  [5, 11], [5, 11], [5, 11], [5, 11],
  [5, 11], [5, 11], [5, 11], [5, 11],
  [7, 27], [7, 27], [7, 27], [7, 27],
  [8, 59], [8, 59],
  [8, 60], [8, 60],
  [9, 1472],
  [9, 1536],
  [9, 1600],
  [9, 1728],
  [7, 18], [7, 18], [7, 18], [7, 18],
  [7, 24], [7, 24], [7, 24], [7, 24],
  [8, 49], [8, 49],
  [8, 50], [8, 50],
  [8, 51], [8, 51],
  [8, 52], [8, 52],
  [7, 25], [7, 25], [7, 25], [7, 25],
  [8, 55], [8, 55],
  [8, 56], [8, 56],
  [8, 57], [8, 57],
  [8, 58], [8, 58],
  [6, 192], [6, 192], [6, 192], [6, 192],
  [6, 192], [6, 192], [6, 192], [6, 192],
  [6, 1664], [6, 1664], [6, 1664], [6, 1664],
  [6, 1664], [6, 1664], [6, 1664], [6, 1664],
  [8, 448], [8, 448],
  [8, 512], [8, 512],
  [9, 704],
  [9, 768],
  [8, 640], [8, 640],
  [8, 576], [8, 576],
  [9, 832],
  [9, 896],
  [9, 960],
  [9, 1024],
  [9, 1088],
  [9, 1152],
  [9, 1216],
  [9, 1280],
  [9, 1344],
  [9, 1408],
  [7, 256], [7, 256], [7, 256], [7, 256],
  [4, 2], [4, 2], [4, 2], [4, 2],
  [4, 2], [4, 2], [4, 2], [4, 2],
  [4, 2], [4, 2], [4, 2], [4, 2],
  [4, 2], [4, 2], [4, 2], [4, 2],
  [4, 2], [4, 2], [4, 2], [4, 2],
  [4, 2], [4, 2], [4, 2], [4, 2],
  [4, 2], [4, 2], [4, 2], [4, 2],
  [4, 2], [4, 2], [4, 2], [4, 2],
  [4, 3], [4, 3], [4, 3], [4, 3],
  [4, 3], [4, 3], [4, 3], [4, 3],
  [4, 3], [4, 3], [4, 3], [4, 3],
  [4, 3], [4, 3], [4, 3], [4, 3],
  [4, 3], [4, 3], [4, 3], [4, 3],
  [4, 3], [4, 3], [4, 3], [4, 3],
  [4, 3], [4, 3], [4, 3], [4, 3],
  [4, 3], [4, 3], [4, 3], [4, 3],
  [5, 128], [5, 128], [5, 128], [5, 128],
  [5, 128], [5, 128], [5, 128], [5, 128],
  [5, 128], [5, 128], [5, 128], [5, 128],
  [5, 128], [5, 128], [5, 128], [5, 128],
  [5, 8], [5, 8], [5, 8], [5, 8],
  [5, 8], [5, 8], [5, 8], [5, 8],
  [5, 8], [5, 8], [5, 8], [5, 8],
  [5, 8], [5, 8], [5, 8], [5, 8],
  [5, 9], [5, 9], [5, 9], [5, 9],
  [5, 9], [5, 9], [5, 9], [5, 9],
  [5, 9], [5, 9], [5, 9], [5, 9],
  [5, 9], [5, 9], [5, 9], [5, 9],
  [6, 16], [6, 16], [6, 16], [6, 16],
  [6, 16], [6, 16], [6, 16], [6, 16],
  [6, 17], [6, 17], [6, 17], [6, 17],
  [6, 17], [6, 17], [6, 17], [6, 17],
  [4, 4], [4, 4], [4, 4], [4, 4],
  [4, 4], [4, 4], [4, 4], [4, 4],
  [4, 4], [4, 4], [4, 4], [4, 4],
  [4, 4], [4, 4], [4, 4], [4, 4],
  [4, 4], [4, 4], [4, 4], [4, 4],
  [4, 4], [4, 4], [4, 4], [4, 4],
  [4, 4], [4, 4], [4, 4], [4, 4],
  [4, 4], [4, 4], [4, 4], [4, 4],
  [4, 5], [4, 5], [4, 5], [4, 5],
  [4, 5], [4, 5], [4, 5], [4, 5],
  [4, 5], [4, 5], [4, 5], [4, 5],
  [4, 5], [4, 5], [4, 5], [4, 5],
  [4, 5], [4, 5], [4, 5], [4, 5],
  [4, 5], [4, 5], [4, 5], [4, 5],
  [4, 5], [4, 5], [4, 5], [4, 5],
  [4, 5], [4, 5], [4, 5], [4, 5],
  [6, 14], [6, 14], [6, 14], [6, 14],
  [6, 14], [6, 14], [6, 14], [6, 14],
  [6, 15], [6, 15], [6, 15], [6, 15],
  [6, 15], [6, 15], [6, 15], [6, 15],
  [5, 64], [5, 64], [5, 64], [5, 64],
  [5, 64], [5, 64], [5, 64], [5, 64],
  [5, 64], [5, 64], [5, 64], [5, 64],
  [5, 64], [5, 64], [5, 64], [5, 64],
  [4, 6], [4, 6], [4, 6], [4, 6],
  [4, 6], [4, 6], [4, 6], [4, 6],
  [4, 6], [4, 6], [4, 6], [4, 6],
  [4, 6], [4, 6], [4, 6], [4, 6],
  [4, 6], [4, 6], [4, 6], [4, 6],
  [4, 6], [4, 6], [4, 6], [4, 6],
  [4, 6], [4, 6], [4, 6], [4, 6],
  [4, 6], [4, 6], [4, 6], [4, 6],
  [4, 7], [4, 7], [4, 7], [4, 7],
  [4, 7], [4, 7], [4, 7], [4, 7],
  [4, 7], [4, 7], [4, 7], [4, 7],
  [4, 7], [4, 7], [4, 7], [4, 7],
  [4, 7], [4, 7], [4, 7], [4, 7],
  [4, 7], [4, 7], [4, 7], [4, 7],
  [4, 7], [4, 7], [4, 7], [4, 7],
  [4, 7], [4, 7], [4, 7], [4, 7]
];

const List<List<int>> blackTable1 = [
  [-1, -1], [-1, -1],
  [12, ccittEOL], [12, ccittEOL],
  [-1, -1], [-1, -1], [-1, -1], [-1, -1],
  [-1, -1], [-1, -1], [-1, -1], [-1, -1],
  [-1, -1], [-1, -1], [-1, -1], [-1, -1],
  [-1, -1], [-1, -1], [-1, -1], [-1, -1],
  [-1, -1], [-1, -1], [-1, -1], [-1, -1],
  [-1, -1], [-1, -1], [-1, -1], [-1, -1],
  [-1, -1], [-1, -1], [-1, -1], [-1, -1],
  [11, 1792], [11, 1792], [11, 1792], [11, 1792],
  [12, 1984], [12, 1984],
  [12, 2048], [12, 2048],
  [12, 2112], [12, 2112],
  [12, 2176], [12, 2176],
  [12, 2240], [12, 2240],
  [12, 2304], [12, 2304],
  [11, 1856], [11, 1856], [11, 1856], [11, 1856],
  [11, 1920], [11, 1920], [11, 1920], [11, 1920],
  [12, 2368], [12, 2368],
  [12, 2432], [12, 2432],
  [12, 2496], [12, 2496],
  [12, 2560], [12, 2560],
  [10, 18], [10, 18], [10, 18], [10, 18],
  [10, 18], [10, 18], [10, 18], [10, 18],
  [12, 52], [12, 52],
  [13, 640],
  [13, 704],
  [13, 768],
  [13, 832],
  [12, 55], [12, 55],
  [12, 56], [12, 56],
  [13, 1280],
  [13, 1344],
  [13, 1408],
  [13, 1472],
  [12, 59], [12, 59],
  [12, 60], [12, 60],
  [13, 1536],
  [13, 1600],
  [11, 24], [11, 24], [11, 24], [11, 24],
  [11, 25], [11, 25], [11, 25], [11, 25],
  [13, 1664],
  [13, 1728],
  [12, 320], [12, 320],
  [12, 384], [12, 384],
  [12, 448], [12, 448],
  [13, 512],
  [13, 576],
  [12, 53], [12, 53],
  [12, 54], [12, 54],
  [13, 896],
  [13, 960],
  [13, 1024],
  [13, 1088],
  [13, 1152],
  [13, 1216],
  [10, 64], [10, 64], [10, 64], [10, 64],
  [10, 64], [10, 64], [10, 64], [10, 64]
];

const List<List<int>> blackTable2 = [
  [8, 13], [8, 13], [8, 13], [8, 13],
  [8, 13], [8, 13], [8, 13], [8, 13],
  [8, 13], [8, 13], [8, 13], [8, 13],
  [8, 13], [8, 13], [8, 13], [8, 13],
  [11, 23], [11, 23],
  [12, 50],
  [12, 51],
  [12, 44],
  [12, 45],
  [12, 46],
  [12, 47],
  [12, 57],
  [12, 58],
  [12, 61],
  [12, 256],
  [10, 16], [10, 16], [10, 16], [10, 16],
  [10, 17], [10, 17], [10, 17], [10, 17],
  [12, 48],
  [12, 49],
  [12, 62],
  [12, 63],
  [12, 30],
  [12, 31],
  [12, 32],
  [12, 33],
  [12, 40],
  [12, 41],
  [11, 22], [11, 22],
  [8, 14], [8, 14], [8, 14], [8, 14],
  [8, 14], [8, 14], [8, 14], [8, 14],
  [8, 14], [8, 14], [8, 14], [8, 14],
  [8, 14], [8, 14], [8, 14], [8, 14],
  [7, 10], [7, 10], [7, 10], [7, 10],
  [7, 10], [7, 10], [7, 10], [7, 10],
  [7, 10], [7, 10], [7, 10], [7, 10],
  [7, 10], [7, 10], [7, 10], [7, 10],
  [7, 10], [7, 10], [7, 10], [7, 10],
  [7, 10], [7, 10], [7, 10], [7, 10],
  [7, 10], [7, 10], [7, 10], [7, 10],
  [7, 10], [7, 10], [7, 10], [7, 10],
  [7, 11], [7, 11], [7, 11], [7, 11],
  [7, 11], [7, 11], [7, 11], [7, 11],
  [7, 11], [7, 11], [7, 11], [7, 11],
  [7, 11], [7, 11], [7, 11], [7, 11],
  [7, 11], [7, 11], [7, 11], [7, 11],
  [7, 11], [7, 11], [7, 11], [7, 11],
  [7, 11], [7, 11], [7, 11], [7, 11],
  [7, 11], [7, 11], [7, 11], [7, 11],
  [9, 15], [9, 15], [9, 15], [9, 15],
  [9, 15], [9, 15], [9, 15], [9, 15],
  [12, 128],
  [12, 192],
  [12, 26],
  [12, 27],
  [12, 28],
  [12, 29],
  [11, 19], [11, 19],
  [11, 20], [11, 20],
  [12, 34],
  [12, 35],
  [12, 36],
  [12, 37],
  [12, 38],
  [12, 39],
  [11, 21], [11, 21],
  [12, 42],
  [12, 43],
  [10, 0], [10, 0], [10, 0], [10, 0],
  [7, 12], [7, 12], [7, 12], [7, 12],
  [7, 12], [7, 12], [7, 12], [7, 12],
  [7, 12], [7, 12], [7, 12], [7, 12],
  [7, 12], [7, 12], [7, 12], [7, 12],
  [7, 12], [7, 12], [7, 12], [7, 12],
  [7, 12], [7, 12], [7, 12], [7, 12],
  [7, 12], [7, 12], [7, 12], [7, 12],
  [7, 12], [7, 12], [7, 12], [7, 12]
];

const List<List<int>> blackTable3 = [
  [-1, -1], [-1, -1], [-1, -1], [-1, -1],
  [6, 9],
  [6, 8],
  [5, 7], [5, 7],
  [4, 6], [4, 6], [4, 6], [4, 6],
  [4, 5], [4, 5], [4, 5], [4, 5],
  [3, 1], [3, 1], [3, 1], [3, 1],
  [3, 1], [3, 1], [3, 1], [3, 1],
  [3, 4], [3, 4], [3, 4], [3, 4],
  [3, 4], [3, 4], [3, 4], [3, 4],
  [2, 3], [2, 3], [2, 3], [2, 3],
  [2, 3], [2, 3], [2, 3], [2, 3],
  [2, 3], [2, 3], [2, 3], [2, 3],
  [2, 3], [2, 3], [2, 3], [2, 3],
  [2, 2], [2, 2], [2, 2], [2, 2],
  [2, 2], [2, 2], [2, 2], [2, 2],
  [2, 2], [2, 2], [2, 2], [2, 2],
  [2, 2], [2, 2], [2, 2], [2, 2]
];
// @formatter:on
// dart format on

class CCITTFaxDecoderOptions {
  final int k;
  final bool endOfLine;
  final bool encodedByteAlign;
  final int columns;
  final int rows;
  final bool endOfBlock;
  final bool blackIs1;

  CCITTFaxDecoderOptions({
    this.k = 0,
    this.endOfLine = false,
    this.encodedByteAlign = false,
    this.columns = 1728,
    this.rows = 0,
    this.endOfBlock = true,
    this.blackIs1 = false,
  });
}

class CCITTFaxDecoder {
  final CCITTFaxDecoderSource source;
  bool eof = false;
  late int encoding;
  late bool eoline;
  late bool byteAlign;
  late int columns;
  late int rows;
  late bool eoblock;
  late bool black;

  late Int32List codingLine;
  late Int32List refLine;
  int codingPos = 0;
  int row = 0;
  bool nextLine2D = false;
  int inputBits = 0;
  int inputBuf = 0;
  int outputBits = 0;
  bool rowsDone = false;
  bool err = false;

  CCITTFaxDecoder(this.source, [CCITTFaxDecoderOptions? options]) {
    options ??= CCITTFaxDecoderOptions();
    encoding = options.k;
    eoline = options.endOfLine;
    byteAlign = options.encodedByteAlign;
    columns = options.columns;
    rows = options.rows;
    eoblock = options.endOfBlock;
    black = options.blackIs1;

    codingLine = Int32List(columns + 1);
    refLine = Int32List(columns + 2);

    codingLine[0] = columns;
    codingPos = 0;

    row = 0;
    nextLine2D = encoding < 0;
    inputBits = 0;
    inputBuf = 0;
    outputBits = 0;
    rowsDone = false;

    int code1;
    while ((code1 = _lookBits(12)) == 0) {
      _eatBits(1);
    }
    if (code1 == 1) {
      _eatBits(12);
    }
    if (encoding > 0) {
      nextLine2D = _lookBits(1) == 0;
      _eatBits(1);
    }
  }

  int readNextChar() {
    if (eof) return -1;

    int refPos = 0, blackPixels = 0, bits, i;

    if (outputBits == 0) {
      if (rowsDone) {
        eof = true;
      }
      if (eof) {
        return -1;
      }
      err = false;

      int code1, code2, code3;
      if (nextLine2D) {
        for (i = 0; codingLine[i] < columns; ++i) {
          refLine[i] = codingLine[i];
        }
        refLine[i++] = columns;
        refLine[i] = columns;
        codingLine[0] = 0;
        codingPos = 0;
        refPos = 0;
        blackPixels = 0;

        while (codingLine[codingPos] < columns) {
          code1 = _getTwoDimCode();
          switch (code1) {
            case twoDimPass:
              _addPixels(refLine[refPos + 1], blackPixels);
              if (refLine[refPos + 1] < columns) {
                refPos += 2;
              }
              break;
            case twoDimHoriz:
              code1 = code2 = 0;
              if (blackPixels != 0) {
                do {
                  code3 = _getBlackCode();
                  code1 += code3;
                } while (code3 >= 64);
                do {
                  code3 = _getWhiteCode();
                  code2 += code3;
                } while (code3 >= 64);
              } else {
                do {
                  code3 = _getWhiteCode();
                  code1 += code3;
                } while (code3 >= 64);
                do {
                  code3 = _getBlackCode();
                  code2 += code3;
                } while (code3 >= 64);
              }
              _addPixels(codingLine[codingPos] + code1, blackPixels);
              if (codingLine[codingPos] < columns) {
                _addPixels(codingLine[codingPos] + code2, blackPixels ^ 1);
              }
              while (refLine[refPos] <= codingLine[codingPos] && refLine[refPos] < columns) {
                refPos += 2;
              }
              break;
            case twoDimVertR3:
              _addPixels(refLine[refPos] + 3, blackPixels);
              blackPixels ^= 1;
              if (codingLine[codingPos] < columns) {
                ++refPos;
                while (refLine[refPos] <= codingLine[codingPos] && refLine[refPos] < columns) {
                  refPos += 2;
                }
              }
              break;
            case twoDimVertR2:
              _addPixels(refLine[refPos] + 2, blackPixels);
              blackPixels ^= 1;
              if (codingLine[codingPos] < columns) {
                ++refPos;
                while (refLine[refPos] <= codingLine[codingPos] && refLine[refPos] < columns) {
                  refPos += 2;
                }
              }
              break;
            case twoDimVertR1:
              _addPixels(refLine[refPos] + 1, blackPixels);
              blackPixels ^= 1;
              if (codingLine[codingPos] < columns) {
                ++refPos;
                while (refLine[refPos] <= codingLine[codingPos] && refLine[refPos] < columns) {
                  refPos += 2;
                }
              }
              break;
            case twoDimVert0:
              _addPixels(refLine[refPos], blackPixels);
              blackPixels ^= 1;
              if (codingLine[codingPos] < columns) {
                ++refPos;
                while (refLine[refPos] <= codingLine[codingPos] && refLine[refPos] < columns) {
                  refPos += 2;
                }
              }
              break;
            case twoDimVertL3:
              _addPixelsNeg(refLine[refPos] - 3, blackPixels);
              blackPixels ^= 1;
              if (codingLine[codingPos] < columns) {
                if (refPos > 0) {
                  --refPos;
                } else {
                  ++refPos;
                }
                while (refLine[refPos] <= codingLine[codingPos] && refLine[refPos] < columns) {
                  refPos += 2;
                }
              }
              break;
            case twoDimVertL2:
              _addPixelsNeg(refLine[refPos] - 2, blackPixels);
              blackPixels ^= 1;
              if (codingLine[codingPos] < columns) {
                if (refPos > 0) {
                  --refPos;
                } else {
                  ++refPos;
                }
                while (refLine[refPos] <= codingLine[codingPos] && refLine[refPos] < columns) {
                  refPos += 2;
                }
              }
              break;
            case twoDimVertL1:
              _addPixelsNeg(refLine[refPos] - 1, blackPixels);
              blackPixels ^= 1;
              if (codingLine[codingPos] < columns) {
                if (refPos > 0) {
                  --refPos;
                } else {
                  ++refPos;
                }
                while (refLine[refPos] <= codingLine[codingPos] && refLine[refPos] < columns) {
                  refPos += 2;
                }
              }
              break;
            case ccittEOF:
              _addPixels(columns, 0);
              eof = true;
              break;
            default:
              info("bad 2d code");
              _addPixels(columns, 0);
              err = true;
          }
        }
      } else {
        codingLine[0] = 0;
        codingPos = 0;
        blackPixels = 0;
        while (codingLine[codingPos] < columns) {
          code1 = 0;
          if (blackPixels != 0) {
            do {
              code3 = _getBlackCode();
              code1 += code3;
            } while (code3 >= 64);
          } else {
            do {
              code3 = _getWhiteCode();
              code1 += code3;
            } while (code3 >= 64);
          }
          _addPixels(codingLine[codingPos] + code1, blackPixels);
          blackPixels ^= 1;
        }
      }

      bool gotEOL = false;

      if (byteAlign) {
        inputBits &= ~7;
      }

      if (!eoblock && row == rows - 1) {
        rowsDone = true;
      } else {
        code1 = _lookBits(12);
        if (eoline) {
          while (code1 != ccittEOF && code1 != 1) {
            _eatBits(1);
            code1 = _lookBits(12);
          }
        } else {
          while (code1 == 0) {
            _eatBits(1);
            code1 = _lookBits(12);
          }
        }
        if (code1 == 1) {
          _eatBits(12);
          gotEOL = true;
        } else if (code1 == ccittEOF) {
          eof = true;
        }
      }

      if (!eof && encoding > 0 && !rowsDone) {
        nextLine2D = _lookBits(1) == 0;
        _eatBits(1);
      }

      if (eoblock && gotEOL && byteAlign) {
        code1 = _lookBits(12);
        if (code1 == 1) {
          _eatBits(12);
          if (encoding > 0) {
            _lookBits(1);
            _eatBits(1);
          }
          if (encoding >= 0) {
            for (i = 0; i < 4; ++i) {
              code1 = _lookBits(12);
              if (code1 != 1) {
                info("bad rtc code: \$code1");
              }
              _eatBits(12);
              if (encoding > 0) {
                _lookBits(1);
                _eatBits(1);
              }
            }
          }
          eof = true;
        }
      } else if (err && eoline) {
        while (true) {
          code1 = _lookBits(13);
          if (code1 == ccittEOF) {
            eof = true;
            return -1;
          }
          if ((code1 >> 1) == 1) {
            break;
          }
          _eatBits(1);
        }
        _eatBits(12);
        if (encoding > 0) {
          _eatBits(1);
          nextLine2D = (code1 & 1) == 0;
        }
      }

      outputBits = codingLine[0] > 0
          ? codingLine[codingPos = 0]
          : codingLine[codingPos = 1];
      row++;
    }

    int c;
    if (outputBits >= 8) {
      c = (codingPos & 1) != 0 ? 0 : 0xff;
      outputBits -= 8;
      if (outputBits == 0 && codingLine[codingPos] < columns) {
        codingPos++;
        outputBits = codingLine[codingPos] - codingLine[codingPos - 1];
      }
    } else {
      bits = 8;
      c = 0;
      do {
        if (outputBits > bits) {
          c <<= bits;
          if ((codingPos & 1) == 0) {
            c |= 0xff >> (8 - bits);
          }
          outputBits -= bits;
          bits = 0;
        } else {
          c <<= outputBits;
          if ((codingPos & 1) == 0) {
            c |= 0xff >> (8 - outputBits);
          }
          bits -= outputBits;
          outputBits = 0;
          if (codingLine[codingPos] < columns) {
            codingPos++;
            outputBits = codingLine[codingPos] - codingLine[codingPos - 1];
          } else if (bits > 0) {
            c <<= bits;
            bits = 0;
          }
        }
      } while (bits > 0);
    }
    if (black) {
      c ^= 0xff;
    }
    return c;
  }

  void _addPixels(int a1, int blackPixels) {
    if (a1 > codingLine[codingPos]) {
      if (a1 > columns) {
        info("row is wrong length");
        err = true;
        a1 = columns;
      }
      if (((codingPos & 1) ^ blackPixels) != 0) {
        ++codingPos;
      }
      codingLine[codingPos] = a1;
    }
  }

  void _addPixelsNeg(int a1, int blackPixels) {
    if (a1 > codingLine[codingPos]) {
      if (a1 > columns) {
        info("row is wrong length");
        err = true;
        a1 = columns;
      }
      if (((codingPos & 1) ^ blackPixels) != 0) {
        ++codingPos;
      }
      codingLine[codingPos] = a1;
    } else if (a1 < codingLine[codingPos]) {
      if (a1 < 0) {
        info("invalid code");
        err = true;
        a1 = 0;
      }
      while (codingPos > 0 && a1 < codingLine[codingPos - 1]) {
        --codingPos;
      }
      codingLine[codingPos] = a1;
    }
  }

  List<dynamic> _findTableCode(int start, int end, List<List<int>> table, [int limit = 0]) {
    for (int i = start; i <= end; ++i) {
      int code = _lookBits(i);
      if (code == ccittEOF) {
        return [true, 1, false];
      }
      if (i < end) {
        code <<= end - i;
      }
      if (limit == 0 || code >= limit) {
        final p = table[code - limit];
        if (p[0] == i) {
          _eatBits(i);
          return [true, p[1], true];
        }
      }
    }
    return [false, 0, false];
  }

  int _getTwoDimCode() {
    int code = 0;
    List<int> p;
    if (eoblock) {
      code = _lookBits(7);
      if (code < twoDimTable.length) {
        p = twoDimTable[code];
        if (p[0] > 0) {
          _eatBits(p[0]);
          return p[1];
        }
      }
    } else {
      final result = _findTableCode(1, 7, twoDimTable);
      if (result[0] && result[2]) {
        return result[1];
      }
    }
    info("Bad two dim code");
    return ccittEOF;
  }

  int _getWhiteCode() {
    int code = 0;
    List<int> p;
    if (eoblock) {
      code = _lookBits(12);
      if (code == ccittEOF) {
        return 1;
      }

      p = (code >> 5) == 0 ? whiteTable1[code] : whiteTable2[code >> 3];

      if (p[0] > 0) {
        _eatBits(p[0]);
        return p[1];
      }
    } else {
      var result = _findTableCode(1, 9, whiteTable2);
      if (result[0]) {
        return result[1];
      }

      result = _findTableCode(11, 12, whiteTable1);
      if (result[0]) {
        return result[1];
      }
    }
    info("bad white code");
    _eatBits(1);
    return 1;
  }

  int _getBlackCode() {
    int code;
    List<int> p;
    if (eoblock) {
      code = _lookBits(13);
      if (code == ccittEOF) {
        return 1;
      }
      if ((code >> 7) == 0) {
        p = blackTable1[code];
      } else if ((code >> 9) == 0 && (code >> 7) != 0) {
        p = blackTable2[(code >> 1) - 64];
      } else {
        p = blackTable3[code >> 7];
      }

      if (p[0] > 0) {
        _eatBits(p[0]);
        return p[1];
      }
    } else {
      var result = _findTableCode(2, 6, blackTable3);
      if (result[0]) {
        return result[1];
      }

      result = _findTableCode(7, 12, blackTable2, 64);
      if (result[0]) {
        return result[1];
      }

      result = _findTableCode(10, 13, blackTable1);
      if (result[0]) {
        return result[1];
      }
    }
    info("bad black code");
    _eatBits(1);
    return 1;
  }

  int _lookBits(int n) {
    int c;
    while (inputBits < n) {
      if ((c = source.next()) == -1) {
        if (inputBits == 0) {
          return ccittEOF;
        }
        return (inputBuf << (n - inputBits)) & (0xffff >> (16 - n));
      }
      inputBuf = (inputBuf << 8) | c;
      inputBits += 8;
    }
    return (inputBuf >> (inputBits - n)) & (0xffff >> (16 - n));
  }

  void _eatBits(int n) {
    if ((inputBits -= n) < 0) {
      inputBits = 0;
    }
  }
}
