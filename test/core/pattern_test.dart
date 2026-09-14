import 'dart:typed_data';

import 'package:pdfjs/src/core/colorspace_utils.dart';
import 'package:pdfjs/src/core/pattern.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/shared/util.dart';
import 'package:test/test.dart';

class MockPdfFunctionFactory {
  dynamic create(dynamic fnObj, [bool parseArray = false]) {
    // Return a simple function that outputs [1.0, 0.5, 0.2] regardless of input
    return (Float32List src, int srcOffset, Float32List dest, int destOffset) {
      final t = src[srcOffset];
      dest[destOffset] = t;
      dest[destOffset + 1] = 1.0 - t;
      dest[destOffset + 2] = 0.5;
    };
  }
}

class MockXRef {
  dynamic fetch(dynamic ref) => ref;
  dynamic fetchIfRef(dynamic ref) => ref;
}

void main() {
  group('Pattern and Shading', () {
    late MockXRef xref;
    late MockPdfFunctionFactory fnFactory;
    late GlobalColorSpaceCache globalCsCache;
    late LocalColorSpaceCache localCsCache;

    setUp(() {
      xref = MockXRef();
      fnFactory = MockPdfFunctionFactory();
      globalCsCache = GlobalColorSpaceCache();
      localCsCache = LocalColorSpaceCache();
    });

    test('DummyShading returns dummy IR', () {
      final dummy = DummyShading();
      expect(dummy.getIR(), equals(['Dummy']));
    });

    test('RadialAxialShading axial produces valid IR', () {
      final dict = Dict();
      dict.set('ShadingType', ShadingType.axial);
      dict.set('Coords', [0.0, 0.0, 100.0, 200.0]);
      dict.set('ColorSpace', Name.get('DeviceRGB'));
      dict.set('Function', Dict());
      dict.set('Domain', [0.0, 1.0]);

      final shading = RadialAxialShading(
        dict,
        xref,
        null,
        fnFactory,
        globalCsCache,
        localCsCache,
      );

      final ir = shading.getIR();
      expect(ir[0], equals('RadialAxial'));
      expect(ir[1], equals('axial'));
      expect(ir[4], equals([0.0, 0.0]));
      expect(ir[5], equals([100.0, 200.0]));
      expect(ir[6], isNull);
      expect(ir[7], isNull);

      final colorStops = ir[3] as List;
      expect(colorStops.isNotEmpty, isTrue);
      expect(colorStops.first[0], equals(0.0));
      expect(colorStops.last[0], equals(1.0));
    });

    test('RadialAxialShading radial produces valid IR with radii', () {
      final dict = Dict();
      dict.set('ShadingType', ShadingType.radial);
      dict.set('Coords', [10.0, 20.0, 5.0, 40.0, 50.0, 25.0]);
      dict.set('ColorSpace', Name.get('DeviceRGB'));
      dict.set('Function', Dict());

      final shading = RadialAxialShading(
        dict,
        xref,
        null,
        fnFactory,
        globalCsCache,
        localCsCache,
      );

      final ir = shading.getIR();
      expect(ir[0], equals('RadialAxial'));
      expect(ir[1], equals('radial'));
      expect(ir[4], equals([10.0, 20.0]));
      expect(ir[5], equals([40.0, 50.0]));
      expect(ir[6], equals(5.0));
      expect(ir[7], equals(25.0));
    });

    test('getTilingPatternIR creates structured IR for valid tiling pattern', () {
      final dict = Dict();
      dict.set('BBox', [0.0, 0.0, 50.0, 60.0]);
      dict.set('XStep', 50.0);
      dict.set('YStep', 60.0);
      dict.set('PaintType', 1);
      dict.set('TilingType', 1);

      final ir = getTilingPatternIR([], dict, '#ff0000');
      expect(ir[0], equals('TilingPattern'));
      expect(ir[1], equals('#ff0000'));
      expect(ir[4], equals([0.0, 0.0, 50.0, 60.0]));
      expect(ir[5], equals(50.0));
      expect(ir[6], equals(60.0));
      expect(ir[7], equals(1));
      expect(ir[8], equals(1));
      expect(ir[9], isTrue);
    });

    test('getTilingPatternIR throws on zero-sized bbox or missing required fields', () {
      final dict = Dict();
      dict.set('BBox', [0.0, 0.0, 0.0, 60.0]); // zero width
      dict.set('XStep', 50.0);
      dict.set('YStep', 60.0);
      dict.set('PaintType', 1);
      dict.set('TilingType', 1);

      expect(() => getTilingPatternIR([], dict, null), throwsA(isA<FormatError>()));
    });

    test('clearPatternCaches clears Bernstein cache', () {
      expect(() => clearPatternCaches(), returnsNormally);
    });
  });
}
