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

class CalRGBCS extends DeviceRgbCS {
  CalRGBCS(List<num>? whitePoint, List<num>? blackPoint, List<num>? gamma,
      List<num>? matrix);
}

class LabCS extends ColorSpace {
  LabCS(List<num>? whitePoint, List<num>? blackPoint, List<num>? range)
      : super('Lab', 3);

  @override
  bool get usesZeroToOneRange => false;
}
