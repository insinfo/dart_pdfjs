// Copyright 2020 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import '../shared/scripting_utils.dart';
import 'pdf_object.dart';

/// Acrobat-compatible color constants and conversion helpers.
class Color extends PDFObject {
  Color() : super();

  final List<Object?> transparent = <Object?>['T'];
  final List<Object?> black = <Object?>['G', 0];
  final List<Object?> white = <Object?>['G', 1];
  final List<Object?> red = <Object?>['RGB', 1, 0, 0];
  final List<Object?> green = <Object?>['RGB', 0, 1, 0];
  final List<Object?> blue = <Object?>['RGB', 0, 0, 1];
  final List<Object?> cyan = <Object?>['CMYK', 1, 0, 0, 0];
  final List<Object?> magenta = <Object?>['CMYK', 0, 1, 0, 0];
  final List<Object?> yellow = <Object?>['CMYK', 0, 0, 1, 0];
  final List<Object?> dkGray = <Object?>['G', 0.25];
  final List<Object?> gray = <Object?>['G', 0.5];
  final List<Object?> ltGray = <Object?>['G', 0.75];

  static bool isValidSpace(Object? colorSpace) =>
      colorSpace == 'T' ||
      colorSpace == 'G' ||
      colorSpace == 'RGB' ||
      colorSpace == 'CMYK';

  static bool isValidColor(Object? colorArray) {
    if (colorArray is! List || colorArray.isEmpty) return false;
    final space = colorArray[0];
    if (!isValidSpace(space)) return false;
    final expectedLength = switch (space) {
      'T' => 1,
      'G' => 2,
      'RGB' => 4,
      'CMYK' => 5,
      _ => 0,
    };
    if (colorArray.length != expectedLength) return false;
    return colorArray.skip(1).every(
          (component) => component is num && component >= 0 && component <= 1,
        );
  }

  static List<Object?> _correctColor(Object? colorArray) =>
      isValidColor(colorArray)
          ? List<Object?>.from(colorArray! as List)
          : <Object?>['G', 0];

  List<Object?> convert(Object? colorArray, Object? colorSpace) {
    if (!isValidSpace(colorSpace)) return black;
    if (colorSpace == 'T') return <Object?>['T'];

    final color = _correctColor(colorArray);
    final sourceSpace = color[0] as String;
    if (sourceSpace == colorSpace) return color;
    if (sourceSpace == 'T') return convert(black, colorSpace);

    final components = color.skip(1).cast<num>().toList(growable: false);
    final converted = switch ('$sourceSpace\_$colorSpace') {
      'G_RGB' => ColorConverters.gToRgb(components),
      'G_CMYK' => ColorConverters.gToCmyk(components),
      'RGB_G' => ColorConverters.rgbToG(components),
      'RGB_CMYK' => ColorConverters.rgbToCmyk(components),
      'CMYK_G' => ColorConverters.cmykToG(components),
      'CMYK_RGB' => ColorConverters.cmykToRgb(components),
      _ => <Object?>['G', 0],
    };
    return List<Object?>.from(converted);
  }

  bool equal(Object? colorArray1, Object? colorArray2) {
    final first = _correctColor(colorArray1);
    var second = _correctColor(colorArray2);
    if (first[0] == 'T' || second[0] == 'T') {
      return first[0] == 'T' && second[0] == 'T';
    }
    if (first[0] != second[0]) second = convert(second, first[0]);
    for (var i = 1; i < first.length; i++) {
      if (first[i] != second[i]) return false;
    }
    return true;
  }
}
