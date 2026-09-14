// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';


/// Transport stream for PDF data via PDFDataRangeTransport.
class PDFDataTransportStream {
  bool _progressiveDone = false;
  List<ByteBuffer> _queuedChunks = [];

  PDFDataTransportStream(Map<String, dynamic> source) {
    final pdfDataRangeTransport = source['pdfDataRangeTransport'];
    if (pdfDataRangeTransport == null) {
      throw ArgumentError('pdfDataRangeTransport is required');
    }
    final initialData = pdfDataRangeTransport['initialData'];
    final progressiveDone = pdfDataRangeTransport['progressiveDone'] == true;

    if (initialData is Uint8List && initialData.isNotEmpty) {
      _queuedChunks.add(initialData.buffer);
    }
    _progressiveDone = progressiveDone;
  }

  void onReceiveData(int? begin, dynamic chunk) {
    if (chunk is Uint8List) {
      _queuedChunks.add(chunk.buffer);
    }
  }
}

/// Reader for the full PDF data transport stream.
class PDFDataTransportStreamReader {
  bool _done = false;
  final List<ByteBuffer> _queuedChunks;

  PDFDataTransportStreamReader(PDFDataTransportStream stream)
      : _queuedChunks = stream._queuedChunks.toList() {
    _done = stream._progressiveDone;
  }

  Future<Map<String, dynamic>> read() async {
    if (_queuedChunks.isNotEmpty) {
      final chunk = _queuedChunks.removeAt(0);
      return {'value': chunk, 'done': false};
    }
    if (_done) {
      return {'done': true};
    }
    return {'done': true};
  }

  void cancel(dynamic reason) {
    _done = true;
  }

  void progressiveDone() {
    _done = true;
  }
}

/// Reader for ranged PDF data transport streams.
class PDFDataTransportStreamRangeReader {
  final int begin;
  final int end;
  bool _done = false;
  final List<ByteBuffer> _queuedChunks = [];

  PDFDataTransportStreamRangeReader(this.begin, this.end);

  void enqueue(ByteBuffer chunk) {
    if (_done) return;
    _queuedChunks.add(chunk);
  }

  Future<Map<String, dynamic>> read() async {
    if (_queuedChunks.isNotEmpty) {
      final chunk = _queuedChunks.removeAt(0);
      return {'value': chunk, 'done': false};
    }
    if (_done) {
      return {'done': true};
    }
    return {'done': true};
  }

  void cancel(dynamic reason) {
    _done = true;
    _queuedChunks.clear();
  }
}
