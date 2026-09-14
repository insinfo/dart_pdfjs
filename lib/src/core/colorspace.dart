// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;
import 'dart:typed_data';

import '../shared/math_clamp.dart';
import '../shared/util.dart';
import 'base_stream.dart';

void resizeRgbImage(
  List<int> src,
  Uint8List dest,
  int w1,
  int h1,
  int w2,
  int h2,
  int alpha01,
) {
  const components = 3;
  alpha01 = alpha01 != 1 ? 0 : alpha01;
  final xRatio = w1 / w2;
  final yRatio = h1 / h2;
  var newIndex = 0;
  final xScaled = Uint16List(w2);
  final w1Scanline = w1 * components;

  for (var i = 0; i < w2; i++) {
    xScaled[i] = (i * xRatio).floor() * components;
  }
  for (var i = 0; i < h2; i++) {
    final py = (i * yRatio).floor() * w1Scanline;
    for (var j = 0; j < w2; j++) {
      var oldIndex = py + xScaled[j];
      dest[newIndex++] = src[oldIndex++];
      dest[newIndex++] = src[oldIndex++];
      dest[newIndex++] = src[oldIndex++];
      newIndex += alpha01;
    }
  }
}

void resizeRgbaImage(
  List<int> src,
  Uint8List dest,
  int w1,
  int h1,
  int w2,
  int h2,
  int alpha01,
) {
  final xRatio = w1 / w2;
  final yRatio = h1 / h2;
  var newIndex = 0;
  final xScaled = Uint16List(w2);

  const components = 4;
  final w1Scanline = w1 * components;
  for (var i = 0; i < w2; i++) {
    xScaled[i] = (i * xRatio).floor() * components;
  }
  for (var i = 0; i < h2; i++) {
    final row = (i * yRatio).floor() * w1Scanline;
    for (var j = 0; j < w2; j++) {
      final oldIndex = row + xScaled[j];
      dest[newIndex++] = src[oldIndex];
      dest[newIndex++] = src[oldIndex + 1];
      dest[newIndex++] = src[oldIndex + 2];
      if (alpha01 == 1) {
        newIndex++;
      }
    }
  }
}

void copyRgbaImage(List<int> src, Uint8List dest, int alpha01) {
  var j = 0;
  for (var i = 0; i < src.length; i += 4) {
    dest[j++] = src[i];
    dest[j++] = src[i + 1];
    dest[j++] = src[i + 2];
    j += alpha01;
  }
}

bool isDefaultDecodeHelper(List<num>? decode, int expectedLen) {
  if (decode == null) {
    return true;
  }
  if (decode.length < expectedLen) {
    warn('Decode map length is too short.');
    return true;
  }
  if (decode.length > expectedLen) {
    info('Truncating too long decode map.');
    decode.length = expectedLen;
  }
  return false;
}

abstract class ColorSpace {
  ColorSpace(this.name, this.numComps);

  final String name;
  final int? numComps;
  static final Uint8List _rgbBuf = Uint8List(3);

  Uint8List getRgb(List<num> src, int srcOffset, [Uint8List? output]) {
    final out = output ?? Uint8List(3);
    getRgbItem(src, srcOffset, out, 0);
    return out;
  }

  String getRgbHex(List<num> src, int srcOffset) {
    final buffer = getRgb(src, srcOffset, _rgbBuf);
    return PdfJsUtil.makeHexColor(buffer[0], buffer[1], buffer[2]);
  }

  void getRgbItem(
      List<num> src, int srcOffset, Uint8List dest, int destOffset) {
    throw UnsupportedError('Should not call ColorSpace.getRgbItem');
  }

  void getRgbBuffer(
    List<num> src,
    int srcOffset,
    int count,
    Uint8List dest,
    int destOffset,
    int bits,
    int alpha01,
  ) {
    throw UnsupportedError('Should not call ColorSpace.getRgbBuffer');
  }

  int getOutputLength(int inputLength, int alpha01) {
    throw UnsupportedError('Should not call ColorSpace.getOutputLength');
  }

  bool isPassthrough(int bits) => false;

  bool isDefaultDecode(List<num>? decode, int bpc) {
    return ColorSpace.isDefaultDecodeMap(decode, numComps!);
  }

  void fillRgb(
    Uint8List dest,
    int originalWidth,
    int originalHeight,
    int width,
    int height,
    int actualHeight,
    int bpc,
    List<num> comps,
    int alpha01,
  ) {
    final count = originalWidth * originalHeight;
    Uint8List? rgbBuf;
    final numComponentColors = 1 << bpc;
    final needsResizing = originalHeight != height || originalWidth != width;

    if (isPassthrough(bpc)) {
      rgbBuf = Uint8List.fromList(comps.cast<int>());
    } else if (numComps == 1 &&
        count > numComponentColors &&
        name != 'DeviceGray' &&
        name != 'DeviceRGB') {
      final allColors = List<num>.generate(numComponentColors, (i) => i);
      final colorMap = Uint8List(numComponentColors * 3);
      getRgbBuffer(allColors, 0, numComponentColors, colorMap, 0, bpc, 0);

      if (!needsResizing) {
        var destPos = 0;
        for (var i = 0; i < count; i++) {
          final key = comps[i].toInt() * 3;
          dest[destPos++] = colorMap[key];
          dest[destPos++] = colorMap[key + 1];
          dest[destPos++] = colorMap[key + 2];
          destPos += alpha01;
        }
      } else {
        rgbBuf = Uint8List(count * 3);
        var rgbPos = 0;
        for (var i = 0; i < count; i++) {
          final key = comps[i].toInt() * 3;
          rgbBuf[rgbPos++] = colorMap[key];
          rgbBuf[rgbPos++] = colorMap[key + 1];
          rgbBuf[rgbPos++] = colorMap[key + 2];
        }
      }
    } else if (!needsResizing) {
      getRgbBuffer(comps, 0, width * actualHeight, dest, 0, bpc, alpha01);
    } else {
      rgbBuf = Uint8List(count * 3);
      getRgbBuffer(comps, 0, count, rgbBuf, 0, bpc, 0);
    }

    if (rgbBuf != null) {
      if (needsResizing) {
        resizeRgbImage(
          rgbBuf,
          dest,
          originalWidth,
          originalHeight,
          width,
          height,
          alpha01,
        );
      } else {
        var destPos = 0;
        var rgbPos = 0;
        for (var i = 0; i < width * actualHeight; i++) {
          dest[destPos++] = rgbBuf[rgbPos++];
          dest[destPos++] = rgbBuf[rgbPos++];
          dest[destPos++] = rgbBuf[rgbPos++];
          destPos += alpha01;
        }
      }
    }
  }

  bool get usesZeroToOneRange => true;

  static bool isDefaultDecodeMap(List<num>? decode, int numComps) {
    if (isDefaultDecodeHelper(decode, numComps * 2)) {
      return true;
    }
    for (var i = 0; i < decode!.length; i += 2) {
      if (decode[i] != 0 || decode[i + 1] != 1) {
        return false;
      }
    }
    return true;
  }
}

typedef TintFunction = void Function(
  List<num> src,
  int srcOffset,
  List<num> dest,
  int destOffset,
);

class AlternateCS extends ColorSpace {
  AlternateCS(int numComps, this.base, this.tintFn)
      : tmpBuf = Float32List(base.numComps!),
        super('Alternate', numComps);

  final ColorSpace base;
  final TintFunction tintFn;
  final Float32List tmpBuf;

  @override
  void getRgbItem(
      List<num> src, int srcOffset, Uint8List dest, int destOffset) {
    tintFn(src, srcOffset, tmpBuf, 0);
    base.getRgbItem(tmpBuf, 0, dest, destOffset);
  }

  @override
  void getRgbBuffer(
    List<num> src,
    int srcOffset,
    int count,
    Uint8List dest,
    int destOffset,
    int bits,
    int alpha01,
  ) {
    final scale = 1 / ((1 << bits) - 1);
    final baseNumComps = base.numComps!;
    final usesZeroToOneRange = base.usesZeroToOneRange;
    final isBasePassthrough =
        (base.isPassthrough(8) || !usesZeroToOneRange) && alpha01 == 0;
    var pos = isBasePassthrough ? destOffset : 0;
    final baseBuf = isBasePassthrough ? dest : Uint8List(baseNumComps * count);
    final scaled = Float32List(numComps!);
    final tinted = Float32List(baseNumComps);

    for (var i = 0; i < count; i++) {
      for (var j = 0; j < numComps!; j++) {
        scaled[j] = src[srcOffset++].toDouble() * scale;
      }
      tintFn(scaled, 0, tinted, 0);
      if (usesZeroToOneRange) {
        for (var j = 0; j < baseNumComps; j++) {
          baseBuf[pos++] = (tinted[j] * 255).round().clamp(0, 255);
        }
      } else {
        base.getRgbItem(tinted, 0, baseBuf, pos);
        pos += baseNumComps;
      }
    }

    if (!isBasePassthrough) {
      base.getRgbBuffer(baseBuf, 0, count, dest, destOffset, 8, alpha01);
    }
  }

  @override
  int getOutputLength(int inputLength, int alpha01) {
    return base.getOutputLength(
      (inputLength * base.numComps! ~/ numComps!),
      alpha01,
    );
  }
}

class PatternCS extends ColorSpace {
  PatternCS(this.base) : super('Pattern', null);

  final ColorSpace? base;

  @override
  bool isDefaultDecode(List<num>? decode, int bpc) {
    throw UnsupportedError('Should not call PatternCS.isDefaultDecode');
  }
}

class IndexedCS extends ColorSpace {
  IndexedCS(this.base, this.highVal, dynamic lookup) : super('Indexed', 1) {
    final length = base.numComps! * (highVal + 1);
    this.lookup = Uint8List(length);

    if (lookup is BaseStream) {
      this.lookup.setRange(0, length, lookup.getBytes(length));
    } else if (lookup is String) {
      for (var i = 0; i < length; i++) {
        this.lookup[i] = lookup.codeUnitAt(i) & 0xff;
      }
    } else if (lookup is List<int>) {
      this.lookup.setRange(0, math.min(length, lookup.length), lookup);
    } else {
      throw FormatError('IndexedCS - unrecognized lookup table: $lookup');
    }
  }

  final ColorSpace base;
  final int highVal;
  late final Uint8List lookup;

  @override
  void getRgbItem(
      List<num> src, int srcOffset, Uint8List dest, int destOffset) {
    final start =
        mathClamp(src[srcOffset].round(), 0, highVal).toInt() * base.numComps!;
    base.getRgbBuffer(lookup, start, 1, dest, destOffset, 8, 0);
  }

  @override
  void getRgbBuffer(
    List<num> src,
    int srcOffset,
    int count,
    Uint8List dest,
    int destOffset,
    int bits,
    int alpha01,
  ) {
    final numComps = base.numComps!;
    final outputDelta = base.getOutputLength(numComps, alpha01);
    for (var i = 0; i < count; i++) {
      final lookupPos =
          mathClamp(src[srcOffset++].round(), 0, highVal).toInt() * numComps;
      base.getRgbBuffer(lookup, lookupPos, 1, dest, destOffset, 8, alpha01);
      destOffset += outputDelta;
    }
  }

  @override
  int getOutputLength(int inputLength, int alpha01) {
    return base.getOutputLength(inputLength * base.numComps!, alpha01);
  }

  @override
  bool isDefaultDecode(List<num>? decode, int bpc) {
    if (isDefaultDecodeHelper(decode, 2)) {
      return true;
    }
    if (bpc < 1) {
      warn('Bits per component is not correct');
      return true;
    }
    return decode![0] == 0 && decode[1] == (1 << bpc) - 1;
  }
}

class DeviceGrayCS extends ColorSpace {
  DeviceGrayCS() : super('DeviceGray', 1);

  @override
  void getRgbItem(
      List<num> src, int srcOffset, Uint8List dest, int destOffset) {
    final c = (src[srcOffset] * 255).round().clamp(0, 255);
    dest[destOffset] = c;
    dest[destOffset + 1] = c;
    dest[destOffset + 2] = c;
  }

  @override
  void getRgbBuffer(
    List<num> src,
    int srcOffset,
    int count,
    Uint8List dest,
    int destOffset,
    int bits,
    int alpha01,
  ) {
    final scale = 255 / ((1 << bits) - 1);
    var j = srcOffset;
    var q = destOffset;
    for (var i = 0; i < count; i++) {
      final c = (scale * src[j++]).round().clamp(0, 255);
      dest[q++] = c;
      dest[q++] = c;
      dest[q++] = c;
      q += alpha01;
    }
  }

  @override
  int getOutputLength(int inputLength, int alpha01) =>
      inputLength * (3 + alpha01);
}

class DeviceRgbCS extends ColorSpace {
  DeviceRgbCS() : super('DeviceRGB', 3);

  @override
  void getRgbItem(
      List<num> src, int srcOffset, Uint8List dest, int destOffset) {
    dest[destOffset] = (src[srcOffset] * 255).round().clamp(0, 255);
    dest[destOffset + 1] = (src[srcOffset + 1] * 255).round().clamp(0, 255);
    dest[destOffset + 2] = (src[srcOffset + 2] * 255).round().clamp(0, 255);
  }

  @override
  void getRgbBuffer(
    List<num> src,
    int srcOffset,
    int count,
    Uint8List dest,
    int destOffset,
    int bits,
    int alpha01,
  ) {
    if (bits == 8 && alpha01 == 0) {
      dest.setRange(
        destOffset,
        destOffset + count * 3,
        src.cast<int>(),
        srcOffset,
      );
      return;
    }
    final scale = 255 / ((1 << bits) - 1);
    var j = srcOffset;
    var q = destOffset;
    for (var i = 0; i < count; i++) {
      dest[q++] = (scale * src[j++]).round().clamp(0, 255);
      dest[q++] = (scale * src[j++]).round().clamp(0, 255);
      dest[q++] = (scale * src[j++]).round().clamp(0, 255);
      q += alpha01;
    }
  }

  @override
  int getOutputLength(int inputLength, int alpha01) {
    return inputLength * (3 + alpha01) ~/ 3;
  }

  @override
  bool isPassthrough(int bits) => bits == 8;
}

class DeviceRgbaCS extends ColorSpace {
  DeviceRgbaCS() : super('DeviceRGBA', 4);

  @override
  int getOutputLength(int inputLength, int alpha01) => inputLength * 4;

  @override
  bool isPassthrough(int bits) => bits == 8;

  @override
  void fillRgb(
    Uint8List dest,
    int originalWidth,
    int originalHeight,
    int width,
    int height,
    int actualHeight,
    int bpc,
    List<num> comps,
    int alpha01,
  ) {
    if (originalHeight != height || originalWidth != width) {
      resizeRgbaImage(comps.cast<int>(), dest, originalWidth, originalHeight,
          width, height, alpha01);
    } else {
      copyRgbaImage(comps.cast<int>(), dest, alpha01);
    }
  }
}

class DeviceCmykCS extends ColorSpace {
  DeviceCmykCS() : super('DeviceCMYK', 4);

  void _toRgb(
    List<num> src,
    int srcOffset,
    double srcScale,
    Uint8List dest,
    int destOffset,
  ) {
    final c = src[srcOffset] * srcScale;
    final m = src[srcOffset + 1] * srcScale;
    final y = src[srcOffset + 2] * srcScale;
    final k = src[srcOffset + 3] * srcScale;

    dest[destOffset] = (255 +
            c *
                (-4.387332384609988 * c +
                    54.48615194189176 * m +
                    18.82290502165302 * y +
                    212.25662451639585 * k +
                    -285.2331026137004) +
            m *
                (1.7149763477362134 * m -
                    5.6096736904047315 * y +
                    -17.873870861415444 * k -
                    5.497006427196366) +
            y *
                (-2.5217340131683033 * y -
                    21.248923337353073 * k +
                    17.5119270841813) +
            k * (-21.86122147463605 * k - 189.48180835922747))
        .round()
        .clamp(0, 255);

    dest[destOffset + 1] = (255 +
            c *
                (8.841041422036149 * c +
                    60.118027045597366 * m +
                    6.871425592049007 * y +
                    31.159100130055922 * k +
                    -79.2970844816548) +
            m *
                (-15.310361306967817 * m +
                    17.575251261109482 * y +
                    131.35250912493976 * k -
                    190.9453302588951) +
            y *
                (4.444339102852739 * y +
                    9.8632861493405 * k -
                    24.86741582555878) +
            k * (-20.737325471181034 * k - 187.80453709719578))
        .round()
        .clamp(0, 255);

    dest[destOffset + 2] = (255 +
            c *
                (0.8842522430003296 * c +
                    8.078677503112928 * m +
                    30.89978309703729 * y -
                    0.23883238689178934 * k -
                    14.183576799673286) +
            m *
                (10.49593273432072 * m +
                    63.02378494754052 * y +
                    50.606957656360734 * k -
                    112.23884253719248) +
            y *
                (0.03296041114873217 * y +
                    115.60384449646641 * k -
                    193.58209356861505) +
            k * (-22.33816807309886 * k - 180.12613974708367))
        .round()
        .clamp(0, 255);
  }

  @override
  void getRgbItem(
      List<num> src, int srcOffset, Uint8List dest, int destOffset) {
    _toRgb(src, srcOffset, 1, dest, destOffset);
  }

  @override
  void getRgbBuffer(
    List<num> src,
    int srcOffset,
    int count,
    Uint8List dest,
    int destOffset,
    int bits,
    int alpha01,
  ) {
    final scale = 1 / ((1 << bits) - 1);
    for (var i = 0; i < count; i++) {
      _toRgb(src, srcOffset, scale, dest, destOffset);
      srcOffset += 4;
      destOffset += 3 + alpha01;
    }
  }

  @override
  int getOutputLength(int inputLength, int alpha01) {
    return inputLength * (3 + alpha01) ~/ 4;
  }
}

class CalGrayCS extends ColorSpace {
  CalGrayCS(List<num>? whitePoint, List<num>? blackPoint, num? gamma)
      : super('CalGray', 1) {
    if (whitePoint == null) {
      throw FormatError(
          'WhitePoint missing - required for color space CalGray');
    }
    xw = whitePoint[0].toDouble();
    yw = whitePoint[1].toDouble();
    zw = whitePoint[2].toDouble();
    xb = blackPoint?[0].toDouble() ?? 0;
    yb = blackPoint?[1].toDouble() ?? 0;
    zb = blackPoint?[2].toDouble() ?? 0;
    g = gamma?.toDouble() ?? 1;

    if (xw < 0 || zw < 0 || yw != 1) {
      throw FormatError(
          'Invalid WhitePoint components for $name, no fallback available');
    }
    if (xb < 0 || yb < 0 || zb < 0) {
      info('Invalid BlackPoint for $name, falling back to default.');
      xb = yb = zb = 0;
    }
    if (xb != 0 || yb != 0 || zb != 0) {
      warn(
          '$name, BlackPoint: XB: $xb, YB: $yb, ZB: $zb, only default values are supported.');
    }
    if (g < 1) {
      info('Invalid Gamma: $g for $name, falling back to default.');
      g = 1;
    }
  }

  late double xw;
  late double yw;
  late double zw;
  late double xb;
  late double yb;
  late double zb;
  late double g;

  void _toRgb(List<num> src, int srcOffset, Uint8List dest, int destOffset,
      double scale) {
    final a = src[srcOffset] * scale;
    final ag = math.pow(a, g);
    final l = yw * ag;
    final val =
        math.max(295.8 * math.pow(l, 0.3333333333333333) - 40.8, 0).round();
    final c = val.clamp(0, 255);
    dest[destOffset] = c;
    dest[destOffset + 1] = c;
    dest[destOffset + 2] = c;
  }

  @override
  void getRgbItem(
      List<num> src, int srcOffset, Uint8List dest, int destOffset) {
    _toRgb(src, srcOffset, dest, destOffset, 1);
  }

  @override
  void getRgbBuffer(
    List<num> src,
    int srcOffset,
    int count,
    Uint8List dest,
    int destOffset,
    int bits,
    int alpha01,
  ) {
    final scale = 1 / ((1 << bits) - 1);
    for (var i = 0; i < count; i++) {
      _toRgb(src, srcOffset, dest, destOffset, scale);
      srcOffset++;
      destOffset += 3 + alpha01;
    }
  }

  @override
  int getOutputLength(int inputLength, int alpha01) =>
      inputLength * (3 + alpha01);
}

class CalRGBCS extends ColorSpace {
  static final Float32List _bradfordScaleMatrix = Float32List.fromList([
    0.8951, 0.2664, -0.1614,
    -0.7502, 1.7135, 0.0367,
    0.0389, -0.0685, 1.0296,
  ]);

  static final Float32List _bradfordScaleInverseMatrix = Float32List.fromList([
    0.9869929, -0.1470543, 0.1599627,
    0.4323053, 0.5183603, 0.0492912,
    -0.0085287, 0.0400428, 0.9684867,
  ]);

  static final Float32List _srgbD65XyzToRgbMatrix = Float32List.fromList([
    3.2404542, -1.5371385, -0.4985314,
    -0.9692660, 1.8760108, 0.0415560,
    0.0556434, -0.2040259, 1.0572252,
  ]);

  static final Float32List _flatWhitepointMatrix =
      Float32List.fromList([1.0, 1.0, 1.0]);

  static final double _decodeLConstant =
      math.pow((8.0 + 16.0) / 116.0, 3) / 8.0;

  late Float32List whitePoint;
  late Float32List blackPoint;
  late double gr;
  late double gg;
  late double gb;
  late double mxa;
  late double mya;
  late double mza;
  late double mxb;
  late double myb;
  late double mzb;
  late double mxc;
  late double myc;
  late double mzc;

  CalRGBCS(
    List<num>? whitePoint,
    List<num>? blackPoint,
    List<num>? gamma,
    List<num>? matrix,
  ) : super('CalRGB', 3) {
    if (whitePoint == null || whitePoint.length < 3) {
      throw FormatError('WhitePoint missing - required for color space CalRGB');
    }
    this.whitePoint = Float32List.fromList([
      whitePoint[0].toDouble(),
      whitePoint[1].toDouble(),
      whitePoint[2].toDouble(),
    ]);
    if (blackPoint != null && blackPoint.length >= 3) {
      this.blackPoint = Float32List.fromList([
        blackPoint[0].toDouble(),
        blackPoint[1].toDouble(),
        blackPoint[2].toDouble(),
      ]);
    } else {
      this.blackPoint = Float32List(3);
    }

    if (gamma != null && gamma.length >= 3) {
      gr = gamma[0].toDouble();
      gg = gamma[1].toDouble();
      gb = gamma[2].toDouble();
    } else {
      gr = gg = gb = 1.0;
    }

    if (matrix != null && matrix.length >= 9) {
      mxa = matrix[0].toDouble();
      mya = matrix[1].toDouble();
      mza = matrix[2].toDouble();
      mxb = matrix[3].toDouble();
      myb = matrix[4].toDouble();
      mzb = matrix[5].toDouble();
      mxc = matrix[6].toDouble();
      myc = matrix[7].toDouble();
      mzc = matrix[8].toDouble();
    } else {
      mxa = 1.0;
      mya = 0.0;
      mza = 0.0;
      mxb = 0.0;
      myb = 1.0;
      mzb = 0.0;
      mxc = 0.0;
      myc = 0.0;
      mzc = 1.0;
    }

    final xw = this.whitePoint[0];
    final yw = this.whitePoint[1];
    final zw = this.whitePoint[2];
    if (xw < 0 || zw < 0 || yw != 1.0) {
      throw FormatError(
        'Invalid WhitePoint components for $name, no fallback available',
      );
    }

    final xb = this.blackPoint[0];
    final yb = this.blackPoint[1];
    final zb = this.blackPoint[2];
    if (xb < 0 || yb < 0 || zb < 0) {
      info(
          'Invalid BlackPoint for $name [$xb, $yb, $zb], falling back to default.');
      this.blackPoint = Float32List(3);
    }

    if (gr < 0 || gg < 0 || gb < 0) {
      info('Invalid Gamma [$gr, $gg, $gb] for $name, falling back to default.');
      gr = gg = gb = 1.0;
    }
  }

  void _matrixProduct(Float32List a, Float32List b, Float32List result) {
    result[0] = a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
    result[1] = a[3] * b[0] + a[4] * b[1] + a[5] * b[2];
    result[2] = a[6] * b[0] + a[7] * b[1] + a[8] * b[2];
  }

  void _toFlat(
      Float32List sourceWhitePoint, Float32List lms, Float32List result) {
    result[0] = (lms[0] * 1.0) / sourceWhitePoint[0];
    result[1] = (lms[1] * 1.0) / sourceWhitePoint[1];
    result[2] = (lms[2] * 1.0) / sourceWhitePoint[2];
  }

  void _toD65(
      Float32List sourceWhitePoint, Float32List lms, Float32List result) {
    const d65x = 0.95047;
    const d65y = 1.0;
    const d65z = 1.08883;

    result[0] = (lms[0] * d65x) / sourceWhitePoint[0];
    result[1] = (lms[1] * d65y) / sourceWhitePoint[1];
    result[2] = (lms[2] * d65z) / sourceWhitePoint[2];
  }

  double _srgbTransferFunction(double color) {
    if (color <= 0.0031308) {
      return mathClamp(12.92 * color, 0.0, 1.0).toDouble();
    }
    if (color >= 0.99554525) {
      return 1.0;
    }
    return mathClamp(
      (1.0 + 0.055) * math.pow(color, 1.0 / 2.4) - 0.055,
      0.0,
      1.0,
    ).toDouble();
  }

  double _decodeL(double l) {
    if (l < 0) {
      return -_decodeL(-l);
    }
    if (l > 8.0) {
      return math.pow((l + 16.0) / 116.0, 3).toDouble();
    }
    return l * _decodeLConstant;
  }

  void _compensateBlackPoint(
    Float32List sourceBlackPoint,
    Float32List xyzFlat,
    Float32List result,
  ) {
    if (sourceBlackPoint[0] == 0 &&
        sourceBlackPoint[1] == 0 &&
        sourceBlackPoint[2] == 0) {
      result[0] = xyzFlat[0];
      result[1] = xyzFlat[1];
      result[2] = xyzFlat[2];
      return;
    }

    final zeroDecodeL = _decodeL(0);
    final xDst = zeroDecodeL;
    final xSrc = _decodeL(sourceBlackPoint[0]);
    final yDst = zeroDecodeL;
    final ySrc = _decodeL(sourceBlackPoint[1]);
    final zDst = zeroDecodeL;
    final zSrc = _decodeL(sourceBlackPoint[2]);

    final xScale = (1.0 - xDst) / (1.0 - xSrc);
    final xOffset = 1.0 - xScale;
    final yScale = (1.0 - yDst) / (1.0 - ySrc);
    final yOffset = 1.0 - yScale;
    final zScale = (1.0 - zDst) / (1.0 - zSrc);
    final zOffset = 1.0 - zScale;

    result[0] = xyzFlat[0] * xScale + xOffset;
    result[1] = xyzFlat[1] * yScale + yOffset;
    result[2] = xyzFlat[2] * zScale + zOffset;
  }

  void _normalizeWhitePointToFlat(
    Float32List sourceWhitePoint,
    Float32List xyzIn,
    Float32List result,
    Float32List tempNorm,
  ) {
    if (sourceWhitePoint[0] == 1.0 && sourceWhitePoint[2] == 1.0) {
      result[0] = xyzIn[0];
      result[1] = xyzIn[1];
      result[2] = xyzIn[2];
      return;
    }
    _matrixProduct(_bradfordScaleMatrix, xyzIn, result);
    _toFlat(sourceWhitePoint, result, tempNorm);
    _matrixProduct(_bradfordScaleInverseMatrix, tempNorm, result);
  }

  void _normalizeWhitePointToD65(
    Float32List sourceWhitePoint,
    Float32List xyzIn,
    Float32List result,
    Float32List tempNorm,
  ) {
    _matrixProduct(_bradfordScaleMatrix, xyzIn, result);
    _toD65(sourceWhitePoint, result, tempNorm);
    _matrixProduct(_bradfordScaleInverseMatrix, tempNorm, result);
  }

  void _toRgb(
    List<num> src,
    int srcOffset,
    Uint8List dest,
    int destOffset,
    double scale,
    Float32List xyz,
    Float32List xyzFlat,
    Float32List tempNorm,
  ) {
    final a = mathClamp(src[srcOffset] * scale, 0.0, 1.0).toDouble();
    final b = mathClamp(src[srcOffset + 1] * scale, 0.0, 1.0).toDouble();
    final c = mathClamp(src[srcOffset + 2] * scale, 0.0, 1.0).toDouble();

    final agr = a == 1.0 ? 1.0 : math.pow(a, gr).toDouble();
    final bgg = b == 1.0 ? 1.0 : math.pow(b, gg).toDouble();
    final cgb = c == 1.0 ? 1.0 : math.pow(c, gb).toDouble();

    final x = mxa * agr + mxb * bgg + mxc * cgb;
    final y = mya * agr + myb * bgg + myc * cgb;
    final z = mza * agr + mzb * bgg + mzc * cgb;

    xyz[0] = x;
    xyz[1] = y;
    xyz[2] = z;

    _normalizeWhitePointToFlat(whitePoint, xyz, xyzFlat, tempNorm);
    _compensateBlackPoint(blackPoint, xyzFlat, xyz);
    _normalizeWhitePointToD65(_flatWhitepointMatrix, xyz, xyzFlat, tempNorm);
    _matrixProduct(_srgbD65XyzToRgbMatrix, xyzFlat, xyz);

    dest[destOffset] =
        mathClamp((_srgbTransferFunction(xyz[0]) * 255).round(), 0, 255)
            .toInt();
    dest[destOffset + 1] =
        mathClamp((_srgbTransferFunction(xyz[1]) * 255).round(), 0, 255)
            .toInt();
    dest[destOffset + 2] =
        mathClamp((_srgbTransferFunction(xyz[2]) * 255).round(), 0, 255)
            .toInt();
  }

  @override
  void getRgbItem(
    List<num> src,
    int srcOffset,
    Uint8List dest,
    int destOffset,
  ) {
    final xyz = Float32List(3);
    final xyzFlat = Float32List(3);
    final tempNorm = Float32List(3);
    _toRgb(src, srcOffset, dest, destOffset, 1.0, xyz, xyzFlat, tempNorm);
  }

  @override
  void getRgbBuffer(
    List<num> src,
    int srcOffset,
    int count,
    Uint8List dest,
    int destOffset,
    int bits,
    int alpha01,
  ) {
    final scale = 1.0 / ((1 << bits) - 1);
    final xyz = Float32List(3);
    final xyzFlat = Float32List(3);
    final tempNorm = Float32List(3);

    for (var i = 0; i < count; i++) {
      _toRgb(src, srcOffset, dest, destOffset, scale, xyz, xyzFlat, tempNorm);
      srcOffset += 3;
      destOffset += 3 + alpha01;
    }
  }

  @override
  int getOutputLength(int inputLength, int alpha01) {
    return (inputLength * (3 + alpha01)) ~/ 3;
  }
}

class LabCS extends ColorSpace {
  late double xw;
  late double yw;
  late double zw;
  late double amin;
  late double amax;
  late double bmin;
  late double bmax;
  late double xb;
  late double yb;
  late double zb;

  LabCS(List<num>? whitePoint, List<num>? blackPoint, List<num>? range)
      : super('Lab', 3) {
    if (whitePoint == null || whitePoint.length < 3) {
      throw FormatError('WhitePoint missing - required for color space Lab');
    }
    xw = whitePoint[0].toDouble();
    yw = whitePoint[1].toDouble();
    zw = whitePoint[2].toDouble();

    if (range != null && range.length >= 4) {
      amin = range[0].toDouble();
      amax = range[1].toDouble();
      bmin = range[2].toDouble();
      bmax = range[3].toDouble();
    } else {
      amin = -100.0;
      amax = 100.0;
      bmin = -100.0;
      bmax = 100.0;
    }

    if (blackPoint != null && blackPoint.length >= 3) {
      xb = blackPoint[0].toDouble();
      yb = blackPoint[1].toDouble();
      zb = blackPoint[2].toDouble();
    } else {
      xb = yb = zb = 0.0;
    }

    if (xw < 0 || zw < 0 || yw != 1.0) {
      throw FormatError('Invalid WhitePoint components, no fallback available');
    }
    if (xb < 0 || yb < 0 || zb < 0) {
      info('Invalid BlackPoint, falling back to default');
      xb = yb = zb = 0.0;
    }
    if (amin > amax || bmin > bmax) {
      info('Invalid Range, falling back to defaults');
      amin = -100.0;
      amax = 100.0;
      bmin = -100.0;
      bmax = 100.0;
    }
  }

  double _fnG(double x) {
    return x >= 6.0 / 29.0
        ? math.pow(x, 3).toDouble()
        : (108.0 / 841.0) * (x - 4.0 / 29.0);
  }

  double _decode(double value, double high1, double low2, double high2) {
    return low2 + (value * (high2 - low2)) / high1;
  }

  void _toRgb(
    List<num> src,
    int srcOffset,
    dynamic maxVal,
    Uint8List dest,
    int destOffset,
  ) {
    var ls = src[srcOffset].toDouble();
    var as = src[srcOffset + 1].toDouble();
    var bs = src[srcOffset + 2].toDouble();

    if (maxVal is num) {
      final mv = maxVal.toDouble();
      ls = _decode(ls, mv, 0.0, 100.0);
      as = _decode(as, mv, amin, amax);
      bs = _decode(bs, mv, bmin, bmax);
    }

    if (as > amax) {
      as = amax;
    } else if (as < amin) {
      as = amin;
    }
    if (bs > bmax) {
      bs = bmax;
    } else if (bs < bmin) {
      bs = bmin;
    }

    final m = (ls + 16.0) / 116.0;
    final l = m + as / 500.0;
    final n = m - bs / 200.0;

    final x = xw * _fnG(l);
    final y = yw * _fnG(m);
    final z = zw * _fnG(n);

    double r, g, b;
    if (zw < 1.0) {
      // D50
      r = x * 3.1339 + y * -1.617 + z * -0.4906;
      g = x * -0.9785 + y * 1.916 + z * 0.0333;
      b = x * 0.072 + y * -0.229 + z * 1.4057;
    } else {
      // D65
      r = x * 3.2406 + y * -1.5372 + z * -0.4986;
      g = x * -0.9689 + y * 1.8758 + z * 0.0415;
      b = x * 0.0557 + y * -0.204 + z * 1.057;
    }

    dest[destOffset] = (math.sqrt(r.clamp(0.0, double.infinity)) * 255.0)
        .round()
        .clamp(0, 255);
    dest[destOffset + 1] = (math.sqrt(g.clamp(0.0, double.infinity)) * 255.0)
        .round()
        .clamp(0, 255);
    dest[destOffset + 2] = (math.sqrt(b.clamp(0.0, double.infinity)) * 255.0)
        .round()
        .clamp(0, 255);
  }

  @override
  void getRgbItem(
    List<num> src,
    int srcOffset,
    Uint8List dest,
    int destOffset,
  ) {
    _toRgb(src, srcOffset, false, dest, destOffset);
  }

  @override
  void getRgbBuffer(
    List<num> src,
    int srcOffset,
    int count,
    Uint8List dest,
    int destOffset,
    int bits,
    int alpha01,
  ) {
    final maxVal = (1 << bits) - 1;
    for (var i = 0; i < count; i++) {
      _toRgb(src, srcOffset, maxVal, dest, destOffset);
      srcOffset += 3;
      destOffset += 3 + alpha01;
    }
  }

  @override
  int getOutputLength(int inputLength, int alpha01) {
    return (inputLength * (3 + alpha01)) ~/ 3;
  }

  @override
  bool isDefaultDecode(List<num>? decode, int bpc) => true;

  @override
  bool get usesZeroToOneRange => false;
}

