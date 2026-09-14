// Copyright 2025 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfjs/src/core/obj_bin_transform_core.dart';
import 'package:pdfjs/src/display/obj_bin_transform_display.dart';
import 'package:test/test.dart';

void main() {
  group('obj_bin_transform', () {
    group('Font data', () {
      final cssFontInfo = {
        'fontFamily': 'Sample Family',
        'fontWeight': 'not a number',
        'italicAngle': 'angle',
        'uselessProp': "doesn't matter",
      };

      final systemFontInfo = {
        'guessFallback': false,
        'css': 'some string',
        'loadedName': 'another string',
        'baseFontName': 'base name',
        'src': 'source',
        'style': {
          'style': 'normal',
          'weight': '400',
          'uselessProp': "doesn't matter",
        },
        'uselessProp': "doesn't matter",
      };

      final fontInfo = {
        'black': true,
        'bold': true,
        'disableFontFace': true,
        'fontExtraProperties': true,
        'isInvalidPDFjsFont': true,
        'isType3Font': true,
        'italic': true,
        'missingFile': true,
        'remeasure': true,
        'vertical': true,
        'ascent': 1.0,
        'defaultWidth': 1.0,
        'descent': 1.0,
        'bbox': [1, 1, 1, 1],
        'fontMatrix': [1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        'defaultVMetrics': [1, 1, 1],
        'fallbackName': 'string',
        'loadedName': 'string',
        'mimetype': 'string',
        'name': 'string',
        'data': Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
        'uselessProp': 'something',
      };

      test('must roundtrip correctly for CssFontInfo', () {
        var sizeEstimate = 0;
        for (final string in ['Sample Family', 'not a number', 'angle']) {
          sizeEstimate += 4 + utf8.encode(string).length;
        }
        final buffer = compileCssFontInfo(cssFontInfo);
        expect(buffer.lengthInBytes, equals(sizeEstimate));
        final deserialized = CssFontInfo(buffer);
        expect(deserialized.fontFamily, equals('Sample Family'));
        expect(deserialized.fontWeight, equals('not a number'));
        expect(deserialized.italicAngle, equals('angle'));
      });

      test('must roundtrip correctly for SystemFontInfo', () {
        var sizeEstimate = 1 + 4;
        for (final string in [
          'some string',
          'another string',
          'base name',
          'source',
          'normal',
          '400',
        ]) {
          sizeEstimate += 4 + utf8.encode(string).length;
        }
        final buffer = compileSystemFontInfo(systemFontInfo);
        expect(buffer.lengthInBytes, equals(sizeEstimate));
        final deserialized = SystemFontInfo(buffer);
        expect(deserialized.guessFallback, isFalse);
        expect(deserialized.css, equals('some string'));
        expect(deserialized.loadedName, equals('another string'));
        expect(deserialized.baseFontName, equals('base name'));
        expect(deserialized.src, equals('source'));
        expect(deserialized.style.style, equals('normal'));
        expect(deserialized.style.weight, equals('400'));
      });

      test('must roundtrip correctly for FontInfo', () {
        final buffer = compileFontInfo(fontInfo);
        expect(buffer.lengthInBytes, greaterThan(0));
        final deserialized = FontInfo(buffer: buffer);
        expect(deserialized.black, isTrue);
        expect(deserialized.bold, isTrue);
        expect(deserialized.disableFontFace, isTrue);
        expect(deserialized.fontExtraProperties, isTrue);
        expect(deserialized.isInvalidPDFjsFont, isTrue);
        expect(deserialized.isType3Font, isTrue);
        expect(deserialized.italic, isTrue);
        expect(deserialized.missingFile, isTrue);
        expect(deserialized.remeasure, isTrue);
        expect(deserialized.vertical, isTrue);
        expect(deserialized.ascent, equals(1.0));
        expect(deserialized.defaultWidth, equals(1.0));
        expect(deserialized.descent, equals(1.0));
        expect(deserialized.bbox, equals([1, 1, 1, 1]));
        expect(deserialized.fontMatrix, equals([1.0, 1.0, 1.0, 1.0, 1.0, 1.0]));
        expect(deserialized.defaultVMetrics, equals([1, 1, 1]));
        expect(deserialized.fallbackName, equals('string'));
        expect(deserialized.loadedName, equals('string'));
        expect(deserialized.mimetype, equals('string'));
        expect(deserialized.name, equals('string'));
        expect(deserialized.data, equals([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));
        expect(deserialized.cssFontInfo, isNull);
        expect(deserialized.systemFontInfo, isNull);
      });

      test('nesting should work as expected for FontInfo', () {
        final nestedFontInfo = Map<String, dynamic>.from(fontInfo)
          ..['cssFontInfo'] = cssFontInfo
          ..['systemFontInfo'] = systemFontInfo;
        final buffer = compileFontInfo(nestedFontInfo);
        final deserialized = FontInfo(buffer: buffer);
        expect(deserialized.cssFontInfo?.fontWeight, equals('not a number'));
        expect(deserialized.systemFontInfo?.src, equals('source'));
      });

      test('clearData should clear font data', () {
        final buffer = compileFontInfo(fontInfo);
        final deserialized = FontInfo(buffer: buffer);
        expect(deserialized.data, isNotNull);
        deserialized.clearData();
        expect(deserialized.data, isNull);
      });
    });

    group('Pattern data', () {
      final axialPatternIR = [
        'RadialAxial',
        'axial',
        [0.0, 0.0, 100.0, 50.0],
        [
          [0.0, '#ff0000'],
          [0.5, '#00ff00'],
          [1.0, '#0000ff'],
        ],
        [10.0, 20.0],
        [90.0, 40.0],
        null,
        null,
      ];

      final radialPatternIR = [
        'RadialAxial',
        'radial',
        [5.0, 5.0, 95.0, 45.0],
        [
          [0.0, '#ffff00'],
          [0.3, '#ff00ff'],
          [0.7, '#00ffff'],
          [1.0, '#ffffff'],
        ],
        [25.0, 25.0],
        [75.0, 35.0],
        5.0,
        25.0,
      ];

      test('must serialize and deserialize axial gradients correctly', () {
        final buffer = compilePatternInfo(axialPatternIR);
        expect(buffer.lengthInBytes, greaterThan(0));

        final patternInfo = PatternInfo(buffer);
        final reconstructedIR = patternInfo.getIR();

        expect(reconstructedIR[0], equals('RadialAxial'));
        expect(reconstructedIR[1], equals('axial'));
        expect(reconstructedIR[2], equals([0.0, 0.0, 100.0, 50.0]));
        expect(
          reconstructedIR[3],
          equals([
            [0.0, '#ff0000'],
            [0.5, '#00ff00'],
            [1.0, '#0000ff'],
          ]),
        );
        expect(reconstructedIR[4], equals([10.0, 20.0]));
        expect(reconstructedIR[5], equals([90.0, 40.0]));
        expect(reconstructedIR[6], isNull);
        expect(reconstructedIR[7], isNull);
      });

      test('must serialize and deserialize radial gradients correctly', () {
        final buffer = compilePatternInfo(radialPatternIR);
        expect(buffer.lengthInBytes, greaterThan(0));

        final patternInfo = PatternInfo(buffer);
        final reconstructedIR = patternInfo.getIR();

        expect(reconstructedIR[0], equals('RadialAxial'));
        expect(reconstructedIR[1], equals('radial'));
        expect(reconstructedIR[2], equals([5.0, 5.0, 95.0, 45.0]));
        final stops = reconstructedIR[3] as List;
        expect(stops.length, equals(4));
        expect((stops[0][0] as num).toDouble(), closeTo(0.0, 1e-5));
        expect(stops[0][1], equals('#ffff00'));
        expect((stops[1][0] as num).toDouble(), closeTo(0.3, 1e-5));
        expect(stops[1][1], equals('#ff00ff'));
        expect((stops[2][0] as num).toDouble(), closeTo(0.7, 1e-5));
        expect(stops[2][1], equals('#00ffff'));
        expect((stops[3][0] as num).toDouble(), closeTo(1.0, 1e-5));
        expect(stops[3][1], equals('#ffffff'));
        expect(reconstructedIR[4], equals([25.0, 25.0]));
        expect(reconstructedIR[5], equals([75.0, 35.0]));
        expect(reconstructedIR[6], equals(5.0));
        expect(reconstructedIR[7], equals(25.0));
      });
    });

    group('FontPathInfo', () {
      test('must compile and retrieve font path', () {
        final input = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
        final buffer = compileFontPathInfo(input);
        final pathInfo = FontPathInfo(buffer);
        expect(pathInfo.path, equals([1.0, 2.0, 3.0, 4.0]));
      });
    });
  });
}
