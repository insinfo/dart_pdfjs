// Copyright 2022 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.
// Ported from pdf.js/web/draw_layer_builder.js.

import 'package:pdfjs/src/display/draw_layer.dart';
import 'package:web/web.dart' as web;

/// Owns the drawing overlay used by annotation editors.
final class DrawLayerBuilder {
  DrawLayer? _drawLayer;
  bool _cancelled = false;

  bool get cancelled => _cancelled;

  Future<void> render({String intent = 'display'}) async {
    if (intent != 'display' || _drawLayer != null || _cancelled) return;
    _drawLayer = DrawLayer();
  }

  void cancel() {
    _cancelled = true;
    _drawLayer?.destroy();
    _drawLayer = null;
  }

  void setParent(web.Element parent) => _drawLayer?.setParent(parent);

  DrawLayer? getDrawLayer() => _drawLayer;
}
