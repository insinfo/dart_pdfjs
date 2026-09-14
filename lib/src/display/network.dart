// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'fetch_stream.dart';
import 'network_utils.dart';

/// Non-streaming network backend compatible with PDF.js' XHR transport.
///
/// Modern Dart web applications use the Fetch API internally, while this
/// adapter deliberately exposes the non-streaming behavior of XMLHttpRequest.
/// This preserves the PDF.js reader contract for URLs where fetch streaming is
/// unavailable and avoids maintaining two independent HTTP implementations.
class PDFNetworkStream {
  final Map<String, dynamic> source;
  final Uri url;
  final bool isHttp;
  final Headers headers;

  late final PDFFetchStream _transport;
  PDFNetworkStreamReader? _fullReader;
  final Set<PDFNetworkStreamRangeReader> _rangeReaders = {};

  String? responseOrigin;

  PDFNetworkStream(this.source)
      : url = _parseUrl(source),
        isHttp = _isHttpUrl(source['url']),
        headers = createHeaders(
          _isHttpUrl(source['url']),
          source['httpHeaders'],
        ) {
    _transport = PDFFetchStream(source);
  }

  static Uri _parseUrl(Map<String, dynamic> source) {
    final value = source['url'];
    if (value is Uri) return value;
    if (value is String && value.isNotEmpty) return Uri.parse(value);
    throw ArgumentError('PDFNetworkStream requires a URL.');
  }

  static bool _isHttpUrl(dynamic value) {
    final uri = value is Uri ? value : Uri.tryParse(value?.toString() ?? '');
    return uri?.scheme == 'http' || uri?.scheme == 'https';
  }

  bool get withCredentials => source['withCredentials'] == true;
  int get progressiveDataLength => _fullReader?.loaded ?? 0;

  PDFNetworkStreamReader getFullReader() {
    if (_fullReader != null) {
      throw StateError(
          'PDFNetworkStream.getFullReader can only be called once.');
    }
    return _fullReader = PDFNetworkStreamReader(
      this,
      _transport.getFullReader(),
    );
  }

  PDFNetworkStreamRangeReader? getRangeReader(int begin, int end) {
    if (begin < 0 || end <= begin) {
      throw RangeError('Expected a non-empty, positive byte range.');
    }
    if (end <= progressiveDataLength) return null;
    final transportReader = _transport.getRangeReader(begin, end);
    if (transportReader == null) return null;
    final reader = PDFNetworkStreamRangeReader(
      this,
      transportReader,
      begin,
      end,
      onClosed: (reader) => _rangeReaders.remove(reader),
    );
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

/// Full-document reader for [PDFNetworkStream].
class PDFNetworkStreamReader {
  final PDFNetworkStream stream;
  final PDFFetchStreamReader _reader;

  PDFNetworkStreamReader(this.stream, this._reader);

  Future<void> get headersReady async {
    await _reader.headersReady;
    stream.responseOrigin = _reader.stream.responseOrigin;
  }

  bool get isRangeSupported => _reader.isRangeSupported;

  /// XMLHttpRequest buffers the complete response before exposing it.
  bool get isStreamingSupported => false;

  int get contentLength => _reader.contentLength;
  String? get filename => _reader.filename;
  int get loaded => _reader.loaded;

  FetchProgressCallback? get onProgress => _reader.onProgress;
  set onProgress(FetchProgressCallback? callback) {
    _reader.onProgress = callback;
  }

  Future<Map<String, dynamic>> read() => _reader.read();

  void cancel(dynamic reason) => _reader.cancel(reason);
}

/// Reader for one byte range requested through [PDFNetworkStream].
class PDFNetworkStreamRangeReader {
  final PDFNetworkStream stream;
  final PDFFetchStreamRangeReader _reader;
  final int begin;
  final int end;
  final void Function(PDFNetworkStreamRangeReader reader)? _onClosed;
  bool _closed = false;

  PDFNetworkStreamRangeReader(
    this.stream,
    this._reader,
    this.begin,
    this.end, {
    void Function(PDFNetworkStreamRangeReader reader)? onClosed,
  }) : _onClosed = onClosed;

  Future<Map<String, dynamic>> read() async {
    final result = await _reader.read();
    if (result['done'] == true) _close();
    return result;
  }

  void cancel(dynamic reason) {
    _reader.cancel(reason);
    _close();
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    _onClosed?.call(this);
  }
}

Uint8List networkResultBytes(Map<String, dynamic> result) {
  final value = result['value'];
  if (value is ByteBuffer) return Uint8List.view(value);
  if (value is Uint8List) return value;
  throw StateError('Network result does not contain a binary value.');
}
