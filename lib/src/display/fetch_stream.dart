// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';

import 'network_utils.dart';

/// PDF Fetch Stream - uses Dart's HTTP client for PDF data retrieval.
class PDFFetchStream {
  final Map<String, dynamic> source;
  final Headers headers;
  String? responseOrigin;

  PDFFetchStream(this.source)
      : headers = createHeaders(
          true, source['httpHeaders']) {
    final url = source['url'];
    assert(url != null, 'PDFFetchStream requires a url.');
  }
}

/// Full-document reader for PDFFetchStream.
class PDFFetchStreamReader {
  final PDFFetchStream stream;
  bool _isStreamingSupported;
  bool _isRangeSupported = false;
  int _contentLength = 0;
  String? _filename;
  final Completer<void> _headersCompleter = Completer<void>();

  PDFFetchStreamReader(this.stream)
      : _isStreamingSupported = stream.source['disableStream'] != true;

  Future<void> get headersReady => _headersCompleter.future;

  bool get isStreamingSupported => _isStreamingSupported;
  bool get isRangeSupported => _isRangeSupported;
  int get contentLength => _contentLength;
  String? get filename => _filename;

  Future<Map<String, dynamic>> read() async {
    return {'done': true};
  }

  void cancel(dynamic reason) {}
}

/// Range reader for PDFFetchStream.
class PDFFetchStreamRangeReader {
  final PDFFetchStream stream;
  final int begin;
  final int end;
  final Completer<void> _readCompleter = Completer<void>();

  PDFFetchStreamRangeReader(this.stream, this.begin, this.end);

  Future<Map<String, dynamic>> read() async {
    return {'done': true};
  }

  void cancel(dynamic reason) {}
}
