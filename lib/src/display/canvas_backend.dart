// Copyright 2026. Apache License 2.0.

import 'package:web/web.dart' as web;

import '../core/operator_list.dart';
import 'api.dart';
import 'canvas.dart';

/// Browser Canvas 2D implementation used by [PDFPageProxy.render].
class CanvasPageRenderer implements PDFPageRenderer {
  final CanvasGraphics graphics;
  bool _cancelled = false;

  CanvasPageRenderer(web.CanvasRenderingContext2D context)
      : graphics = CanvasGraphics(context);

  @override
  void render(OperatorList operatorList, RenderParameters parameters) {
    if (_cancelled) return;
    graphics.beginDrawing(
      transform: parameters.transform,
      viewportTransform: parameters.viewport.transform,
      background: parameters.background,
    );
    try {
      graphics.executeOperatorList(
        operatorList,
        operationsFilter: parameters.operationsFilter,
      );
    } finally {
      graphics.endDrawing();
    }
  }

  @override
  void cancel([dynamic reason]) {
    _cancelled = true;
  }
}

PDFPageRenderer createCanvasPageRenderer(RenderParameters parameters) {
  final context = parameters.canvasContext;
  if (context is! web.CanvasRenderingContext2D) {
    throw ArgumentError.value(
      context,
      'canvasContext',
      'must be a CanvasRenderingContext2D',
    );
  }
  return CanvasPageRenderer(context);
}
