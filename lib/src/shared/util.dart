// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'dart:math' as math;

// --- Constants ---

const List<double> bboxInit = [double.infinity, double.infinity, double.negativeInfinity, double.negativeInfinity];

final Float32List f32BboxInit = Float32List.fromList([
  double.infinity, double.infinity,
  double.negativeInfinity, double.negativeInfinity,
]);

const List<double> fontIdentityMatrix = [0.001, 0, 0, 0.001, 0, 0];

const double lineFactor = 1.35;
const double lineDescentFactor = 0.35;
const double baselineFactor = lineDescentFactor / lineFactor;

// --- Enums / Flag classes ---

abstract class RenderingIntentFlag {
  static const int any = 0x01;
  static const int display = 0x02;
  static const int print = 0x04;
  static const int save = 0x08;
  static const int annotationsForms = 0x10;
  static const int annotationsStorage = 0x20;
  static const int annotationsDisable = 0x40;
  static const int isEditing = 0x80;
  static const int opList = 0x100;
}

abstract class AnnotationMode {
  static const int disable = 0;
  static const int enable = 1;
  static const int enableForms = 2;
  static const int enableStorage = 3;
}

const String annotationEditorPrefix = 'pdfjs_internal_editor_';

abstract class AnnotationEditorType {
  static const int disable = -1;
  static const int none = 0;
  static const int freetext = 3;
  static const int highlight = 9;
  static const int stamp = 13;
  static const int ink = 15;
  static const int popup = 16;
  static const int signature = 101;
  static const int comment = 102;
}

abstract class AnnotationEditorParamsType {
  static const int resize = 1;
  static const int create = 2;
  static const int freetextSize = 11;
  static const int freetextColor = 12;
  static const int freetextOpacity = 13;
  static const int inkColor = 21;
  static const int inkThickness = 22;
  static const int inkOpacity = 23;
  static const int highlightColor = 31;
  static const int highlightThickness = 32;
  static const int highlightFree = 33;
  static const int highlightShowAll = 34;
  static const int drawStep = 41;
}

abstract class PermissionFlag {
  static const int print = 0x04;
  static const int modifyContents = 0x08;
  static const int copy = 0x10;
  static const int modifyAnnotations = 0x20;
  static const int fillInteractiveForms = 0x100;
  static const int copyForAccessibility = 0x200;
  static const int assemble = 0x400;
  static const int printHighQuality = 0x800;
}

abstract class MeshFigureType {
  static const int triangles = 1;
  static const int lattice = 2;
  static const int patch = 3;
}

abstract class TextRenderingMode {
  static const int fill = 0;
  static const int stroke = 1;
  static const int fillStroke = 2;
  static const int invisible = 3;
  static const int fillAddToPath = 4;
  static const int strokeAddToPath = 5;
  static const int fillStrokeAddToPath = 6;
  static const int addToPath = 7;
  static const int fillStrokeMask = 3;
  static const int addToPathFlag = 4;
}

abstract class ImageKind {
  static const int grayscale1bpp = 1;
  static const int rgb24bpp = 2;
  static const int rgba32bpp = 3;
}

abstract class AnnotationType {
  static const int text = 1;
  static const int link = 2;
  static const int freetext = 3;
  static const int line = 4;
  static const int square = 5;
  static const int circle = 6;
  static const int polygon = 7;
  static const int polyline = 8;
  static const int highlight = 9;
  static const int underline = 10;
  static const int squiggly = 11;
  static const int strikeout = 12;
  static const int stamp = 13;
  static const int caret = 14;
  static const int ink = 15;
  static const int popup = 16;
  static const int fileattachment = 17;
  static const int sound = 18;
  static const int movie = 19;
  static const int widget = 20;
  static const int screen = 21;
  static const int printermark = 22;
  static const int trapnet = 23;
  static const int watermark = 24;
  static const int threed = 25;
  static const int redact = 26;
}

abstract class AnnotationReplyType {
  static const String group = 'Group';
  static const String reply = 'R';
}

abstract class AnnotationFlag {
  static const int invisible = 0x01;
  static const int hidden = 0x02;
  static const int print = 0x04;
  static const int noZoom = 0x08;
  static const int noRotate = 0x10;
  static const int noView = 0x20;
  static const int readOnly = 0x40;
  static const int locked = 0x80;
  static const int toggleNoView = 0x100;
  static const int lockedContents = 0x200;
}

abstract class AnnotationFieldFlag {
  static const int readOnly = 0x0000001;
  static const int required = 0x0000002;
  static const int noExport = 0x0000004;
  static const int multiline = 0x0001000;
  static const int password = 0x0002000;
  static const int noToggleToOff = 0x0004000;
  static const int radio = 0x0008000;
  static const int pushButton = 0x0010000;
  static const int combo = 0x0020000;
  static const int edit = 0x0040000;
  static const int sort = 0x0080000;
  static const int fileSelect = 0x0100000;
  static const int multiSelect = 0x0200000;
  static const int doNotSpellCheck = 0x0400000;
  static const int doNotScroll = 0x0800000;
  static const int comb = 0x1000000;
  static const int richText = 0x2000000;
  static const int radiosInUnison = 0x2000000;
  static const int commitOnSelChange = 0x4000000;
}

abstract class AnnotationBorderStyleType {
  static const int solid = 1;
  static const int dashed = 2;
  static const int beveled = 3;
  static const int inset = 4;
  static const int underline = 5;
}

const Map<String, String> annotationActionEventType = {
  'E': 'Mouse Enter', 'X': 'Mouse Exit',
  'D': 'Mouse Down', 'U': 'Mouse Up',
  'Fo': 'Focus', 'Bl': 'Blur',
  'PO': 'PageOpen', 'PC': 'PageClose',
  'PV': 'PageVisible', 'PI': 'PageInvisible',
  'K': 'Keystroke', 'F': 'Format',
  'V': 'Validate', 'C': 'Calculate',
};

const Map<String, String> documentActionEventType = {
  'WC': 'WillClose', 'WS': 'WillSave', 'DS': 'DidSave',
  'WP': 'WillPrint', 'DP': 'DidPrint',
};

const Map<String, String> pageActionEventType = {
  'O': 'PageOpen', 'C': 'PageClose',
};

abstract class VerbosityLevel {
  static const int errors = 0;
  static const int warnings = 1;
  static const int infos = 5;
}

// All the possible operations for an operator list.
abstract class OPS {
  static const int dependency = 1;
  static const int setLineWidth = 2;
  static const int setLineCap = 3;
  static const int setLineJoin = 4;
  static const int setMiterLimit = 5;
  static const int setDash = 6;
  static const int setRenderingIntent = 7;
  static const int setFlatness = 8;
  static const int setGState = 9;
  static const int save = 10;
  static const int restore = 11;
  static const int transform = 12;
  static const int moveTo = 13;
  static const int lineTo = 14;
  static const int curveTo = 15;
  static const int curveTo2 = 16;
  static const int curveTo3 = 17;
  static const int closePath = 18;
  static const int rectangle = 19;
  static const int stroke = 20;
  static const int closeStroke = 21;
  static const int fill = 22;
  static const int eoFill = 23;
  static const int fillStroke = 24;
  static const int eoFillStroke = 25;
  static const int closeFillStroke = 26;
  static const int closeEOFillStroke = 27;
  static const int endPath = 28;
  static const int clip = 29;
  static const int eoClip = 30;
  static const int beginText = 31;
  static const int endText = 32;
  static const int setCharSpacing = 33;
  static const int setWordSpacing = 34;
  static const int setHScale = 35;
  static const int setLeading = 36;
  static const int setFont = 37;
  static const int setTextRenderingMode = 38;
  static const int setTextRise = 39;
  static const int moveText = 40;
  static const int setLeadingMoveText = 41;
  static const int setTextMatrix = 42;
  static const int nextLine = 43;
  static const int showText = 44;
  static const int showSpacedText = 45;
  static const int nextLineShowText = 46;
  static const int nextLineSetSpacingShowText = 47;
  static const int setCharWidth = 48;
  static const int setCharWidthAndBounds = 49;
  static const int setStrokeColorSpace = 50;
  static const int setFillColorSpace = 51;
  static const int setStrokeColor = 52;
  static const int setStrokeColorN = 53;
  static const int setFillColor = 54;
  static const int setFillColorN = 55;
  static const int setStrokeGray = 56;
  static const int setFillGray = 57;
  static const int setStrokeRGBColor = 58;
  static const int setFillRGBColor = 59;
  static const int setStrokeCMYKColor = 60;
  static const int setFillCMYKColor = 61;
  static const int shadingFill = 62;
  static const int beginInlineImage = 63;
  static const int beginImageData = 64;
  static const int endInlineImage = 65;
  static const int paintXObject = 66;
  static const int markPoint = 67;
  static const int markPointProps = 68;
  static const int beginMarkedContent = 69;
  static const int beginMarkedContentProps = 70;
  static const int endMarkedContent = 71;
  static const int beginCompat = 72;
  static const int endCompat = 73;
  static const int paintFormXObjectBegin = 74;
  static const int paintFormXObjectEnd = 75;
  static const int beginGroup = 76;
  static const int endGroup = 77;
  static const int beginAnnotation = 80;
  static const int endAnnotation = 81;
  static const int paintImageMaskXObject = 83;
  static const int paintImageMaskXObjectGroup = 84;
  static const int paintImageXObject = 85;
  static const int paintInlineImageXObject = 86;
  static const int paintInlineImageXObjectGroup = 87;
  static const int paintImageXObjectRepeat = 88;
  static const int paintImageMaskXObjectRepeat = 89;
  static const int paintSolidColorImageMask = 90;
  static const int constructPath = 91;
  static const int setStrokeTransparent = 92;
  static const int setFillTransparent = 93;
  static const int rawFillPath = 94;
}

abstract class DrawOPS {
  static const int moveTo = 0;
  static const int lineTo = 1;
  static const int curveTo = 2;
  static const int quadraticCurveTo = 3;
  static const int closePath = 4;
}

abstract class PasswordResponses {
  static const int needPassword = 1;
  static const int incorrectPassword = 2;
}

// --- Verbosity ---

int _verbosity = VerbosityLevel.warnings;

void setVerbosityLevel(int level) {
  _verbosity = level;
}

int getVerbosityLevel() => _verbosity;

void info(String msg) {
  if (_verbosity >= VerbosityLevel.infos) {
    print('Info: $msg');
  }
}

void warn(String msg) {
  if (_verbosity >= VerbosityLevel.warnings) {
    print('Warning: $msg');
  }
}

Never unreachable(String msg) {
  throw StateError(msg);
}

void assert_(bool cond, String msg) {
  if (!cond) {
    unreachable(msg);
  }
}

// --- Exceptions ---

class BaseException implements Exception {
  final String message;
  final String name;
  BaseException(this.message, this.name);
  @override
  String toString() => '$name: $message';
}

class PasswordException extends BaseException {
  final int code;
  PasswordException(String msg, this.code) : super(msg, 'PasswordException');
}

class UnknownErrorException extends BaseException {
  final String details;
  UnknownErrorException(String msg, this.details)
      : super(msg, 'UnknownErrorException');
}

class InvalidPDFException extends BaseException {
  InvalidPDFException(String msg) : super(msg, 'InvalidPDFException');
}

class ResponseException extends BaseException {
  final int status;
  final bool missing;
  ResponseException(String msg, this.status, this.missing)
      : super(msg, 'ResponseException');
}

class FormatError extends BaseException {
  FormatError(String msg) : super(msg, 'FormatError');
}

class AbortException extends BaseException {
  AbortException(String msg) : super(msg, 'AbortException');
}

// --- Utility functions ---

String bytesToString(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.writeCharCode(b);
  }
  return sb.toString();
}

Uint8List stringToBytes(String str) {
  final length = str.length;
  final bytes = Uint8List(length);
  for (int i = 0; i < length; i++) {
    bytes[i] = str.codeUnitAt(i) & 0xff;
  }
  return bytes;
}

int objectSize(Map<String, dynamic> obj) => obj.length;

bool isLittleEndian() {
  final buffer8 = Uint8List(4);
  buffer8[0] = 1;
  final view32 = buffer8.buffer.asUint32List(0, 1);
  return view32[0] == 1;
}

// --- Hex numbers table ---

final List<String> hexNumbers = List<String>.generate(
  256,
  (n) => n.toRadixString(16).padLeft(2, '0'),
);

// --- Util class ---

class PdfJsUtil {
  PdfJsUtil._();

  static String makeHexColor(int r, int g, int b) {
    return '#${hexNumbers[r]}${hexNumbers[g]}${hexNumbers[b]}';
  }

  static void scaleMinMax(List<double> transform, List<double> minMax) {
    double temp;
    if (transform[0] != 0) {
      if (transform[0] < 0) {
        temp = minMax[0]; minMax[0] = minMax[2]; minMax[2] = temp;
      }
      minMax[0] *= transform[0];
      minMax[2] *= transform[0];
      if (transform[3] < 0) {
        temp = minMax[1]; minMax[1] = minMax[3]; minMax[3] = temp;
      }
      minMax[1] *= transform[3];
      minMax[3] *= transform[3];
    } else {
      temp = minMax[0]; minMax[0] = minMax[1]; minMax[1] = temp;
      temp = minMax[2]; minMax[2] = minMax[3]; minMax[3] = temp;
      if (transform[1] < 0) {
        temp = minMax[1]; minMax[1] = minMax[3]; minMax[3] = temp;
      }
      minMax[1] *= transform[1];
      minMax[3] *= transform[1];
      if (transform[2] < 0) {
        temp = minMax[0]; minMax[0] = minMax[2]; minMax[2] = temp;
      }
      minMax[0] *= transform[2];
      minMax[2] *= transform[2];
    }
    minMax[0] += transform[4];
    minMax[1] += transform[5];
    minMax[2] += transform[4];
    minMax[3] += transform[5];
  }

  /// Concatenates two transformation matrices.
  static List<double> transform(List<double> m1, List<double> m2) {
    return [
      m1[0] * m2[0] + m1[2] * m2[1],
      m1[1] * m2[0] + m1[3] * m2[1],
      m1[0] * m2[2] + m1[2] * m2[3],
      m1[1] * m2[2] + m1[3] * m2[3],
      m1[0] * m2[4] + m1[2] * m2[5] + m1[4],
      m1[1] * m2[4] + m1[3] * m2[5] + m1[5],
    ];
  }

  /// For 2d affine transforms.
  static void applyTransform(List<double> p, List<double> m, [int pos = 0]) {
    final p0 = p[pos];
    final p1 = p[pos + 1];
    p[pos] = p0 * m[0] + p1 * m[2] + m[4];
    p[pos + 1] = p0 * m[1] + p1 * m[3] + m[5];
  }

  static void applyInverseTransform(List<double> p, List<double> m) {
    final p0 = p[0];
    final p1 = p[1];
    final d = m[0] * m[3] - m[1] * m[2];
    p[0] = (p0 * m[3] - p1 * m[2] + m[2] * m[5] - m[4] * m[3]) / d;
    p[1] = (-p0 * m[1] + p1 * m[0] + m[4] * m[1] - m[5] * m[0]) / d;
  }

  static List<double> inverseTransform(List<double> m) {
    final d = m[0] * m[3] - m[1] * m[2];
    return [
      m[3] / d, -m[1] / d,
      -m[2] / d, m[0] / d,
      (m[2] * m[5] - m[4] * m[3]) / d,
      (m[4] * m[1] - m[5] * m[0]) / d,
    ];
  }

  static void singularValueDecompose2dScale(
      List<double> matrix, List<double> output) {
    final m0 = matrix[0], m1 = matrix[1], m2 = matrix[2], m3 = matrix[3];
    final a = m0 * m0 + m1 * m1;
    final b = m0 * m2 + m1 * m3;
    final c = m2 * m2 + m3 * m3;
    final first = (a + c) / 2;
    final second = math.sqrt(first * first - (a * c - b * b));
    output[0] = math.sqrt(first + second == 0 ? 1 : first + second);
    output[1] = math.sqrt(first - second == 0 ? 1 : first - second);
  }

  static List<double> normalizeRect(List<double> rect) {
    final r = List<double>.from(rect);
    if (rect[0] > rect[2]) { r[0] = rect[2]; r[2] = rect[0]; }
    if (rect[1] > rect[3]) { r[1] = rect[3]; r[3] = rect[1]; }
    return r;
  }

  static List<double>? intersect(List<double> rect1, List<double> rect2) {
    final xLow = math.max(math.min(rect1[0], rect1[2]), math.min(rect2[0], rect2[2]));
    final xHigh = math.min(math.max(rect1[0], rect1[2]), math.max(rect2[0], rect2[2]));
    if (xLow > xHigh) return null;
    final yLow = math.max(math.min(rect1[1], rect1[3]), math.min(rect2[1], rect2[3]));
    final yHigh = math.min(math.max(rect1[1], rect1[3]), math.max(rect2[1], rect2[3]));
    if (yLow > yHigh) return null;
    return [xLow, yLow, xHigh, yHigh];
  }

  static void bezierBoundingBox(double x0, double y0, double x1, double y1,
      double x2, double y2, double x3, double y3, List<double> minMax) {
    minMax[0] = math.min(minMax[0], math.min(x0, x3));
    minMax[1] = math.min(minMax[1], math.min(y0, y3));
    minMax[2] = math.max(minMax[2], math.max(x0, x3));
    minMax[3] = math.max(minMax[3], math.max(y0, y3));

    _getExtremum(x0, x1, x2, x3, y0, y1, y2, y3,
        3 * (-x0 + 3 * (x1 - x2) + x3), 6 * (x0 - 2 * x1 + x2), 3 * (x1 - x0), minMax);
    _getExtremum(x0, x1, x2, x3, y0, y1, y2, y3,
        3 * (-y0 + 3 * (y1 - y2) + y3), 6 * (y0 - 2 * y1 + y2), 3 * (y1 - y0), minMax);
  }

  static void _getExtremumOnCurve(double x0, double x1, double x2, double x3,
      double y0, double y1, double y2, double y3, double t, List<double> minMax) {
    if (t <= 0 || t >= 1) return;
    final mt = 1 - t;
    final tt = t * t;
    final ttt = tt * t;
    final x = mt * (mt * (mt * x0 + 3 * t * x1) + 3 * tt * x2) + ttt * x3;
    final y = mt * (mt * (mt * y0 + 3 * t * y1) + 3 * tt * y2) + ttt * y3;
    minMax[0] = math.min(minMax[0], x);
    minMax[1] = math.min(minMax[1], y);
    minMax[2] = math.max(minMax[2], x);
    minMax[3] = math.max(minMax[3], y);
  }

  static void _getExtremum(double x0, double x1, double x2, double x3,
      double y0, double y1, double y2, double y3,
      double a, double b, double c, List<double> minMax) {
    if (a.abs() < 1e-12) {
      if (b.abs() >= 1e-12) {
        _getExtremumOnCurve(x0, x1, x2, x3, y0, y1, y2, y3, -c / b, minMax);
      }
      return;
    }
    final delta = b * b - 4 * c * a;
    if (delta < 0) return;
    final sqrtDelta = math.sqrt(delta);
    final a2 = 2 * a;
    _getExtremumOnCurve(x0, x1, x2, x3, y0, y1, y2, y3, (-b + sqrtDelta) / a2, minMax);
    _getExtremumOnCurve(x0, x1, x2, x3, y0, y1, y2, y3, (-b - sqrtDelta) / a2, minMax);
  }
}

// --- String utility functions ---

bool isArrayEqual(List arr1, List arr2) {
  if (arr1.length != arr2.length) return false;
  for (int i = 0; i < arr1.length; i++) {
    if (arr1[i] != arr2[i]) return false;
  }
  return true;
}

String getModificationDate([DateTime? date]) {
  date ??= DateTime.now();
  final utc = date.toUtc();
  return '${utc.year}'
      '${utc.month.toString().padLeft(2, '0')}'
      '${utc.day.toString().padLeft(2, '0')}'
      '${utc.hour.toString().padLeft(2, '0')}'
      '${utc.minute.toString().padLeft(2, '0')}'
      '${utc.second.toString().padLeft(2, '0')}';
}

String stripPath(String str) {
  final idx = str.lastIndexOf('/');
  return idx >= 0 ? str.substring(idx + 1) : str;
}

const String annotationPrefix = 'pdfjs_internal_id_';
