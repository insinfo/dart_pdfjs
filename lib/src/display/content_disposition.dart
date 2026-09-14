// Copyright 2017 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:convert';

import '../shared/util.dart';

/// Extract file name from the Content-Disposition HTTP response header.
String getFilenameFromContentDispositionHeader(String contentDisposition) {
  var needsEncodingFixup = true;

  String textdecode(String? encoding, String value) {
    if (encoding != null && encoding.isNotEmpty) {
      final enc = encoding.toLowerCase();
      try {
        final buffer = stringToBytes(value);
        if (enc == 'utf-8' || enc == 'utf8') {
          value = utf8.decode(buffer);
          needsEncodingFixup = false;
        } else if (enc == 'iso-8859-1' || enc == 'latin1') {
          value = latin1.decode(buffer);
          needsEncodingFixup = false;
        }
      } catch (_) {}
    }
    return value;
  }

  String fixupEncoding(String value) {
    if (needsEncodingFixup && RegExp(r'[\x80-\xff]').hasMatch(value)) {
      value = textdecode('utf-8', value);
      if (needsEncodingFixup) {
        value = textdecode('iso-8859-1', value);
      }
    }
    return value;
  }

  RegExp toParamRegExp(String attributePattern, [String flags = '']) {
    return RegExp(
      '(?:^|;)\\s*$attributePattern\\s*=\\s*([^";\\s][^;\\s]*|"(?:[^"\\\\]|\\\\"?)+"?)',
      caseSensitive: !flags.contains('i'),
      multiLine: flags.contains('m'),
    );
  }

  String rfc2616unquote(String value) {
    if (value.startsWith('"')) {
      final parts = value.substring(1).split('\\"');
      for (var i = 0; i < parts.length; ++i) {
        final quotindex = parts[i].indexOf('"');
        if (quotindex != -1) {
          parts[i] = parts[i].substring(0, quotindex);
          parts.length = i + 1;
        }
        parts[i] = parts[i].replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!);
      }
      value = parts.join('"');
    }
    return value;
  }

  String rfc5987decode(String extvalue) {
    final encodingend = extvalue.indexOf("'");
    if (encodingend == -1) {
      return extvalue;
    }
    final encoding = extvalue.substring(0, encodingend);
    final langvalue = extvalue.substring(encodingend + 1);
    final value = langvalue.replaceFirst(RegExp(r"^[^']*'"), '');
    return textdecode(encoding, value);
  }

  String rfc2047decode(String value) {
    if (!value.startsWith('=?') || RegExp(r'[\x00-\x19\x80-\xff]').hasMatch(value)) {
      return value;
    }
    return value.replaceAllMapped(
      RegExp(r'=\?([\w-]*)\?([QqBb])\?((?:[^?]|\?(?!=))*)\?='),
      (match) {
        final charset = match[1]!;
        final encoding = match[2]!;
        var text = match[3]!;
        if (encoding == 'q' || encoding == 'Q') {
          text = text.replaceAll('_', ' ');
          text = text.replaceAllMapped(RegExp(r'=([0-9a-fA-F]{2})'), (hexMatch) {
            return String.fromCharCode(int.parse(hexMatch[1]!, radix: 16));
          });
          return textdecode(charset, text);
        }
        try {
          final decodedBytes = base64Decode(text);
          text = utf8.decode(decodedBytes, allowMalformed: true);
        } catch (_) {}
        return textdecode(charset, text);
      },
    );
  }

  String unescapeUri(String str) {
    try {
      return Uri.decodeComponent(str);
    } catch (_) {
      return str;
    }
  }

  String rfc2231getparam(String contentDispositionStr) {
    final matches = <int, List<String>>{};
    final iter = RegExp(
      r'(?:^|;)\s*filename\*(\d+)(\*?)\s*=\s*([^";\s][^;\s]*|"(?:[^"\\]|\\"?)+"?)',
      caseSensitive: false,
    );

    for (final match in iter.allMatches(contentDispositionStr)) {
      final nStr = match[1]!;
      final quot = match[2]!;
      final part = match[3]!;
      final n = int.parse(nStr);
      if (matches.containsKey(n)) {
        if (n == 0) break;
        continue;
      }
      matches[n] = [quot, part];
    }

    final parts = <String>[];
    for (var n = 0; n < matches.length; ++n) {
      if (!matches.containsKey(n)) {
        break;
      }
      final pair = matches[n]!;
      final quot = pair[0];
      var part = rfc2616unquote(pair[1]);
      if (quot.isNotEmpty) {
        part = unescapeUri(part);
        if (n == 0) {
          part = rfc5987decode(part);
        }
      }
      parts.add(part);
    }
    return parts.join('');
  }

  // filename*=ext-value
  final fnStarMatch = toParamRegExp(r'filename\*', 'i').firstMatch(contentDisposition);
  if (fnStarMatch != null) {
    var raw = fnStarMatch[1]!;
    var filename = rfc2616unquote(raw);
    filename = unescapeUri(filename);
    filename = rfc5987decode(filename);
    filename = rfc2047decode(filename);
    return fixupEncoding(filename);
  }

  // Continuations
  final cont = rfc2231getparam(contentDisposition);
  if (cont.isNotEmpty) {
    final filename = rfc2047decode(cont);
    return fixupEncoding(filename);
  }

  // filename=value
  final fnMatch = toParamRegExp('filename', 'i').firstMatch(contentDisposition);
  if (fnMatch != null) {
    var raw = fnMatch[1]!;
    var filename = rfc2616unquote(raw);
    filename = rfc2047decode(filename);
    return fixupEncoding(filename);
  }

  return '';
}
