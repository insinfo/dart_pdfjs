// Copyright 2022 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.
// Ported from pdf.js/web/annotation_editor_layer_builder.js.

import 'package:pdfjs/src/display/annotation_layer.dart';
import 'package:pdfjs/src/display/display_utils.dart';
import 'package:pdfjs/src/display/draw_layer.dart';
import 'package:web/web.dart' as web;

import 'l10n.dart';
import 'struct_tree_layer_builder.dart';
import 'text_accessibility.dart';

/// A concrete editor item owned by the page editor layer.
abstract interface class AnnotationEditor {
  String get id;
  web.HTMLElement render();
  void update(PageViewport viewport);
  void destroy();
}

/// Typed integration surface supplied by the application editor manager.
abstract interface class AnnotationEditorUIManager {
  String get direction;
  bool get isVisible;
  Iterable<AnnotationEditor> editorsForPage(int pageIndex);
  void attachLayer(int pageIndex, AnnotationEditorLayer layer);
  void detachLayer(int pageIndex, AnnotationEditorLayer layer);
}

/// Browser implementation of an editable annotation overlay.
final class AnnotationEditorLayer {
  AnnotationEditorLayer({
    required this.uiManager,
    required this.div,
    required this.pageIndex,
    required this.viewport,
    this.structTreeLayer,
    this.accessibilityManager,
    this.l10n,
    this.annotationLayer,
    this.textLayer,
    this.drawLayer,
  });

  final AnnotationEditorUIManager uiManager;
  final web.HTMLDivElement div;
  final StructTreeLayerBuilder? structTreeLayer;
  final TextAccessibilityManager? accessibilityManager;
  final L10n? l10n;
  final AnnotationLayer? annotationLayer;
  final web.HTMLElement? textLayer;
  final DrawLayer? drawLayer;
  int pageIndex;
  PageViewport viewport;
  final List<(AnnotationEditor, web.HTMLElement)> _editors = [];
  bool _destroyed = false;
  bool _paused = false;

  bool get isInvisible => !uiManager.isVisible;
  bool get paused => _paused;
  bool get destroyed => _destroyed;

  Future<void> render() async {
    if (_destroyed) throw StateError('Annotation editor layer is destroyed.');
    _applyViewport();
    drawLayer?.setParent(div);
    uiManager.attachLayer(pageIndex, this);
    for (final editor in uiManager.editorsForPage(pageIndex)) {
      final element = editor.render();
      if (element.id.isEmpty) element.id = editor.id;
      div.append(element);
      _editors.add((editor, element));
      accessibilityManager?.addPointerInTextLayer(
        element,
        isRemovable: false,
      );
      await l10n?.translateOnce(element);
    }
    structTreeLayer?.updateTextLayer();
  }

  void update({required PageViewport viewport}) {
    if (_destroyed) return;
    this.viewport = viewport;
    _applyViewport();
    for (final (editor, _) in _editors) {
      editor.update(viewport);
    }
  }

  void updatePageIndex(int pageIndex) {
    if (_destroyed || pageIndex == this.pageIndex) return;
    uiManager.detachLayer(this.pageIndex, this);
    this.pageIndex = pageIndex;
    uiManager.attachLayer(pageIndex, this);
  }

  void pause(bool on) {
    if (_destroyed || _paused == on) return;
    _paused = on;
    if (on) {
      div.setAttribute('inert', '');
    } else {
      div.removeAttribute('inert');
    }
  }

  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    uiManager.detachLayer(pageIndex, this);
    for (final (editor, element) in _editors) {
      accessibilityManager?.removePointerInTextLayer(element);
      editor.destroy();
    }
    _editors.clear();
    drawLayer?.destroy();
    div.textContent = '';
  }

  void _applyViewport() {
    div.style
      ..width = '${viewport.width}px'
      ..height = '${viewport.height}px'
      ..transform = 'matrix(${viewport.transform.join(',')})';
    div.setAttribute('data-main-rotation', '${viewport.rotation}');
  }
}

typedef AnnotationEditorLayerAppended = void Function(
  web.HTMLDivElement element,
);

/// Creates, updates, pauses and destroys the editor layer for one PDF page.
final class AnnotationEditorLayerBuilder {
  AnnotationEditorLayerBuilder({
    required AnnotationEditorUIManager uiManager,
    required this.pageIndex,
    this.l10n,
    this.structTreeLayer,
    this.accessibilityManager,
    this.annotationLayer,
    this.textLayer,
    this.drawLayer,
    this.onAppend,
  }) : _uiManager = uiManager;

  final AnnotationEditorUIManager _uiManager;
  int pageIndex;
  final L10n? l10n;
  final StructTreeLayerBuilder? structTreeLayer;
  final TextAccessibilityManager? accessibilityManager;
  final AnnotationLayer? annotationLayer;
  final web.HTMLElement? textLayer;
  final DrawLayer? drawLayer;
  final AnnotationEditorLayerAppended? onAppend;
  AnnotationEditorLayer? annotationEditorLayer;
  web.HTMLDivElement? div;
  bool _cancelled = false;

  bool get cancelled => _cancelled;

  void updatePageIndex(int newPageIndex) {
    pageIndex = newPageIndex;
    annotationEditorLayer?.updatePageIndex(newPageIndex);
  }

  Future<void> render({
    required PageViewport viewport,
    String intent = 'display',
  }) async {
    if (intent != 'display' || _cancelled) return;
    final clonedViewport = viewport.clone(dontFlip: true);
    final current = div;
    if (current != null) {
      annotationEditorLayer?.update(viewport: clonedViewport);
      show();
      return;
    }
    final container = web.document.createElement('div') as web.HTMLDivElement;
    container
      ..className = 'annotationEditorLayer'
      ..setAttribute('hidden', '')
      ..dir = _uiManager.direction;
    div = container;
    onAppend?.call(container);
    final layer = AnnotationEditorLayer(
      uiManager: _uiManager,
      div: container,
      structTreeLayer: structTreeLayer,
      accessibilityManager: accessibilityManager,
      pageIndex: pageIndex,
      l10n: l10n,
      viewport: clonedViewport,
      annotationLayer: annotationLayer,
      textLayer: textLayer,
      drawLayer: drawLayer,
    );
    annotationEditorLayer = layer;
    await layer.render();
    if (_cancelled) {
      layer.destroy();
      return;
    }
    show();
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    annotationEditorLayer?.destroy();
  }

  void hide() {
    final container = div;
    if (container == null) return;
    annotationEditorLayer?.pause(true);
    container.setAttribute('hidden', '');
  }

  void show() {
    final container = div;
    final layer = annotationEditorLayer;
    if (container == null || layer == null || layer.isInvisible) return;
    container.removeAttribute('hidden');
    layer.pause(false);
  }
}
