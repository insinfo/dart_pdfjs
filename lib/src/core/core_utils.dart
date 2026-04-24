// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import '../shared/util.dart';

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

class XFAPathComponent {
  const XFAPathComponent({
    required this.name,
    required this.pos,
  });

  final String name;
  final int pos;
}

List<XFAPathComponent> parseXFAPath(String path) {
  final positionPattern = RegExp(r'(.+)\[(\d+)\]$');
  return path.split('.').map((component) {
    final match = positionPattern.firstMatch(component);
    if (match != null) {
      return XFAPathComponent(
        name: match.group(1)!,
        pos: int.parse(match.group(2)!),
      );
    }
    return XFAPathComponent(name: component, pos: 0);
  }).toList(growable: false);
}

class MissingDataException implements Exception {
  final int begin;
  final int end;
  MissingDataException(this.begin, this.end);
  @override
  String toString() => 'MissingDataException: from $begin to $end';
}

bool isWhiteSpace(int ch) {
  return ch == 0x20 || ch == 0x09 || ch == 0x0D || ch == 0x0A;
}

bool isSpace(int ch) {
  return ch == 0x20 || ch == 0x09 || ch == 0x0D || ch == 0x0A;
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
