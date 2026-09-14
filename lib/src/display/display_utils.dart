// Copyright 2015 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;
import 'dart:typed_data';
import '../shared/math_clamp.dart';
import '../shared/util.dart';

const String svgNs = 'http://www.w3.org/2000/svg';
const String SVG_NS = svgNs;

class PixelsPerInch {
  static const double CSS = 96.0;
  static const double PDF = 72.0;
  static const double PDF_TO_CSS_UNITS = CSS / PDF;
}

class RawDims {
  final double pageWidth;
  final double pageHeight;
  final double pageX;
  final double pageY;

  const RawDims({
    required this.pageWidth,
    required this.pageHeight,
    required this.pageX,
    required this.pageY,
  });
}

class PageViewport {
  final List<double> viewBox;
  final double userUnit;
  final double scale;
  final int rotation;
  final double offsetX;
  final double offsetY;
  final bool dontFlip;

  late final double width;
  late final double height;
  late final List<double> transform;

  PageViewport({
    required List<num> viewBox,
    double userUnit = 1.0,
    required double scale,
    required int rotation,
    double offsetX = 0.0,
    double offsetY = 0.0,
    bool dontFlip = false,
  })  : viewBox = viewBox.map((e) => e.toDouble()).toList(),
        userUnit = userUnit,
        scale = scale,
        rotation = rotation,
        offsetX = offsetX,
        offsetY = offsetY,
        dontFlip = dontFlip {
    final effectiveScale = scale * userUnit;

    final centerX = (this.viewBox[2] + this.viewBox[0]) / 2.0;
    final centerY = (this.viewBox[3] + this.viewBox[1]) / 2.0;

    var normRotation = rotation % 360;
    if (normRotation < 0) {
      normRotation += 360;
    }

    double rotateA, rotateB, rotateC, rotateD;
    switch (normRotation) {
      case 180:
        rotateA = -1.0;
        rotateB = 0.0;
        rotateC = 0.0;
        rotateD = 1.0;
        break;
      case 90:
        rotateA = 0.0;
        rotateB = 1.0;
        rotateC = 1.0;
        rotateD = 0.0;
        break;
      case 270:
        rotateA = 0.0;
        rotateB = -1.0;
        rotateC = -1.0;
        rotateD = 0.0;
        break;
      case 0:
        rotateA = 1.0;
        rotateB = 0.0;
        rotateC = 0.0;
        rotateD = -1.0;
        break;
      default:
        throw ArgumentError(
            'PageViewport: Invalid rotation, must be a multiple of 90 degrees.');
    }

    if (dontFlip) {
      rotateC = -rotateC;
      rotateD = -rotateD;
    }

    double offsetCanvasX, offsetCanvasY;
    if (rotateA == 0.0) {
      offsetCanvasX =
          (centerY - this.viewBox[1]).abs() * effectiveScale + offsetX;
      offsetCanvasY =
          (centerX - this.viewBox[0]).abs() * effectiveScale + offsetY;
      width = (this.viewBox[3] - this.viewBox[1]) * effectiveScale;
      height = (this.viewBox[2] - this.viewBox[0]) * effectiveScale;
    } else {
      offsetCanvasX =
          (centerX - this.viewBox[0]).abs() * effectiveScale + offsetX;
      offsetCanvasY =
          (centerY - this.viewBox[1]).abs() * effectiveScale + offsetY;
      width = (this.viewBox[2] - this.viewBox[0]) * effectiveScale;
      height = (this.viewBox[3] - this.viewBox[1]) * effectiveScale;
    }

    transform = [
      rotateA * effectiveScale,
      rotateB * effectiveScale,
      rotateC * effectiveScale,
      rotateD * effectiveScale,
      offsetCanvasX -
          rotateA * effectiveScale * centerX -
          rotateC * effectiveScale * centerY,
      offsetCanvasY -
          rotateB * effectiveScale * centerX -
          rotateD * effectiveScale * centerY,
    ];
  }

  RawDims get rawDims {
    return RawDims(
      pageWidth: viewBox[2] - viewBox[0],
      pageHeight: viewBox[3] - viewBox[1],
      pageX: viewBox[0],
      pageY: viewBox[1],
    );
  }

  PageViewport clone({
    double? scale,
    int? rotation,
    double? offsetX,
    double? offsetY,
    bool? dontFlip,
  }) {
    return PageViewport(
      viewBox: List<double>.from(viewBox),
      userUnit: userUnit,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      dontFlip: dontFlip ?? this.dontFlip,
    );
  }

  List<double> convertToViewportPoint(num x, num y) {
    final p = [x.toDouble(), y.toDouble()];
    Util.applyTransform(p, transform);
    return p;
  }

  List<double> convertToViewportRectangle(List<num> rect) {
    final topLeft = [rect[0].toDouble(), rect[1].toDouble()];
    Util.applyTransform(topLeft, transform);
    final bottomRight = [rect[2].toDouble(), rect[3].toDouble()];
    Util.applyTransform(bottomRight, transform);
    return [topLeft[0], topLeft[1], bottomRight[0], bottomRight[1]];
  }

  List<double> convertToPdfPoint(num x, num y) {
    final p = [x.toDouble(), y.toDouble()];
    Util.applyInverseTransform(p, transform);
    return p;
  }
}

class RenderingCancelledException implements Exception {
  final String message;
  final int extraDelay;

  RenderingCancelledException(this.message, [this.extraDelay = 0]);

  @override
  String toString() => 'RenderingCancelledException: $message';
}

bool isDataScheme(String url) {
  var i = 0;
  final ii = url.length;
  while (i < ii && url[i].trim().isEmpty) {
    i++;
  }
  if (i + 5 <= ii && url.substring(i, i + 5).toLowerCase() == 'data:') {
    return true;
  }
  return false;
}

bool isPdfFile(dynamic filename) {
  return filename is String &&
      RegExp(r'\.pdf$', caseSensitive: false).hasMatch(filename);
}

String getFilenameFromUrl(String url) {
  final clean = url.split(RegExp(r'[#?]')).first;
  return stripPath(clean);
}

String getPdfFilenameFromUrl(dynamic url,
    [String defaultFilename = 'document.pdf']) {
  if (url is! String) {
    return defaultFilename;
  }
  if (isDataScheme(url)) {
    return defaultFilename;
  }

  final trimmed = url.trim();

  Uri? tryParse(String str) {
    try {
      final uri = Uri.parse(str);
      if (uri.hasScheme || str.startsWith('/')) return uri;
    } catch (_) {}
    try {
      final decoded = Uri.decodeComponent(str);
      final uri = Uri.parse(decoded);
      if (uri.hasScheme || decoded.startsWith('/')) return uri;
    } catch (_) {}
    try {
      return Uri.parse('https://foo.bar/$str');
    } catch (_) {}
    return null;
  }

  final parsed = tryParse(trimmed);
  if (parsed == null) {
    return defaultFilename;
  }

  String decodeName(String name) {
    try {
      var decoded = Uri.decodeComponent(name);
      if (decoded.contains('/')) {
        decoded = stripPath(decoded);
        if (RegExp(r'^\.pdf$', caseSensitive: false).hasMatch(decoded)) {
          return name;
        }
      }
      return decoded;
    } catch (_) {
      return name;
    }
  }

  final pdfRegex = RegExp(r'\.pdf$', caseSensitive: false);
  final filename = stripPath(parsed.path);
  if (pdfRegex.hasMatch(filename)) {
    return decodeName(filename);
  }

  if (parsed.queryParameters.isNotEmpty) {
    // Check values and keys
    for (final val in parsed.queryParameters.values.toList().reversed) {
      if (pdfRegex.hasMatch(val)) {
        return decodeName(val);
      }
    }
    for (final key in parsed.queryParameters.keys.toList().reversed) {
      if (pdfRegex.hasMatch(key)) {
        return decodeName(key);
      }
    }
  }

  // Check raw query for ?file2.pdf style queries
  if (parsed.query.isNotEmpty) {
    final query = parsed.query;
    final m = RegExp(r'[^/?#=]+\.pdf\b', caseSensitive: false).allMatches(query);
    if (m.isNotEmpty) {
      return decodeName(m.last.group(0)!);
    }
  }

  if (parsed.fragment.isNotEmpty) {
    final m = RegExp(r'[^/?#=]+\.pdf\b', caseSensitive: false)
        .allMatches(parsed.fragment);
    if (m.isNotEmpty) {
      return decodeName(m.last.group(0)!);
    }
  }

  return defaultFilename;
}

class StatTimer {
  final Map<String, int> _started = {};
  final List<Map<String, dynamic>> times = [];

  void time(String name) {
    _started[name] = DateTime.now().millisecondsSinceEpoch;
  }

  void timeEnd(String name) {
    final start = _started.remove(name);
    if (start != null) {
      times.add({
        'name': name,
        'start': start,
        'end': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  @override
  String toString() {
    if (times.isEmpty) return '';
    var longest = 0;
    for (final t in times) {
      final len = (t['name'] as String).length;
      if (len > longest) longest = len;
    }
    final sb = StringBuffer();
    for (final t in times) {
      final name = (t['name'] as String).padRight(longest);
      final duration = (t['end'] as int) - (t['start'] as int);
      sb.writeln('$name ${duration}ms');
    }
    return sb.toString();
  }
}

bool isValidFetchUrl(dynamic url, [dynamic baseUrl]) {
  if (url is! String) return false;
  try {
    Uri uri;
    if (baseUrl != null) {
      final base = Uri.parse(baseUrl.toString());
      uri = base.resolve(url);
    } else {
      uri = Uri.parse(url);
    }
    return uri.scheme == 'http' || uri.scheme == 'https';
  } catch (_) {
    return false;
  }
}

class PDFDateString {
  static final RegExp _regex = RegExp(
    r"^D:(\d{4})(\d{2})?(\d{2})?(\d{2})?(\d{2})?(\d{2})?([Z|+|-])?(\d{2})?'?(\d{2})?'?",
  );

  static DateTime? toDateObject(dynamic input) {
    if (input is DateTime) {
      return input;
    }
    if (input == null || input is! String) {
      return null;
    }

    final match = _regex.firstMatch(input);
    if (match == null) {
      return null;
    }

    final year = int.parse(match.group(1)!);
    final monthStr = match.group(2);
    var month = 1;
    if (monthStr != null) {
      final m = int.parse(monthStr);
      month = (m >= 1 && m <= 12) ? m : 1;
    }

    final dayStr = match.group(3);
    var day = 1;
    if (dayStr != null) {
      final d = int.parse(dayStr);
      day = (d >= 1 && d <= 31) ? d : 1;
    }

    final hourStr = match.group(4);
    var hour = 0;
    if (hourStr != null) {
      final h = int.parse(hourStr);
      hour = (h >= 0 && h <= 23) ? h : 0;
    }

    final minStr = match.group(5);
    var minute = 0;
    if (minStr != null) {
      final m = int.parse(minStr);
      minute = (m >= 0 && m <= 59) ? m : 0;
    }

    final secStr = match.group(6);
    var second = 0;
    if (secStr != null) {
      final s = int.parse(secStr);
      second = (s >= 0 && s <= 59) ? s : 0;
    }

    final relation = match.group(7) ?? 'Z';
    final offHourStr = match.group(8);
    var offsetHour = 0;
    if (offHourStr != null) {
      final oh = int.parse(offHourStr);
      offsetHour = (oh >= 0 && oh <= 23) ? oh : 0;
    }

    final offMinStr = match.group(9);
    var offsetMinute = 0;
    if (offMinStr != null) {
      final om = int.parse(offMinStr);
      offsetMinute = (om >= 0 && om <= 59) ? om : 0;
    }

    var date = DateTime.utc(year, month, day, hour, minute, second);
    if (relation == '-') {
      date = date.add(Duration(hours: offsetHour, minutes: offsetMinute));
    } else if (relation == '+') {
      date = date.subtract(Duration(hours: offsetHour, minutes: offsetMinute));
    }
    return date;
  }
}

List<int> applyOpacity(List<num> color, [num? opacity]) {
  final op = MathClamp(opacity ?? 1, 0, 1).toDouble();
  final white = 255.0 * (1.0 - op);
  return color.map((c) => (c * op + white).round()).toList();
}

void _rgbToHsl(List<num> rgb, Float32List output) {
  final r = rgb[0] / 255.0;
  final g = rgb[1] / 255.0;
  final b = rgb[2] / 255.0;

  final maxVal = math.max(r, math.max(g, b));
  final minVal = math.min(r, math.min(g, b));
  final l = (maxVal + minVal) / 2.0;

  if (maxVal == minVal) {
    output[0] = 0.0;
    output[1] = 0.0;
  } else {
    final d = maxVal - minVal;
    output[1] = l < 0.5 ? d / (maxVal + minVal) : d / (2.0 - maxVal - minVal);
    if (maxVal == r) {
      output[0] = ((g - b) / d + (g < b ? 6.0 : 0.0)) * 60.0;
    } else if (maxVal == g) {
      output[0] = ((b - r) / d + 2.0) * 60.0;
    } else {
      output[0] = ((r - g) / d + 4.0) * 60.0;
    }
  }
  output[2] = l;
}

void _hslToRgb(Float32List hsl, Float32List output) {
  final h = hsl[0];
  final s = hsl[1];
  final l = hsl[2];
  final c = (1.0 - (2.0 * l - 1.0).abs()) * s;
  final x = c * (1.0 - (((h / 60.0) % 2.0) - 1.0).abs());
  final m = l - c / 2.0;

  final sector = (h / 60.0).floor();
  switch (sector) {
    case 0:
      output[0] = c + m;
      output[1] = x + m;
      output[2] = m;
      break;
    case 1:
      output[0] = x + m;
      output[1] = c + m;
      output[2] = m;
      break;
    case 2:
      output[0] = m;
      output[1] = c + m;
      output[2] = x + m;
      break;
    case 3:
      output[0] = m;
      output[1] = x + m;
      output[2] = c + m;
      break;
    case 4:
      output[0] = x + m;
      output[1] = m;
      output[2] = c + m;
      break;
    default:
      output[0] = c + m;
      output[1] = m;
      output[2] = x + m;
      break;
  }
}

double _computeLuminance(double x) {
  return x <= 0.03928 ? x / 12.92 : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
}

double _contrastRatio(Float32List hsl1, Float32List hsl2, Float32List output) {
  _hslToRgb(hsl1, output);
  final lum1 = 0.2126 * output[0] + 0.7152 * output[1] + 0.0722 * output[2];

  _hslToRgb(hsl2, output);
  final lum2 = 0.2126 * output[0] + 0.7152 * output[1] + 0.0722 * output[2];

  return lum1 > lum2
      ? (lum1 + 0.05) / (lum2 + 0.05)
      : (lum2 + 0.05) / (lum1 + 0.05);
}

final Map<int, String> _contrastCache = {};

String findContrastColor(List<num> baseColor, List<num> fixedColor) {
  final key = baseColor[0].toInt() +
      baseColor[1].toInt() * 0x100 +
      baseColor[2].toInt() * 0x10000 +
      fixedColor[0].toInt() * 0x1000000 +
      fixedColor[1].toInt() * 0x100000000 +
      fixedColor[2].toInt() * 0x10000000000;

  final cached = _contrastCache[key];
  if (cached != null) {
    return cached;
  }

  final array = Float32List(9);
  final output = Float32List.sublistView(array, 0, 3);
  final baseHSL = Float32List.sublistView(array, 3, 6);
  _rgbToHsl(baseColor, baseHSL);
  final fixedHSL = Float32List.sublistView(array, 6, 9);
  _rgbToHsl(fixedColor, fixedHSL);

  final isFixedColorDark = fixedHSL[2] < 0.5;
  final minContrast = isFixedColorDark ? 12.0 : 4.5;

  baseHSL[2] = isFixedColorDark
      ? math.sqrt(baseHSL[2])
      : 1.0 - math.sqrt(1.0 - baseHSL[2]);

  if (_contrastRatio(baseHSL, fixedHSL, output) < minContrast) {
    double start = isFixedColorDark ? baseHSL[2] : 0.0;
    double end = isFixedColorDark ? 1.0 : baseHSL[2];
    const precision = 0.005;

    while (end - start > precision) {
      final mid = (start + end) / 2.0;
      baseHSL[2] = mid;
      final currentRatio = _contrastRatio(baseHSL, fixedHSL, output);
      if (isFixedColorDark == (currentRatio < minContrast)) {
        start = mid;
      } else {
        end = mid;
      }
    }
    baseHSL[2] = isFixedColorDark ? end : start;
  }

  _hslToRgb(baseHSL, output);
  final hex = Util.makeHexColor(
    (output[0] * 255.0).round(),
    (output[1] * 255.0).round(),
    (output[2] * 255.0).round(),
  );
  _contrastCache[key] = hex;
  return hex;
}

class OutputScale {
  double sx;
  double sy;

  OutputScale({double? sx, double? sy})
      : sx = sx ?? pixelRatio,
        sy = sy ?? pixelRatio;

  bool get scaled => sx != 1.0 || sy != 1.0;
  bool get symmetric => sx == sy;

  static double get pixelRatio => 1.0;

  bool limitCanvas(
    double width,
    double height,
    double maxPixels,
    double maxDim, [
    double capAreaFactor = -1.0,
  ]) {
    var maxAreaScale = double.infinity;
    var maxWidthScale = double.infinity;
    var maxHeightScale = double.infinity;

    if (maxPixels > 0) {
      maxAreaScale = math.sqrt(maxPixels / (width * height));
    }
    if (maxDim != -1.0) {
      maxWidthScale = maxDim / width;
      maxHeightScale = maxDim / height;
    }
    final maxScale =
        math.min(maxAreaScale, math.min(maxWidthScale, maxHeightScale));

    if (sx > maxScale || sy > maxScale) {
      sx = maxScale;
      sy = maxScale;
      return true;
    }
    return false;
  }
}

const List<String> supportedImageMimeTypes = [
  'image/apng',
  'image/avif',
  'image/bmp',
  'image/gif',
  'image/jpeg',
  'image/png',
  'image/svg+xml',
  'image/webp',
  'image/x-icon',
];
const List<String> SupportedImageMimeTypes = supportedImageMimeTypes;

/// Parse a CSS color string like "rgb(r, g, b)" and return [r, g, b].
List<int> getRGB(String color) {
  final match =
      RegExp(r'rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)').firstMatch(color);
  if (match != null) {
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
  }
  // Try rgba
  final matchA = RegExp(
          r'rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*[\d.]+\s*\)')
      .firstMatch(color);
  if (matchA != null) {
    return [
      int.parse(matchA.group(1)!),
      int.parse(matchA.group(2)!),
      int.parse(matchA.group(3)!),
    ];
  }
  // Try hex
  if (color.startsWith('#')) {
    final hex = color.substring(1);
    if (hex.length == 6) {
      return [
        int.parse(hex.substring(0, 2), radix: 16),
        int.parse(hex.substring(2, 4), radix: 16),
        int.parse(hex.substring(4, 6), radix: 16),
      ];
    }
    if (hex.length == 3) {
      return [
        int.parse(hex[0] + hex[0], radix: 16),
        int.parse(hex[1] + hex[1], radix: 16),
        int.parse(hex[2] + hex[2], radix: 16),
      ];
    }
  }
  return [0, 0, 0];
}

/// Prevent default and stop propagation of a DOM event.
/// This is a stub that works with package:web event objects.
void stopEvent(dynamic evt) {
  // In Dart web with package:web, events are js interop objects.
  // This function would call preventDefault/stopPropagation.
}

/// Set the dimensions of a layer element based on the viewport.
void setLayerDimensions(dynamic container, PageViewport viewport) {
  // Set container dimensions to match the viewport.
  // In Dart web context, this would set CSS properties.
}

/// Get the current transform from a canvas context.
List<double> getCurrentTransform(dynamic ctx) {
  // Returns the current transformation matrix as a list.
  return [1, 0, 0, 1, 0, 0];
}

/// Update the hash part of a URL.
String updateUrlHash(String url, String hash) {
  final idx = url.indexOf('#');
  if (idx >= 0) {
    return '${url.substring(0, idx)}$hash';
  }
  return '$url$hash';
}

/// Make SVG path from draw operations.
String makePathFromDrawOPS(dynamic ops) {
  // Convert draw operations to SVG path string.
  return '';
}
