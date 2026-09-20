// Copyright 2012 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.
// Ported from pdf.js/web/base_pdf_page_view.js.

import 'dart:async';

import 'package:pdfjs/pdfjs.dart' as pdfjs;

import 'pdf_rendering_queue.dart';
import 'renderable_view.dart';

/// Minimal class-list contract, implemented by a browser adapter or test node.
abstract interface class PageClassList {
  void add(String token);
  void remove(Iterable<String> tokens);
  bool contains(String token);
}

/// Platform-neutral page container.
abstract interface class PageViewContainer {
  PageClassList get classes;
}

/// Platform-neutral canvas operations needed by the base page view.
abstract interface class PageCanvas {
  int get width;
  set width(int value);
  int get height;
  set height(int value);

  PageCanvas clone();
  void drawCanvas(PageCanvas source);
  void replaceWith(PageCanvas replacement);
  void remove();
}

abstract interface class PageCanvasFactory {
  PageCanvas create();
}

abstract interface class ViewerEventBus {
  void dispatch(String name, Map<String, Object?> detail);
}

/// Task shape required by incremental viewer rendering.
abstract interface class ViewerRenderTask {
  Future<void> get promise;
  set onContinue(void Function(void Function())? callback);
  set onError(void Function(Object error)? callback);
  Object? get recordedBBoxes;
  void cancel([int extraDelay]);
}

/// Render source used by [BasePDFPageView].
abstract interface class PageRenderSource {
  ViewerRenderTask render(pdfjs.RenderParameters options);
  Object? get imageCoordinates;
}

/// Adapts the current package:pdfjs task to the viewer task contract.
///
/// The library renderer currently renders an operator list atomically, so it
/// has no intermediate continuation callback or recorded bounding boxes. The
/// adapter still provides cancellation/error semantics without dynamic calls.
final class PdfJsViewerRenderTask implements ViewerRenderTask {
  PdfJsViewerRenderTask(this.task) {
    unawaited(
      task.promise.then<void>(
        (_) {},
        onError: (Object error, StackTrace _) => _onError?.call(error),
      ),
    );
  }

  final pdfjs.RenderTask task;
  void Function(Object error)? _onError;

  @override
  Future<void> get promise => task.promise;

  @override
  Object? get recordedBBoxes => null;

  @override
  set onContinue(void Function(void Function())? callback) {
    // package:pdfjs currently completes an operator list atomically and thus
    // never asks the viewer for a continuation. Keeping this typed setter
    // makes the adapter compatible with incremental renderers.
  }

  @override
  set onError(void Function(Object error)? callback) {
    _onError = callback;
  }

  @override
  void cancel([int extraDelay = 0]) => task.cancel(extraDelay);
}

/// Real adapter for [pdfjs.PDFPageProxy].
final class PdfJsPageRenderSource implements PageRenderSource {
  const PdfJsPageRenderSource(this.page);

  final pdfjs.PDFPageProxy page;

  @override
  Object? get imageCoordinates => null;

  @override
  ViewerRenderTask render(pdfjs.RenderParameters options) =>
      PdfJsViewerRenderTask(page.render(options));
}

final class PageColors {
  const PageColors({this.background, this.foreground});
  final String? background;
  final String? foreground;

  bool get isHighContrast => background != null && foreground != null;
}

final class BasePDFPageViewOptions {
  const BasePDFPageViewOptions({
    required this.eventBus,
    required this.id,
    required this.renderSource,
    required this.container,
    required this.canvasFactory,
    this.pageColors,
    this.renderingQueue,
    this.enableOptimizedPartialRendering = false,
    this.imagesRightClickMinSize = -1,
    this.minDurationToUpdateCanvas = const Duration(milliseconds: 500),
    this.now = _defaultNow,
    this.timestamp = _defaultTimestamp,
  });

  final ViewerEventBus eventBus;
  final int id;
  final PageRenderSource renderSource;
  final PageViewContainer container;
  final PageCanvasFactory canvasFactory;
  final PageColors? pageColors;
  final PDFRenderingQueue? renderingQueue;
  final bool enableOptimizedPartialRendering;
  final int imagesRightClickMinSize;
  final Duration minDurationToUpdateCanvas;
  final DateTime Function() now;
  final double Function() timestamp;

  static DateTime _defaultNow() => DateTime.now();
  static double _defaultTimestamp() =>
      DateTime.now().microsecondsSinceEpoch /
      Duration.microsecondsPerMillisecond;
}

/// DOM-independent base for page views.
abstract class BasePDFPageView implements RenderableView {
  BasePDFPageView(BasePDFPageViewOptions options)
      : eventBus = options.eventBus,
        id = options.id,
        renderSource = options.renderSource,
        div = options.container,
        canvasFactory = options.canvasFactory,
        pageColors = options.pageColors,
        renderingQueue = options.renderingQueue,
        enableOptimizedPartialRendering =
            options.enableOptimizedPartialRendering,
        imagesRightClickMinSize = options.imagesRightClickMinSize,
        minDurationToUpdateCanvas = options.minDurationToUpdateCanvas,
        _now = options.now,
        _timestamp = options.timestamp;

  final ViewerEventBus eventBus;
  final int id;
  final PageRenderSource renderSource;
  final PageViewContainer div;
  final PageCanvasFactory canvasFactory;
  final PageColors? pageColors;
  final PDFRenderingQueue? renderingQueue;
  final bool enableOptimizedPartialRendering;
  final int imagesRightClickMinSize;
  final Duration minDurationToUpdateCanvas;
  final DateTime Function() _now;
  final double Function() _timestamp;

  Timer? _loadingTimer;
  Object? _renderError;
  RenderingState _renderingState = RenderingState.initial;
  void Function(bool isLastShow)? _showCanvas;
  DateTime? _startTime;
  PageCanvas? _tempCanvas;

  PageCanvas? canvas;
  ViewerRenderTask? renderTask;
  Object? imageCoordinates;
  Object? recordedBBoxes;
  void Function()? _resume;

  @override
  String get renderingId => 'page$id';

  @override
  void Function()? get resume => _resume;

  @override
  set resume(void Function()? callback) => _resume = callback;

  @override
  RenderingState get renderingState => _renderingState;

  @override
  set renderingState(RenderingState state) {
    if (state == _renderingState) return;
    _renderingState = state;
    _loadingTimer?.cancel();
    _loadingTimer = null;

    switch (state) {
      case RenderingState.paused:
        div.classes.remove(const ['loading']);
        _startTime = null;
        _showCanvas?.call(false);
      case RenderingState.running:
        div.classes.add('loadingIcon');
        _loadingTimer = Timer(Duration.zero, () {
          div.classes.add('loading');
          _loadingTimer = null;
        });
        _startTime = _now();
      case RenderingState.initial:
      case RenderingState.finished:
        div.classes.remove(const ['loadingIcon', 'loading']);
        _startTime = null;
    }
  }

  ({PageCanvas canvas, PageCanvas? previousCanvas}) createCanvas(
    void Function(PageCanvas canvas) onShow, {
    bool hideUntilComplete = false,
  }) {
    final hasHighContrastMode = pageColors?.isHighContrast ?? false;
    final previousCanvas = canvas;
    final updateOnFirstShow =
        previousCanvas == null && !hasHighContrastMode && !hideUntilComplete;
    var activeCanvas = canvasFactory.create();
    canvas = activeCanvas;

    _showCanvas = (bool isLastShow) {
      if (updateOnFirstShow) {
        var tempCanvas = _tempCanvas;
        if (!isLastShow && minDurationToUpdateCanvas > Duration.zero) {
          final start = _startTime;
          if (start != null &&
              _now().difference(start) < minDurationToUpdateCanvas) {
            return;
          }
          if (tempCanvas == null) {
            tempCanvas = _tempCanvas = activeCanvas;
            activeCanvas = canvas = activeCanvas.clone();
            onShow(activeCanvas);
          }
        }
        if (tempCanvas != null) {
          activeCanvas.drawCanvas(tempCanvas);
          if (isLastShow) {
            _resetTempCanvas();
          } else {
            _startTime = _now();
          }
          return;
        }
        onShow(activeCanvas);
        _showCanvas = null;
        return;
      }
      if (!isLastShow) return;
      if (previousCanvas != null) {
        previousCanvas.replaceWith(activeCanvas);
        previousCanvas.width = 0;
        previousCanvas.height = 0;
      } else {
        onShow(activeCanvas);
      }
    };
    return (canvas: activeCanvas, previousCanvas: previousCanvas);
  }

  void _renderContinueCallback(void Function() continueRendering) {
    _showCanvas?.call(false);
    final queue = renderingQueue;
    if (queue != null && !queue.isHighestPriority(this)) {
      renderingState = RenderingState.paused;
      resume = () {
        renderingState = RenderingState.running;
        continueRendering();
      };
      return;
    }
    continueRendering();
  }

  void resetCanvas() {
    final activeCanvas = canvas;
    if (activeCanvas == null) return;
    activeCanvas.remove();
    activeCanvas.width = 0;
    activeCanvas.height = 0;
    canvas = null;
    _resetTempCanvas();
  }

  void _resetTempCanvas() {
    final tempCanvas = _tempCanvas;
    if (tempCanvas == null) return;
    tempCanvas.width = 0;
    tempCanvas.height = 0;
    _tempCanvas = null;
  }

  Future<void> drawCanvas(
    pdfjs.RenderParameters options, {
    required void Function() onCancel,
    required void Function(ViewerRenderTask task) onFinish,
  }) async {
    final task = renderSource.render(options);
    renderTask = task;
    task.onContinue = _renderContinueCallback;
    task.onError = (Object error) {
      if (error is pdfjs.RenderingCancelledException) {
        onCancel();
        _renderError = null;
      }
    };

    Object? error;
    StackTrace? errorStack;
    var cancelled = false;
    try {
      await task.promise;
      _showCanvas?.call(true);
    } on pdfjs.RenderingCancelledException {
      cancelled = true;
    } catch (caught, stack) {
      error = caught;
      errorStack = stack;
      _showCanvas?.call(true);
    } finally {
      _renderError = error;
      if (identical(task, renderTask)) {
        renderTask = null;
        if (enableOptimizedPartialRendering) {
          recordedBBoxes ??= task.recordedBBoxes;
        }
        if (imagesRightClickMinSize != -1) {
          imageCoordinates ??= renderSource.imageCoordinates;
        }
      }
    }
    if (cancelled) return;
    renderingState = RenderingState.finished;
    onFinish(task);
    if (error != null) Error.throwWithStackTrace(error, errorStack!);
  }

  void cancelRendering({int cancelExtraDelay = 0}) {
    renderTask?.cancel(cancelExtraDelay);
    renderTask = null;
    resume = null;
  }

  void dispatchPageRender() {
    eventBus.dispatch('pagerender', <String, Object?>{
      'source': this,
      'pageNumber': id,
    });
  }

  void dispatchPageRendered({
    required bool cssTransform,
    required bool isDetailView,
  }) {
    eventBus.dispatch('pagerendered', <String, Object?>{
      'source': this,
      'pageNumber': id,
      'cssTransform': cssTransform,
      'isDetailView': isDetailView,
      'timestamp': _timestamp(),
      'error': _renderError,
    });
  }

  void disposeBaseView() {
    _loadingTimer?.cancel();
    _loadingTimer = null;
    cancelRendering();
    resetCanvas();
  }
}
