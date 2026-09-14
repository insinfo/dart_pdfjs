// Copyright 2015 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:web/web.dart' as web;

/// A canvas-and-context pair.
class CanvasAndContext {
  web.HTMLCanvasElement? canvas;
  web.CanvasRenderingContext2D? context;

  CanvasAndContext({this.canvas, this.context});
}

/// Base class for canvas factories.
/// Subclasses must implement [createCanvasElement].
abstract class BaseCanvasFactory {
  final bool _enableHWA;

  BaseCanvasFactory({bool enableHWA = false}) : _enableHWA = enableHWA;

  /// Create a new canvas with the given dimensions.
  CanvasAndContext create(int width, int height) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Invalid canvas size');
    }
    final canvas = createCanvasElement(width, height);
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    return CanvasAndContext(canvas: canvas, context: ctx);
  }

  /// Reset an existing canvas to new dimensions.
  void reset(CanvasAndContext canvasAndContext, int width, int height) {
    final canvas = canvasAndContext.canvas;
    if (canvas == null) {
      throw StateError('Canvas is not specified');
    }
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Invalid canvas size');
    }
    canvas.width = width;
    canvas.height = height;
  }

  /// Destroy a canvas, releasing resources.
  void destroy(CanvasAndContext canvasAndContext) {
    final canvas = canvasAndContext.canvas;
    if (canvas == null) {
      throw StateError('Canvas is not specified');
    }
    canvas.width = 0;
    canvas.height = 0;
    canvasAndContext.canvas = null;
    canvasAndContext.context = null;
  }

  /// Abstract method to create a canvas element.
  web.HTMLCanvasElement createCanvasElement(int width, int height);
}

/// DOM-based canvas factory that creates canvas elements using the web package.
class DOMCanvasFactory extends BaseCanvasFactory {
  DOMCanvasFactory({bool enableHWA = false}) : super(enableHWA: enableHWA);

  @override
  web.HTMLCanvasElement createCanvasElement(int width, int height) {
    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = width;
    canvas.height = height;
    return canvas;
  }
}
