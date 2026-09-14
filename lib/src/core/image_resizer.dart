// Copyright 2023 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;
import 'dart:typed_data';

import '../shared/util.dart';
import 'core_utils.dart';

const int minImageDim = 2048;
const int maxImageDim = 32768;
const int maxError = 128;

class ImageResizer {
  static int _goodSquareLength = minImageDim;
  static bool _isImageDecoderSupported = false;
  static bool _hasMaxArea = false;
  static int _maxDim = maxImageDim;
  static int _maxArea = minImageDim * minImageDim;

  final dynamic _imgData;
  final bool _isMask;

  ImageResizer(this._imgData, [this._isMask = false]);

  static bool get canUseImageDecoder => _isImageDecoderSupported;

  static int get MAX_DIM => _maxDim;
  static set MAX_DIM(int val) => _maxDim = val;

  static int get MAX_AREA {
    if (!_hasMaxArea) {
      _hasMaxArea = true;
      _maxArea = _goodSquareLength * _goodSquareLength;
    }
    return _maxArea;
  }

  static set MAX_AREA(int area) {
    if (area >= 0) {
      _hasMaxArea = true;
      _maxArea = area;
    }
  }

  static void setOptions({
    int canvasMaxAreaInBytes = -1,
    bool isImageDecoderSupported = false,
  }) {
    if (!_hasMaxArea && canvasMaxAreaInBytes > 0) {
      MAX_AREA = canvasMaxAreaInBytes >> 2;
    }
    _isImageDecoderSupported = isImageDecoderSupported;
  }

  static bool needsToBeResized(int width, int height) {
    if (width <= _goodSquareLength && height <= _goodSquareLength) {
      return false;
    }

    final maxDim = MAX_DIM;
    if (width > maxDim || height > maxDim) {
      return true;
    }

    final area = width * height;
    if (_hasMaxArea) {
      return area > MAX_AREA;
    }

    if (area < _goodSquareLength * _goodSquareLength) {
      return false;
    }

    return area > MAX_AREA;
  }

  static int getReducePowerForJPX(
    int width,
    int height,
    int componentsCount,
  ) {
    final area = width * height;
    final maxJPXArea = (1 << 30) / (componentsCount * 4);
    if (!needsToBeResized(width, height)) {
      if (area > maxJPXArea) {
        return (math.log(area / maxJPXArea) / math.ln2).ceil();
      }
      return 0;
    }

    final maxDim = MAX_DIM;
    final maxArea = MAX_AREA;
    final minFactor = math.max(
      width / maxDim,
      math.max(
        height / maxDim,
        math.sqrt(area / math.min(maxJPXArea, maxArea.toDouble())),
      ),
    );
    return (math.log(minFactor) / math.ln2).ceil();
  }

  static Future<dynamic> createImage(dynamic imgData, [bool isMask = false]) async {
    return ImageResizer(imgData, isMask)._createImage();
  }

  static int _getInt(dynamic obj, String key) {
    if (obj is Map) {
      final val = obj[key];
      return val is num ? val.toInt() : 0;
    }
    if (key == 'width') return (obj.width as num).toInt();
    if (key == 'height') return (obj.height as num).toInt();
    if (key == 'kind') return (obj.kind as num).toInt();
    return 0;
  }

  static dynamic _getData(dynamic obj) {
    if (obj is Map) return obj['data'];
    return obj.data;
  }

  Future<dynamic> _createImage() async {
    final imgData = _imgData;
    final width = _getInt(imgData, 'width');
    final height = _getInt(imgData, 'height');

    if (width * height * 4 > MAX_INT_32) {
      final result = _rescaleImageData();
      if (result != null) {
        return result;
      }
    }

    // Direct pure Dart downsampling if exceeds limits.
    if (needsToBeResized(width, height)) {
      final result = _rescaleImageData();
      if (result != null) {
        return result;
      }
    }

    return imgData;
  }

  dynamic _rescaleImageData() {
    final imgData = _imgData;
    final dynamic data = _getData(imgData);
    final width = _getInt(imgData, 'width');
    final height = _getInt(imgData, 'height');
    final kind = _getInt(imgData, 'kind');

    final rgbaSize = width * height * 4;
    final K = math.max(1, (math.log(rgbaSize / MAX_INT_32) / math.ln2).ceil());
    final newWidth = width >> K;
    final newHeight = height >> K;

    if (newWidth <= 0 || newHeight <= 0) {
      return imgData;
    }

    final dest32 = Uint32List(newWidth * newHeight);
    final srcBytes = data is Uint8List
        ? data
        : (data is ByteBuffer
            ? Uint8List.view(data)
            : Uint8List.fromList((data as List).cast<int>()));

    final stepX = width / newWidth;
    final stepY = height / newHeight;

    if (kind == ImageKind.RGBA_32BPP) {
      final src32 = Uint32List.view(srcBytes.buffer, srcBytes.offsetInBytes);
      var destIdx = 0;
      for (var y = 0; y < newHeight; y++) {
        final srcY = (y * stepY).toInt();
        final rowOffset = srcY * width;
        for (var x = 0; x < newWidth; x++) {
          final srcX = (x * stepX).toInt();
          dest32[destIdx++] = src32[rowOffset + srcX];
        }
      }
    } else if (kind == ImageKind.RGB_24BPP) {
      var destIdx = 0;
      for (var y = 0; y < newHeight; y++) {
        final srcY = (y * stepY).toInt();
        final rowOffset = srcY * width * 3;
        for (var x = 0; x < newWidth; x++) {
          final srcX = (x * stepX).toInt();
          final offset = rowOffset + srcX * 3;
          final r = srcBytes[offset];
          final g = srcBytes[offset + 1];
          final b = srcBytes[offset + 2];
          dest32[destIdx++] = 0xff000000 | (b << 16) | (g << 8) | r;
        }
      }
    } else if (kind == ImageKind.GRAYSCALE_1BPP) {
      var destIdx = 0;
      final rowBytes = (width + 7) >> 3;
      for (var y = 0; y < newHeight; y++) {
        final srcY = (y * stepY).toInt();
        final rowOffset = srcY * rowBytes;
        for (var x = 0; x < newWidth; x++) {
          final srcX = (x * stepX).toInt();
          final byte = srcBytes[rowOffset + (srcX >> 3)];
          final bit = (byte >> (7 - (srcX & 7))) & 1;
          final val = _isMask
              ? (bit != 0 ? 0 : 255)
              : (bit != 0 ? 255 : 0);
          dest32[destIdx++] = 0xff000000 | (val << 16) | (val << 8) | val;
        }
      }
    }

    if (imgData is Map) {
      imgData['data'] = Uint8List.view(dest32.buffer);
      imgData['width'] = newWidth;
      imgData['height'] = newHeight;
      imgData['kind'] = ImageKind.RGBA_32BPP;
    } else {
      try {
        imgData.data = Uint8List.view(dest32.buffer);
        imgData.width = newWidth;
        imgData.height = newHeight;
        imgData.kind = ImageKind.RGBA_32BPP;
      } catch (_) {}
    }

    return imgData;
  }

  Uint8List encodeBMP() => _encodeBMP();

  Uint8List _encodeBMP() {
    final imgData = _imgData;
    final width = _getInt(imgData, 'width');
    final height = _getInt(imgData, 'height');
    final kind = _getInt(imgData, 'kind');
    final dynamic rawData = _getData(imgData);

    Uint8List data = rawData is Uint8List
        ? rawData
        : (rawData is ByteBuffer
            ? Uint8List.view(rawData)
            : Uint8List.fromList((rawData as List).cast<int>()));

    int bitPerPixel;
    Uint8List colorTable = Uint8List(0);
    Uint8List maskTable = colorTable;
    int compression = 0;

    switch (kind) {
      case ImageKind.GRAYSCALE_1BPP:
        bitPerPixel = 1;
        colorTable = Uint8List.fromList(
          _isMask
              ? [255, 255, 255, 255, 0, 0, 0, 0]
              : [0, 0, 0, 0, 255, 255, 255, 255],
        );
        final rowLen = (width + 7) >> 3;
        final rowSize = (rowLen + 3) & -4;
        if (rowLen != rowSize) {
          final newData = Uint8List(rowSize * height);
          var k = 0;
          for (var i = 0, ii = height * rowLen; i < ii; i += rowLen, k += rowSize) {
            newData.setRange(k, k + rowLen, data.sublist(i, i + rowLen));
          }
          data = newData;
        }
        break;

      case ImageKind.RGB_24BPP:
        bitPerPixel = 24;
        final rowLen = 3 * width;
        final rowSize = (rowLen + 3) & -4;
        final extraLen = rowSize - rowLen;
        if (extraLen > 0) {
          final newData = Uint8List(rowSize * height);
          var k = 0;
          for (var i = 0, ii = height * rowLen; i < ii; i += rowLen) {
            for (var j = 0; j < rowLen; j += 3) {
              newData[k++] = data[i + j + 2]; // B
              newData[k++] = data[i + j + 1]; // G
              newData[k++] = data[i + j];     // R
            }
            k += extraLen;
          }
          data = newData;
        } else {
          final swapped = Uint8List.fromList(data);
          for (var i = 0, ii = swapped.length; i < ii; i += 3) {
            final tmp = swapped[i];
            swapped[i] = swapped[i + 2];
            swapped[i + 2] = tmp;
          }
          data = swapped;
        }
        break;

      case ImageKind.RGBA_32BPP:
        bitPerPixel = 32;
        compression = 3;
        maskTable = Uint8List(4 + 4 + 4 + 4 + 52);
        final maskView = ByteData.sublistView(maskTable);
        if (Endian.host == Endian.little) {
          maskView.setUint32(0, 0x000000ff, Endian.little);
          maskView.setUint32(4, 0x0000ff00, Endian.little);
          maskView.setUint32(8, 0x00ff0000, Endian.little);
          maskView.setUint32(12, 0xff000000, Endian.little);
        } else {
          maskView.setUint32(0, 0xff000000, Endian.big);
          maskView.setUint32(4, 0x00ff0000, Endian.big);
          maskView.setUint32(8, 0x0000ff00, Endian.big);
          maskView.setUint32(12, 0x000000ff, Endian.big);
        }
        break;

      default:
        throw UnsupportedError('Invalid image kind: $kind');
    }

    var i = 0;
    final headerLength = 40 + maskTable.length;
    final fileLength = 14 + headerLength + colorTable.length + data.length;
    final bmpData = Uint8List(fileLength);
    final view = ByteData.sublistView(bmpData);

    // Signature 'BM'
    view.setUint16(i, 0x4d42, Endian.little);
    i += 2;

    // File size
    view.setUint32(i, fileLength, Endian.little);
    i += 4;

    // Reserved
    view.setUint32(i, 0, Endian.little);
    i += 4;

    // Data offset
    view.setUint32(i, 14 + headerLength + colorTable.length, Endian.little);
    i += 4;

    // Header size
    view.setUint32(i, headerLength, Endian.little);
    i += 4;

    // Width
    view.setInt32(i, width, Endian.little);
    i += 4;

    // Height (negative = top-to-bottom)
    view.setInt32(i, -height, Endian.little);
    i += 4;

    // Planes (must be 1)
    view.setUint16(i, 1, Endian.little);
    i += 2;

    // Bits per pixel
    view.setUint16(i, bitPerPixel, Endian.little);
    i += 2;

    // Compression
    view.setUint32(i, compression, Endian.little);
    i += 4;

    // Image size
    view.setUint32(i, 0, Endian.little);
    i += 4;

    // Horizontal resolution
    view.setInt32(i, 0, Endian.little);
    i += 4;

    // Vertical resolution
    view.setInt32(i, 0, Endian.little);
    i += 4;

    // Number of colors in palette
    view.setUint32(i, colorTable.length ~/ 4, Endian.little);
    i += 4;

    // Number of important colors
    view.setUint32(i, 0, Endian.little);
    i += 4;

    bmpData.setRange(i, i + maskTable.length, maskTable);
    i += maskTable.length;

    bmpData.setRange(i, i + colorTable.length, colorTable);
    i += colorTable.length;

    bmpData.setRange(i, i + data.length, data);

    return bmpData;
  }
}
