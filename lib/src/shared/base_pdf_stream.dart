// Copyright 2018 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'dart:typed_data';
import 'util.dart';

class ReadResult {
  final Uint8List? value;
  final bool done;

  const ReadResult({this.value, this.done = false});
}

/// Interface that represents PDF data transport. If possible, it allows
/// progressively load entire or fragment of the PDF binary data.
abstract class BasePDFStream {
  // ignore: unused_field
  final dynamic _source;
  
  // ignore: prefer_typing_uninitialized_variables
  final _pdfStreamReaderFactory;
  
  // ignore: prefer_typing_uninitialized_variables
  final _pdfStreamRangeReaderFactory;

  BasePDFStreamReader? _fullReader;
  final Set<BasePDFStreamRangeReader> _rangeReaders = {};

  BasePDFStream(this._source, this._pdfStreamReaderFactory, this._pdfStreamRangeReaderFactory);

  int get progressiveDataLength {
    return _fullReader?.loaded ?? 0;
  }

  /// Gets a reader for the entire PDF data.
  BasePDFStreamReader getFullReader() {
    assert_(_fullReader == null, 'BasePDFStream.getFullReader can only be called once.');
    _fullReader = _pdfStreamReaderFactory(this);
    return _fullReader!;
  }

  /// Gets a reader for the range of the PDF data.
  /// NOTE: Currently this method is only expected to be invoked *after*
  /// the `BasePDFStreamReader.headersReady` promise has resolved.
  BasePDFStreamRangeReader? getRangeReader(int begin, int end) {
    if (end <= progressiveDataLength) {
      return null;
    }
    final reader = _pdfStreamRangeReaderFactory(this, begin, end);
    _rangeReaders.add(reader);
    return reader;
  }

  /// Cancels all opened reader and closes all their opened requests.
  void cancelAllRequests(dynamic reason) {
    _fullReader?.cancel(reason);

    // Always create a copy of the rangeReaders.
    final readersCopy = Set<BasePDFStreamRangeReader>.from(_rangeReaders);
    for (final reader in readersCopy) {
      reader.cancel(reason);
    }
  }
}

typedef ProgressCallback = void Function(int loaded, int total);

/// Interface for a PDF binary data reader.
abstract class BasePDFStreamReader {
  ProgressCallback? onProgress;

  int _contentLength = 0;
  String? _filename;
  final Completer<void> _headersCapability = Completer<void>();
  bool _isRangeSupported = false;
  bool _isStreamingSupported = false;
  int _loaded = 0;
  
  // ignore: unused_field
  final BasePDFStream _stream;

  BasePDFStreamReader(this._stream);

  void callOnProgress() {
    onProgress?.call(_loaded, _contentLength);
  }

  /// Gets a promise that is resolved when the headers and other metadata of
  /// the PDF data stream are available.
  Future<void> get headersReady => _headersCapability.future;

  /// Gets the Content-Disposition filename. It is defined after the headersReady
  /// promise is resolved.
  String? get filename => _filename;

  /// Gets PDF binary data length. It is defined after the headersReady promise
  /// is resolved.
  int get contentLength => _contentLength;

  /// Gets ability of the stream to handle range requests.
  bool get isRangeSupported => _isRangeSupported;

  /// Gets ability of the stream to progressively load binary data.
  bool get isStreamingSupported => _isStreamingSupported;

  int get loaded => _loaded;

  /// Requests a chunk of the binary data. The method returns the promise, which
  /// is resolved into object with properties "value" and "done".
  Future<ReadResult> read() async {
    unreachable('Abstract method `read` called');
  }

  /// Cancels all pending read requests and closes the stream.
  void cancel(dynamic reason) {
    unreachable('Abstract method `cancel` called');
  }
}

/// Interface for a PDF binary data fragment reader.
abstract class BasePDFStreamRangeReader {
  // ignore: unused_field
  final BasePDFStream _stream;

  BasePDFStreamRangeReader(this._stream, int begin, int end);

  /// Requests a chunk of the binary data. The method returns the promise, which
  /// is resolved into object with properties "value" and "done".
  Future<ReadResult> read() async {
    unreachable('Abstract method `read` called');
  }

  /// Cancels all pending read requests and closes the stream.
  void cancel(dynamic reason) {
    unreachable('Abstract method `cancel` called');
  }
}
