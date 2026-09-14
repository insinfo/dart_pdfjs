// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'package:pdfjs/src/core/evaluator.dart';
import 'package:pdfjs/src/core/image_evaluator.dart';
import 'package:pdfjs/src/core/operator_list.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/stream.dart';
import 'package:pdfjs/src/core/xref.dart';
import 'package:pdfjs/src/shared/util.dart';
import 'package:test/test.dart';

Dict dict(Map<String, dynamic> entries) {
  final result = Dict();
  for (final entry in entries.entries) {
    result.set(entry.key, entry.value);
  }
  return result;
}

Stream imageStream(List<int> bytes, Map<String, dynamic> entries) {
  return Stream(Uint8List.fromList(bytes))..dict = dict(entries);
}

XRef xref() => XRef(StringStream(''), null);

Future<Map<String, dynamic>> decode(
  List<int> bytes,
  Map<String, dynamic> entries, {
  bool inline = false,
}) {
  return ImageEvaluator.decode(
    xref: xref(),
    resources: Dict(),
    image: imageStream(bytes, entries),
    isInline: inline,
  );
}

Uint8List pixels(Map<String, dynamic> image) => image['data'] as Uint8List;

void main() {
  group('ImageEvaluator', () {
    test('decodes an RGB image to an RGBA display payload', () async {
      final result = await decode(
        <int>[255, 0, 0, 0, 128, 255],
        <String, dynamic>{
          'Width': 2,
          'Height': 1,
          'BitsPerComponent': 8,
          'ColorSpace': Name.get('DeviceRGB'),
        },
      );

      expect(result['width'], 2);
      expect(result['height'], 1);
      expect(result['kind'], ImageKind.RGBA_32BPP);
      expect(
        pixels(result),
        orderedEquals(<int>[255, 0, 0, 255, 0, 128, 255, 255]),
      );
    });

    test('accepts abbreviated inline-image dictionary keys', () async {
      final result = await decode(
        <int>[12, 34, 56],
        <String, dynamic>{
          'W': 1,
          'H': 1,
          'BPC': 8,
          'CS': Name.get('RGB'),
        },
        inline: true,
      );

      expect(pixels(result), orderedEquals(<int>[12, 34, 56, 255]));
    });

    test('expands 8-bit DeviceGray samples to RGB channels', () async {
      final result = await decode(
        <int>[0, 127, 255],
        <String, dynamic>{
          'W': 3,
          'H': 1,
          'BPC': 8,
          'CS': Name.get('G'),
        },
      );

      expect(
        pixels(result),
        orderedEquals(<int>[
          0,
          0,
          0,
          255,
          127,
          127,
          127,
          255,
          255,
          255,
          255,
          255,
        ]),
      );
    });

    test('unpacks one-bit grayscale rows with PDF row padding', () async {
      final result = await decode(
        <int>[0x80, 0x40],
        <String, dynamic>{
          'W': 2,
          'H': 2,
          'BPC': 1,
          'CS': Name.get('DeviceGray'),
        },
      );

      expect(
        pixels(result),
        orderedEquals(<int>[
          255,
          255,
          255,
          255,
          0,
          0,
          0,
          255,
          0,
          0,
          0,
          255,
          255,
          255,
          255,
          255,
        ]),
      );
    });

    test('applies a reversed Decode array', () async {
      final result = await decode(
        <int>[0, 255],
        <String, dynamic>{
          'W': 2,
          'H': 1,
          'BPC': 8,
          'CS': Name.get('DeviceGray'),
          'D': <dynamic>[1, 0],
        },
      );

      expect(
        pixels(result),
        orderedEquals(<int>[
          255,
          255,
          255,
          255,
          0,
          0,
          0,
          255,
        ]),
      );
    });

    test('converts DeviceCMYK pixels to an RGBA payload', () async {
      final result = await decode(
        <int>[0, 255, 255, 0, 255, 0, 255, 0],
        <String, dynamic>{
          'W': 2,
          'H': 1,
          'BPC': 8,
          'CS': Name.get('DeviceCMYK'),
        },
      );

      final data = pixels(result);
      expect(data, hasLength(8));
      expect(data[3], 255);
      expect(data[7], 255);
      expect(data.sublist(0, 3), isNot(equals(data.sublist(4, 7))));
    });

    test('uses a soft mask as the alpha channel', () async {
      final softMask = imageStream(<int>[
        0,
        255
      ], <String, dynamic>{
        'W': 2,
        'H': 1,
        'BPC': 8,
        'CS': Name.get('DeviceGray'),
      });
      final source = imageStream(<int>[
        255,
        0,
        0,
        0,
        255,
        0
      ], <String, dynamic>{
        'W': 2,
        'H': 1,
        'BPC': 8,
        'CS': Name.get('DeviceRGB'),
        'SMask': softMask,
      });

      final result = await ImageEvaluator.decode(
        xref: xref(),
        resources: Dict(),
        image: source,
      );
      expect(pixels(result)[3], 0);
      expect(pixels(result)[7], 255);
    });

    test('uses a color-key mask as the alpha channel', () async {
      final result = await decode(
        <int>[255, 0, 0, 0, 255, 0],
        <String, dynamic>{
          'W': 2,
          'H': 1,
          'BPC': 8,
          'CS': Name.get('DeviceRGB'),
          'Mask': <dynamic>[255, 255, 0, 0, 0, 0],
        },
      );

      expect(pixels(result)[3], 0);
      expect(pixels(result)[7], 255);
    });

    test('expands an image mask to black pixels and alpha', () async {
      final result = await decode(
        <int>[0x40],
        <String, dynamic>{
          'W': 2,
          'H': 1,
          'IM': true,
          'BPC': 1,
        },
      );

      expect(result['isImageMask'], isTrue);
      expect(
        pixels(result),
        orderedEquals(<int>[0, 0, 0, 255, 0, 0, 0, 0]),
      );
    });

    test('honors inverse decoding for image masks', () async {
      final result = await decode(
        <int>[0x40],
        <String, dynamic>{
          'W': 2,
          'H': 1,
          'IM': true,
          'BPC': 1,
          'D': <dynamic>[1, 0],
        },
      );

      expect(
        pixels(result),
        orderedEquals(<int>[0, 0, 0, 0, 0, 0, 0, 255]),
      );
    });

    test('rejects image streams without dictionaries', () async {
      final stream = Stream(Uint8List.fromList(<int>[0]));
      expect(
        () => ImageEvaluator.decode(
          xref: xref(),
          resources: Dict(),
          image: stream,
        ),
        throwsA(isA<FormatError>()),
      );
    });

    test('rejects missing dimensions', () async {
      expect(
        () => decode(<int>[
          0
        ], <String, dynamic>{
          'BPC': 8,
          'CS': Name.get('DeviceGray'),
        }),
        throwsA(isA<FormatError>()),
      );
    });
  });

  group('PartialEvaluator image integration', () {
    test('embeds decoded XObject pixels directly in the operator list',
        () async {
      final source = imageStream(<int>[
        10,
        20,
        30
      ], <String, dynamic>{
        'Subtype': Name.get('Image'),
        'Width': 1,
        'Height': 1,
        'BitsPerComponent': 8,
        'ColorSpace': Name.get('DeviceRGB'),
      });
      final resources = dict(<String, dynamic>{
        'XObject': dict(<String, dynamic>{'Im': source}),
      });
      final operatorList = OperatorList(RenderingIntentFlag.opList);
      await PartialEvaluator(xref: xref(), pageIndex: 0).getOperatorList(
        contentStream: StringStream('/Im Do'),
        executionContext: null,
        operatorList: operatorList,
        resources: resources,
      );

      expect(operatorList.fnArray, <int>[OPS.paintImageXObject]);
      final image = operatorList.argsArray.single.single as Map;
      expect(image['width'], 1);
      expect(image['height'], 1);
      expect(image['data'], orderedEquals(<int>[10, 20, 30, 255]));
      expect(operatorList.dependencies, isEmpty);
    });

    test('decodes inline RGB image bytes before emitting the operation',
        () async {
      final operatorList = OperatorList(RenderingIntentFlag.opList);
      await PartialEvaluator(xref: xref(), pageIndex: 0).getOperatorList(
        contentStream: StringStream('BI /W 1 /H 1 /BPC 8 /CS /RGB ID abc EI'),
        executionContext: null,
        operatorList: operatorList,
      );

      expect(operatorList.fnArray, <int>[OPS.paintInlineImageXObject]);
      final image = operatorList.argsArray.single.single as Map;
      expect(image['data'], orderedEquals(<int>[97, 98, 99, 255]));
    });
  });
}
