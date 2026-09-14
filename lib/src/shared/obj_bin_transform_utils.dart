// Copyright 2025 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

abstract class CSS_FONT_INFO {
  static const List<String> strings = ['fontFamily', 'fontWeight', 'italicAngle'];
}

abstract class SYSTEM_FONT_INFO {
  static const List<String> strings = ['css', 'loadedName', 'baseFontName', 'src'];
}

abstract class FONT_INFO {
  static const List<String> bools = [
    'black',
    'bold',
    'disableFontFace',
    'fontExtraProperties',
    'isInvalidPDFjsFont',
    'isType3Font',
    'italic',
    'missingFile',
    'remeasure',
    'vertical',
  ];

  static const List<String> numbers = ['ascent', 'defaultWidth', 'descent'];

  static const List<String> strings = ['fallbackName', 'loadedName', 'mimetype', 'name'];

  static final int offsetNumbers = ((bools.length * 2) / 8).ceil();

  static final int offsetBbox = offsetNumbers + numbers.length * 8;

  static final int offsetFontMatrix = offsetBbox + 1 + 2 * 4;

  static final int offsetDefaultVmetrics = offsetFontMatrix + 1 + 8 * 6;

  static final int offsetStrings = offsetDefaultVmetrics + 1 + 2 * 3;
}

abstract class PATTERN_INFO {
  static const int kind = 0; // 1=axial, 2=radial, 3=mesh
  static const int hasBbox = 1; // 0/1
  static const int hasBackground = 2; // 0/1 (background for mesh patterns)
  static const int shadingType = 3; // shadingType (only for mesh patterns)
  static const int nCoord = 4; // number of coordinate pairs
  static const int nColor = 8; // number of RGBA-stride color entries
  static const int nStop = 12; // number of gradient stops
  static const int nFigures = 16; // number of figures
}
