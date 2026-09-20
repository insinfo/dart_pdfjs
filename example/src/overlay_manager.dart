// Copyright 2014 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Coordinates modal dialogs used by the PDF viewer.
///
/// Only one registered dialog can be active at a time. A dialog registered
/// with [canForceClose] may replace the current overlay when it opens.
class OverlayManager {
  final Map<web.HTMLDialogElement, _OverlayRegistration> _overlays =
      Map.identity();
  final Map<web.HTMLDialogElement, JSFunction> _cancelListeners =
      Map.identity();

  web.HTMLDialogElement? _active;

  web.HTMLDialogElement? get active => _active;

  /// Registers [dialog] with this manager.
  Future<void> register(
    web.HTMLDialogElement dialog, {
    bool canForceClose = false,
  }) async {
    if (_overlays.containsKey(dialog)) {
      throw StateError('The overlay is already registered.');
    }
    _overlays[dialog] = _OverlayRegistration(canForceClose: canForceClose);
    final listener = ((web.Event event) {
      if (identical(_active, event.target)) {
        _active = null;
      }
    }).toJS;
    _cancelListeners[dialog] = listener;
    dialog.addEventListener('cancel', listener);
  }

  /// Opens a previously registered [dialog].
  Future<void> open(web.HTMLDialogElement dialog) async {
    final registration = _overlays[dialog];
    if (registration == null) {
      throw StateError('The overlay does not exist.');
    }
    final active = _active;
    if (active != null) {
      if (identical(active, dialog)) {
        throw StateError('The overlay is already active.');
      }
      if (registration.canForceClose) {
        await close();
      } else {
        throw StateError('Another overlay is currently active.');
      }
    }
    _active = dialog;
    dialog.showModal();
  }

  /// Closes [dialog], or the active dialog when omitted.
  Future<void> close([web.HTMLDialogElement? dialog]) async {
    dialog ??= _active;
    if (dialog == null || !_overlays.containsKey(dialog)) {
      throw StateError('The overlay does not exist.');
    }
    if (_active == null) {
      throw StateError('The overlay is currently not active.');
    }
    if (!identical(_active, dialog)) {
      throw StateError('Another overlay is currently active.');
    }
    dialog.close();
    _active = null;
  }

  /// Closes [dialog] only when it is currently active.
  Future<void> closeIfActive(web.HTMLDialogElement dialog) async {
    if (identical(_active, dialog)) {
      await close(dialog);
    }
  }

  /// Releases listeners owned by this manager.
  ///
  /// This lifecycle helper is Dart-specific; the viewer keeps one manager for
  /// its entire lifetime, while tests and embedded viewers may be short-lived.
  Future<void> dispose() async {
    for (final entry in _cancelListeners.entries) {
      entry.key.removeEventListener('cancel', entry.value);
    }
    _cancelListeners.clear();
    _overlays.clear();
    _active = null;
  }
}

class _OverlayRegistration {
  final bool canForceClose;

  const _OverlayRegistration({required this.canForceClose});
}
