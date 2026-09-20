// Copyright 2025 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const Duration sidebarResizeTimeout = Duration(milliseconds: 400);

final class SidebarElements {
  const SidebarElements({
    required this.sidebar,
    required this.resizer,
    required this.toggleButton,
  });
  final web.HTMLElement sidebar;
  final web.HTMLElement resizer;
  final web.HTMLElement toggleButton;
}

/// Resizable, keyboard-accessible sidebar foundation.
///
/// Subclasses may override the three lifecycle hooks to suspend expensive
/// rendering while the user drags the divider.
class Sidebar {
  Sidebar(
    SidebarElements elements, {
    required bool ltr,
    required bool isResizerOnTheLeft,
    web.AbortSignal? globalAbortSignal,
  })  : sidebar = elements.sidebar,
        _resizer = elements.resizer,
        _isResizerOnTheLeft = isResizerOnTheLeft,
        _coefficient = ltr == isResizerOnTheLeft ? -1 : 1 {
    final style = web.window.getComputedStyle(sidebar);
    _initialWidth = _width =
        double.tryParse(style.getPropertyValue('--sidebar-width')) ??
            sidebar.getBoundingClientRect().width;
    final min =
        double.tryParse(style.getPropertyValue('--sidebar-min-width')) ?? 0;
    final max =
        double.tryParse(style.getPropertyValue('--sidebar-max-width')) ??
            double.infinity;
    _resizer.setAttribute('aria-valuemin', '$min');
    _resizer.setAttribute('aria-valuemax', max.isFinite ? '$max' : 'Infinity');
    _resizer.setAttribute('aria-valuenow', '$_width');
    _makeSidebarResizable();
    elements.toggleButton
        .addEventListener('click', ((web.Event _) => toggle()).toJS);
    _isOpen = false;
    sidebar.hidden = true.toJS;
    globalAbortSignal?.addEventListener(
      'abort',
      ((web.Event _) => destroy()).toJS,
      web.AddEventListenerOptions(once: true),
    );
    _resizeObserver = web.ResizeObserver(
      ((JSArray<web.ResizeObserverEntry> _, web.ResizeObserver __) {
        final inlineSize = sidebar.getBoundingClientRect().width;
        if (!_prevX.isNaN) {
          _prevX += _coefficient * (inlineSize - _width);
        }
        _setWidth(inlineSize);
      }).toJS,
    )..observe(sidebar);
  }

  final web.HTMLElement sidebar;
  final web.HTMLElement _resizer;
  final bool _isResizerOnTheLeft;
  final int _coefficient;
  late double _initialWidth;
  late double _width;
  late web.ResizeObserver? _resizeObserver;
  Timer? _resizeTimer;
  web.AbortController? _pointerMoveController;
  bool _isKeyboardResizing = false;
  bool _isOpen = false;
  double _prevX = 0;
  bool _destroyed = false;

  double get width => _width;
  set width(double value) => sidebar.style.width = '${value}px';
  bool get isOpen => _isOpen;

  /// Updates open state for specialized sidebar controllers.
  void setOpenState(bool value) {
    _isOpen = value;
    sidebar.hidden = (!value).toJS;
  }

  void onStartResizing() {}
  void onStopResizing() {}
  void onResizing(double newWidth) {}

  void toggle([bool? visibility]) {
    _isOpen = visibility ?? !_isOpen;
    sidebar.hidden = (!_isOpen).toJS;
  }

  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    _resizeTimer?.cancel();
    _pointerMoveController?.abort();
    _pointerMoveController = null;
    _resizeObserver?.disconnect();
    _resizeObserver = null;
  }

  void _makeSidebarResizable() {
    _resizer.addEventListener(
        'pointerdown',
        ((web.Event rawEvent) {
          final event = rawEvent as web.PointerEvent;
          if (_pointerMoveController != null) {
            _cancelResize();
            return;
          }
          onStartResizing();
          _stopEvent(event);
          _prevX = event.clientX.toDouble();
          final controller = _pointerMoveController = web.AbortController();
          final signal = controller.signal;
          sidebar.classList.add('resizing');
          (sidebar.parentElement as web.HTMLElement?)?.style.minWidth = '0';
          web.window.addEventListener(
            'contextmenu',
            ((web.Event e) => e.preventDefault()).toJS,
            web.AddEventListenerOptions(signal: signal),
          );
          web.window.addEventListener(
              'pointermove',
              ((web.Event rawMove) {
                final move = rawMove as web.PointerEvent;
                if (_pointerMoveController == null ||
                    (move.clientX - _prevX).abs() < 1) return;
                _stopEvent(move);
                final newWidth =
                    (_width + _coefficient * (move.clientX - _prevX)).round();
                sidebar.style.width = '${newWidth}px';
              }).toJS,
              web.AddEventListenerOptions(signal: signal, capture: true));
          web.window.addEventListener(
            'blur',
            ((web.Event _) => _cancelResize()).toJS,
            web.AddEventListenerOptions(signal: signal),
          );
          web.window.addEventListener(
              'pointerup',
              ((web.Event rawUp) {
                if (_pointerMoveController != null) {
                  _cancelResize();
                  _stopEvent(rawUp);
                }
              }).toJS,
              web.AddEventListenerOptions(signal: signal));
        }).toJS);

    _resizer.addEventListener(
        'keydown',
        ((web.Event rawEvent) {
          final event = rawEvent as web.KeyboardEvent;
          final left = event.key == 'ArrowLeft';
          if (!left && event.key != 'ArrowRight') return;
          if (!_isKeyboardResizing) {
            sidebar.classList.add('resizing');
            _isKeyboardResizing = true;
            onStartResizing();
          }
          final base = event.ctrlKey || event.metaKey ? 10 : 1;
          final dx = base * (left ? -1 : 1);
          _resizeTimer?.cancel();
          _resizeTimer = Timer(sidebarResizeTimeout, _cancelResize);
          sidebar.style.width = '${(_width + _coefficient * dx).round()}px';
          _stopEvent(event);
        }).toJS);
  }

  void _cancelResize() {
    _resizeTimer?.cancel();
    _resizeTimer = null;
    sidebar.classList.remove('resizing');
    _pointerMoveController?.abort();
    _pointerMoveController = null;
    _isKeyboardResizing = false;
    onStopResizing();
    _prevX = double.nan;
  }

  void _setWidth(double newWidth) {
    if (!newWidth.isFinite) return;
    _width = newWidth;
    _resizer.setAttribute('aria-valuenow', '${newWidth.round()}');
    if (_isResizerOnTheLeft) {
      (sidebar.parentElement as web.HTMLElement?)?.style.insetInlineStart =
          '${(_initialWidth - newWidth).toStringAsFixed(3)}px';
    }
    onResizing(newWidth);
  }

  static void _stopEvent(web.Event event) {
    event
      ..preventDefault()
      ..stopPropagation();
  }
}
