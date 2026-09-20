// Copyright 2013 Rob Wu <rob@robwu.nl>
// Licensed under the Apache License, Version 2.0.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

const String grabToPanGrabClass = 'grab-to-pan-grab';
const String grabToPanGrabbingClass = 'grab-to-pan-grabbing';

/// Adds mouse-driven panning to a scrollable HTML element.
///
/// This is the Dart counterpart of PDF.js' `GrabToPan`. Listener references
/// are retained explicitly so activation, a pending drag, and disposal all
/// have deterministic lifecycles.
class GrabToPan {
  GrabToPan({required this.element})
      : document = element.ownerDocument!,
        overlay =
            element.ownerDocument!.createElement('div') as web.HTMLDivElement {
    overlay.className = grabToPanGrabbingClass;
    _mouseDownListener = _onMouseDown.toJS;
    _mouseMoveListener = _onMouseMove.toJS;
    _mouseUpListener = _onMouseUp.toJS;
    _scrollListener = _onScroll.toJS;
  }

  final web.HTMLElement element;
  final web.Document document;
  final web.HTMLDivElement overlay;

  late final web.EventListener _mouseDownListener;
  late final web.EventListener _mouseMoveListener;
  late final web.EventListener _mouseUpListener;
  late final web.EventListener _scrollListener;

  bool _active = false;
  bool _panning = false;
  bool _watchingScroll = false;
  double scrollLeftStart = 0;
  double scrollTopStart = 0;
  int clientXStart = 0;
  int clientYStart = 0;

  bool get active => _active;
  bool get panning => _panning;

  /// Binds grab detection. Repeated calls are intentionally idempotent.
  void activate() {
    if (_active) return;
    _active = true;
    element.addEventListener(
      'mousedown',
      _mouseDownListener,
      web.AddEventListenerOptions(capture: true),
    );
    element.classList.add(grabToPanGrabClass);
  }

  /// Removes all listeners and immediately terminates a pending pan.
  void deactivate() {
    if (!_active) return;
    _active = false;
    element.removeEventListener(
      'mousedown',
      _mouseDownListener,
      web.EventListenerOptions(capture: true),
    );
    _endPan();
    element.classList.remove(grabToPanGrabClass);
  }

  void toggle() => _active ? deactivate() : activate();

  /// Returns whether a click target must retain its normal browser behavior.
  ///
  /// Links and form controls, including descendants of buttons and links, are
  /// excluded from grab handling just like in the upstream viewer.
  bool ignoreTarget(web.Element node) => node.matches(
        'a[href], a[href] *, input, textarea, button, button *, select, option',
      );

  void _onMouseDown(web.Event rawEvent) {
    final event = rawEvent as web.MouseEvent;
    final target = event.target;
    if (event.button != 0 || target is! web.Element || ignoreTarget(target)) {
      return;
    }

    scrollLeftStart = element.scrollLeft;
    scrollTopStart = element.scrollTop;
    clientXStart = event.clientX;
    clientYStart = event.clientY;

    _endPan();
    _panning = true;
    document.addEventListener(
      'mousemove',
      _mouseMoveListener,
      web.AddEventListenerOptions(capture: true),
    );
    document.addEventListener(
      'mouseup',
      _mouseUpListener,
      web.AddEventListenerOptions(capture: true),
    );
    _watchingScroll = true;
    element.addEventListener(
      'scroll',
      _scrollListener,
      web.AddEventListenerOptions(capture: true),
    );

    event
      ..preventDefault()
      ..stopPropagation();

    final focused = document.activeElement;
    if (focused is web.HTMLElement && !focused.contains(target)) {
      focused.blur();
    }
  }

  void _onMouseMove(web.Event rawEvent) {
    if (!_panning) return;
    final event = rawEvent as web.MouseEvent;
    _stopWatchingScroll();

    if ((event.buttons & 1) == 0) {
      _endPan();
      return;
    }
    final xDiff = event.clientX - clientXStart;
    final yDiff = event.clientY - clientYStart;
    element.scrollTo(
      web.ScrollToOptions(
        top: scrollTopStart - yDiff,
        left: scrollLeftStart - xDiff,
        behavior: 'instant',
      ),
    );

    if (overlay.parentNode == null) {
      document.body?.append(overlay);
    }
  }

  void _onMouseUp(web.Event _) => _endPan();

  void _onScroll(web.Event _) => _endPan();

  void _stopWatchingScroll() {
    if (!_watchingScroll) return;
    _watchingScroll = false;
    element.removeEventListener(
      'scroll',
      _scrollListener,
      web.EventListenerOptions(capture: true),
    );
  }

  void _endPan() {
    if (_panning) {
      document.removeEventListener(
        'mousemove',
        _mouseMoveListener,
        web.EventListenerOptions(capture: true),
      );
      document.removeEventListener(
        'mouseup',
        _mouseUpListener,
        web.EventListenerOptions(capture: true),
      );
      _panning = false;
    }
    _stopWatchingScroll();
    overlay.remove();
  }

  void dispose() => deactivate();
}
