import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:pdfjs/src/core/colorspace.dart';
import 'package:pdfjs/src/core/colorspace_utils.dart';
import 'package:pdfjs/src/core/primitives.dart';

class _XRef {
  final Map<Ref, dynamic> objects = <Ref, dynamic>{};

  dynamic fetchIfRef(dynamic obj) => obj is Ref ? objects[obj] : obj;

  dynamic fetch(Ref ref) => objects[ref];
}

class _FunctionFactory {
  TintFunction create(dynamic raw) {
    return (src, srcOffset, dest, destOffset) {
      final tint = src[srcOffset].toDouble();
      dest[destOffset] = tint;
      dest[destOffset + 1] = 0.0;
      dest[destOffset + 2] = 1 - tint;
    };
  }
}

void main() {
  group('ColorSpaceUtils', () {
    late _XRef xref;
    late GlobalColorSpaceCache globalCache;
    late LocalColorSpaceCache localCache;

    setUp(() {
      xref = _XRef();
      globalCache = GlobalColorSpaceCache();
      localCache = LocalColorSpaceCache();
    });

    ColorSpace parse(dynamic cs, {Dict? resources, dynamic factory}) {
      return ColorSpaceUtils.parse(
        cs: cs,
        xref: xref,
        resources: resources,
        pdfFunctionFactory: factory,
        globalColorSpaceCache: globalCache,
        localColorSpaceCache: localCache,
      );
    }

    test('parses device names and caches names locally', () {
      final first = parse(Name.get('DeviceRGB'));
      final second = parse(Name.get('DeviceRGB'));

      expect(first, same(ColorSpaceUtils.rgb));
      expect(second, same(first));
      expect(localCache.getByName('DeviceRGB'), same(first));
    });

    test('resolves color spaces from resources', () {
      final colorSpaces = Dict()..set('CS1', Name.get('DeviceCMYK'));
      final resources = Dict()..set('ColorSpace', colorSpaces);

      final cs = parse(Name.get('CS1'), resources: resources);

      expect(cs, same(ColorSpaceUtils.cmyk));
      expect(localCache.getByName('CS1'), same(cs));
    });

    test('parses indexed color spaces', () {
      final cs = parse([
        Name.get('Indexed'),
        Name.get('DeviceRGB'),
        1,
        String.fromCharCodes([255, 0, 0, 0, 255, 0]),
      ]);
      final dest = Uint8List(6);

      expect(cs, isA<IndexedCS>());
      cs.getRgbBuffer([0, 1], 0, 2, dest, 0, 8, 0);
      expect(dest, [255, 0, 0, 0, 255, 0]);
    });

    test('parses Separation color spaces with tint function', () {
      final cs = parse(
        [
          Name.get('Separation'),
          Name.get('Spot'),
          Name.get('DeviceRGB'),
          'tint',
        ],
        factory: _FunctionFactory(),
      );
      final dest = Uint8List(3);

      expect(cs, isA<AlternateCS>());
      cs.getRgbItem([1], 0, dest, 0);
      expect(dest, [255, 0, 0]);
    });

    test('caches referenced color spaces globally and locally', () {
      final ref = Ref.get(7, 0);
      xref.objects[ref] = Name.get('DeviceGray');

      final first = parse(ref);
      final second = parse(ref);

      expect(first, same(ColorSpaceUtils.gray));
      expect(second, same(first));
      expect(globalCache.getByRef(ref), same(first));
      expect(localCache.getByRef(ref), same(first));
    });
  });
}
