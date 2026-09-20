// Copyright 2012 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.
// Ported from pdf.js/web/pdf_page_detail_view.js.

import 'dart:math' as math;

import 'package:pdfjs/pdfjs.dart';
import 'package:pdfjs/src/display/display_utils.dart';
import 'package:web/web.dart' as web;

import 'base_pdf_page_view.dart';
import 'renderable_view.dart';

final class DetailArea {
  const DetailArea({
    required this.minX,
    required this.minY,
    required this.width,
    required this.height,
    required this.scale,
  });
  final double minX;
  final double minY;
  final double width;
  final double height;
  final double scale;
  double get maxX => minX + width;
  double get maxY => minY + height;
}

final class VisibleDetailArea {
  const VisibleDetailArea({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
}

abstract interface class RecordedBoundingBoxes {
  bool isEmpty(int index);
  double minX(int index);
  double maxX(int index);
  double minY(int index);
  double maxY(int index);
}

abstract interface class DetailPageCanvas implements PageCanvas {
  Object get renderingContext;
  void setPosition({
    required double widthPercent,
    required double heightPercent,
    required double topPercent,
    required double leftPercent,
  });
  void setAriaHidden();
  void setDetailClass();
}

/// Browser canvas implementation usable by page and detail views.
final class BrowserDetailPageCanvas implements DetailPageCanvas {
  BrowserDetailPageCanvas([web.HTMLCanvasElement? element])
      : element = element ??
            web.document.createElement('canvas') as web.HTMLCanvasElement;

  final web.HTMLCanvasElement element;

  @override
  int get width => element.width;
  @override
  set width(int value) => element.width = value;
  @override
  int get height => element.height;
  @override
  set height(int value) => element.height = value;
  @override
  Object get renderingContext => element.getContext('2d')!;

  @override
  PageCanvas clone() => BrowserDetailPageCanvas()
    ..width = width
    ..height = height;

  @override
  void drawCanvas(PageCanvas source) {
    if (source is! BrowserDetailPageCanvas) return;
    final context = element.getContext('2d') as web.CanvasRenderingContext2D?;
    context?.drawImage(source.element, 0, 0);
  }

  @override
  void remove() => element.remove();
  @override
  void replaceWith(PageCanvas replacement) {
    if (replacement is BrowserDetailPageCanvas) {
      element.replaceWith(replacement.element);
    }
  }

  @override
  void setAriaHidden() => element.setAttribute('aria-hidden', 'true');
  @override
  void setDetailClass() => element.className = 'detailView';
  @override
  void setPosition({
    required double widthPercent,
    required double heightPercent,
    required double topPercent,
    required double leftPercent,
  }) {
    element.style
      ..width = '$widthPercent%'
      ..height = '$heightPercent%'
      ..top = '$topPercent%'
      ..left = '$leftPercent%';
  }
}

final class BrowserDetailCanvasFactory implements PageCanvasFactory {
  const BrowserDetailCanvasFactory();
  @override
  PageCanvas create() => BrowserDetailPageCanvas();
}

abstract interface class DetailPageHost {
  BasePDFPageViewOptions get baseViewOptions;
  PageViewport get viewport;
  double get maxCanvasPixels;
  double get capCanvasAreaFactor;
  bool get pdfPageLoaded;
  RenderingState get renderingState;
  PDFPageDetailView? get detailView;
  void setPdfPage(Object page);
  void insertDetailCanvas(DetailPageCanvas canvas);
  RenderParameters createDetailRenderParameters({
    required DetailPageCanvas canvas,
    required List<num> transform,
    required bool Function(int index)? operationsFilter,
  });
}

/// High-resolution renderer for the currently visible portion of a page.
final class PDFPageDetailView extends BasePDFPageView {
  PDFPageDetailView({required this.pageView}) : super(pageView.baseViewOptions);

  final DetailPageHost pageView;
  DetailArea? _detailArea;
  bool renderingCancelled = false;

  DetailArea? get detailArea => _detailArea;

  @override
  String get renderingId => 'detail$id';

  void setPdfPage(Object page) => pageView.setPdfPage(page);

  @override
  set renderingState(RenderingState state) {
    renderingCancelled = false;
    super.renderingState = state;
  }

  void reset({bool keepCanvas = false}) {
    final wasCancelled = renderingCancelled ||
        renderingState == RenderingState.running ||
        renderingState == RenderingState.paused;
    cancelRendering();
    renderingState = RenderingState.initial;
    renderingCancelled = wasCancelled;
    if (!keepCanvas) resetCanvas();
  }

  bool shouldRenderDifferentArea(VisibleDetailArea visible) {
    final detail = _detailArea;
    if (detail == null) return true;
    if (visible.minX < detail.minX ||
        visible.minY < detail.minY ||
        visible.maxX > detail.maxX ||
        visible.maxY > detail.maxY ||
        detail.scale != pageView.viewport.scale) {
      return true;
    }
    final paddingLeft = visible.minX - detail.minX;
    final paddingRight = detail.maxX - visible.maxX;
    final paddingTop = visible.minY - detail.minY;
    final paddingBottom = detail.maxY - visible.maxY;
    const ratio = 3.0;
    bool exceeds(double numerator, double denominator) =>
        denominator <= 0 ? numerator > 0 : numerator / denominator > ratio;
    return (detail.minX > 0 && exceeds(paddingRight, paddingLeft)) ||
        (detail.maxX < pageView.viewport.width &&
            exceeds(paddingLeft, paddingRight)) ||
        (detail.minY > 0 && exceeds(paddingBottom, paddingTop)) ||
        (detail.maxY < pageView.viewport.height &&
            exceeds(paddingTop, paddingBottom));
  }

  void update({
    VisibleDetailArea? visibleArea,
    bool underlyingViewUpdated = false,
  }) {
    if (underlyingViewUpdated) {
      cancelRendering();
      renderingState = RenderingState.initial;
      return;
    }
    if (visibleArea == null || !shouldRenderDifferentArea(visibleArea)) return;
    final viewport = pageView.viewport;
    final visibleWidth = visibleArea.maxX - visibleArea.minX;
    final visibleHeight = visibleArea.maxY - visibleArea.minY;
    if (visibleWidth <= 0 || visibleHeight <= 0) return;
    final pixelRatio = OutputScale.pixelRatio;
    final visiblePixels =
        visibleWidth * visibleHeight * pixelRatio * pixelRatio;
    final cappedPixels = _capPixels(
      pageView.maxCanvasPixels,
      pageView.capCanvasAreaFactor,
      pixelRatio,
    );
    final linearRatio = math.sqrt(cappedPixels / visiblePixels);
    final overflowScale = math.max(0, math.min(1, (linearRatio - 1) / 2));
    final overflowWidth = visibleWidth * overflowScale;
    final overflowHeight = visibleHeight * overflowScale;
    final minX = math.max(0, visibleArea.minX - overflowWidth).toDouble();
    final maxX = math.min(viewport.width, visibleArea.maxX + overflowWidth);
    final minY = math.max(0, visibleArea.minY - overflowHeight).toDouble();
    final maxY = math.min(viewport.height, visibleArea.maxY + overflowHeight);
    _detailArea = DetailArea(
      minX: minX,
      minY: minY,
      width: maxX - minX,
      height: maxY - minY,
      scale: viewport.scale,
    );
    reset(keepCanvas: true);
  }

  static double _capPixels(double maximum, double factor, double ratio) {
    if (factor < 0) return maximum;
    final screen = web.window.screen;
    final screenPixels = (screen.availWidth *
            screen.availHeight *
            ratio *
            ratio *
            (1 + factor / 100))
        .ceilToDouble();
    return maximum > 0 ? math.min(maximum, screenPixels) : screenPixels;
  }

  bool Function(int)? _operationsFilter(DetailArea area) {
    final boxes = recordedBBoxes;
    if (!enableOptimizedPartialRendering || boxes is! RecordedBoundingBoxes) {
      return null;
    }
    final viewport = pageView.viewport;
    final minX = area.minX / viewport.width;
    final minY = area.minY / viewport.height;
    final maxX = area.maxX / viewport.width;
    final maxY = area.maxY / viewport.height;
    return (index) =>
        !boxes.isEmpty(index) &&
        boxes.minX(index) <= maxX &&
        boxes.maxX(index) >= minX &&
        boxes.minY(index) <= maxY &&
        boxes.maxY(index) >= minY;
  }

  @override
  Future<void> draw() async {
    if (!identical(pageView.detailView, this)) return;
    final area = _detailArea;
    if (area == null)
      throw StateError('A visible area must be set before draw.');
    final hideUntilComplete =
        pageView.renderingState == RenderingState.finished ||
            renderingState == RenderingState.finished;
    if (renderingState != RenderingState.initial) reset();
    if (!pageView.pdfPageLoaded) {
      renderingState = RenderingState.finished;
      throw StateError('pdfPage is not loaded');
    }
    renderingState = RenderingState.running;
    final created = createCanvas(
      (canvas) => pageView.insertDetailCanvas(canvas as DetailPageCanvas),
      hideUntilComplete: hideUntilComplete,
    );
    final canvas = created.canvas as DetailPageCanvas;
    canvas.setAriaHidden();
    if (enableOptimizedPartialRendering) canvas.setDetailClass();
    final viewport = pageView.viewport;
    final ratio = OutputScale.pixelRatio;
    final transform = <num>[
      ratio,
      0,
      0,
      ratio,
      -area.minX * ratio,
      -area.minY * ratio
    ];
    canvas
      ..width = (area.width * ratio).round()
      ..height = (area.height * ratio).round()
      ..setPosition(
        widthPercent: area.width * 100 / viewport.width,
        heightPercent: area.height * 100 / viewport.height,
        topPercent: area.minY * 100 / viewport.height,
        leftPercent: area.minX * 100 / viewport.width,
      );
    final options = pageView.createDetailRenderParameters(
      canvas: canvas,
      transform: transform,
      operationsFilter: _operationsFilter(area),
    );
    dispatchPageRender();
    await drawCanvas(
      options,
      onCancel: () {
        canvas.remove();
        this.canvas = created.previousCanvas;
      },
      onFinish: (_) => dispatchPageRendered(
        cssTransform: false,
        isDetailView: true,
      ),
    );
  }
}
