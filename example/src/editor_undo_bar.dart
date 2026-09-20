// Copyright 2024 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'event_utils.dart';

/// Displays the transient undo notification used by annotation editors.
class EditorUndoBar {
  EditorUndoBar({
    required this.container,
    required this.message,
    required this.undoButton,
    required this.closeButton,
    required this.eventBus,
  });

  static const Map<String, String> _l10nMessages = {
    'highlight': 'pdfjs-editor-undo-bar-message-highlight',
    'freetext': 'pdfjs-editor-undo-bar-message-freetext',
    'stamp': 'pdfjs-editor-undo-bar-message-stamp',
    'ink': 'pdfjs-editor-undo-bar-message-ink',
    'signature': 'pdfjs-editor-undo-bar-message-signature',
    'comment': 'pdfjs-editor-undo-bar-message-comment',
    '_multiple': 'pdfjs-editor-undo-bar-message-multiple',
  };

  final web.HTMLElement container;
  final web.HTMLElement message;
  final web.HTMLButtonElement undoButton;
  final web.HTMLButtonElement closeButton;
  final EventBus eventBus;

  web.AbortController? _initController;
  web.AbortController? _showController;
  Timer? _focusTimer;
  bool isOpen = false;

  void show(void Function() undoAction, Object messageData) {
    _initializeOnce();
    hide();

    if (messageData is String) {
      message.setAttribute('data-l10n-id', _l10nMessages[messageData] ?? '');
      message.removeAttribute('data-l10n-args');
    } else if (messageData is num) {
      message.setAttribute('data-l10n-id', _l10nMessages['_multiple']!);
      message.setAttribute(
        'data-l10n-args',
        jsonEncode({'count': messageData}),
      );
    } else {
      throw ArgumentError.value(messageData, 'messageData');
    }

    isOpen = true;
    container.hidden = false.toJS;
    final controller = web.AbortController();
    _showController = controller;
    undoButton.addEventListener(
      'click',
      ((web.Event _) {
        undoAction();
        hide();
      }).toJS,
      web.AddEventListenerOptions(signal: controller.signal),
    );

    _focusTimer = Timer(const Duration(milliseconds: 100), () {
      if (!container.contains(web.document.activeElement)) container.focus();
      _focusTimer = null;
    });
  }

  void _initializeOnce() {
    if (_initController != null) return;
    final controller = web.AbortController();
    _initController = controller;
    final options = web.AddEventListenerOptions(signal: controller.signal);
    container.addEventListener(
      'contextmenu',
      ((web.Event event) => event.preventDefault()).toJS,
      options,
    );
    closeButton.addEventListener(
      'click',
      ((web.Event _) => hide()).toJS,
      options,
    );
    eventBus.internalOn('beforeprint', (_) => hide(),
        signal: controller.signal);
    eventBus.internalOn('download', (_) => hide(), signal: controller.signal);
  }

  void hide() {
    if (!isOpen) return;
    isOpen = false;
    container.hidden = true.toJS;
    _showController?.abort();
    _showController = null;
    _focusTimer?.cancel();
    _focusTimer = null;
  }

  void destroy() {
    _initController?.abort();
    _initController = null;
    hide();
  }
}
