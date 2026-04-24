// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'base_stream.dart';
import '../shared/util.dart';

/// Stream de bytes concreto baseado em Uint8List.
class Stream extends BaseStream {
  final Uint8List bytes;
  int start;
  int end;
  dynamic dict;

  Stream(dynamic arrayBuffer, [int? startPos, int? length, this.dict])
      : bytes = arrayBuffer is Uint8List
            ? arrayBuffer
            : Uint8List.view(arrayBuffer as ByteBuffer),
        start = startPos ?? 0,
        end = 0 {
    pos = start;
    end = (startPos != null && length != null) ? startPos + length : bytes.length;
  }

  @override
  int get length => end - start;

  @override
  bool get isEmpty => length == 0;

  @override
  int getByte() {
    if (pos >= end) return -1;
    return bytes[pos++];
  }

  @override
  Uint8List getBytes([int? length]) {
    final strEnd = end;
    if (length == null || length == 0) {
      final subBytes = bytes.sublist(pos, strEnd);
      pos = strEnd;
      return subBytes;
    }
    var endPos = pos + length;
    if (endPos > strEnd) endPos = strEnd;
    final subBytes = bytes.sublist(pos, endPos);
    pos = endPos;
    return subBytes;
  }

  @override
  Uint8List getByteRange(int begin, int end) {
    if (begin < 0) begin = 0;
    if (end > this.end) end = this.end;
    return bytes.sublist(begin, end);
  }

  @override
  void reset() {
    pos = start;
  }

  @override
  void moveStart() {
    start = pos;
  }

  @override
  BaseStream makeSubStream(int start, [int? length, dynamic dict]) {
    return Stream(bytes.buffer.asUint8List(), start, length, dict);
  }

  Stream clone() {
    return Stream(
      bytes.buffer.asUint8List(),
      start,
      end - start,
      (dict as dynamic)?.clone(),
    );
  }
}

/// Stream criado a partir de uma String.
class StringStream extends Stream {
  StringStream(String str) : super(stringToBytes(str));
}

/// Stream vazio.
class NullStream extends Stream {
  NullStream() : super(Uint8List(0));
}
