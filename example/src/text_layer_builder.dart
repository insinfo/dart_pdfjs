// Copyright 2012 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.
// Ported from pdf.js/web/text_layer_builder.js.

import 'dart:js_interop';

import 'package:pdfjs/src/display/display_utils.dart';
import 'package:pdfjs/src/display/text_layer.dart';
import 'package:pdfjs/src/display/text_layer_images.dart';
import 'package:web/web.dart' as web;

import 'layer_page_adapter.dart';
import 'ui_utils.dart';

abstract interface class TextHighlighterController {
  void setTextMapping(
    List<web.Node> textDivs,
    List<String> textContentItems,
  );
  void enable();
  void disable();
}

abstract interface class TextAccessibilityController {
  void setTextMapping(List<web.HTMLElement> textDivs);
  void enable();
  void disable();
}

typedef TextLayerAppended = void Function(web.HTMLDivElement element);

/// Builds the selectable text overlay and maintains selection ergonomics.
final class TextLayerBuilder {
  TextLayerBuilder({
    required this.pdfPage,
    this.highlighter,
    this.accessibilityManager,
    this.enablePermissions = false,
    this.onAppend,
    this.abortSignal,
  }) {
    div = web.document.createElement('div') as web.HTMLDivElement;
    div
      ..tabIndex = 0
      ..className = 'textLayer';
  }

  final LayerPage pdfPage;
  final TextHighlighterController? highlighter;
  final TextAccessibilityController? accessibilityManager;
  final bool enablePermissions;
  final TextLayerAppended? onAppend;
  final web.AbortSignal? abortSignal;
  late final web.HTMLDivElement div;

  TextLayer? _textLayer;
  bool _renderingDone = false;
  final List<(web.EventTarget, String, web.EventListener)> _listeners = [];

  static final Map<web.HTMLDivElement, web.HTMLDivElement> _textLayers = {};
  static final List<(web.EventTarget, String, web.EventListener)>
      _globalListeners = [];
  static bool _pointerDown = false;

  bool get renderingDone => _renderingDone;
  List<web.HTMLElement> get textDivs => _textLayer?.textDivs ?? const [];
  List<String> get textContentItemsStr =>
      _textLayer?.textContentItemsStr ?? const [];

  Future<void> render({
    required PageViewport viewport,
    TextLayerImages? images,
    Map<String, dynamic>? textContentParams,
  }) async {
    if (_renderingDone && _textLayer != null) {
      _textLayer!.update(viewport: viewport, onBefore: hide);
      show();
      return;
    }
    cancel();
    final params = textContentParams ?? const <String, dynamic>{};
    final content = await pdfPage.getTextContent(
      includeMarkedContent: params['includeMarkedContent'] != false,
      disableNormalization: params['disableNormalization'] != false,
    );
    if (abortSignal?.aborted == true) return;

    final layer = TextLayer(
      textContentSource: content,
      images: images,
      container: div,
      viewport: viewport,
    );
    _textLayer = layer;
    highlighter?.setTextMapping(layer.textDivs, layer.textContentItemsStr);
    accessibilityManager?.setTextMapping(layer.textDivs);
    await layer.render();
    if (!identical(_textLayer, layer)) return;
    _renderingDone = true;

    // Mapping lists are populated by render in the Dart display layer.
    highlighter?.setTextMapping(layer.textDivs, layer.textContentItemsStr);
    accessibilityManager?.setTextMapping(layer.textDivs);
    final end = web.document.createElement('div') as web.HTMLDivElement;
    end.className = 'endOfContent';
    div.append(end);
    _bindMouse(end);
    onAppend?.call(div);
    highlighter?.enable();
    accessibilityManager?.enable();
  }

  void hide() {
    if (!div.hasAttribute('hidden') && _renderingDone) {
      highlighter?.disable();
      div.setAttribute('hidden', '');
    }
  }

  void show() {
    if (div.hasAttribute('hidden') && _renderingDone) {
      div.removeAttribute('hidden');
      highlighter?.enable();
    }
  }

  void cancel() {
    _textLayer?.cancel();
    _textLayer = null;
    highlighter?.disable();
    accessibilityManager?.disable();
    _removeListeners();
    _removeGlobalSelectionListener(div);
  }

  void _bindMouse(web.HTMLDivElement end) {
    _listen(div, 'mousedown', (_) => div.classList.add('selecting'));
    _listen(div, 'copy', (web.Event event) {
      if (!enablePermissions && event is web.ClipboardEvent) {
        final selected = web.document.getSelection()?.toString() ?? '';
        event.clipboardData?.setData(
          'text/plain',
          removeNullCharacters(selected),
        );
      }
      event
        ..preventDefault()
        ..stopPropagation();
    });
    _textLayers[div] = end;
    _enableGlobalSelectionListener();
  }

  void _listen(
    web.EventTarget target,
    String type,
    void Function(web.Event) callback,
  ) {
    final listener = callback.toJS;
    target.addEventListener(type, listener);
    _listeners.add((target, type, listener));
  }

  void _removeListeners() {
    for (final (target, type, listener) in _listeners) {
      target.removeEventListener(type, listener);
    }
    _listeners.clear();
  }

  static void _reset(web.HTMLDivElement end, web.HTMLDivElement layer) {
    layer.append(end);
    end.style
      ..width = ''
      ..height = ''
      ..userSelect = '';
    layer.classList.remove('selecting');
  }

  static void _removeGlobalSelectionListener(web.HTMLDivElement layer) {
    _textLayers.remove(layer);
    if (_textLayers.isNotEmpty) return;
    for (final (target, type, listener) in _globalListeners) {
      target.removeEventListener(type, listener);
    }
    _globalListeners.clear();
    _pointerDown = false;
  }

  static void _globalListen(
    web.EventTarget target,
    String type,
    void Function(web.Event) callback,
  ) {
    final listener = callback.toJS;
    target.addEventListener(type, listener);
    _globalListeners.add((target, type, listener));
  }

  static void _enableGlobalSelectionListener() {
    if (_globalListeners.isNotEmpty) return;
    _globalListen(web.document, 'pointerdown', (_) => _pointerDown = true);
    _globalListen(web.document, 'pointerup', (_) {
      _pointerDown = false;
      _textLayers.forEach((layer, end) => _reset(end, layer));
    });
    _globalListen(web.window, 'blur', (_) {
      _pointerDown = false;
      _textLayers.forEach((layer, end) => _reset(end, layer));
    });
    _globalListen(web.document, 'keyup', (_) {
      if (!_pointerDown) {
        _textLayers.forEach((layer, end) => _reset(end, layer));
      }
    });
    _globalListen(web.document, 'selectionchange', (_) {
      final selection = web.document.getSelection();
      if (selection == null || selection.rangeCount == 0) {
        _textLayers.forEach((layer, end) => _reset(end, layer));
        return;
      }
      final active = <web.HTMLDivElement>{};
      for (var rangeIndex = 0;
          rangeIndex < selection.rangeCount;
          rangeIndex++) {
        final range = selection.getRangeAt(rangeIndex);
        for (final layer in _textLayers.keys) {
          try {
            if (range.intersectsNode(layer)) active.add(layer);
          } catch (_) {
            // A detached layer cannot intersect the live selection.
          }
        }
      }
      _textLayers.forEach((layer, end) {
        if (active.contains(layer)) {
          layer.classList.add('selecting');
        } else {
          _reset(end, layer);
        }
      });
    });
  }
}
