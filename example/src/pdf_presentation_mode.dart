// Copyright 2012 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:pdfjs/src/shared/util.dart' show AnnotationEditorType;
import 'package:web/web.dart' as web;

import 'event_utils.dart';
import 'ui_utils.dart';

const Duration _controlsHideDelay = Duration(seconds: 3);
const String _activeClass = 'pdfPresentationMode';
const String _controlsClass = 'pdfPresentationModeControls';
const int _mouseScrollCooldownMilliseconds = 50;
const double _pageSwitchThreshold = 0.1;
const double _swipeMinDistanceThreshold = 50;
const double _swipeAngleThreshold = math.pi / 6;

/// Minimal contract used by presentation mode.
abstract interface class PDFPresentationViewer {
  int get pagesCount;
  int get currentPageNumber;
  set currentPageNumber(int value);
  String get currentScaleValue;
  set currentScaleValue(String value);
  int get scrollMode;
  set scrollMode(int value);
  int get spreadMode;
  set spreadMode(int value);
  bool get pageViewsReady;
  bool get hasEqualPageSizes;
  int get annotationEditorMode;
  set annotationEditorMode(int value);

  void focus();
  bool previousPage();
  bool nextPage();
}

/// Browser fullscreen boundary, injectable to keep presentation behavior
/// deterministic in browser tests and embedding applications.
abstract interface class PresentationFullscreen {
  bool get supported;
  bool get active;
  Future<void> request(web.HTMLElement element);
}

final class BrowserPresentationFullscreen implements PresentationFullscreen {
  const BrowserPresentationFullscreen();

  @override
  bool get supported => web.document.fullscreenEnabled;

  @override
  bool get active => web.document.fullscreenElement != null;

  @override
  Future<void> request(web.HTMLElement element) async {
    await element.requestFullscreen().toDart;
  }
}

final class _PresentationArguments {
  _PresentationArguments({
    required this.pageNumber,
    required this.scaleValue,
    required this.scrollMode,
    this.spreadMode,
    this.annotationEditorMode,
  });

  final int pageNumber;
  final String scaleValue;
  final int scrollMode;
  final int? spreadMode;
  final int? annotationEditorMode;
}

final class _TouchSwipeState {
  _TouchSwipeState(this.startX, this.startY)
      : endX = startX,
        endY = startY;

  final double startX;
  final double startY;
  double endX;
  double endY;
}

/// Controls full-screen presentation and restores all viewer state on exit.
class PDFPresentationMode {
  PDFPresentationMode({
    required this.container,
    required this.pdfViewer,
    required this.eventBus,
    PresentationFullscreen? fullscreen,
  }) : fullscreen = fullscreen ?? const BrowserPresentationFullscreen();

  final web.HTMLDivElement container;
  final PDFPresentationViewer pdfViewer;
  final EventBus eventBus;
  final PresentationFullscreen fullscreen;

  int _state = PresentationModeState.unknown;
  _PresentationArguments? _args;
  web.AbortController? _fullscreenChangeAbortController;
  web.AbortController? _windowAbortController;
  Timer? _controlsTimer;
  bool contextMenuOpen = false;
  int mouseScrollTimeStamp = 0;
  double mouseScrollDelta = 0;
  _TouchSwipeState? _touchSwipeState;

  int get state => _state;
  bool get active =>
      _state == PresentationModeState.changing ||
      _state == PresentationModeState.fullscreen;
  bool get controlsVisible => container.classList.contains(_controlsClass);

  /// Requests fullscreen and snapshots the state that must be restored.
  Future<bool> request() async {
    if (active || pdfViewer.pagesCount == 0 || !fullscreen.supported) {
      return false;
    }
    _addFullscreenChangeListeners();
    _notifyStateChange(PresentationModeState.changing);

    _args = _PresentationArguments(
      pageNumber: pdfViewer.currentPageNumber,
      scaleValue: pdfViewer.currentScaleValue,
      scrollMode: pdfViewer.scrollMode,
      spreadMode: pdfViewer.spreadMode != SpreadMode.none &&
              !(pdfViewer.pageViewsReady && pdfViewer.hasEqualPageSizes)
          ? pdfViewer.spreadMode
          : null,
      annotationEditorMode:
          pdfViewer.annotationEditorMode != AnnotationEditorType.disable
              ? pdfViewer.annotationEditorMode
              : null,
    );

    try {
      await fullscreen.request(container);
      pdfViewer.focus();
      return true;
    } catch (_) {
      _args = null;
      _removeFullscreenChangeListeners();
      _notifyStateChange(PresentationModeState.normal);
      return false;
    }
  }

  void _notifyStateChange(int state) {
    _state = state;
    eventBus.dispatch('presentationmodechanged', {
      'source': this,
      'state': state,
    });
  }

  void _enter() {
    final args = _args;
    if (args == null) return;
    _notifyStateChange(PresentationModeState.fullscreen);
    container.classList.add(_activeClass);

    scheduleMicrotask(() {
      if (_args == null) return;
      pdfViewer.scrollMode = ScrollMode.page;
      if (args.spreadMode != null) pdfViewer.spreadMode = SpreadMode.none;
      pdfViewer.currentPageNumber = args.pageNumber;
      pdfViewer.currentScaleValue = 'page-fit';
      if (args.annotationEditorMode != null) {
        pdfViewer.annotationEditorMode = AnnotationEditorType.none;
      }
    });

    _addWindowListeners();
    _showControls();
    contextMenuOpen = false;
    web.document.getSelection()?.removeAllRanges();
  }

  void _exit() {
    final args = _args;
    if (args == null) return;
    final pageNumber = pdfViewer.currentPageNumber;
    container.classList.remove(_activeClass);

    scheduleMicrotask(() {
      _removeFullscreenChangeListeners();
      _notifyStateChange(PresentationModeState.normal);
      pdfViewer.scrollMode = args.scrollMode;
      if (args.spreadMode != null) pdfViewer.spreadMode = args.spreadMode!;
      pdfViewer.currentScaleValue = args.scaleValue;
      pdfViewer.currentPageNumber = pageNumber;
      if (args.annotationEditorMode != null) {
        pdfViewer.annotationEditorMode = args.annotationEditorMode!;
      }
      _args = null;
    });

    _removeWindowListeners();
    _hideControls();
    _resetMouseScrollState();
    contextMenuOpen = false;
  }

  void _mouseWheel(web.WheelEvent event) {
    if (!active) return;
    event.preventDefault();
    handleWheelDelta(normalizeWheelEventDelta(event));
  }

  /// Applies an already normalized wheel delta. Public for non-DOM adapters.
  void handleWheelDelta(double delta, {int? timestamp}) {
    if (!active) return;
    final currentTime = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    if (currentTime > mouseScrollTimeStamp &&
        currentTime - mouseScrollTimeStamp < _mouseScrollCooldownMilliseconds) {
      return;
    }
    if ((mouseScrollDelta > 0 && delta < 0) ||
        (mouseScrollDelta < 0 && delta > 0)) {
      _resetMouseScrollState();
    }
    mouseScrollDelta += delta;
    if (mouseScrollDelta.abs() < _pageSwitchThreshold) return;

    final totalDelta = mouseScrollDelta;
    _resetMouseScrollState();
    final changed =
        totalDelta > 0 ? pdfViewer.previousPage() : pdfViewer.nextPage();
    if (changed) mouseScrollTimeStamp = currentTime;
  }

  void _mouseDown(web.MouseEvent event) {
    if (contextMenuOpen) {
      contextMenuOpen = false;
      event.preventDefault();
      return;
    }
    if (event.button != 0) return;
    final target = event.target;
    if (target is web.HTMLAnchorElement &&
        target.parentElement?.hasAttribute('data-internal-link') == true) {
      return;
    }
    event.preventDefault();
    if (event.shiftKey) {
      pdfViewer.previousPage();
    } else {
      pdfViewer.nextPage();
    }
  }

  void _showControls() {
    _controlsTimer?.cancel();
    container.classList.add(_controlsClass);
    _controlsTimer = Timer(_controlsHideDelay, () {
      container.classList.remove(_controlsClass);
      _controlsTimer = null;
    });
  }

  void _hideControls() {
    _controlsTimer?.cancel();
    _controlsTimer = null;
    container.classList.remove(_controlsClass);
  }

  void _resetMouseScrollState() {
    mouseScrollTimeStamp = 0;
    mouseScrollDelta = 0;
  }

  void _touchSwipe(web.TouchEvent event) {
    final points = <({double x, double y})>[];
    for (var i = 0; i < event.touches.length; i++) {
      final touch = event.touches.item(i);
      if (touch != null) points.add((x: touch.pageX, y: touch.pageY));
    }
    handleTouch(
      event.type,
      points,
      preventDefault: () => event.preventDefault(),
    );
  }

  /// Handles touch coordinates independently of a concrete browser event.
  void handleTouch(
    String type,
    List<({double x, double y})> touches, {
    void Function()? preventDefault,
  }) {
    if (!active) return;
    if (touches.length > 1) {
      _touchSwipeState = null;
      return;
    }
    switch (type) {
      case 'touchstart':
        if (touches.isEmpty) return;
        _touchSwipeState = _TouchSwipeState(touches.first.x, touches.first.y);
      case 'touchmove':
        if (_touchSwipeState == null || touches.isEmpty) return;
        _touchSwipeState!
          ..endX = touches.first.x
          ..endY = touches.first.y;
        preventDefault?.call();
      case 'touchend':
        final swipe = _touchSwipeState;
        if (swipe == null) return;
        _touchSwipeState = null;
        final dx = swipe.endX - swipe.startX;
        final dy = swipe.endY - swipe.startY;
        final absAngle = math.atan2(dy, dx).abs();
        var delta = 0.0;
        if (dx.abs() > _swipeMinDistanceThreshold &&
            (absAngle <= _swipeAngleThreshold ||
                absAngle >= math.pi - _swipeAngleThreshold)) {
          delta = dx;
        } else if (dy.abs() > _swipeMinDistanceThreshold &&
            (absAngle - math.pi / 2).abs() <= _swipeAngleThreshold) {
          delta = dy;
        }
        if (delta > 0) {
          pdfViewer.previousPage();
        } else if (delta < 0) {
          pdfViewer.nextPage();
        }
    }
  }

  void _addWindowListeners() {
    if (_windowAbortController != null) return;
    final controller = web.AbortController();
    _windowAbortController = controller;
    final options = web.AddEventListenerOptions(signal: controller.signal);
    final wheelOptions = web.AddEventListenerOptions(
      passive: false,
      signal: controller.signal,
    );
    web.window.addEventListener(
      'mousemove',
      ((web.Event _) => _showControls()).toJS,
      options,
    );
    web.window.addEventListener(
      'mousedown',
      ((web.Event event) => _mouseDown(event as web.MouseEvent)).toJS,
      options,
    );
    web.window.addEventListener(
      'wheel',
      ((web.Event event) => _mouseWheel(event as web.WheelEvent)).toJS,
      wheelOptions,
    );
    web.window.addEventListener(
      'keydown',
      ((web.Event _) => _resetMouseScrollState()).toJS,
      options,
    );
    web.window.addEventListener(
      'contextmenu',
      ((web.Event _) => contextMenuOpen = true).toJS,
      options,
    );
    for (final type in const ['touchstart', 'touchmove', 'touchend']) {
      web.window.addEventListener(
        type,
        ((web.Event event) => _touchSwipe(event as web.TouchEvent)).toJS,
        options,
      );
    }
  }

  void _removeWindowListeners() {
    _windowAbortController?.abort();
    _windowAbortController = null;
  }

  void _addFullscreenChangeListeners() {
    if (_fullscreenChangeAbortController != null) return;
    final controller = web.AbortController();
    _fullscreenChangeAbortController = controller;
    web.window.addEventListener(
      'fullscreenchange',
      ((web.Event _) => fullscreen.active ? _enter() : _exit()).toJS,
      web.AddEventListenerOptions(signal: controller.signal),
    );
  }

  void _removeFullscreenChangeListeners() {
    _fullscreenChangeAbortController?.abort();
    _fullscreenChangeAbortController = null;
  }

  /// Releases all listeners and presentation-only UI state.
  void dispose() {
    _removeWindowListeners();
    _removeFullscreenChangeListeners();
    _hideControls();
    container.classList.remove(_activeClass);
    _args = null;
    contextMenuOpen = false;
    _touchSwipeState = null;
    _resetMouseScrollState();
    if (_state != PresentationModeState.normal) {
      _notifyStateChange(PresentationModeState.normal);
    }
  }
}
