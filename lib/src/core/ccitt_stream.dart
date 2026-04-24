// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'ccitt.dart';
import 'decode_stream.dart';
import 'primitives.dart';
import 'base_stream.dart';

class _CCITTFaxDecoderSourceImpl implements CCITTFaxDecoderSource {
  final Uint8List bytes;
  int pos = 0;

  _CCITTFaxDecoderSourceImpl(this.bytes);

  @override
  int next() {
    if (pos >= bytes.length) return -1;
    return bytes[pos++];
  }
}

class CCITTFaxStream extends DecodeStream {
  int? maybeLength;
  late CCITTFaxDecoderOptions params;
  CCITTFaxDecoder? ccittFaxDecoder;

  CCITTFaxStream(BaseStream str, int? maybeLength, dynamic paramsArg) : super(maybeLength ?? 0) {
    this.stream = str;
    this.maybeLength = maybeLength;
    this.dict = (str as dynamic).dict;

    Dict p;
    if (paramsArg is Dict) {
      p = paramsArg;
    } else {
      p = Dict.empty;
    }

    params = CCITTFaxDecoderOptions(
      k: p.get('K') ?? 0,
      endOfLine: p.get('EndOfLine') == true,
      encodedByteAlign: p.get('EncodedByteAlign') == true,
      columns: p.get('Columns') ?? 1728,
      rows: p.get('Rows') ?? 0,
      endOfBlock: p.get('EndOfBlock') ?? true,
      blackIs1: p.get('BlackIs1') == true,
    );
  }

  Uint8List get bytes {
    return stream!.getBytes(maybeLength);
  }

  @override
  void readBlock([dynamic decoderOptions]) {
    decodeImageFallback(null, null);
  }

  bool get isImageStream => true;
  bool get isAsyncDecoder => true;

  Future<Uint8List> decodeImage([Uint8List? bytesArg, int? length, dynamic decoderOptions]) async {
    if (isEof) {
      return buffer;
    }
    
    // We strictly use fallback in dart to prevent WebAssembly complexity of JBig2CCITTFaxWasmImage
    // which relies on JS Interop natively that isn't included in the core port yet.
    return decodeImageFallback(bytesArg, length);
  }

  Uint8List decodeImageFallback(Uint8List? bytesArg, int? length) {
    if (isEof) {
      return buffer;
    }

    if (bytesArg == null) {
      stream!.reset();
      bytesArg = bytes;
    }

    final source = _CCITTFaxDecoderSourceImpl(bytesArg);
    if (length != null && buffer.lengthInBytes < length) {
      buffer = Uint8List(length);
    }

    ccittFaxDecoder = CCITTFaxDecoder(source, params);
    int outPos = 0;

    while (!isEof) {
      final c = ccittFaxDecoder!.readNextChar();
      if (c == -1) {
        isEof = true;
        break;
      }
      if (length == null) {
        ensureBuffer(outPos + 1);
      }
      buffer[outPos++] = c;
    }

    bufferLength = buffer.length;
    return buffer.sublist(0, length ?? bufferLength);
  }
}
