// Copyright 2025 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:convert';
import 'dart:typed_data';

import '../shared/obj_bin_transform_utils.dart';
import '../shared/util.dart';

class SystemFontStyle {
  final String? style;
  final String? weight;

  const SystemFontStyle({this.style, this.weight});

  dynamic operator [](String key) {
    if (key == 'style') return style;
    if (key == 'weight') return weight;
    return null;
  }
}

class CssFontInfo {
  final ByteBuffer _buffer;
  final ByteData _view;

  CssFontInfo(ByteBuffer buffer)
      : _buffer = buffer,
        _view = ByteData.sublistView(Uint8List.view(buffer));

  String _readString(int index) {
    assert(index < CSS_FONT_INFO.strings.length, 'Invalid string index');
    var offset = 0;
    for (var i = 0; i < index; i++) {
      offset += _view.getUint32(offset, Endian.big) + 4;
    }
    final length = _view.getUint32(offset, Endian.big);
    final bytes = Uint8List.view(_buffer, offset + 4, length);
    return utf8.decode(bytes);
  }

  String get fontFamily => _readString(0);
  String get fontWeight => _readString(1);
  String get italicAngle => _readString(2);
}

class SystemFontInfo {
  final ByteBuffer _buffer;
  final ByteData _view;

  SystemFontInfo(ByteBuffer buffer)
      : _buffer = buffer,
        _view = ByteData.sublistView(Uint8List.view(buffer));

  bool get guessFallback => _view.getUint8(0) != 0;

  String _readString(int index) {
    assert(index < SYSTEM_FONT_INFO.strings.length, 'Invalid string index');
    var offset = 5;
    for (var i = 0; i < index; i++) {
      offset += _view.getUint32(offset, Endian.big) + 4;
    }
    final length = _view.getUint32(offset, Endian.big);
    final bytes = Uint8List.view(_buffer, offset + 4, length);
    return utf8.decode(bytes);
  }

  String get css => _readString(0);
  String get loadedName => _readString(1);
  String get baseFontName => _readString(2);
  String get src => _readString(3);

  SystemFontStyle get style {
    var offset = 1;
    offset += 4 + _view.getUint32(offset, Endian.big);
    final styleLength = _view.getUint32(offset, Endian.big);
    final styleBytes = Uint8List.view(_buffer, offset + 4, styleLength);
    final style = utf8.decode(styleBytes);

    offset += 4 + styleLength;
    final weightLength = _view.getUint32(offset, Endian.big);
    final weightBytes = Uint8List.view(_buffer, offset + 4, weightLength);
    final weight = utf8.decode(weightBytes);

    return SystemFontStyle(style: style, weight: weight);
  }
}

class FontInfo {
  ByteBuffer _buffer;
  ByteData _view;
  final Map<String, dynamic>? extra;

  FontInfo({required ByteBuffer buffer, this.extra})
      : _buffer = buffer,
        _view = ByteData.sublistView(Uint8List.view(buffer));

  bool? _readBoolean(int index) {
    assert(index < FONT_INFO.bools.length, 'Invalid boolean index');
    final byteOffset = index ~/ 4;
    final bitOffset = (index * 2) % 8;
    final value = (_view.getUint8(byteOffset) >> bitOffset) & 0x03;
    return value == 0x00 ? null : value == 0x02;
  }

  bool? get black => _readBoolean(0);
  bool? get bold => _readBoolean(1);
  bool? get disableFontFace => _readBoolean(2);
  bool? get fontExtraProperties => _readBoolean(3);
  bool? get isInvalidPDFjsFont => _readBoolean(4);
  bool? get isType3Font => _readBoolean(5);
  bool? get italic => _readBoolean(6);
  bool? get missingFile => _readBoolean(7);
  bool? get remeasure => _readBoolean(8);
  bool? get vertical => _readBoolean(9);

  double _readNumber(int index) {
    assert(index < FONT_INFO.numbers.length, 'Invalid number index');
    return _view.getFloat64(FONT_INFO.offsetNumbers + index * 8, Endian.big);
  }

  double get ascent => _readNumber(0);
  double get defaultWidth => _readNumber(1);
  double get descent => _readNumber(2);

  List<num>? _readArray(int offset, int arrLen, String lookupName, int increment) {
    final len = _view.getUint8(offset);
    if (len == 0) {
      return null;
    }
    assert(len == arrLen, 'Invalid array length.');
    offset += 1;
    final arr = <num>[];
    for (var i = 0; i < len; i++) {
      if (lookupName == 'getInt16') {
        arr.add(_view.getInt16(offset, Endian.little));
      } else if (lookupName == 'getFloat64') {
        arr.add(_view.getFloat64(offset, Endian.little));
      }
      offset += increment;
    }
    return arr;
  }

  List<num>? get bbox => _readArray(
        FONT_INFO.offsetBbox,
        4,
        'getInt16',
        2,
      );

  List<num>? get fontMatrix => _readArray(
        FONT_INFO.offsetFontMatrix,
        6,
        'getFloat64',
        8,
      );

  List<num>? get defaultVMetrics => _readArray(
        FONT_INFO.offsetDefaultVmetrics,
        3,
        'getInt16',
        2,
      );

  String _readString(int index) {
    assert(index < FONT_INFO.strings.length, 'Invalid string index');
    var offset = FONT_INFO.offsetStrings + 4;
    for (var i = 0; i < index; i++) {
      offset += _view.getUint32(offset, Endian.big) + 4;
    }
    final length = _view.getUint32(offset, Endian.big);
    final bytes = Uint8List.view(_buffer, offset + 4, length);
    return utf8.decode(bytes);
  }

  String get fallbackName => _readString(0);
  String get loadedName => _readString(1);
  String get mimetype => _readString(2);
  String get name => _readString(3);

  ({int offset, int length}) _getDataOffsets() {
    var offset = FONT_INFO.offsetStrings;
    final stringsLength = _view.getUint32(offset, Endian.big);
    offset += 4 + stringsLength;
    final systemFontInfoLength = _view.getUint32(offset, Endian.big);
    offset += 4 + systemFontInfoLength;
    final cssFontInfoLength = _view.getUint32(offset, Endian.big);
    offset += 4 + cssFontInfoLength;
    final length = _view.getUint32(offset, Endian.big);
    return (offset: offset, length: length);
  }

  Uint8List? get data {
    final info = _getDataOffsets();
    return info.length == 0
        ? null
        : Uint8List.view(_buffer, info.offset + 4, info.length);
  }

  void clearData() {
    final info = _getDataOffsets();
    if (info.length == 0) {
      return;
    }
    _view.setUint32(info.offset, 0, Endian.big);
    final copied = Uint8List.fromList(
      Uint8List.view(_buffer, 0, info.offset + 4),
    );
    _buffer = copied.buffer;
    _view = ByteData.sublistView(copied);
  }

  CssFontInfo? get cssFontInfo {
    var offset = FONT_INFO.offsetStrings;
    final stringsLength = _view.getUint32(offset, Endian.big);
    offset += 4 + stringsLength;
    final systemFontInfoLength = _view.getUint32(offset, Endian.big);
    offset += 4 + systemFontInfoLength;
    final cssFontInfoLength = _view.getUint32(offset, Endian.big);
    if (cssFontInfoLength == 0) {
      return null;
    }
    final cssBytes = Uint8List.fromList(
      Uint8List.view(_buffer, offset + 4, cssFontInfoLength),
    );
    return CssFontInfo(cssBytes.buffer);
  }

  SystemFontInfo? get systemFontInfo {
    var offset = FONT_INFO.offsetStrings;
    final stringsLength = _view.getUint32(offset, Endian.big);
    offset += 4 + stringsLength;
    final systemFontInfoLength = _view.getUint32(offset, Endian.big);
    if (systemFontInfoLength == 0) {
      return null;
    }
    final sysBytes = Uint8List.fromList(
      Uint8List.view(_buffer, offset + 4, systemFontInfoLength),
    );
    return SystemFontInfo(sysBytes.buffer);
  }
}

class PatternInfo {
  final ByteBuffer buffer;
  final ByteData view;
  final Uint8List data;

  PatternInfo(this.buffer)
      : view = ByteData.sublistView(Uint8List.view(buffer)),
        data = Uint8List.view(buffer);

  List<dynamic> getIR() {
    final dataView = view;
    final kind = data[PATTERN_INFO.kind];
    final hasBbox = data[PATTERN_INFO.hasBbox] != 0;
    final hasBackground = data[PATTERN_INFO.hasBackground] != 0;
    final nCoord = dataView.getUint32(PATTERN_INFO.nCoord, Endian.little);
    final nColor = dataView.getUint32(PATTERN_INFO.nColor, Endian.little);
    final nStop = dataView.getUint32(PATTERN_INFO.nStop, Endian.little);

    var offset = 20;
    final coords = Float32List.view(buffer, offset, nCoord * 2);
    offset += nCoord * 8;
    final colors = Uint8List.view(buffer, offset, nColor * 4);
    offset += nColor * 4;

    final stops = <dynamic>[];
    for (var i = 0; i < nStop; ++i) {
      final p = dataView.getFloat32(offset, Endian.little);
      offset += 4;
      final rgb = dataView.getUint32(offset, Endian.little);
      offset += 4;
      stops.add([p, '#${rgb.toRadixString(16).padLeft(6, '0')}']);
    }

    List<double>? bbox;
    if (hasBbox) {
      bbox = [];
      for (var i = 0; i < 4; ++i) {
        bbox.add(dataView.getFloat32(offset, Endian.little));
        offset += 4;
      }
    }

    Uint8List? background;
    if (hasBackground) {
      background = Uint8List.view(buffer, offset, 3);
      offset += 3;
    }

    if (kind == 1) {
      // axial
      return [
        'RadialAxial',
        'axial',
        bbox,
        stops,
        [coords[0], coords[1]],
        [coords[2], coords[3]],
        null,
        null,
      ];
    }
    if (kind == 2) {
      // radial
      return [
        'RadialAxial',
        'radial',
        bbox,
        stops,
        [coords[0], coords[1]],
        [coords[3], coords[4]],
        coords[2],
        coords[5],
      ];
    }
    if (kind == 3) {
      final shadingType = data[PATTERN_INFO.shadingType];
      List<num>? bounds;
      if (coords.isNotEmpty) {
        bounds = List<num>.from(bboxInit);
        for (var i = 0; i < coords.length; i += 2) {
          Util.pointBoundingBox(coords[i], coords[i + 1], bounds);
        }
      }
      return [
        'Mesh',
        shadingType,
        coords,
        colors,
        nCoord,
        bounds,
        bbox,
        background,
      ];
    }
    throw UnsupportedError('Unsupported pattern kind: $kind');
  }
}

class FontPathInfo {
  final ByteBuffer _buffer;

  FontPathInfo(ByteBuffer buffer) : _buffer = buffer;

  Float32List get path => Float32List.view(_buffer);
}
