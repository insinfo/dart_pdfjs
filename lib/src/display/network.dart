// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'dart:async';

import 'network_utils.dart';

/// PDF Network Stream using XHR-style requests for loading PDF data.
class PDFNetworkStream {
  final Map<String, dynamic> source;
  final Uri url;
  final bool isHttp;
  final Headers headers;
  String? responseOrigin;

  PDFNetworkStream(this.source)
      : url = source['url'] is Uri
            ? source['url'] as Uri
            : Uri.parse(source['url'].toString()),
        isHttp = _isHttpUrl(source['url']),
        headers = createHeaders(
          _isHttpUrl(source['url']),
          source['httpHeaders'],
        );

  static bool _isHttpUrl(dynamic url) {
    if (url is Uri) {
      return url.scheme == 'http' || url.scheme == 'https';
    }
    final urlStr = url.toString();
    return urlStr.startsWith('http:') || urlStr.startsWith('https:');
  }
}

/// Full-document reader for PDFNetworkStream.
class PDFNetworkStreamReader {
  final PDFNetworkStream stream;
  bool done = false;
  final List<ByteBuffer> cachedChunks = [];
  int contentLength = 0;
  bool isRangeSupported = false;
  bool isStreamingSupported = false;
  String? filename;
  final Completer<void> headersCompleter = Completer<void>();

  PDFNetworkStreamReader(this.stream);

  Future<void> get headersReady => headersCompleter.future;

  Future<Map<String, dynamic>> read() async {
    if (cachedChunks.isNotEmpty) {
      final chunk = cachedChunks.removeAt(0);
      return {'value': chunk, 'done': false};
    }
    if (done) {
      return {'done': true};
    }
    return {'done': true};
  }

  void cancel(dynamic reason) {
    done = true;
    cachedChunks.clear();
  }
}

/// Range reader for PDFNetworkStream.
class PDFNetworkStreamRangeReader {
  final PDFNetworkStream stream;
  final int begin;
  final int end;
  bool done = false;
  final List<ByteBuffer> queuedChunks = [];

  PDFNetworkStreamRangeReader(this.stream, this.begin, this.end);

  Future<Map<String, dynamic>> read() async {
    if (queuedChunks.isNotEmpty) {
      final chunk = queuedChunks.removeAt(0);
      return {'value': chunk, 'done': false};
    }
    if (done) {
      return {'done': true};
    }
    return {'done': true};
  }

  void cancel(dynamic reason) {
    done = true;
    queuedChunks.clear();
  }
}
