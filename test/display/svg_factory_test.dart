// Copyright 2026. Apache License 2.0.

@TestOn('browser')

import 'package:pdfjs/src/display/svg_factory.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  group('DOMSVGFactory', () {
    final factory = DOMSVGFactory();

    test('create rejects invalid dimensions', () {
      expect(() => factory.create(-1, 1), throwsArgumentError);
      expect(() => factory.create(1, -1), throwsArgumentError);
      expect(() => factory.create(0, 1), throwsArgumentError);
      expect(() => factory.create(1, 0), throwsArgumentError);
    });

    test('create returns a configured SVG element', () {
      final svg = factory.create(20, 40);

      expect(svg, isA<web.SVGSVGElement>());
      expect(svg.getAttribute('version'), '1.1');
      expect(svg.getAttribute('width'), '20px');
      expect(svg.getAttribute('height'), '40px');
      expect(svg.getAttribute('preserveAspectRatio'), 'none');
      expect(svg.getAttribute('viewBox'), '0 0 20 40');
    });

    test('create can omit physical dimensions', () {
      final svg = factory.create(20, 40, skipDimensions: true);

      expect(svg.getAttribute('width'), isNull);
      expect(svg.getAttribute('height'), isNull);
      expect(svg.getAttribute('viewBox'), '0 0 20 40');
    });

    test('createElement returns the requested SVG element type', () {
      final rect = factory.createElement('svg:rect');

      expect(rect, isA<web.SVGRectElement>());
      expect(rect.namespaceURI, 'http://www.w3.org/2000/svg');
    });
  });
}
