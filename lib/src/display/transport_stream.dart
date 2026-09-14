// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'dart:typed_data';

import '../shared/base_pdf_stream.dart';

typedef PDFDataRangeListener = void Function(int begin, Uint8List chunk);
typedef PDFDataProgressListener = void Function(int loaded, int? total);
typedef PDFDataProgressiveReadListener = void Function(Uint8List chunk);
typedef PDFDataProgressiveDoneListener = void Function();

/// Host-side contract used to provide PDF bytes progressively or by range.
///
/// Subclasses implement [requestDataRange] and optionally [abort]. Network,
/// file and application-specific transports can then feed received data back
/// through the `onData*` methods. Events emitted before [transportReady] are
/// deliberately queued, matching PDF.js' `PDFDataRangeTransport` semantics.
abstract class PDFDataRangeTransport {
  final int length;
  final Uint8List initialData;
  final bool progressiveDone;
  final String? contentDispositionFilename;

  final List<PDFDataRangeListener> _rangeListeners = [];
  final List<PDFDataProgressListener> _progressListeners = [];
  final List<PDFDataProgressiveReadListener> _progressiveReadListeners = [];
  final List<PDFDataProgressiveDoneListener> _progressiveDoneListeners = [];
  final List<void Function()> _queuedEvents = [];
  bool _ready = false;
  bool _aborted = false;

  PDFDataRangeTransport(
    this.length, {
    Uint8List? initialData,
    this.progressiveDone = false,
    this.contentDispositionFilename,
  }) : initialData = initialData ?? Uint8List(0) {
    if (length < 0) throw RangeError.value(length, 'length');
    if (this.initialData.length > length) {
      throw ArgumentError('initialData cannot exceed the document length.');
    }
  }

  void addRangeListener(PDFDataRangeListener listener) =>
      _rangeListeners.add(listener);
  void addProgressListener(PDFDataProgressListener listener) =>
      _progressListeners.add(listener);
  void addProgressiveReadListener(PDFDataProgressiveReadListener listener) =>
      _progressiveReadListeners.add(listener);
  void addProgressiveDoneListener(PDFDataProgressiveDoneListener listener) =>
      _progressiveDoneListeners.add(listener);

  /// Enables event delivery and flushes events received during setup.
  void transportReady([void Function(Map<String, dynamic> event)? listener]) {
    if (listener != null) {
      addRangeListener((begin, chunk) => listener({
            'type': 'range',
            'begin': begin,
            'chunk': chunk,
          }));
      addProgressiveReadListener((chunk) => listener({
            'type': 'progressiveRead',
            'chunk': chunk,
          }));
      addProgressiveDoneListener(() => listener({'type': 'progressiveDone'}));
    }
    if (_ready) return;
    _ready = true;
    final events = List<void Function()>.from(_queuedEvents);
    _queuedEvents.clear();
    for (final event in events) {
      event();
    }
  }

  void _dispatch(void Function() event) {
    if (_aborted) return;
    if (_ready) {
      event();
    } else {
      _queuedEvents.add(event);
    }
  }

  void onDataRange(int begin, dynamic chunk) {
    final bytes = _asBytes(chunk);
    if (begin < 0 || begin + bytes.length > length) {
      throw RangeError('Range response lies outside the document.');
    }
    _dispatch(() {
      for (final listener in List.of(_rangeListeners)) {
        listener(begin, bytes);
      }
    });
  }

  void onDataProgress(int loaded, [int? total]) {
    if (loaded < 0) throw RangeError.value(loaded, 'loaded');
    _dispatch(() {
      for (final listener in List.of(_progressListeners)) {
        listener(loaded, total);
      }
    });
  }

  void onDataProgressiveRead(dynamic chunk) {
    final bytes = _asBytes(chunk);
    _dispatch(() {
      for (final listener in List.of(_progressiveReadListeners)) {
        listener(bytes);
      }
    });
  }

  void onDataProgressiveDone() {
    _dispatch(() {
      for (final listener in List.of(_progressiveDoneListeners)) {
        listener();
      }
    });
  }

  void requestDataRange(int begin, int end);

  void abort([dynamic reason]) {
    _aborted = true;
    _queuedEvents.clear();
  }
}

Uint8List _asBytes(dynamic value) {
  if (value is Uint8List) {
    return Uint8List.fromList(value);
  }
  if (value is ByteBuffer) return Uint8List.fromList(value.asUint8List());
  if (value is List<int>) return Uint8List.fromList(value);
  throw ArgumentError.value(value, 'chunk', 'Expected binary data.');
}

/// Stream adapter around [PDFDataRangeTransport].
class PDFDataTransportStream extends BasePDFStream {
  late final PDFDataRangeTransport transport;
  bool _progressiveDone = false;
  List<Uint8List>? _queuedChunks = [];

  PDFDataTransportStream(Map<String, dynamic> source)
      : super(
          source,
          (stream) => PDFDataTransportStreamReader(stream),
          (stream, begin, end) =>
              PDFDataTransportStreamRangeReader(stream, begin, end),
        ) {
    final candidate = source['pdfDataRangeTransport'];
    if (candidate is! PDFDataRangeTransport) {
      throw ArgumentError('pdfDataRangeTransport is required');
    }
    transport = candidate;
    if (transport.initialData.isNotEmpty) {
      _queuedChunks!.add(Uint8List.fromList(transport.initialData));
    }
    _progressiveDone = transport.progressiveDone;
    transport.addRangeListener(_onRangeData);
    transport.addProgressiveReadListener(_onProgressiveData);
    transport.addProgressiveDoneListener(_onProgressiveDone);
    transport.addProgressListener((loaded, total) {
      final reader = _reader;
      if (reader != null) reader.reportExternalProgress(loaded, total);
    });
    transport.transportReady();
  }

  PDFDataTransportStreamReader? _reader;

  @override
  PDFDataTransportStreamReader getFullReader() {
    if (_reader != null) {
      throw StateError('PDFDataTransportStream.getFullReader called twice.');
    }
    final reader = super.getFullReader() as PDFDataTransportStreamReader;
    _reader = reader;
    _queuedChunks = null;
    return reader;
  }

  void _onProgressiveData(Uint8List chunk) {
    final reader = _reader;
    if (reader != null) {
      reader.enqueue(chunk);
    } else {
      _queuedChunks!.add(chunk);
    }
  }

  void _onProgressiveDone() {
    _progressiveDone = true;
    _reader?.progressiveDone();
  }

  void _onRangeData(int begin, Uint8List chunk) {
    PDFDataTransportStreamRangeReader? match;
    for (final reader in rangeReaders) {
      if (reader.begin == begin) {
        match = reader;
        break;
      }
    }
    if (match == null) {
      throw StateError('No range reader exists for offset $begin.');
    }
    match.enqueue(chunk);
  }

  // Base keeps readers private; maintain a mirror for deterministic matching.
  final Set<PDFDataTransportStreamRangeReader> rangeReaders = {};

  @override
  PDFDataTransportStreamRangeReader? getRangeReader(int begin, int end) {
    if (begin < 0 || end <= begin || end > transport.length) {
      throw RangeError('Expected a valid non-empty document byte range.');
    }
    if (end <= progressiveDataLength) return null;
    final reader =
        super.getRangeReader(begin, end) as PDFDataTransportStreamRangeReader?;
    if (reader != null) {
      rangeReaders.add(reader);
      reader.onDone = () => rangeReaders.remove(reader);
      transport.requestDataRange(begin, end);
    }
    return reader;
  }

  @override
  void cancelAllRequests(dynamic reason) {
    super.cancelAllRequests(reason);
    rangeReaders.clear();
    transport.abort(reason);
  }
}

class PDFDataTransportStreamReader extends BasePDFStreamReader {
  final List<Uint8List> _queuedChunks;
  final List<Completer<ReadResult>> _requests = [];
  bool _done;

  PDFDataTransportStreamReader(super.stream)
      : _queuedChunks = List.from(
            (stream as PDFDataTransportStream)._queuedChunks ?? const []),
        _done = stream._progressiveDone {
    final owner = this.stream as PDFDataTransportStream;
    addLoadedBytes(_queuedChunks.fold(0, (sum, chunk) => sum + chunk.length));
    setHeaders(
      contentLength: owner.transport.length,
      isStreamingSupported: owner.source['disableStream'] != true,
      isRangeSupported: owner.source['disableRange'] != true,
    );
    final filename = owner.transport.contentDispositionFilename;
    if (filename != null && filename.toLowerCase().endsWith('.pdf')) {
      setFilename(filename);
    }
    if (loaded > 0) scheduleMicrotask(callOnProgress);
  }

  void enqueue(Uint8List chunk) {
    if (_done) return;
    final bytes = Uint8List.fromList(chunk);
    addLoadedBytes(bytes.length);
    if (_requests.isNotEmpty) {
      _requests.removeAt(0).complete(ReadResult(value: bytes));
    } else {
      _queuedChunks.add(bytes);
    }
    callOnProgress();
  }

  void reportExternalProgress(int loaded, int? total) {
    onProgress?.call(loaded, total ?? contentLength);
  }

  @override
  Future<ReadResult> read() {
    if (_queuedChunks.isNotEmpty) {
      return Future.value(ReadResult(value: _queuedChunks.removeAt(0)));
    }
    if (_done) return Future.value(const ReadResult(done: true));
    final request = Completer<ReadResult>();
    _requests.add(request);
    return request.future;
  }

  void _endRequests() {
    for (final request in _requests) {
      if (!request.isCompleted) request.complete(const ReadResult(done: true));
    }
    _requests.clear();
  }

  @override
  void cancel(dynamic reason) {
    _done = true;
    _queuedChunks.clear();
    _endRequests();
  }

  void progressiveDone() {
    _done = true;
    if (_queuedChunks.isEmpty) _endRequests();
  }
}

class PDFDataTransportStreamRangeReader extends BasePDFStreamRangeReader {
  final List<Completer<ReadResult>> _requests = [];
  Uint8List? _queuedChunk;
  bool _done = false;
  void Function()? onDone;

  PDFDataTransportStreamRangeReader(super.stream, super.begin, super.end);

  void enqueue(Uint8List chunk) {
    if (_done) return;
    final bytes = Uint8List.fromList(chunk);
    if (_requests.isEmpty) {
      _queuedChunk = bytes;
    } else {
      _requests.removeAt(0).complete(ReadResult(value: bytes));
      _endRequests();
    }
    _done = true;
    onDone?.call();
  }

  @override
  Future<ReadResult> read() {
    final chunk = _queuedChunk;
    if (chunk != null) {
      _queuedChunk = null;
      return Future.value(ReadResult(value: chunk));
    }
    if (_done) return Future.value(const ReadResult(done: true));
    final request = Completer<ReadResult>();
    _requests.add(request);
    return request.future;
  }

  void _endRequests() {
    for (final request in _requests) {
      if (!request.isCompleted) request.complete(const ReadResult(done: true));
    }
    _requests.clear();
  }

  @override
  void cancel(dynamic reason) {
    if (_done && _queuedChunk == null) return;
    _done = true;
    _queuedChunk = null;
    _endRequests();
    onDone?.call();
  }
}
