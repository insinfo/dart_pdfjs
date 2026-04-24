// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'base_stream.dart';
import 'decode_stream.dart';
import 'primitives.dart';
import 'jpg.dart';

class JpegStream extends DecodeStream {
  int? maybeLength;
  dynamic params;
  
  // Custom force properties que o DecodeStream original do PDF.js possui na classe
  bool forceRGBA = false;
  bool forceRGB = false;
  int drawWidth = 0;
  int drawHeight = 0;

  JpegStream(BaseStream str, int? maybeLength, dynamic paramsArg) : super(maybeLength ?? 0) {
    this.stream = str;
    this.dict = (str as dynamic).dict;
    this.maybeLength = maybeLength;
    this.params = paramsArg;
  }

  Uint8List get bytes {
    return stream!.getBytes(maybeLength);
  }

  @override
  Uint8List ensureBuffer(int requested) {
    // No-op, since `this.readBlock` will always parse the entire image and
    // directly insert all of its data into `this.buffer`.
    return super.ensureBuffer(requested);
  }

  @override
  void readBlock([dynamic decoderOptions]) {
    decodeImage(null);
  }

  JpegOptions get jpegOptions {
    final options = JpegOptions();

    // Checking if values need to be transformed before conversion.
    final decodeArr = dict is Dict ? (dict as Dict).getArray('D', 'Decode') : null;
    if ((forceRGBA || forceRGB) && decodeArr is List) {
      final bitsPerComponent = dict is Dict ? ((dict as Dict).get('BPC', 'BitsPerComponent') ?? 8) : 8;
      final decodeArrLength = decodeArr.length;
      final transform = Int32List(decodeArrLength);
      bool transformNeeded = false;
      final maxValue = (1 << (bitsPerComponent as int)) - 1;
      
      for (int i = 0; i < decodeArrLength; i += 2) {
        transform[i] = ((decodeArr[i + 1] - decodeArr[i]) * 256).toInt();
        transform[i + 1] = (decodeArr[i] * maxValue).toInt();
        if (transform[i] != 256 || transform[i + 1] != 0) {
          transformNeeded = true;
        }
      }
      if (transformNeeded) {
        options.decodeTransform = transform;
      }
    }
    
    // Fetching the 'ColorTransform' entry, if it exists.
    if (params is Dict) {
      final colorTransform = (params as Dict).get('ColorTransform');
      if (colorTransform is int) {
        options.colorTransform = colorTransform;
      }
    }
    
    return options;
  }

  Uint8List _skipUselessBytes(Uint8List data) {
    // Some images may contain 'junk' before the SOI (start-of-image) marker.
    for (int i = 0, ii = data.length - 1; i < ii; i++) {
      if (data[i] == 0xff && data[i + 1] == 0xd8) {
        if (i > 0) {
          return data.sublist(i);
        }
        break;
      }
    }
    return data;
  }

  Uint8List decodeImage([Uint8List? bytesArg]) {
    if (isEof) {
      return buffer;
    }
    
    bytesArg = _skipUselessBytes(bytesArg ?? bytes);

    final jpegImage = JpegImage(jpegOptions);
    jpegImage.parse(bytesArg);
    
    final data = jpegImage.getData({
      'width': drawWidth,
      'height': drawHeight,
      'forceRGBA': forceRGBA,
      'forceRGB': forceRGB,
      'isSourcePDF': true,
    });
    
    buffer = data;
    bufferLength = data.length;
    isEof = true;

    return buffer;
  }

  bool get canAsyncDecodeImageFromBuffer {
    return stream!.isAsync;
  }

  @override
  bool get isImageStream {
    return true;
  }
}
