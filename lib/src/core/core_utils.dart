// Copyright 2019 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;
import 'dart:typed_data';
import '../shared/util.dart';
import 'primitives.dart';


final RegExp pdfVersionRegexp = RegExp(r'^[1-9]\.\d$');
const int maxInt32 = 2147483647; // 2^31 - 1
const int minInt32 = -2147483648; // -(2^31)

const List<double> identityMatrix = [1, 0, 0, 1, 0, 0];

const List<String> resourcesKeysOperatorList = [
  'ColorSpace', 'ExtGState', 'Font', 'Pattern',
  'Properties', 'Shading', 'XObject',
];

const List<String> resourcesKeysTextContent = [
  'ExtGState', 'Font', 'Properties', 'XObject',
];

/// Factory de tabela de lookup com inicialização lazy.
Map<String, dynamic> Function() getLookupTableFactory(
    void Function(Map<String, dynamic>) initializer) {
  Map<String, dynamic>? lookup;
  return () {
    if (lookup == null) {
      lookup = {};
      initializer(lookup!);
    }
    return lookup!;
  };
}

// --- Exceções ---

class MissingDataException extends BaseException {
  final int begin;
  final int end;
  MissingDataException(this.begin, this.end)
      : super('Missing data [$begin, $end)', 'MissingDataException');
}

class ParserEOFException extends BaseException {
  ParserEOFException(String msg) : super(msg, 'ParserEOFException');
}

class XRefEntryException extends BaseException {
  XRefEntryException(String msg) : super(msg, 'XRefEntryException');
}

class XRefParseException extends BaseException {
  XRefParseException(String msg) : super(msg, 'XRefParseException');
}

/// Combina múltiplos buffers em um único Uint8List.
Uint8List arrayBuffersToBytes(List<ByteBuffer> arr) {
  if (arr.isEmpty) return Uint8List(0);
  if (arr.length == 1) return Uint8List.view(arr[0]);
  int dataLength = 0;
  for (final buf in arr) {
    dataLength += buf.lengthInBytes;
  }
  final data = Uint8List(dataLength);
  int pos = 0;
  for (final buf in arr) {
    final item = Uint8List.view(buf);
    data.setRange(pos, pos + item.length, item);
    pos += item.length;
  }
  return data;
}

/// Obtém o valor de uma propriedade herdável em uma árvore de Dict.
dynamic getInheritableProperty({
  required Dict dict,
  required String key,
  bool getArray = false,
  bool stopWhenFound = true,
}) {
  List<dynamic>? values;
  final visited = RefSet();
  Dict? current = dict;

  while (current != null &&
      !(current.objId != null && visited.has(current.objId!))) {
    if (current.objId != null) visited.put(current.objId!);
    final value = getArray ? current.getArray(key) : current.get(key);
    if (value != null) {
      if (stopWhenFound) return value;
      (values ??= []).add(value);
    }
    final parent = current.get('Parent');
    current = parent is Dict ? parent : null;
  }
  return values;
}

// --- Números romanos ---

const List<String> _romanNumberMap = [
  '', 'C', 'CC', 'CCC', 'CD', 'D', 'DC', 'DCC', 'DCCC', 'CM',
  '', 'X', 'XX', 'XXX', 'XL', 'L', 'LX', 'LXX', 'LXXX', 'XC',
  '', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX',
];

String toRomanNumerals(int number, [bool lowerCase = false]) {
  assert_(number > 0, 'The number should be a positive integer.');
  final roman =
      '${'M' * (number ~/ 1000)}'
      '${_romanNumberMap[(number % 1000) ~/ 100]}'
      '${_romanNumberMap[10 + (number % 100) ~/ 10]}'
      '${_romanNumberMap[20 + number % 10]}';
  return lowerCase ? roman.toLowerCase() : roman;
}

int log2(int x) {
  return x > 0 ? (math.log(x) / math.ln2).ceil() : 0;
}

bool isWhiteSpace(int ch) {
  return ch == 0x20 || ch == 0x09 || ch == 0x0d || ch == 0x0a;
}

bool isBooleanArray(dynamic arr, [int? len]) {
  if (arr is! List) return false;
  if (len != null && arr.length != len) return false;
  return arr.every((x) => x is bool);
}

bool isNumberArray(dynamic arr, [int? len]) {
  if (arr is List) {
    if (len != null && arr.length != len) return false;
    return arr.every((x) => x is num);
  }
  return false;
}

List<double>? lookupMatrix(dynamic arr, List<double>? fallback) {
  if (isNumberArray(arr, 6)) return List<double>.from(arr as List);
  return fallback;
}

List<double>? lookupRect(dynamic arr, List<double>? fallback) {
  if (isNumberArray(arr, 4)) return List<double>.from(arr as List);
  return fallback;
}

List<double>? lookupNormalRect(dynamic arr, List<double>? fallback) {
  if (isNumberArray(arr, 4)) return PdfJsUtil.normalizeRect(List<double>.from(arr as List));
  return fallback;
}

String escapePDFName(String str) {
  final buffer = StringBuffer();
  int start = 0;
  for (int i = 0; i < str.length; i++) {
    final char = str.codeUnitAt(i);
    if (char < 0x21 || char > 0x7e ||
        char == 0x23 || char == 0x28 || char == 0x29 ||
        char == 0x3c || char == 0x3e ||
        char == 0x5b || char == 0x5d ||
        char == 0x7b || char == 0x7d ||
        char == 0x2f || char == 0x25) {
      if (start < i) buffer.write(str.substring(start, i));
      buffer.write('#${char.toRadixString(16)}');
      start = i + 1;
    }
  }
  if (buffer.isEmpty) return str;
  if (start < str.length) buffer.write(str.substring(start));
  return buffer.toString();
}

String escapeString(String str) {
  return str.replaceAllMapped(RegExp(r'([()\\' '\n\r])'), (m) {
    final match = m.group(0)!;
    if (match == '\n') return r'\n';
    if (match == '\r') return r'\r';
    return '\\$match';
  });
}

String numberToString(num value) {
  if (value is int || value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  final roundedValue = (value * 100).round();
  if (roundedValue % 100 == 0) return (roundedValue ~/ 100).toString();
  if (roundedValue % 10 == 0) return value.toStringAsFixed(1);
  return value.toStringAsFixed(2);
}

bool isAscii(String? str) {
  if (str == null) return false;
  return RegExp(r'^[\x00-\x7F]*$').hasMatch(str);
}

String stringToUTF16HexString(String str) {
  final buf = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    final char = str.codeUnitAt(i);
    buf.write(hexNumbers[(char >> 8) & 0xff]);
    buf.write(hexNumbers[char & 0xff]);
  }
  return buf.toString();
}

String stringToUTF16String(String str, [bool bigEndian = false]) {
  final buf = StringBuffer();
  if (bigEndian) buf.write('\xFE\xFF');
  for (int i = 0; i < str.length; i++) {
    final char = str.codeUnitAt(i);
    buf.writeCharCode((char >> 8) & 0xff);
    buf.writeCharCode(char & 0xff);
  }
  return buf.toString();
}

String? stringToAsciiOrUTF16BE(String? str) {
  if (str == null) return str;
  return isAscii(str) ? str : stringToUTF16String(str, true);
}

List<double> getRotationMatrix(int rotation, double width, double height) {
  switch (rotation) {
    case 90:  return [0, 1, -1, 0, width, 0];
    case 180: return [-1, 0, 0, -1, width, height];
    case 270: return [0, -1, 1, 0, 0, height];
    default:  throw ArgumentError('Invalid rotation: $rotation');
  }
}

int getSizeInBytes(int x) {
  return ((math.log(1 + x) / math.ln2).ceil() / 8).ceil();
}

String encodeToXmlString(String str) {
  const xmlEntities = {
    0x3c: '&lt;', 0x3e: '&gt;', 0x26: '&amp;',
    0x22: '&quot;', 0x27: '&apos;',
  };
  final buffer = StringBuffer();
  int start = 0;
  for (int i = 0; i < str.length; i++) {
    final char = str.codeUnitAt(i);
    if (0x20 <= char && char <= 0x7e) {
      final entity = xmlEntities[char];
      if (entity != null) {
        if (start < i) buffer.write(str.substring(start, i));
        buffer.write(entity);
        start = i + 1;
      }
    } else {
      if (start < i) buffer.write(str.substring(start, i));
      buffer.write('&#x${char.toRadixString(16).toUpperCase()};');
      start = i + 1;
    }
  }
  if (buffer.isEmpty) return str;
  if (start < str.length) buffer.write(str.substring(start));
  return buffer.toString();
}
