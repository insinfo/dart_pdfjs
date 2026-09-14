// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'network_utils.dart';

typedef FetchProgressCallback = void Function(int loaded, int total);

web.Headers _createWebHeaders(Headers source) {
  final headers = web.Headers();
  for (final entry in source.entries) {
    headers.append(entry.key, entry.value);
  }
  return headers;
}

Headers _responseHeaders(web.Response response) {
  final headers = Headers();
  for (final name in [
    'Accept-Ranges',
    'Content-Disposition',
    'Content-Encoding',
    'Content-Length',
  ]) {
    final value = response.headers.get(name);
    if (value != null) {
      headers.set(name, value);
    }
  }
  return headers;
}

Future<web.Response> _fetchUrl(
  String url,
  Headers sourceHeaders,
  bool withCredentials,
  web.AbortController abortController, {
  int? begin,
  int? end,
}) async {
  final headers = _createWebHeaders(sourceHeaders);
  if (begin != null && end != null) {
    headers.set('Range', 'bytes=$begin-${end - 1}');
  }
  return web.window
      .fetch(
        url.toJS,
        web.RequestInit(
          method: 'GET',
          headers: headers,
          signal: abortController.signal,
          mode: 'cors',
          credentials: withCredentials ? 'include' : 'same-origin',
          redirect: 'follow',
        ),
      )
      .toDart;
}

void _ensureResponseStatus(int status, String url) {
  if (status != 200 && status != 206) {
    throw createResponseError(status, url);
  }
}

Future<Uint8List> _responseBytes(web.Response response) async {
  final buffer = await response.arrayBuffer().toDart;
  return Uint8List.fromList(buffer.toDart.asUint8List());
}

/// Fetch-based PDF stream for HTTP(S) resources.
class PDFFetchStream {
  final Map<String, dynamic> source;
  final Headers headers;
  String? responseOrigin;
  PDFFetchStreamReader? _fullReader;
  final Set<PDFFetchStreamRangeReader> _rangeReaders = {};

  PDFFetchStream(this.source)
      : headers = createHeaders(true, source['httpHeaders']) {
    final uri = _url;
    if (uri.scheme != 'http' && uri.scheme != 'https' && uri.scheme != 'data') {
      throw ArgumentError('PDFFetchStream only supports http(s):// URLs.');
    }
  }

  Uri get _url {
    final value = source['url'];
    if (value is Uri) return value;
    if (value is String) return Uri.parse(value);
    throw ArgumentError('PDFFetchStream requires a URL.');
  }

  String get url => _url.toString();
  bool get withCredentials => source['withCredentials'] == true;

  int get progressiveDataLength => _fullReader?.loaded ?? 0;

  PDFFetchStreamReader getFullReader() {
    if (_fullReader != null) {
      throw StateError('PDFFetchStream.getFullReader can only be called once.');
    }
    return _fullReader = PDFFetchStreamReader(this);
  }

  PDFFetchStreamRangeReader? getRangeReader(int begin, int end) {
    if (end <= progressiveDataLength) return null;
    final reader = PDFFetchStreamRangeReader(this, begin, end);
    _rangeReaders.add(reader);
    return reader;
  }

  void cancelAllRequests(dynamic reason) {
    _fullReader?.cancel(reason);
    for (final reader in _rangeReaders.toList()) {
      reader.cancel(reason);
    }
  }
}

/// Full-document fetch reader. The response is exposed as one binary chunk,
/// while preserving the PDF.js metadata and progress contract.
class PDFFetchStreamReader {
  final PDFFetchStream stream;
  final web.AbortController _abortController = web.AbortController();
  final Completer<void> _headersCompleter = Completer<void>();
  late final Future<Uint8List> _data;
  bool _done = false;
  int _loaded = 0;
  int _contentLength = 0;
  String? _filename;
  bool _isRangeSupported = false;
  late final bool _isStreamingSupported;
  FetchProgressCallback? onProgress;

  PDFFetchStreamReader(this.stream) {
    _isStreamingSupported = stream.source['disableStream'] != true;
    _data = _initialize();
  }

  Future<Uint8List> _initialize() async {
    try {
      final response = await _fetchUrl(
        stream.url,
        stream.headers,
        stream.withCredentials,
        _abortController,
      );
      stream.responseOrigin = getResponseOrigin(response.url);
      _ensureResponseStatus(response.status, stream.url);
      final responseHeaders = _responseHeaders(response);
      final rangeChunkSize = stream.source['rangeChunkSize'];
      if (rangeChunkSize is int && rangeChunkSize > 0) {
        final capabilities = validateRangeRequestCapabilities(
          responseHeaders: responseHeaders,
          isHttp: true,
          rangeChunkSize: rangeChunkSize,
          disableRange: stream.source['disableRange'] == true,
        );
        _contentLength = capabilities.contentLength;
        _isRangeSupported = capabilities.isRangeSupported;
      } else {
        _contentLength =
            int.tryParse(responseHeaders.get('Content-Length') ?? '') ?? 0;
      }
      _filename = extractFilenameFromHeader(responseHeaders);
      if (!_headersCompleter.isCompleted) _headersCompleter.complete();
      return await _responseBytes(response);
    } catch (error, stackTrace) {
      if (!_headersCompleter.isCompleted) {
        _headersCompleter.completeError(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> get headersReady => _headersCompleter.future;
  bool get isStreamingSupported => _isStreamingSupported;
  bool get isRangeSupported => _isRangeSupported;
  int get contentLength => _contentLength;
  String? get filename => _filename;
  int get loaded => _loaded;

  Future<Map<String, dynamic>> read() async {
    if (_done) return {'done': true};
    final bytes = await _data;
    _done = true;
    _loaded = bytes.length;
    onProgress?.call(_loaded, _contentLength);
    return {'value': bytes.buffer, 'done': false};
  }

  void cancel(dynamic reason) {
    _done = true;
    unawaited(_data.then<void>((_) {}, onError: (_) {}));
    _abortController.abort(reason?.toString().toJS);
  }
}

/// Reader for an HTTP byte range.
class PDFFetchStreamRangeReader {
  final PDFFetchStream stream;
  final int begin;
  final int end;
  final web.AbortController _abortController = web.AbortController();
  late final Future<Uint8List> _data = _initialize();
  bool _done = false;

  PDFFetchStreamRangeReader(this.stream, this.begin, this.end);

  Future<Uint8List> _initialize() async {
    final response = await _fetchUrl(
      stream.url,
      stream.headers,
      stream.withCredentials,
      _abortController,
      begin: begin,
      end: end,
    );
    ensureResponseOrigin(
        getResponseOrigin(response.url), stream.responseOrigin);
    _ensureResponseStatus(response.status, stream.url);
    final bytes = await _responseBytes(response);
    return bytes.length != end - begin && bytes.length >= end
        ? Uint8List.fromList(bytes.sublist(begin, end))
        : bytes;
  }

  Future<Map<String, dynamic>> read() async {
    if (_done) return {'done': true};
    final bytes = await _data;
    _done = true;
    return {'value': bytes.buffer, 'done': false};
  }

  void cancel(dynamic reason) {
    _done = true;
    unawaited(_data.then<void>((_) {}, onError: (_) {}));
    _abortController.abort(reason?.toString().toJS);
  }
}
