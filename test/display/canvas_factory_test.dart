// Copyright 2026. Apache License 2.0.

@TestOn('browser')

import 'package:pdfjs/src/display/canvas_factory.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

class _TestCanvasFactory extends BaseCanvasFactory {
  _TestCanvasFactory({super.enableHWA});

  @override
  web.HTMLCanvasElement createCanvasElement(int width, int height) {
    throw UnsupportedError('A DOM canvas is not needed by these tests.');
  }
}

void main() {
  group('BaseCanvasFactory', () {
    test('create rejects invalid dimensions before creating a canvas', () {
      final factory = _TestCanvasFactory();

      expect(() => factory.create(-1, 1), throwsArgumentError);
      expect(() => factory.create(1, -1), throwsArgumentError);
      expect(() => factory.create(0, 1), throwsArgumentError);
      expect(() => factory.create(1, 0), throwsArgumentError);
    });

    test('reset validates the canvas and dimensions', () {
      final factory = _TestCanvasFactory();
      final empty = CanvasAndContext();

      expect(() => factory.reset(empty, 20, 40), throwsStateError);
    });

    test('destroy rejects an absent canvas', () {
      final factory = _TestCanvasFactory();

      expect(() => factory.destroy(CanvasAndContext()), throwsStateError);
    });

    test('preserves the hardware acceleration preference', () {
      expect(_TestCanvasFactory().enableHWA, isFalse);
      expect(_TestCanvasFactory(enableHWA: true).enableHWA, isTrue);
    });
  });

  group('DOMCanvasFactory', () {
    test('creates a canvas and 2D context with the requested dimensions', () {
      final result = DOMCanvasFactory().create(20, 40);

      expect(result.canvas, isA<web.HTMLCanvasElement>());
      expect(result.context, isA<web.CanvasRenderingContext2D>());
      expect(result.canvas!.width, 20);
      expect(result.canvas!.height, 40);
    });

    test('resets canvas dimensions while preserving its context', () {
      final factory = DOMCanvasFactory();
      final result = factory.create(20, 40);
      final context = result.context;

      factory.reset(result, 60, 80);

      expect(result.canvas!.width, 60);
      expect(result.canvas!.height, 80);
      expect(result.context, same(context));
    });

    test('destroys the canvas and releases both references', () {
      final factory = DOMCanvasFactory();
      final result = factory.create(20, 40);

      factory.destroy(result);

      expect(result.canvas, isNull);
      expect(result.context, isNull);
    });
  });
}
