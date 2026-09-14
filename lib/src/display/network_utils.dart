// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import '../shared/util.dart';
import 'content_disposition.dart';

bool isPdfFile(dynamic filename) {
  return filename is String &&
      RegExp(r'\.pdf$', caseSensitive: false).hasMatch(filename);
}

class Headers {
  final Map<String, String> _map = {};

  Headers([Map<dynamic, dynamic>? init]) {
    if (init != null) {
      for (final entry in init.entries) {
        if (entry.value != null) {
          _map[entry.key.toString().toLowerCase()] = entry.value.toString();
        }
      }
    }
  }

  String? get(String name) => _map[name.toLowerCase()];

  void set(String name, String value) {
    _map[name.toLowerCase()] = value;
  }

  void append(String name, String value) {
    _map[name.toLowerCase()] = value;
  }

  Iterable<MapEntry<String, String>> get entries => _map.entries;

  Map<String, String> toMap() => Map.unmodifiable(_map);
}

Headers createHeaders(bool isHttp, [dynamic httpHeaders]) {
  final headers = Headers();
  if (!isHttp || httpHeaders == null || httpHeaders is! Map) {
    return headers;
  }
  for (final entry in httpHeaders.entries) {
    final val = entry.value;
    // Em JS: null é appended como "null", apenas undefined é descartado.
    // Em Dart, se a chave existir no mapa, tratamos:
    headers.append(entry.key.toString(), val == null ? 'null' : val.toString());
  }
  return headers;
}

class RangeRequestCapabilities {
  int contentLength;
  bool isRangeSupported;

  RangeRequestCapabilities({
    this.contentLength = 0,
    this.isRangeSupported = false,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RangeRequestCapabilities &&
            other.contentLength == contentLength &&
            other.isRangeSupported == isRangeSupported);
  }

  @override
  int get hashCode => Object.hash(contentLength, isRangeSupported);

  @override
  String toString() =>
      'RangeRequestCapabilities(contentLength: $contentLength, isRangeSupported: $isRangeSupported)';
}

RangeRequestCapabilities validateRangeRequestCapabilities({
  dynamic responseHeaders,
  bool isHttp = false,
  dynamic rangeChunkSize,
  bool disableRange = false,
}) {
  if (rangeChunkSize is! int || rangeChunkSize <= 0) {
    throw ArgumentError('rangeChunkSize must be an integer larger than zero.');
  }

  final rv = RangeRequestCapabilities();

  String? getHeader(String key) {
    if (responseHeaders is Headers) {
      return responseHeaders.get(key);
    }
    if (responseHeaders is Map) {
      return responseHeaders[key]?.toString() ??
          responseHeaders[key.toLowerCase()]?.toString();
    }
    return null;
  }

  final lenStr = getHeader('Content-Length');
  if (lenStr == null) {
    return rv;
  }
  final length = int.tryParse(lenStr);
  if (length == null) {
    return rv;
  }
  rv.contentLength = length;

  if (length <= 2 * rangeChunkSize) {
    return rv;
  }
  if (disableRange || !isHttp) {
    return rv;
  }

  final acceptRanges = getHeader('Accept-Ranges');
  if (acceptRanges != 'bytes') {
    return rv;
  }

  final contentEncoding = getHeader('Content-Encoding') ?? 'identity';
  if (contentEncoding == 'identity') {
    rv.isRangeSupported = true;
  }
  return rv;
}

String? extractFilenameFromHeader(dynamic responseHeaders) {
  String? getHeader(String key) {
    if (responseHeaders is Headers) {
      return responseHeaders.get(key);
    }
    if (responseHeaders is Map) {
      return responseHeaders[key]?.toString() ??
          responseHeaders[key.toLowerCase()]?.toString();
    }
    return null;
  }

  final contentDisposition = getHeader('Content-Disposition');
  if (contentDisposition != null) {
    var filename = getFilenameFromContentDispositionHeader(contentDisposition);
    if (filename.contains('%')) {
      try {
        filename = Uri.decodeComponent(filename);
      } catch (_) {}
    }
    if (isPdfFile(filename)) {
      return filename;
    }
  }
  return null;
}

ResponseException createResponseError(int status, dynamic url) {
  final uri = url is Uri ? url : Uri.parse(url.toString());
  final isMissing = status == 404 || (status == 0 && uri.scheme == 'file');
  return ResponseException(
    'Unexpected server response ($status) while retrieving PDF "$uri".',
    status,
    isMissing,
  );
}

void ensureResponseOrigin(String? rangeOrigin, String? origin) {
  if (rangeOrigin != origin) {
    throw Exception(
        'Expected range response-origin "$rangeOrigin" to match "$origin".');
  }
}

String? getResponseOrigin(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.origin;
  } catch (_) {
    return null;
  }
}
