// Copyright 2020 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;

import 'math_clamp.dart';

String _makeColorComp(num n) {
  return (mathClamp(n, 0, 1) * 255)
      .floor()
      .toRadixString(16)
      .padLeft(2, '0');
}

num _scaleAndClamp(num x) {
  return mathClamp(x, 0, 1) * 255;
}

/// PDF specifications section 10.3
abstract class ColorConverters {
  static List<dynamic> cmykToG(List<num> components) {
    final c = components[0];
    final y = components[1];
    final m = components[2];
    final k = components[3];
    return ['G', 1 - math.min(1.0, 0.3 * c + 0.59 * m + 0.11 * y + k)];
  }

  static List<dynamic> gToCmyk(List<num> components) {
    final g = components[0];
    return ['CMYK', 0, 0, 0, 1 - g];
  }

  static List<dynamic> gToRgb(List<num> components) {
    final g = components[0];
    return ['RGB', g, g, g];
  }

  static List<num> gToRgb255(List<num> components) {
    final g = _scaleAndClamp(components[0]);
    return [g, g, g];
  }

  static String gToHtml(List<num> components) {
    final g = _makeColorComp(components[0]);
    return '#$g$g$g';
  }

  static List<dynamic> rgbToG(List<num> components) {
    final r = components[0];
    final g = components[1];
    final b = components[2];
    return ['G', 0.3 * r + 0.59 * g + 0.11 * b];
  }

  static List<num> rgbToRgb255(List<num> color) {
    return color.map(_scaleAndClamp).toList();
  }

  static String rgbToHtml(List<num> color) {
    return '#${color.map(_makeColorComp).join('')}';
  }

  static String tToHtml() {
    return '#00000000';
  }

  static List<dynamic> tToRgb() {
    return [null];
  }

  static List<dynamic> cmykToRgb(List<num> components) {
    final c = components[0];
    final y = components[1];
    final m = components[2];
    final k = components[3];
    return [
      'RGB',
      1 - math.min(1.0, c + k),
      1 - math.min(1.0, m + k),
      1 - math.min(1.0, y + k),
    ];
  }

  static List<num> cmykToRgb255(List<num> components) {
    final c = components[0];
    final y = components[1];
    final m = components[2];
    final k = components[3];
    return [
      _scaleAndClamp(1 - math.min(1.0, c + k)),
      _scaleAndClamp(1 - math.min(1.0, m + k)),
      _scaleAndClamp(1 - math.min(1.0, y + k)),
    ];
  }

  static String cmykToHtml(List<num> components) {
    final rgb = cmykToRgb(components).sublist(1).cast<num>();
    return rgbToHtml(rgb);
  }

  static List<dynamic> rgbToCmyk(List<num> components) {
    final r = components[0];
    final g = components[1];
    final b = components[2];
    final c = 1 - r;
    final m = 1 - g;
    final y = 1 - b;
    final k = math.min(c, math.min(m, y));
    return ['CMYK', c, m, y, k];
  }
}

const List<String> dateFormats = [
  'm/d',
  'm/d/yy',
  'mm/dd/yy',
  'mm/yy',
  'd-mmm',
  'd-mmm-yy',
  'dd-mmm-yy',
  'yy-mm-dd',
  'mmm-yy',
  'mmmm-yy',
  'mmm d, yyyy',
  'mmmm d, yyyy',
  'm/d/yy h:MM tt',
  'm/d/yy HH:MM',
];

const List<String> timeFormats = [
  'HH:MM',
  'h:MM tt',
  'HH:MM:ss',
  'h:MM:ss tt',
];
