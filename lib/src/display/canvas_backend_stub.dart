// Copyright 2026. Apache License 2.0.

import 'api.dart';

/// Placeholder exported on platforms without browser Canvas support.
class CanvasPageRenderer implements PDFPageRenderer {
  CanvasPageRenderer(dynamic context) {
    throw UnsupportedError('CanvasPageRenderer requires a browser build.');
  }

  @override
  void cancel([dynamic reason]) {}

  @override
  void render(dynamic operatorList, RenderParameters parameters) {}
}

PDFPageRenderer createCanvasPageRenderer(RenderParameters parameters) {
  throw UnsupportedError('PDF canvas rendering requires a browser build.');
}
