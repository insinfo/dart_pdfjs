// Copyright 2021 Mozilla Foundation
//
// Licensed under the Apache License, Version 2.0.

typedef XFARatio = ({double num, double den});
typedef XFARelevant = ({bool excluded, String viewname});
typedef XFAColor = ({int r, int g, int b});
typedef XFABBox = ({double x, double y, double width, double height});

final RegExp _measurementPattern = RegExp(r'([+-]?\d+\.?\d*)(.*)');
final RegExp _integerPrefix = RegExp(r'^[+-]?\d+');
final RegExp _floatPrefix = RegExp(
  r'^[+-]?(?:(?:\d+\.?\d*)|(?:\.\d+))(?:[eE][+-]?\d+)?',
);

String stripQuotes(String str) {
  if (str.startsWith("'") || str.startsWith('"')) {
    return str.substring(1, str.length - 1);
  }
  return str;
}

int getInteger({
  required String? data,
  required int defaultValue,
  required bool Function(int value) validate,
}) {
  if (data == null || data.isEmpty) return defaultValue;
  final match = _integerPrefix.firstMatch(data.trim());
  final value = match == null ? null : int.tryParse(match.group(0)!);
  return value != null && validate(value) ? value : defaultValue;
}

double getFloat({
  required String? data,
  required double defaultValue,
  required bool Function(double value) validate,
}) {
  if (data == null || data.isEmpty) return defaultValue;
  final match = _floatPrefix.firstMatch(data.trim());
  final value = match == null ? null : double.tryParse(match.group(0)!);
  return value != null && validate(value) ? value : defaultValue;
}

String getKeyword({
  required String? data,
  required String defaultValue,
  required bool Function(String value) validate,
}) {
  if (data == null || data.isEmpty) return defaultValue;
  final value = data.trim();
  return validate(value) ? value : defaultValue;
}

String getStringOption(String? data, List<String> options) => getKeyword(
      data: data,
      defaultValue: options.first,
      validate: options.contains,
    );

double getMeasurement(String? str, [String def = '0']) {
  if (def.isEmpty) def = '0';
  if (str == null || str.isEmpty) return getMeasurement(def);
  final match = _measurementPattern.firstMatch(str.trim());
  if (match == null) return getMeasurement(def);
  final value = double.tryParse(match.group(1)!);
  if (value == null) return getMeasurement(def);
  if (value == 0) return 0;
  return switch (match.group(2)) {
    'pt' || 'px' => value,
    'cm' => value / 2.54 * 72,
    'mm' => value / (10 * 2.54) * 72,
    'in' => value * 72,
    _ => value,
  };
}

XFARatio getRatio(String? data) {
  if (data == null || data.isEmpty) return (num: 1, den: 1);
  final values = data
      .split(':')
      .take(2)
      .map((part) => double.tryParse(part.trim()))
      .whereType<double>()
      .toList();
  if (values.isEmpty) return (num: 1, den: 1);
  return (num: values[0], den: values.length == 1 ? 1 : values[1]);
}

List<XFARelevant> getRelevant(String? data) {
  if (data == null || data.isEmpty) return const [];
  return data.trim().split(RegExp(r'\s+')).map((entry) {
    return (excluded: entry[0] == '-', viewname: entry.substring(1));
  }).toList();
}

XFAColor getColor(String? data, [List<int> def = const [0, 0, 0]]) {
  if (data == null || data.isEmpty) return (r: def[0], g: def[1], b: def[2]);
  final parts = data.split(',').take(3).toList();
  if (parts.length < 3) return (r: def[0], g: def[1], b: def[2]);
  int channel(String part) {
    final match = _integerPrefix.firstMatch(part.trim());
    return (match == null ? null : int.tryParse(match.group(0)!))
            ?.clamp(0, 255) ??
        0;
  }

  return (r: channel(parts[0]), g: channel(parts[1]), b: channel(parts[2]));
}

XFABBox getBBox(String? data) {
  const invalid = (x: -1.0, y: -1.0, width: -1.0, height: -1.0);
  if (data == null || data.isEmpty) return invalid;
  final parts = data.split(',').take(4).toList();
  if (parts.length < 4) return invalid;
  final values =
      parts.map((part) => getMeasurement(part.trim(), '-1')).toList();
  if (values[2] < 0 || values[3] < 0) return invalid;
  return (x: values[0], y: values[1], width: values[2], height: values[3]);
}

class HTMLResult {
  const HTMLResult(this.success, this.html, this.bbox, this.breakNode);

  final bool success;
  final dynamic html;
  final dynamic bbox;
  final dynamic breakNode;

  static const HTMLResult failure = HTMLResult(false, null, null, null);
  static const HTMLResult empty = HTMLResult(true, null, null, null);

  // JS-compatible names.
  static HTMLResult get FAILURE => failure;
  static HTMLResult get EMPTY => empty;

  bool isBreak() => breakNode != null;

  static HTMLResult fromBreakNode(dynamic node) =>
      HTMLResult(false, null, null, node);

  static HTMLResult withSuccess(dynamic html, [dynamic bbox]) =>
      HTMLResult(true, html, bbox, null);
}
