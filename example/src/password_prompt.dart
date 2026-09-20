// Copyright 2012 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:async';
import 'dart:js_interop';

import 'package:pdfjs/src/shared/util.dart' show PasswordResponses;
import 'package:web/web.dart' as web;

import 'overlay_manager.dart';

typedef PasswordUpdateCallback = void Function(Object passwordOrError);

/// Modal prompt that passes either a password or a cancellation error to the
/// loading task callback.
class PasswordPrompt {
  PasswordPrompt({
    required this.dialog,
    required this.label,
    required this.input,
    required this.submitButton,
    required this.cancelButton,
    required this.overlayManager,
    bool isViewerEmbedded = false,
  }) : _isViewerEmbedded = isViewerEmbedded {
    submitButton.addEventListener(
      'click',
      ((web.Event _) => _verify()).toJS,
    );
    cancelButton.addEventListener(
      'click',
      ((web.Event _) => _cancel()).toJS,
    );
    input.addEventListener(
      'keydown',
      ((web.Event event) {
        if ((event as web.KeyboardEvent).keyCode == 13) _verify();
      }).toJS,
    );
    unawaited(overlayManager.register(dialog, canForceClose: true));
    dialog.addEventListener(
      'close',
      ((web.Event _) => _cancel()).toJS,
    );
  }

  final web.HTMLDialogElement dialog;
  final web.HTMLParagraphElement label;
  final web.HTMLInputElement input;
  final web.HTMLButtonElement submitButton;
  final web.HTMLButtonElement cancelButton;
  final OverlayManager overlayManager;
  final bool _isViewerEmbedded;

  Completer<void>? _activeCompleter;
  PasswordUpdateCallback? _updateCallback;
  int? _reason;

  Future<void> open() async {
    await _activeCompleter?.future;
    final activeCompleter = Completer<void>();
    _activeCompleter = activeCompleter;
    try {
      await overlayManager.open(dialog);
    } catch (_) {
      activeCompleter.complete();
      rethrow;
    }

    final incorrect = _reason == PasswordResponses.incorrectPassword;
    if (!_isViewerEmbedded || incorrect) {
      input.focus();
    }
    label.setAttribute(
      'data-l10n-id',
      incorrect ? 'pdfjs-password-invalid' : 'pdfjs-password-label',
    );
  }

  Future<void> close() => overlayManager.closeIfActive(dialog);

  void _verify() {
    if (input.value.isNotEmpty) _invokeCallback(input.value);
  }

  void _cancel() {
    _invokeCallback(StateError('PasswordPrompt cancelled.'));
    final completer = _activeCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _invokeCallback(Object passwordOrError) {
    final callback = _updateCallback;
    if (callback == null) return;
    _updateCallback = null;
    unawaited(close());
    input.value = '';
    callback(passwordOrError);
  }

  Future<void> setUpdateCallback(
    PasswordUpdateCallback updateCallback,
    int reason,
  ) async {
    await _activeCompleter?.future;
    _updateCallback = updateCallback;
    _reason = reason;
  }
}
