// Copyright 2026. Apache License 2.0.

@TestOn('browser')

import 'package:pdfjs/src/display/text_layer_images.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  group('TextLayerImages', () {
    test('renders placeholders with normalized position and dimensions', () {
      final layer = TextLayerImages(
        minSize: 10,
        coordinates: [0.1, 0.2, 0.1, 0.7, 0.6, 0.2],
        viewport: {
          'rawDims': {'pageWidth': 200.0, 'pageHeight': 100.0},
        },
      );

      final container = layer.render();
      final canvas = container.firstElementChild! as web.HTMLCanvasElement;

      expect(container.className, 'textLayerImages');
      expect(canvas.className, 'textLayerImagePlaceholder');
      expect(canvas.style.left, '10%');
      expect(canvas.style.top, '20%');
      expect(canvas.style.width, '50%');
      expect(canvas.style.height, '50%');
      expect(canvas.style.transform, 'matrix(1, 0, 0, 1, 0, 0)');
    });

    test('filters images smaller than the minimum size', () {
      final layer = TextLayerImages(
        minSize: 60,
        coordinates: [0.1, 0.2, 0.1, 0.7, 0.6, 0.2],
        viewport: {
          'rawDims': {'pageWidth': 200.0, 'pageHeight': 100.0},
        },
      );

      expect(layer.render().childElementCount, 0);
    });

    test('populates a placeholder on the contextmenu event', () {
      final pageCanvas =
          web.document.createElement('canvas') as web.HTMLCanvasElement;
      pageCanvas.width = 400;
      pageCanvas.height = 200;
      final layer = TextLayerImages(
        minSize: 10,
        coordinates: [0.1, 0.2, 0.1, 0.7, 0.6, 0.2],
        viewport: {
          'rawDims': {'pageWidth': 200.0, 'pageHeight': 100.0},
        },
        getPageCanvas: () => pageCanvas,
      );
      final container = layer.render();
      final placeholder = container.firstElementChild! as web.HTMLCanvasElement;

      placeholder.dispatchEvent(
        web.MouseEvent('contextmenu', web.MouseEventInit(bubbles: true)),
      );

      expect(placeholder.width, 200);
      expect(placeholder.height, 100);
    });
  });
}
