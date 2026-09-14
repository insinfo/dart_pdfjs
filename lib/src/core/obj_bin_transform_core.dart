// Copyright 2025 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:convert';
import 'dart:typed_data';

import '../shared/obj_bin_transform_utils.dart';

ByteBuffer compileCssFontInfo(Map<String, dynamic> info) {
  final encodedStrings = <String, List<int>>{};
  var stringsLength = 0;
  for (final prop in CSS_FONT_INFO.strings) {
    final str = info[prop]?.toString() ?? '';
    final encoded = utf8.encode(str);
    encodedStrings[prop] = encoded;
    stringsLength += 4 + encoded.length;
  }

  final bytes = Uint8List(stringsLength);
  final view = ByteData.sublistView(bytes);
  var offset = 0;

  for (final prop in CSS_FONT_INFO.strings) {
    final encoded = encodedStrings[prop]!;
    final length = encoded.length;
    view.setUint32(offset, length, Endian.big);
    bytes.setRange(offset + 4, offset + 4 + length, encoded);
    offset += 4 + length;
  }
  return bytes.buffer;
}

ByteBuffer compileSystemFontInfo(Map<String, dynamic> info) {
  final encodedStrings = <String, List<int>>{};
  var stringsLength = 0;
  for (final prop in SYSTEM_FONT_INFO.strings) {
    final str = info[prop]?.toString() ?? '';
    final encoded = utf8.encode(str);
    encodedStrings[prop] = encoded;
    stringsLength += 4 + encoded.length;
  }
  stringsLength += 4;
  List<int>? encodedStyleStyle;
  List<int>? encodedStyleWeight;
  var lengthEstimate = 1 + stringsLength;

  final dynamic style = info['style'];
  if (style != null && style is Map) {
    encodedStyleStyle = utf8.encode(style['style']?.toString() ?? '');
    encodedStyleWeight = utf8.encode(style['weight']?.toString() ?? '');
    lengthEstimate +=
        4 + encodedStyleStyle.length + 4 + encodedStyleWeight.length;
  }

  final bytes = Uint8List(lengthEstimate);
  final view = ByteData.sublistView(bytes);
  var offset = 0;

  view.setUint8(offset++, (info['guessFallback'] == true) ? 1 : 0);
  view.setUint32(offset, 0, Endian.big);
  offset += 4;
  stringsLength = 0;
  for (final prop in SYSTEM_FONT_INFO.strings) {
    final encoded = encodedStrings[prop]!;
    final length = encoded.length;
    stringsLength += 4 + length;
    view.setUint32(offset, length, Endian.big);
    bytes.setRange(offset + 4, offset + 4 + length, encoded);
    offset += 4 + length;
  }
  view.setUint32(offset - stringsLength - 4, stringsLength, Endian.big);

  if (encodedStyleStyle != null && encodedStyleWeight != null) {
    view.setUint32(offset, encodedStyleStyle.length, Endian.big);
    bytes.setRange(
        offset + 4, offset + 4 + encodedStyleStyle.length, encodedStyleStyle);
    offset += 4 + encodedStyleStyle.length;

    view.setUint32(offset, encodedStyleWeight.length, Endian.big);
    bytes.setRange(
        offset + 4, offset + 4 + encodedStyleWeight.length, encodedStyleWeight);
    offset += 4 + encodedStyleWeight.length;
  }

  return bytes.sublist(0, offset).buffer;
}

ByteBuffer compileFontInfo(dynamic font) {
  final dynamic systemFontInfo = (font is Map)
      ? font['systemFontInfo']
      : (font as dynamic).systemFontInfo;
  final ByteBuffer? systemFontInfoBuffer = systemFontInfo != null
      ? compileSystemFontInfo(systemFontInfo as Map<String, dynamic>)
      : null;

  final dynamic cssFontInfo =
      (font is Map) ? font['cssFontInfo'] : (font as dynamic).cssFontInfo;
  final ByteBuffer? cssFontInfoBuffer = cssFontInfo != null
      ? compileCssFontInfo(cssFontInfo as Map<String, dynamic>)
      : null;

  final encodedStrings = <String, List<int>>{};
  var stringsLength = 0;
  for (final prop in FONT_INFO.strings) {
    final dynamic val = (font is Map) ? font[prop] : null;
    final str = val?.toString() ?? '';
    final encoded = utf8.encode(str);
    encodedStrings[prop] = encoded;
    stringsLength += 4 + encoded.length;
  }

  final dynamic fontData =
      (font is Map) ? font['data'] : (font as dynamic).data;
  final List<int>? fontDataBytes = fontData is List<int>
      ? fontData
      : (fontData is TypedData
          ? (fontData as dynamic).buffer.asUint8List() as List<int>
          : null);

  final lengthEstimate = FONT_INFO.offsetStrings +
      4 +
      stringsLength +
      4 +
      (systemFontInfoBuffer?.lengthInBytes ?? 0) +
      4 +
      (cssFontInfoBuffer?.lengthInBytes ?? 0) +
      4 +
      (fontDataBytes?.length ?? 0);

  final bytes = Uint8List(lengthEstimate);
  final view = ByteData.sublistView(bytes);
  var offset = 0;

  final numBools = FONT_INFO.bools.length;
  var boolByte = 0;
  var boolBit = 0;
  for (var i = 0; i < numBools; i++) {
    final propName = FONT_INFO.bools[i];
    final dynamic value = (font is Map) ? font[propName] : null;
    final int bits = value == null ? 0x00 : (value == true ? 0x02 : 0x01);
    boolByte |= bits << boolBit;
    boolBit += 2;
    if (boolBit == 8 || i == numBools - 1) {
      view.setUint8(offset++, boolByte);
      boolByte = 0;
      boolBit = 0;
    }
  }

  for (final prop in FONT_INFO.numbers) {
    final dynamic val = (font is Map) ? font[prop] : null;
    final num numVal = val is num ? val : 0;
    view.setFloat64(offset, numVal.toDouble(), Endian.big);
    offset += 8;
  }

  final dynamic bbox = (font is Map) ? font['bbox'] : null;
  if (bbox is List && bbox.isNotEmpty) {
    view.setUint8(offset++, 4);
    for (var i = 0; i < 4; i++) {
      final coord =
          (i < bbox.length && bbox[i] is num) ? (bbox[i] as num).toInt() : 0;
      view.setInt16(offset, coord, Endian.little);
      offset += 2;
    }
  } else {
    view.setUint8(offset++, 0);
    offset += 2 * 4;
  }

  final dynamic fontMatrix = (font is Map) ? font['fontMatrix'] : null;
  if (fontMatrix is List && fontMatrix.isNotEmpty) {
    view.setUint8(offset++, 6);
    for (var i = 0; i < 6; i++) {
      final pt = (i < fontMatrix.length && fontMatrix[i] is num)
          ? (fontMatrix[i] as num).toDouble()
          : 0.0;
      view.setFloat64(offset, pt, Endian.little);
      offset += 8;
    }
  } else {
    view.setUint8(offset++, 0);
    offset += 8 * 6;
  }

  final dynamic defaultVMetrics =
      (font is Map) ? font['defaultVMetrics'] : null;
  if (defaultVMetrics is List && defaultVMetrics.isNotEmpty) {
    view.setUint8(offset++, 3);
    for (var i = 0; i < 3; i++) {
      final metric =
          (i < defaultVMetrics.length && defaultVMetrics[i] is num)
              ? (defaultVMetrics[i] as num).toInt()
              : 0;
      view.setInt16(offset, metric, Endian.little);
      offset += 2;
    }
  } else {
    view.setUint8(offset++, 0);
    offset += 3 * 2;
  }

  view.setUint32(FONT_INFO.offsetStrings, 0, Endian.big);
  offset += 4;
  for (final prop in FONT_INFO.strings) {
    final encoded = encodedStrings[prop]!;
    final length = encoded.length;
    view.setUint32(offset, length, Endian.big);
    bytes.setRange(offset + 4, offset + 4 + length, encoded);
    offset += 4 + length;
  }
  view.setUint32(
    FONT_INFO.offsetStrings,
    offset - FONT_INFO.offsetStrings - 4,
    Endian.big,
  );

  if (systemFontInfoBuffer == null) {
    view.setUint32(offset, 0, Endian.big);
    offset += 4;
  } else {
    final length = systemFontInfoBuffer.lengthInBytes;
    view.setUint32(offset, length, Endian.big);
    bytes.setRange(
        offset + 4, offset + 4 + length, Uint8List.view(systemFontInfoBuffer));
    offset += 4 + length;
  }

  if (cssFontInfoBuffer == null) {
    view.setUint32(offset, 0, Endian.big);
    offset += 4;
  } else {
    final length = cssFontInfoBuffer.lengthInBytes;
    view.setUint32(offset, length, Endian.big);
    bytes.setRange(
        offset + 4, offset + 4 + length, Uint8List.view(cssFontInfoBuffer));
    offset += 4 + length;
  }

  if (fontDataBytes == null) {
    view.setUint32(offset, 0, Endian.big);
    offset += 4;
  } else {
    view.setUint32(offset, fontDataBytes.length, Endian.big);
    bytes.setRange(offset + 4, offset + 4 + fontDataBytes.length, fontDataBytes);
    offset += 4 + fontDataBytes.length;
  }

  return bytes.sublist(0, offset).buffer;
}

ByteBuffer compilePatternInfo(List<dynamic> ir) {
  int kind;
  List<num>? bbox;
  List<num> coords = [];
  List<int> colors = [];
  List<dynamic> colorStops = [];
  int? shadingType;
  List<int>? background;

  switch (ir[0]) {
    case 'RadialAxial':
      kind = ir[1] == 'axial' ? 1 : 2;
      bbox = ir[2] is List ? (ir[2] as List).cast<num>() : null;
      colorStops = ir[3] is List ? ir[3] as List : [];
      if (kind == 1) {
        coords.addAll((ir[4] as List).cast<num>());
        coords.addAll((ir[5] as List).cast<num>());
      } else {
        final p0 = ir[4] as List;
        final p1 = ir[5] as List;
        coords.addAll([
          p0[0] as num,
          p0[1] as num,
          ir[6] as num,
          p1[0] as num,
          p1[1] as num,
          ir[7] as num
        ]);
      }
      break;
    case 'Mesh':
      kind = 3;
      shadingType = ir[1] is num ? (ir[1] as num).toInt() : null;
      coords = ir[2] is List ? (ir[2] as List).cast<num>() : [];
      colors = ir[3] is List
          ? (ir[3] as List).cast<int>()
          : (ir[3] is TypedData ? (ir[3] as dynamic) as List<int> : []);
      bbox = ir[6] is List ? (ir[6] as List).cast<num>() : null;
      background = ir[7] is List ? (ir[7] as List).cast<int>() : null;
      break;
    default:
      throw UnsupportedError('Unsupported pattern type: ${ir[0]}');
  }

  final nCoord = coords.length ~/ 2;
  final nColor = colors.length ~/ 4;
  final nStop = colorStops.length;

  final byteLen = 20 +
      nCoord * 8 +
      nColor * 4 +
      nStop * 8 +
      (bbox != null ? 16 : 0) +
      (background != null ? 3 : 0);

  final bytes = Uint8List(byteLen);
  final dataView = ByteData.sublistView(bytes);

  dataView.setUint8(PATTERN_INFO.kind, kind);
  dataView.setUint8(PATTERN_INFO.hasBbox, bbox != null ? 1 : 0);
  dataView.setUint8(PATTERN_INFO.hasBackground, background != null ? 1 : 0);
  dataView.setUint8(PATTERN_INFO.shadingType, shadingType ?? 0);
  dataView.setUint32(PATTERN_INFO.nCoord, nCoord, Endian.little);
  dataView.setUint32(PATTERN_INFO.nColor, nColor, Endian.little);
  dataView.setUint32(PATTERN_INFO.nStop, nStop, Endian.little);
  dataView.setUint32(PATTERN_INFO.nFigures, 0, Endian.little);

  var offset = 20;
  final floatView = Float32List.view(bytes.buffer, offset, nCoord * 2);
  for (var i = 0; i < coords.length; i++) {
    floatView[i] = coords[i].toDouble();
  }
  offset += nCoord * 8;

  bytes.setRange(offset, offset + colors.length, colors);
  offset += nColor * 4;

  for (final stop in colorStops) {
    if (stop is List && stop.length >= 2) {
      final pos = (stop[0] as num).toDouble();
      final hex = stop[1].toString();
      dataView.setFloat32(offset, pos, Endian.little);
      offset += 4;
      final hexVal = hex.startsWith('#') ? hex.substring(1) : hex;
      dataView.setUint32(offset, int.parse(hexVal, radix: 16), Endian.little);
      offset += 4;
    }
  }

  if (bbox != null) {
    for (final v in bbox) {
      dataView.setFloat32(offset, v.toDouble(), Endian.little);
      offset += 4;
    }
  }

  if (background != null) {
    bytes.setRange(offset, offset + background.length, background);
  }

  return bytes.buffer;
}

ByteBuffer compileFontPathInfo(TypedData path) {
  if (path is Float32List) {
    return Float32List.fromList(path).buffer;
  }
  final u8 = path.buffer.asUint8List(path.offsetInBytes, path.lengthInBytes);
  return Uint8List.fromList(u8).buffer;
}
