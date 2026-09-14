// Copyright 2019 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import '../shared/base_pdf_stream.dart';

class PDFWorkerStream extends BasePDFStream {
  PDFWorkerStream(dynamic source)
      : super(
          source,
          (stream) => PDFWorkerStreamReader(stream),
          (stream, begin, end) =>
              PDFWorkerStreamRangeReader(stream, begin, end),
        );
}

class PDFWorkerStreamReader extends BasePDFStreamReader {
  dynamic _reader;

  PDFWorkerStreamReader(super.stream) {
    final dynamic msgHandler = (stream as dynamic).source.msgHandler;

    final dynamic readableStream = msgHandler.sendWithStream('GetReader');
    _reader = readableStream.getReader();

    msgHandler.sendWithPromise('ReaderHeadersReady').then((data) {
      if (data is Map) {
        setHeaders(
          contentLength: (data['contentLength'] as num?)?.toInt() ?? 0,
          isStreamingSupported: data['isStreamingSupported'] == true,
          isRangeSupported: data['isRangeSupported'] == true,
        );
      } else {
        setHeaders();
      }
    }, onError: (Object err, StackTrace st) {
      rejectHeaders(err, st);
    });
  }


  @override
  Future<ReadResult> read() async {
    final dynamic res = await _reader.read();
    final bool done = res is Map ? res['done'] == true : (res?.done == true);
    if (done) {
      return const ReadResult(done: true);
    }
    final dynamic value = res is Map ? res['value'] : res?.value;
    final Uint8List bytes = value is Uint8List
        ? value
        : (value is ByteBuffer
            ? value.asUint8List()
            : (value != null ? Uint8List.fromList((value as List).cast<int>()) : Uint8List(0)));
    return ReadResult(value: bytes, done: false);
  }


  @override
  void cancel(dynamic reason) {
    _reader?.cancel(reason);
  }
}

class PDFWorkerStreamRangeReader extends BasePDFStreamRangeReader {
  dynamic _reader;

  PDFWorkerStreamRangeReader(super.stream, super.begin, super.end) {
    final dynamic msgHandler = (stream as dynamic).source.msgHandler;

    final dynamic readableStream = msgHandler.sendWithStream('GetRangeReader', {
      'begin': begin,
      'end': end,
    });
    _reader = readableStream.getReader();
  }

  @override
  Future<ReadResult> read() async {
    final dynamic res = await _reader.read();
    final bool done = res is Map ? res['done'] == true : (res?.done == true);
    if (done) {
      return const ReadResult(done: true);
    }
    final dynamic value = res is Map ? res['value'] : res?.value;
    final Uint8List bytes = value is Uint8List
        ? value
        : (value is ByteBuffer
            ? value.asUint8List()
            : (value != null ? Uint8List.fromList((value as List).cast<int>()) : Uint8List(0)));
    return ReadResult(value: bytes, done: false);
  }


  @override
  void cancel(dynamic reason) {
    _reader?.cancel(reason);
  }
}
