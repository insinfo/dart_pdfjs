// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;
import 'dart:typed_data';

import '../shared/math_clamp.dart';
import '../shared/util.dart';
import 'base_stream.dart';
import 'colorspace.dart';
import 'colorspace_utils.dart';
import 'decode_stream.dart';
import 'image_resizer.dart';
import 'jpeg_stream.dart';
import 'jpx.dart';
import 'primitives.dart';

class PDFImage {
  final BaseStream image;
  int width = 0;
  int height = 0;
  dynamic interpolate;
  bool imageMask = false;
  dynamic matte;
  int bpc = 8;
  ColorSpace? colorSpace;
  int numComps = 1;
  List<dynamic>? decode;
  bool needsDecode = false;
  List<double> decodeCoefficients = [];
  List<double> decodeAddends = [];
  PDFImage? smask;
  dynamic mask;
  Map<String, dynamic>? jpxDecoderOptions;

  PDFImage({
    required this.image,
    required dynamic xref,
    Dict? res,
    bool isInline = false,
    BaseStream? smask,
    dynamic mask,
    bool isMask = false,
    dynamic pdfFunctionFactory,
    GlobalColorSpaceCache? globalColorSpaceCache,
    LocalColorSpaceCache? localColorSpaceCache,
  }) {
    final dict = image.dict is Dict ? image.dict as Dict : Dict(xref);

    final filter = dict.get('F', 'Filter');
    String? filterName;
    if (filter is Name) {
      filterName = filter.name;
    } else if (filter is List && filter.isNotEmpty) {
      final filterZero = xref.fetchIfRef(filter[0]);
      if (filterZero is Name) {
        filterName = filterZero.name;
      }
    }

    switch (filterName) {
      case 'JPXDecode':
        final jpxStream = image.stream ?? image;
        final props = JpxImage.parseImageProperties(jpxStream is JpxByteStream
            ? jpxStream as JpxByteStream
            : JpxImageStreamAdapter(jpxStream));
        image.width = props.width;
        image.height = props.height;
        image.numComps = props.componentsCount;
        image.bitsPerComponent = props.bitsPerComponent;
        jpxStream.reset();

        final reducePower = ImageResizer.getReducePowerForJPX(
          image.width ?? 0,
          image.height ?? 0,
          image.numComps ?? 0,
        );
        jpxDecoderOptions = {
          'numComponents': 0,
          'isIndexedColormap': false,
          'smaskInData': dict.has('SMaskInData'),
          'reducePower': reducePower,
        };
        if (reducePower > 0) {
          final factor = 1 << reducePower;
          image.width = ((image.width ?? 0) / factor).ceil();
          image.height = ((image.height ?? 0) / factor).ceil();
        }
        break;
      case 'JBIG2Decode':
        image.bitsPerComponent = 1;
        image.numComps = 1;
        break;
    }

    dynamic w = dict.get('W', 'Width');
    dynamic h = dict.get('H', 'Height');

    if (image.width != null &&
        image.width! > 0 &&
        image.height != null &&
        image.height! > 0 &&
        (image.width != w || image.height != h)) {
      warn('PDFImage - using the Width/Height of the image data, '
          'rather than the image dictionary.');
      width = image.width!;
      height = image.height!;
    } else {
      final validWidth = w is num && w > 0;
      final validHeight = h is num && h > 0;

      if (!validWidth || !validHeight) {
        if (image.fallbackDims == null) {
          throw FormatError('Invalid image width: $w or height: $h');
        }
        warn('PDFImage - using the Width/Height of the parent image, for SMask/Mask data.');
        if (!validWidth) {
          w = image.fallbackDims!['width'];
        }
        if (!validHeight) {
          h = image.fallbackDims!['height'];
        }
      }
      width = (w as num).toInt();
      height = (h as num).toInt();
    }

    interpolate = dict.get('I', 'Interpolate');
    imageMask = dict.get('IM', 'ImageMask') == true;
    matte = dict.get('Matte');

    var bitsPerComponent = image.bitsPerComponent;
    if (bitsPerComponent == null || bitsPerComponent == 0) {
      final bpcVal = dict.get('BPC', 'BitsPerComponent');
      if (bpcVal is int) {
        bitsPerComponent = bpcVal;
      } else if (imageMask) {
        bitsPerComponent = 1;
      } else {
        throw FormatError('Bits per component missing in image: $imageMask');
      }
    }
    bpc = bitsPerComponent;

    if (!imageMask) {
      dynamic cs = dict.getRaw('CS') ?? dict.getRaw('ColorSpace');
      final hasColorSpace = cs != null;
      if (!hasColorSpace) {
        if (jpxDecoderOptions != null) {
          cs = Name.get('DeviceRGBA');
        } else {
          switch (image.numComps) {
            case 1:
              cs = Name.get('DeviceGray');
              break;
            case 3:
              cs = Name.get('DeviceRGB');
              break;
            case 4:
              cs = Name.get('DeviceCMYK');
              break;
            default:
              throw FormatError(
                  'Images with ${image.numComps} color components not supported.');
          }
        }
      } else if (jpxDecoderOptions?['smaskInData'] == true) {
        cs = Name.get('DeviceRGBA');
      }

      final gCache = globalColorSpaceCache ?? GlobalColorSpaceCache();
      final lCache = localColorSpaceCache ?? LocalColorSpaceCache();

      colorSpace = ColorSpaceUtils.parse(
        cs: cs,
        xref: xref,
        resources: isInline ? res : null,
        pdfFunctionFactory: pdfFunctionFactory,
        globalColorSpaceCache: gCache,
        localColorSpaceCache: lCache,
      );
      numComps = colorSpace!.numComps!;

      if (jpxDecoderOptions != null) {
        jpxDecoderOptions!['numComponents'] = hasColorSpace ? numComps : 0;
        jpxDecoderOptions!['isIndexedColormap'] =
            colorSpace!.name == 'Indexed';
      }
    } else {
      numComps = 1;
    }

    final rawDecode = dict.getArray('D', 'Decode');
    decode = rawDecode is List ? rawDecode : null;
    needsDecode = false;

    if (decode != null) {
      final decodeList = decode!.map((e) => (e as num).toDouble()).toList();
      if ((colorSpace != null && !colorSpace!.isDefaultDecode(decodeList, bpc)) ||
          (isMask && !ColorSpace.isDefaultDecodeMap(decodeList, 1))) {
        needsDecode = true;
        final max = (1 << bpc) - 1;
        decodeCoefficients = [];
        decodeAddends = [];
        final isIndexed = colorSpace?.name == 'Indexed';
        for (var i = 0, j = 0; i < decode!.length; i += 2, ++j) {
          final dmin = (decode![i] as num).toDouble();
          final dmax = (decode![i + 1] as num).toDouble();
          decodeCoefficients.add(isIndexed ? (dmax - dmin) / max : dmax - dmin);
          decodeAddends.add(isIndexed ? dmin : max * dmin);
        }
      }
    }

    if (smask != null) {
      smask.fallbackDims ??= {'width': width, 'height': height};
      this.smask = PDFImage(
        xref: xref,
        res: res,
        image: smask,
        isInline: isInline,
        pdfFunctionFactory: pdfFunctionFactory,
        globalColorSpaceCache: globalColorSpaceCache,
        localColorSpaceCache: localColorSpaceCache,
      );
    } else if (mask != null) {
      if (mask is BaseStream) {
        final maskDict = mask.dict is Dict ? mask.dict as Dict : Dict(xref);
        final maskIsImageMask = maskDict.get('IM', 'ImageMask') == true;
        if (!maskIsImageMask) {
          warn('Ignoring /Mask in image without /ImageMask.');
        } else {
          mask.fallbackDims ??= {'width': width, 'height': height};
          this.mask = PDFImage(
            xref: xref,
            res: res,
            image: mask,
            isInline: isInline,
            isMask: true,
            pdfFunctionFactory: pdfFunctionFactory,
            globalColorSpaceCache: globalColorSpaceCache,
            localColorSpaceCache: localColorSpaceCache,
          );
        }
      } else {
        this.mask = mask;
      }
    }
  }

  static Future<PDFImage> buildImage({
    required dynamic xref,
    required Dict res,
    required BaseStream image,
    bool isInline = false,
    dynamic pdfFunctionFactory,
    GlobalColorSpaceCache? globalColorSpaceCache,
    LocalColorSpaceCache? localColorSpaceCache,
  }) async {
    BaseStream? smaskData;
    dynamic maskData;

    final dict = image.dict is Dict ? image.dict as Dict : Dict(xref);
    final smask = dict.get('SMask');
    final mask = dict.get('Mask');

    if (smask is BaseStream) {
      smaskData = smask;
    } else if (smask != null) {
      warn('Unsupported /SMask format.');
    } else if (mask is BaseStream || mask is List) {
      maskData = mask;
    } else if (mask != null) {
      warn('Unsupported /Mask format.');
    }

    return PDFImage(
      xref: xref,
      res: res,
      image: image,
      isInline: isInline,
      smask: smaskData,
      mask: maskData,
      pdfFunctionFactory: pdfFunctionFactory,
      globalColorSpaceCache: globalColorSpaceCache,
      localColorSpaceCache: localColorSpaceCache,
    );
  }

  static Future<Map<String, dynamic>> createMask({
    required BaseStream image,
    bool isOffscreenCanvasSupported = false,
  }) async {
    final dict = image.dict as Dict;
    final width = (dict.get('W', 'Width') as num).toInt();
    final height = (dict.get('H', 'Height') as num).toInt();

    final interpolate = dict.get('I', 'Interpolate');
    final decode = dict.getArray('D', 'Decode');
    final inverseDecode = decode is List && decode.isNotEmpty && (decode[0] as num) > 0;

    final computedLength = ((width + 7) >> 3) * height;
    final imgArray = await image.getImageData(computedLength);

    final isSingleOpaquePixel = width == 1 &&
        height == 1 &&
        inverseDecode == (imgArray.isEmpty || ((imgArray[0] & 128) != 0));

    if (isSingleOpaquePixel) {
      return {'isSingleOpaquePixel': true};
    }

    final actualLength = imgArray.length;
    final haveFullData = computedLength == actualLength;
    Uint8List data;

    if (image is DecodeStream && (!inverseDecode || haveFullData)) {
      data = imgArray;
    } else if (!inverseDecode) {
      data = Uint8List.fromList(imgArray);
    } else {
      data = Uint8List(computedLength);
      data.setRange(0, actualLength, imgArray);
      data.fillRange(actualLength, computedLength, 0xff);
    }

    if (inverseDecode) {
      for (var i = 0; i < actualLength; i++) {
        data[i] ^= 0xff;
      }
    }

    return {
      'data': data,
      'width': width,
      'height': height,
      'interpolate': interpolate,
    };
  }

  int get drawWidth =>
      math.max(width, math.max(smask?.width ?? 0, (mask is PDFImage ? (mask as PDFImage).width : 0)));

  int get drawHeight =>
      math.max(height, math.max(smask?.height ?? 0, (mask is PDFImage ? (mask as PDFImage).height : 0)));

  void decodeBuffer(List<int> buffer) {
    if (bpc == 1) {
      for (var i = 0, ii = buffer.length; i < ii; i++) {
        buffer[i] = buffer[i] == 0 ? 1 : 0;
      }
      return;
    }
    final max = (1 << bpc) - 1;
    var index = 0;
    for (var i = 0, ii = width * height; i < ii; i++) {
      for (var j = 0; j < numComps; j++) {
        final val = decodeAddends[j] + buffer[index] * decodeCoefficients[j];
        buffer[index] = MathClamp(val.truncate(), 0, max).toInt();
        index++;
      }
    }
  }

  List<int> getComponents(Uint8List buffer) {
    if (bpc == 8) {
      return buffer;
    }

    final length = width * height * numComps;
    var bufferPos = 0;
    final List<int> output = bpc <= 8
        ? Uint8List(length)
        : (bpc <= 16 ? Uint16List(length) : Uint32List(length));
    final rowComps = width * numComps;
    final max = (1 << bpc) - 1;
    var i = 0;

    if (bpc == 1) {
      for (var j = 0; j < height; j++) {
        final loop1End = i + (rowComps & ~7);
        final loop2End = i + rowComps;

        while (i < loop1End) {
          final buf = buffer[bufferPos++];
          output[i] = (buf >> 7) & 1;
          output[i + 1] = (buf >> 6) & 1;
          output[i + 2] = (buf >> 5) & 1;
          output[i + 3] = (buf >> 4) & 1;
          output[i + 4] = (buf >> 3) & 1;
          output[i + 5] = (buf >> 2) & 1;
          output[i + 6] = (buf >> 1) & 1;
          output[i + 7] = buf & 1;
          i += 8;
        }

        if (i < loop2End) {
          final buf = buffer[bufferPos++];
          var maskBit = 128;
          while (i < loop2End) {
            output[i++] = (buf & maskBit) != 0 ? 1 : 0;
            maskBit >>= 1;
          }
        }
      }
    } else {
      var bits = 0;
      var buf = 0;
      for (var k = 0; k < length; ++k) {
        if (k % rowComps == 0) {
          buf = 0;
          bits = 0;
        }

        while (bits < bpc) {
          buf = (buf << 8) | buffer[bufferPos++];
          bits += 8;
        }

        final remainingBits = bits - bpc;
        var value = buf >> remainingBits;
        if (value < 0) {
          value = 0;
        } else if (value > max) {
          value = max;
        }
        output[k] = value;
        buf &= (1 << remainingBits) - 1;
        bits = remainingBits;
      }
    }
    return output;
  }

  Future<void> fillOpacity(
    Uint8List rgbaBuf,
    int width,
    int height,
    int actualHeight,
    List<int> imageComps,
  ) async {
    if (smask != null) {
      await smask!.fillGrayBuffer(
        rgbaBuf,
        destWidth: width,
        destHeight: height,
        maxRows: actualHeight,
        offset: 3,
        stride: 4,
      );
    } else if (mask != null) {
      if (mask is PDFImage) {
        await (mask as PDFImage).fillGrayBuffer(
          rgbaBuf,
          destWidth: width,
          destHeight: height,
          invertOutput: true,
          maxRows: actualHeight,
          offset: 3,
          stride: 4,
        );
      } else if (mask is List) {
        final maskList = (mask as List).cast<num>();
        final numC = numComps;
        for (var i = 0, ii = width * actualHeight; i < ii; ++i) {
          var opacity = 0;
          final imageOffset = i * numC;
          for (var j = 0; j < numC; ++j) {
            final color = imageComps[imageOffset + j];
            final maskOffset = j * 2;
            if (color < maskList[maskOffset] || color > maskList[maskOffset + 1]) {
              opacity = 255;
              break;
            }
          }
          rgbaBuf[i * 4 + 3] = opacity;
        }
      } else {
        throw FormatError('Unknown mask format.');
      }
    } else {
      for (var i = 0, ii = width * actualHeight; i < ii; ++i) {
        rgbaBuf[i * 4 + 3] = 255;
      }
    }
  }

  void undoPreblend(Uint8List buffer, int width, int height) {
    final matteVal = smask?.matte;
    if (matteVal == null || colorSpace == null) return;

    Uint8List matteRgb;
    if (matteVal is List) {
      matteRgb = colorSpace!.getRgb(matteVal.cast<num>(), 0);
    } else {
      return;
    }
    final matteR = matteRgb[0];
    final matteG = matteRgb[1];
    final matteB = matteRgb[2];
    final length = width * height * 4;

    for (var i = 0; i < length; i += 4) {
      final alpha = buffer[i + 3];
      if (alpha == 0) {
        buffer[i] = 255;
        buffer[i + 1] = 255;
        buffer[i + 2] = 255;
        continue;
      }
      final k = 255 / alpha;
      buffer[i] = MathClamp(((buffer[i] - matteR) * k + matteR).round(), 0, 255).toInt();
      buffer[i + 1] = MathClamp(((buffer[i + 1] - matteG) * k + matteG).round(), 0, 255).toInt();
      buffer[i + 2] = MathClamp(((buffer[i + 2] - matteB) * k + matteB).round(), 0, 255).toInt();
    }
  }

  Future<dynamic> createImageData({
    bool forceRGBA = false,
    bool isOffscreenCanvasSupported = false,
  }) async {
    final dWidth = drawWidth;
    final dHeight = drawHeight;
    final imgData = <String, dynamic>{
      'width': dWidth,
      'height': dHeight,
      'interpolate': interpolate,
      'kind': 0,
      'data': null,
    };

    final nComps = numComps;
    final origWidth = width;
    final origHeight = height;
    final bitsPerComp = bpc;

    final rowBytes = (origWidth * nComps * bitsPerComp + 7) >> 3;
    final mustBeResized =
        isOffscreenCanvasSupported && ImageResizer.needsToBeResized(dWidth, dHeight);

    if (smask == null && mask == null && colorSpace?.name == 'DeviceRGBA') {
      imgData['kind'] = ImageKind.RGBA_32BPP;
      final imgArray = await getImageBytes(
        origHeight * origWidth * 4,
        internal: isOffscreenCanvasSupported && mustBeResized,
      );
      imgData['data'] = imgArray;
      if (isOffscreenCanvasSupported && mustBeResized) {
        return ImageResizer.createImage(imgData, false);
      }
      return imgData;
    }

    if (!forceRGBA) {
      int? kind;
      if (colorSpace?.name == 'DeviceGray' && bitsPerComp == 1) {
        kind = ImageKind.GRAYSCALE_1BPP;
      } else if (colorSpace?.name == 'DeviceRGB' && bitsPerComp == 8 && !needsDecode) {
        kind = ImageKind.RGB_24BPP;
      }

      if (kind != null &&
          smask == null &&
          mask == null &&
          dWidth == origWidth &&
          dHeight == origHeight) {
        final data = await getImageBytes(origHeight * rowBytes,
            internal: isOffscreenCanvasSupported && mustBeResized);
        imgData['kind'] = kind;
        imgData['data'] = data;

        if (needsDecode) {
          for (var i = 0, ii = data.length; i < ii; i++) {
            data[i] ^= 0xff;
          }
        }
        if (isOffscreenCanvasSupported && mustBeResized) {
          return ImageResizer.createImage(imgData, needsDecode);
        }
        return imgData;
      }

      if (image is JpegStream && smask == null && mask == null && !needsDecode) {
        var imageLength = origHeight * rowBytes;
        switch (colorSpace?.name) {
          case 'DeviceGray':
            imageLength *= 3;
            continue devRgb;
          devRgb:
          case 'DeviceRGB':
          case 'DeviceCMYK':
            imgData['kind'] = ImageKind.RGB_24BPP;
            imgData['data'] = await getImageBytes(
              imageLength,
              drawWidth: dWidth,
              drawHeight: dHeight,
              forceRGB: true,
              internal: mustBeResized,
            );
            if (mustBeResized) {
              return ImageResizer.createImage(imgData);
            }
            return imgData;
        }
      }
    }

    final imgArray = await getImageBytes(origHeight * rowBytes, internal: true);
    final actualHeight = rowBytes > 0
        ? ((imgArray.length / rowBytes) * dHeight / origHeight).floor()
        : dHeight;

    final comps = getComponents(imgArray);
    Uint8List data;
    var alpha01 = 0;
    var maybeUndoPreblend = false;

    if (!forceRGBA && smask == null && mask == null) {
      imgData['kind'] = ImageKind.RGB_24BPP;
      data = Uint8List(dWidth * dHeight * 3);
      alpha01 = 0;
      maybeUndoPreblend = false;
    } else {
      imgData['kind'] = ImageKind.RGBA_32BPP;
      data = Uint8List(dWidth * dHeight * 4);
      alpha01 = 1;
      maybeUndoPreblend = true;
      await fillOpacity(data, dWidth, dHeight, actualHeight, comps);
    }

    if (needsDecode) {
      decodeBuffer(comps);
    }

    colorSpace?.fillRgb(
      data,
      origWidth,
      origHeight,
      dWidth,
      dHeight,
      actualHeight,
      bitsPerComp,
      comps,
      alpha01,
    );

    if (maybeUndoPreblend) {
      undoPreblend(data, dWidth, actualHeight);
    }

    imgData['data'] = data;
    if (mustBeResized) {
      return ImageResizer.createImage(imgData);
    }
    return imgData;
  }

  Future<void> fillGrayBuffer(
    Uint8List buffer, {
    int? destWidth,
    int? destHeight,
    bool invertOutput = false,
    int? maxRows,
    int offset = 0,
    int stride = 1,
  }) async {
    if (numComps != 1) {
      throw FormatError('Reading gray scale from a color image: $numComps');
    }

    final srcWidth = width;
    final srcHeight = height;
    final bitsPerComp = bpc;

    final rowBytes = (srcWidth * numComps * bitsPerComp + 7) >> 3;
    final imgArray = await getImageBytes(srcHeight * rowBytes, internal: true);
    final comps = getComponents(imgArray);

    final resolvedDestWidth = destWidth ?? srcWidth;
    final resolvedDestHeight = destHeight ?? srcHeight;
    final needsResampling =
        resolvedDestWidth != srcWidth || resolvedDestHeight != srcHeight;
    final rows = maxRows == null
        ? resolvedDestHeight
        : math.min(resolvedDestHeight, maxRows);

    var outputWidth = srcWidth;
    var yRatio = 0.0;
    Uint32List? xScaled;
    if (needsResampling) {
      outputWidth = resolvedDestWidth;
      yRatio = srcHeight / resolvedDestHeight;
      final xRatio = srcWidth / resolvedDestWidth;
      xScaled = Uint32List(resolvedDestWidth);
      for (var i = 0; i < resolvedDestWidth; i++) {
        xScaled[i] = (i * xRatio).floor();
      }
    }

    final maskVal = invertOutput ? 0xff : 0;

    if (bitsPerComp == 1) {
      if (xScaled != null) {
        final xMap = xScaled;
        var destIndex = offset;
        if (needsDecode) {
          for (var row = 0; row < rows; row++) {
            final py = (row * yRatio).floor() * srcWidth;
            for (var col = 0; col < outputWidth; col++) {
              buffer[destIndex] = ((comps[py + xMap[col]] - 1) & 255) ^ maskVal;
              destIndex += stride;
            }
          }
        } else {
          for (var row = 0; row < rows; row++) {
            final py = (row * yRatio).floor() * srcWidth;
            for (var col = 0; col < outputWidth; col++) {
              buffer[destIndex] = (-comps[py + xMap[col]] & 255) ^ maskVal;
              destIndex += stride;
            }
          }
        }
      } else {
        final length = outputWidth * rows;
        if (needsDecode) {
          for (var i = 0; i < length; ++i) {
            buffer[i * stride + offset] = ((comps[i] - 1) & 255) ^ maskVal;
          }
        } else {
          for (var i = 0; i < length; ++i) {
            buffer[i * stride + offset] = (-comps[i] & 255) ^ maskVal;
          }
        }
      }
      return;
    }

    if (needsDecode) {
      decodeBuffer(comps);
    }

    final scale = 255.0 / ((1 << bitsPerComp) - 1);
    if (xScaled != null) {
      final xMap = xScaled;
      var destIndex = offset;
      for (var row = 0; row < rows; row++) {
        final py = (row * yRatio).floor() * srcWidth;
        for (var col = 0; col < outputWidth; col++) {
          buffer[destIndex] = ((scale * comps[py + xMap[col]]).round()) ^ maskVal;
          destIndex += stride;
        }
      }
    } else {
      final length = outputWidth * rows;
      for (var i = 0; i < length; ++i) {
        buffer[i * stride + offset] = ((scale * comps[i]).round()) ^ maskVal;
      }
    }
  }

  Future<Uint8List> getImageBytes(
    int length, {
    int? drawWidth,
    int? drawHeight,
    bool forceRGBA = false,
    bool forceRGB = false,
    bool internal = false,
  }) async {
    image.reset();
    image.drawWidth = drawWidth ?? width;
    image.drawHeight = drawHeight ?? height;
    image.forceRGBA = forceRGBA;
    image.forceRGB = forceRGB;
    final imageBytes = await image.getImageData(length, jpxDecoderOptions);

    if (internal || image is DecodeStream) {
      return imageBytes;
    }
    return Uint8List.fromList(imageBytes);
  }
}

class JpxImageStreamAdapter implements JpxByteStream {
  final BaseStream stream;
  JpxImageStreamAdapter(this.stream);

  @override
  int getByte() => stream.getByte();

  @override
  void skip(int count) => stream.skip(count);

  @override
  int getInt32() {
    final b0 = stream.getByte();
    final b1 = stream.getByte();
    final b2 = stream.getByte();
    final b3 = stream.getByte();
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
  }

  @override
  int getUint16() {
    final b0 = stream.getByte();
    final b1 = stream.getByte();
    return (b0 << 8) | b1;
  }
}
