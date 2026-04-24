// Copyright 2021 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import '../shared/util.dart';

/// Classe base abstrata para todos os streams de PDF.
abstract class BaseStream {
  late int pos;
  dynamic dict;
  int get end => length;

  int get length => unreachable('Abstract getter `length` accessed');

  bool get isEmpty => unreachable('Abstract getter `isEmpty` accessed');

  bool get isDataLoaded => true;

  int getByte() => unreachable('Abstract method `getByte` called');

  Uint8List getBytes([int? length]) =>
      unreachable('Abstract method `getBytes` called');

  Future<Uint8List> getImageData(int length, [dynamic decoderOptions]) async {
    return getBytes(length);
  }

  Future<Uint8List> asyncGetBytes() =>
      unreachable('Abstract method `asyncGetBytes` called');

  bool get isAsync => false;

  bool get isAsyncDecoder => false;

  bool get isImageStream => false;

  bool get canAsyncDecodeImageFromBuffer => false;

  Future<dynamic> getTransferableImage() async => null;

  int peekByte() {
    final peekedByte = getByte();
    if (peekedByte != -1) {
      pos--;
    }
    return peekedByte;
  }

  Uint8List peekBytes(int length) {
    final bytes = getBytes(length);
    pos -= bytes.length;
    return bytes;
  }

  int getUint16() {
    final b0 = getByte();
    final b1 = getByte();
    if (b0 == -1 || b1 == -1) return -1;
    return (b0 << 8) + b1;
  }

  int getInt32() {
    final b0 = getByte();
    final b1 = getByte();
    final b2 = getByte();
    final b3 = getByte();
    return (b0 << 24) + (b1 << 16) + (b2 << 8) + b3;
  }

  Uint8List getByteRange(int begin, int end) =>
      unreachable('Abstract method `getByteRange` called');

  String getString([int? length]) {
    return bytesToString(getBytes(length));
  }

  void skip([int n = 1]) {
    pos += n;
  }

  void reset() => unreachable('Abstract method `reset` called');

  void moveStart() => unreachable('Abstract method `moveStart` called');

  BaseStream makeSubStream(int start, [int? length, dynamic dict]) =>
      unreachable('Abstract method `makeSubStream` called');

  List<BaseStream>? getBaseStreams() => null;

  BaseStream getOriginalStream() => this;
}
