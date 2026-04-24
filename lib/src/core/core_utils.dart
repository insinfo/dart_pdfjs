// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'dart:math' as math;

import '../shared/util.dart';
import 'primitives.dart';
import 'base_stream.dart';

final RegExp PDF_VERSION_REGEXP = RegExp(r'^[1-9]\.\d$');
const int MAX_INT_32 = 2147483647;
const int MIN_INT_32 = -2147483648;

const List<num> IDENTITY_MATRIX = [1, 0, 0, 1, 0, 0];

const List<String> RESOURCES_KEYS_OPERATOR_LIST = [
  "ColorSpace",
  "ExtGState",
  "Font",
  "Pattern",
  "Properties",
  "Shading",
  "XObject",
];

const List<String> RESOURCES_KEYS_TEXT_CONTENT = [
  "ExtGState",
  "Font",
  "Properties",
  "XObject",
];

class MissingDataException implements Exception {
  final int begin;
  final int end;
  MissingDataException(this.begin, this.end);
  @override
  String toString() => 'MissingDataException: from $begin to $end';
}

class ParserEOFException implements Exception {
  final String message;
  ParserEOFException(this.message);
  @override
  String toString() => 'ParserEOFException: $message';
}

class XRefParseException implements Exception {
  final String message;
  XRefParseException([this.message = '']);
  @override
  String toString() => 'XRefParseException: $message';
}

class XRefEntryException implements Exception {
  final String message;
  XRefEntryException([this.message = '']);
  @override
  String toString() => 'XRefEntryException: $message';
}

Uint8List arrayBuffersToBytes(List<ByteBuffer> arr) {
  if (arr.isEmpty) {
    return Uint8List(0);
  }
  if (arr.length == 1) {
    return Uint8List.view(arr[0]);
  }
  var dataLength = 0;
  for (var i = 0; i < arr.length; i++) {
    dataLength += arr[i].lengthInBytes;
  }
  final data = Uint8List(dataLength);
  var pos = 0;
  for (var i = 0; i < arr.length; i++) {
    final item = Uint8List.view(arr[i]);
    data.setAll(pos, item);
    pos += item.lengthInBytes;
  }
  return data;
}

dynamic getInheritableProperty({
  required dynamic dict,
  required String key,
  bool getArray = false,
  bool stopWhenFound = true,
}) {
  List<dynamic>? values;
  final visited = RefSet();

  while (dict is Dict && !(dict.objId != null && visited.has(dict.objId!))) {
    if (dict.objId != null) {
      visited.put(dict.objId!);
    }
    final value = getArray ? dict.getArray(key) : dict.get(key);
    if (value != null) {
      if (stopWhenFound) {
        return value;
      }
      values ??= [];
      values.add(value);
    }
    dict = dict.get('Parent');
  }
  return values;
}

class ParentToUpdate {
  final Dict? dict;
  final Ref? ref;
  ParentToUpdate({this.dict, this.ref});
}

ParentToUpdate getParentToUpdate(dynamic dict, Ref ref, dynamic xref) {
  final visited = RefSet();
  final firstDict = dict;
  Dict? resultDict;
  Ref? resultRef;

  while (dict is Dict && !visited.has(ref)) {
    visited.put(ref);
    if (dict.has('T')) {
      break;
    }
    final nextRef = dict.getRaw('Parent');
    if (nextRef is! Ref) {
      return ParentToUpdate(dict: resultDict, ref: resultRef);
    }
    ref = nextRef;
    dict = xref.fetch(ref);
  }
  if (dict is Dict && dict != firstDict) {
    resultDict = dict;
    resultRef = ref;
  }
  return ParentToUpdate(dict: resultDict, ref: resultRef);
}

bool deepCompare(dynamic a, dynamic b) {
  if (a == b) {
    return true;
  }
  if (a is Dict && b is Dict) {
    if (a.size != b.size) {
      return false;
    }
    for (final entry in a.getRawEntries()) {
      final key = entry.key;
      final value1 = entry.value;
      final value2 = b.getRaw(key);
      if (value2 == null || !deepCompare(value1, value2)) {
        return false;
      }
    }
    return true;
  }

  if (a is List && b is List) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (!deepCompare(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }

  return false;
}

const List<String> ROMAN_NUMBER_MAP = [
  "",
  "C",
  "CC",
  "CCC",
  "CD",
  "D",
  "DC",
  "DCC",
  "DCCC",
  "CM",
  "",
  "X",
  "XX",
  "XXX",
  "XL",
  "L",
  "LX",
  "LXX",
  "LXXX",
  "XC",
  "",
  "I",
  "II",
  "III",
  "IV",
  "V",
  "VI",
  "VII",
  "VIII",
  "IX"
];

String toRomanNumerals(int number, [bool lowerCase = false]) {
  if (number <= 0) {
    throw ArgumentError('The number should be a positive integer.');
  }

  final mCount = number ~/ 1000;
  final roman = "M" * mCount +
      ROMAN_NUMBER_MAP[(number % 1000) ~/ 100] +
      ROMAN_NUMBER_MAP[10 + ((number % 100) ~/ 10)] +
      ROMAN_NUMBER_MAP[20 + (number % 10)];
  return lowerCase ? roman.toLowerCase() : roman;
}

int log2(num x) {
  return x > 0 ? (math.log(x) / math.ln2).ceil() : 0;
}

bool isWhiteSpace(int ch) {
  return ch == 0x20 || ch == 0x09 || ch == 0x0D || ch == 0x0A;
}

bool isSpace(int ch) {
  return ch == 0x20 || ch == 0x09 || ch == 0x0D || ch == 0x0A;
}

bool isBooleanArray(dynamic arr, [int? len]) {
  if (arr is! List) return false;
  if (len != null && arr.length != len) return false;
  return arr.every((x) => x is bool);
}

bool isNumberArray(dynamic arr, [int? len]) {
  if (arr is! List) {
    if (arr is TypedData) {
      if (arr is Int64List || arr is Uint64List) return false;
      if (len != null && arr.lengthInBytes ~/ arr.elementSizeInBytes != len)
        return false;
      return true;
    }
    return false;
  }
  if (len != null && arr.length != len) return false;
  return arr.every((x) => x is num);
}

dynamic lookupMatrix(dynamic arr, dynamic fallback) {
  return isNumberArray(arr, 6) ? arr : fallback;
}

dynamic lookupRect(dynamic arr, dynamic fallback) {
  return isNumberArray(arr, 4) ? arr : fallback;
}

dynamic lookupNormalRect(dynamic arr, dynamic fallback) {
  return isNumberArray(arr, 4) ? PdfJsUtil.normalizeRect(arr) : fallback;
}

class XFAPathComponent {
  final String name;
  final int pos;
  const XFAPathComponent({required this.name, required this.pos});
}

List<XFAPathComponent> parseXFAPath(String path) {
  final positionPattern = RegExp(r'(.+)\[(\d+)\]$');
  return path.split('.').map((component) {
    final m = positionPattern.firstMatch(component);
    if (m != null) {
      return XFAPathComponent(name: m.group(1)!, pos: int.parse(m.group(2)!));
    }
    return XFAPathComponent(name: component, pos: 0);
  }).toList();
}

String escapePDFName(String str) {
  final buffer = StringBuffer();
  var start = 0;
  for (var i = 0; i < str.length; i++) {
    final charCode = str.codeUnitAt(i);
    if (charCode < 0x21 ||
        charCode > 0x7e ||
        charCode == 0x23 ||
        charCode == 0x28 ||
        charCode == 0x29 ||
        charCode == 0x3c ||
        charCode == 0x3e ||
        charCode == 0x5b ||
        charCode == 0x5d ||
        charCode == 0x7b ||
        charCode == 0x7d ||
        charCode == 0x2f ||
        charCode == 0x25) {
      if (start < i) {
        buffer.write(str.substring(start, i));
      }
      buffer.write('#${charCode.toRadixString(16)}');
      start = i + 1;
    }
  }

  if (buffer.isEmpty) {
    return str;
  }

  if (start < str.length) {
    buffer.write(str.substring(start, str.length));
  }

  return buffer.toString();
}

String escapeString(String str) {
  return str.replaceAllMapped(RegExp(r'([()\\\n\r])'), (match) {
    final m = match.group(1)!;
    if (m == '\n') {
      return r'\n';
    } else if (m == '\r') {
      return r'\r';
    }
    return '\\$m';
  });
}

void _collectJS(
    dynamic entry, dynamic xref, List<String> list, RefSet parents) {
  if (entry == null) {
    return;
  }

  Ref? parent;
  if (entry is Ref) {
    if (parents.has(entry)) {
      return;
    }
    parent = entry;
    parents.put(parent);
    entry = xref.fetch(entry);
  }
  if (entry is List) {
    for (final element in entry) {
      _collectJS(element, xref, list, parents);
    }
  } else if (entry is Dict) {
    if (isName(entry.get('S'), 'JavaScript')) {
      final js = entry.get('JS');
      String? code;
      if (js is BaseStream) {
        code = js.getString();
      } else if (js is String) {
        code = js;
      }
      if (code != null) {
        code = stringToPDFString(code, keepEscapeSequence: true)
            .replaceAll('\x00', '');
        if (code.isNotEmpty) {
          list.add(code.trim());
        }
      }
    }
    _collectJS(entry.getRaw('Next'), xref, list, parents);
  }

  if (parent != null) {
    parents.remove(parent);
  }
}

Map<String, List<String>>? collectActions(
    dynamic xref, Dict dict, Map<String, String> eventType) {
  final actions = <String, List<String>>{};
  final additionalActionsDicts = getInheritableProperty(
    dict: dict,
    key: 'AA',
    stopWhenFound: false,
  );

  if (additionalActionsDicts != null && additionalActionsDicts is List) {
    for (var i = additionalActionsDicts.length - 1; i >= 0; i--) {
      final additionalActions = additionalActionsDicts[i];
      if (additionalActions is! Dict) {
        continue;
      }
      for (final entry in additionalActions.getRawEntries()) {
        final key = entry.key;
        final rawActionDict = entry.value;
        final action = eventType[key];
        if (action == null) {
          continue;
        }
        final parents = RefSet();
        final list = <String>[];
        _collectJS(rawActionDict, xref, list, parents);
        if (list.isNotEmpty) {
          actions[action] = list;
        }
      }
    }
  }

  if (dict.has('A')) {
    final actionDict = dict.get('A');
    final parents = RefSet();
    final list = <String>[];
    _collectJS(actionDict, xref, list, parents);
    if (list.isNotEmpty) {
      actions['Action'] = list;
    }
  }
  return actions.isNotEmpty ? actions : null;
}

const Map<int, String> _xmlEntities = {
  0x3c: '&lt;',
  0x3e: '&gt;',
  0x26: '&amp;',
  0x22: '&quot;',
  0x27: '&apos;',
};

Iterable<int> codePointIter(String str) sync* {
  yield* str.runes;
}

String encodeToXmlString(String str) {
  final buffer = StringBuffer();
  var changed = false;
  for (final char in str.runes) {
    if (0x20 <= char && char <= 0x7e) {
      final entity = _xmlEntities[char];
      if (entity != null) {
        buffer.write(entity);
        changed = true;
      } else {
        buffer.writeCharCode(char);
      }
    } else {
      buffer.write('&#x${char.toRadixString(16).toUpperCase()};');
      changed = true;
    }
  }
  return changed ? buffer.toString() : str;
}

bool validateFontName(String fontFamily, [bool mustWarn = false]) {
  final quoted = RegExp(r'''^("|').*("|')$''').firstMatch(fontFamily);
  if (quoted != null && quoted.group(1) == quoted.group(2)) {
    final quote = quoted.group(1)!;
    final escapedQuote = RegExp.escape(quote);
    if (RegExp('[^\\\\]$escapedQuote')
        .hasMatch(fontFamily.substring(1, fontFamily.length - 1))) {
      if (mustWarn) {
        warn('FontFamily contains unescaped $quote: $fontFamily.');
      }
      return false;
    }
  } else {
    for (final ident in fontFamily.split(RegExp(r'[ \t]+'))) {
      if (RegExp(r'^(\d|(-(\d|-)))').hasMatch(ident) ||
          !RegExp(r'^[\w\-\\]+$').hasMatch(ident)) {
        if (mustWarn) {
          warn('FontFamily contains invalid <custom-ident>: $fontFamily.');
        }
        return false;
      }
    }
  }
  return true;
}

bool validateCSSFont(Map<String, dynamic> cssFontInfo) {
  const DEFAULT_CSS_FONT_OBLIQUE = "14";
  const DEFAULT_CSS_FONT_WEIGHT = "400";
  const CSS_FONT_WEIGHT_VALUES = {
    "100",
    "200",
    "300",
    "400",
    "500",
    "600",
    "700",
    "800",
    "900",
    "1000",
    "normal",
    "bold",
    "bolder",
    "lighter"
  };

  final fontFamily = cssFontInfo['fontFamily'] as String?;
  final fontWeight = cssFontInfo['fontWeight'];
  final italicAngle = cssFontInfo['italicAngle'];

  if (fontFamily == null || !validateFontName(fontFamily, true)) {
    return false;
  }

  final weight = fontWeight?.toString() ?? "";
  cssFontInfo['fontWeight'] = CSS_FONT_WEIGHT_VALUES.contains(weight)
      ? weight
      : DEFAULT_CSS_FONT_WEIGHT;

  final angle = double.tryParse(italicAngle?.toString() ?? '');
  cssFontInfo['italicAngle'] = (angle == null || angle < -90 || angle > 90)
      ? DEFAULT_CSS_FONT_OBLIQUE
      : italicAngle.toString();

  return true;
}

class RecoveredJsUrl {
  final String url;
  final bool newWindow;
  RecoveredJsUrl(this.url, this.newWindow);
}

RecoveredJsUrl? recoverJsURL(String str) {
  const URL_OPEN_METHODS = ["app.launchURL", "window.open", "xfa.host.gotoURL"];
  final methodsJoined =
      URL_OPEN_METHODS.map((m) => m.replaceAll('.', r'\.')).join('|');
  final regex = RegExp(
    '^\\s*($methodsJoined)\\((?:\'|")([^\'"]*)(?:\'|")(?:,\\s*(\\w+)\\)|\\))',
    caseSensitive: false,
  );

  final match = regex.firstMatch(str);
  if (match != null && match.group(2) != null) {
    return RecoveredJsUrl(
      match.group(2)!,
      match.group(1)!.toLowerCase() == 'app.launchurl' &&
          match.group(3)?.toLowerCase() == 'true',
    );
  }

  return null;
}

String numberToString(num value) {
  if (value is int) {
    return value.toString();
  }
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  final roundedValue = (value * 100).round();
  if (roundedValue % 100 == 0) {
    return (roundedValue / 100).toInt().toString();
  }

  if (roundedValue % 10 == 0) {
    return value.toStringAsFixed(1);
  }

  return value.toStringAsFixed(2);
}

bool isAscii(String? str) {
  if (str == null) return false;
  return RegExp(r'^[\x00-\x7F]*$').hasMatch(str);
}

String? stringToAsciiOrUTF16BE(String? str) {
  if (str == null) {
    return str;
  }
  return isAscii(str) ? str : stringToUTF16String(str, bigEndian: true);
}

String stringToUTF16HexString(String str) {
  final buffer = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    final char = str.codeUnitAt(i);
    buffer.write(((char >> 8) & 0xff).toRadixString(16).padLeft(2, '0'));
    buffer.write((char & 0xff).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

String stringToUTF16String(String str, {bool bigEndian = false}) {
  final buffer = StringBuffer();
  if (bigEndian) {
    buffer.write('\xFE\xFF');
  }
  for (var i = 0; i < str.length; i++) {
    final char = str.codeUnitAt(i);
    buffer.writeCharCode((char >> 8) & 0xff);
    buffer.writeCharCode(char & 0xff);
  }
  return buffer.toString();
}

List<num> getRotationMatrix(int rotation, num width, num height) {
  switch (rotation) {
    case 90:
      return [0, 1, -1, 0, width, 0];
    case 180:
      return [-1, 0, 0, -1, width, height];
    case 270:
      return [0, -1, 1, 0, 0, height];
    default:
      throw ArgumentError('Invalid rotation');
  }
}

int getSizeInBytes(int x) {
  return ((math.log(1 + x) / math.ln2).ceil() / 8).ceil();
}
