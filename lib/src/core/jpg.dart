// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import '../shared/util.dart';
import 'jpeg_decoder.dart' as decoder;

class JpegError extends BaseException {
  JpegError(String msg) : super(msg, 'JpegError');
}

class JpegFrameComponent {
  JpegFrameComponent({
    required this.index,
    required this.h,
    required this.v,
    required this.quantizationId,
    required this.scaleX,
    required this.scaleY,
  });

  final int? index;
  final int h;
  final int v;
  final int quantizationId;
  final double scaleX;
  final double scaleY;
}

class JpegOptions {
  Int32List? decodeTransform;
  int? colorTransform;

  JpegOptions({this.decodeTransform, this.colorTransform});
}

class JpegImage {
  final JpegOptions options;
  int width = 0;
  int height = 0;
  int numComponents = 0;
  Map<String, dynamic>? jfif;
  Map<String, dynamic>? adobe;
  final List<JpegFrameComponent> components = [];
  Uint8List? _encodedData;

  JpegImage([JpegOptions? options]) : options = options ?? JpegOptions();

  void parse(Uint8List data) {
    _encodedData = Uint8List.fromList(data);
    if (data.length < 4) {
      throw JpegError('SOI not found');
    }

    final reader = _JpegReader(data);
    var fileMarker = reader.readUint16();
    if (fileMarker != 0xffd8) {
      throw JpegError('SOI not found');
    }

    _JpegFrame? frame;
    Map<String, dynamic>? parsedJfif;
    Map<String, dynamic>? parsedAdobe;
    var numSOSMarkers = 0;

    while (reader.offset < data.length) {
      fileMarker = reader.readMarker();
      if (fileMarker == 0xffd9) {
        break;
      }

      switch (fileMarker) {
        case >= 0xffe0 && <= 0xffef:
        case 0xfffe:
          final appData = reader.readDataBlock();
          if (fileMarker == 0xffe0 &&
              _startsWith(appData, [0x4a, 0x46, 0x49, 0x46, 0])) {
            parsedJfif = {
              'version': {
                'major': appData.length > 5 ? appData[5] : 0,
                'minor': appData.length > 6 ? appData[6] : 0
              },
              'densityUnits': appData.length > 7 ? appData[7] : 0,
              'xDensity':
                  appData.length > 9 ? (appData[8] << 8) | appData[9] : 0,
              'yDensity':
                  appData.length > 11 ? (appData[10] << 8) | appData[11] : 0,
              'thumbWidth': appData.length > 12 ? appData[12] : 0,
              'thumbHeight': appData.length > 13 ? appData[13] : 0,
            };
          } else if (fileMarker == 0xffee &&
              _startsWith(appData, [0x41, 0x64, 0x6f, 0x62, 0x65])) {
            parsedAdobe = {
              'version':
                  appData.length > 6 ? (appData[5] << 8) | appData[6] : 0,
              'flags0': appData.length > 8 ? (appData[7] << 8) | appData[8] : 0,
              'flags1':
                  appData.length > 10 ? (appData[9] << 8) | appData[10] : 0,
              'transformCode': appData.length > 11 ? appData[11] : 0,
            };
          }
          break;

        case 0xffdb: // DQT
        case 0xffc4: // DHT
        case 0xffcc: // DAC
          reader.skipDataBlock();
          break;

        case 0xffdd: // DRI
          reader.skipDataBlock();
          break;

        case 0xffc0:
        case 0xffc1:
        case 0xffc2:
          if (frame != null) {
            throw JpegError('Only single frame JPEGs supported');
          }
          frame = _readFrame(reader, fileMarker);
          break;

        case 0xffda: // SOS
          if (frame == null) {
            throw JpegError('SOS marker found before SOF marker');
          }
          reader.skipDataBlock();
          numSOSMarkers++;
          reader.skipScanData();
          break;

        case 0xffdc: // DNL
          reader.skipDataBlock();
          break;

        case 0xffff:
          break;

        default:
          if (fileMarker >= 0xffd0 && fileMarker <= 0xffd7) {
            break;
          }
          throw JpegError(
            'JpegImage.parse - unknown marker: ${fileMarker.toRadixString(16)}',
          );
      }
    }

    if (frame == null) {
      throw JpegError('JpegImage.parse - no frame data found.');
    }

    width = frame.samplesPerLine;
    height = frame.scanLines;
    jfif = parsedJfif;
    adobe = parsedAdobe;
    components
      ..clear()
      ..addAll(frame.components);
    numComponents = components.length;

    if (numSOSMarkers == 0) {
      warn('JpegImage.parse - no scan data found.');
    }
  }

  Uint8List getData(Map<String, dynamic> params) {
    final encoded = _encodedData;
    if (encoded == null) throw JpegError('JPEG data has not been parsed.');
    try {
      final image = decoder.JpegDecoder.decode(encoded);
      final targetWidth =
          params['width'] is int ? params['width'] as int : image.width;
      final targetHeight =
          params['height'] is int ? params['height'] as int : image.height;
      final forceRgba = params['forceRGBA'] == true;
      final forceRgb = params['forceRGB'] == true || forceRgba;
      final sourceChannels = image.bytesPerPixel;
      final targetChannels = forceRgba ? 4 : (forceRgb ? 3 : sourceChannels);
      final output = Uint8List(targetWidth * targetHeight * targetChannels);
      for (var y = 0; y < targetHeight; y++) {
        final sourceY = y * image.height ~/ targetHeight;
        for (var x = 0; x < targetWidth; x++) {
          final sourceX = x * image.width ~/ targetWidth;
          final source = (sourceY * image.width + sourceX) * sourceChannels;
          final target = (y * targetWidth + x) * targetChannels;
          if (sourceChannels == 1 && targetChannels >= 3) {
            output[target] =
                output[target + 1] = output[target + 2] = image.pixels[source];
          } else {
            final copied = sourceChannels < targetChannels
                ? sourceChannels
                : targetChannels;
            for (var channel = 0; channel < copied; channel++) {
              output[target + channel] = image.pixels[source + channel];
            }
          }
          if (targetChannels == 4) output[target + 3] = 255;
        }
      }
      return output;
    } on decoder.JpegDecodeException catch (error) {
      throw JpegError(error.message);
    }
  }

  static dynamic canUseImageDecoder(Uint8List data, int? colorTransform) {
    // Retorna false ou objeto com exifStart/exifEnd. Em Dart Native cross-platform, geralmente false.
    return false;
  }
}

class _JpegFrame {
  _JpegFrame({
    required this.samplesPerLine,
    required this.scanLines,
    required this.components,
  });

  final int samplesPerLine;
  final int scanLines;
  final List<JpegFrameComponent> components;
}

class _JpegReader {
  _JpegReader(this.data);

  final Uint8List data;
  int offset = 0;

  int readUint16() {
    if (offset + 1 >= data.length) {
      throw JpegError('unexpected end of JPEG data');
    }
    final value = (data[offset] << 8) | data[offset + 1];
    offset += 2;
    return value;
  }

  int readMarker() {
    while (offset < data.length && data[offset] != 0xff) {
      offset++;
    }
    while (offset < data.length && data[offset] == 0xff) {
      offset++;
    }
    if (offset >= data.length) {
      return 0xffd9;
    }
    return 0xff00 | data[offset++];
  }

  Uint8List readDataBlock() {
    final length = readUint16();
    if (length < 2 || offset + length - 2 > data.length) {
      throw JpegError('invalid JPEG data block length');
    }
    final block = Uint8List.sublistView(data, offset, offset + length - 2);
    offset += length - 2;
    return block;
  }

  void skipDataBlock() {
    readDataBlock();
  }

  void skipScanData() {
    while (offset + 1 < data.length) {
      if (data[offset] == 0xff) {
        final next = data[offset + 1];
        if (next == 0x00) {
          offset += 2;
          continue;
        }
        if (next >= 0xd0 && next <= 0xd7) {
          offset += 2;
          continue;
        }
        return;
      }
      offset++;
    }
  }
}

_JpegFrame _readFrame(_JpegReader reader, int marker) {
  final length = reader.readUint16();
  final frameEnd = reader.offset + length - 2;
  if (length < 8 || frameEnd > reader.data.length) {
    throw JpegError('invalid SOF marker length');
  }

  final precision = reader.data[reader.offset++];
  if (precision != 8) {
    throw JpegError('only 8-bit JPEG images are supported');
  }
  final scanLines = reader.readUint16();
  final samplesPerLine = reader.readUint16();
  final componentsCount = reader.data[reader.offset++];
  if (componentsCount <= 0) {
    throw JpegError('invalid JPEG component count');
  }

  var maxH = 0;
  var maxV = 0;
  final rawComponents = <({int id, int h, int v, int qId})>[];
  for (var i = 0; i < componentsCount; i++) {
    if (reader.offset + 2 >= frameEnd) {
      throw JpegError('invalid JPEG component data');
    }
    final componentId = reader.data[reader.offset++];
    final sampling = reader.data[reader.offset++];
    final h = sampling >> 4;
    final v = sampling & 15;
    final qId = reader.data[reader.offset++];
    if (h == 0 || v == 0) {
      throw JpegError('invalid JPEG component sampling');
    }
    if (h > maxH) maxH = h;
    if (v > maxV) maxV = v;
    rawComponents.add((id: componentId, h: h, v: v, qId: qId));
  }
  reader.offset = frameEnd;

  final components = <JpegFrameComponent>[
    for (final component in rawComponents)
      JpegFrameComponent(
        index: component.id,
        h: component.h,
        v: component.v,
        quantizationId: component.qId,
        scaleX: component.h / maxH,
        scaleY: component.v / maxV,
      )
  ];

  return _JpegFrame(
    samplesPerLine: samplesPerLine,
    scanLines: scanLines,
    components: components,
  );
}

bool _startsWith(Uint8List data, List<int> prefix) {
  if (data.length < prefix.length) {
    return false;
  }
  for (var i = 0; i < prefix.length; i++) {
    if (data[i] != prefix[i]) {
      return false;
    }
  }
  return true;
}
