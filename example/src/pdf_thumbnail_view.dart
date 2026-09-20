// Copyright 2012 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:pdfjs/pdfjs.dart' as pdfjs;
import 'package:pdfjs/src/display/display_utils.dart' show OutputScale;
import 'package:web/web.dart' as web;

import 'app_options.dart';
import 'base_pdf_page_view.dart' show PageColors;
import 'event_utils.dart';
import 'pdf_link_service.dart';
import 'pdf_rendering_queue.dart';
import 'renderable_view.dart';

const int drawUpscaleFactor = 2;
const int maxNumScalingSteps = 3;
const int thumbnailWidth = 126;

abstract interface class ThumbnailRenderTask {
  Future<void> get promise;
  set onContinue(void Function(void Function())? callback);
  void cancel();
}

abstract interface class ThumbnailPdfPage {
  int get rotate;
  pdfjs.PageViewport getViewport({required double scale, int? rotation});
  ThumbnailRenderTask render(ThumbnailRenderContext context);
}

final class ThumbnailRenderContext {
  const ThumbnailRenderContext({
    required this.canvas,
    required this.viewport,
    this.transform,
    this.optionalContentConfig,
    this.pageColors,
  });
  final web.HTMLCanvasElement canvas;
  final pdfjs.PageViewport viewport;
  final List<num>? transform;
  final Future<Object?>? optionalContentConfig;
  final PageColors? pageColors;
}

final class PdfJsThumbnailRenderTask implements ThumbnailRenderTask {
  PdfJsThumbnailRenderTask(this.task);
  final pdfjs.RenderTask task;

  @override
  Future<void> get promise => task.promise;

  @override
  set onContinue(void Function(void Function())? callback) {
    // The current Dart renderer runs an operator list atomically. This setter
    // remains part of the contract for incremental render backends.
  }

  @override
  void cancel() => task.cancel();
}

/// Adapter connecting the public PDF page API to thumbnail rendering.
final class PdfJsThumbnailPage implements ThumbnailPdfPage {
  const PdfJsThumbnailPage(this.page);
  final pdfjs.PDFPageProxy page;

  @override
  int get rotate => page.rotate;

  @override
  pdfjs.PageViewport getViewport({required double scale, int? rotation}) =>
      page.getViewport(scale: scale, rotation: rotation);

  @override
  ThumbnailRenderTask render(ThumbnailRenderContext context) {
    final canvasContext = context.canvas.getContext('2d');
    if (canvasContext == null) {
      throw StateError('A 2D canvas context is required for thumbnails.');
    }
    return PdfJsThumbnailRenderTask(
      page.render(
        pdfjs.RenderParameters(
          canvasContext: canvasContext,
          viewport: context.viewport,
          transform: context.transform,
          background: context.pageColors?.background ?? '#ffffff',
        ),
      ),
    );
  }
}

abstract interface class ThumbnailLinkService {
  int get pagesCount;
}

final class PDFThumbnailLinkServiceAdapter implements ThumbnailLinkService {
  const PDFThumbnailLinkServiceAdapter(this.service);
  final PDFLinkService service;
  @override
  int get pagesCount => service.pagesCount;
}

abstract interface class ThumbnailSourcePageView {
  web.HTMLCanvasElement? get thumbnailCanvas;
  ThumbnailPdfPage get pdfPage;
  double get scale;
}

final class PDFThumbnailViewOptions {
  const PDFThumbnailViewOptions({
    required this.container,
    required this.eventBus,
    required this.id,
    required this.defaultViewport,
    required this.linkService,
    required this.renderingQueue,
    this.optionalContentConfig,
    this.maxCanvasPixels,
    this.maxCanvasDim,
    this.pageColors,
    this.enableSplitMerge = false,
  });

  final web.HTMLDivElement container;
  final EventBus eventBus;
  final int id;
  final pdfjs.PageViewport defaultViewport;
  final Future<Object?>? optionalContentConfig;
  final ThumbnailLinkService linkService;
  final PDFRenderingQueue renderingQueue;
  final int? maxCanvasPixels;
  final int? maxCanvasDim;
  final PageColors? pageColors;
  final bool enableSplitMerge;
}

final class _DrawContext {
  const _DrawContext(this.canvas, this.transform);
  final web.HTMLCanvasElement canvas;
  final List<num>? transform;
}

/// A single thumbnail in the sidebar.
final class PDFThumbnailView implements RenderableView {
  PDFThumbnailView(PDFThumbnailViewOptions options)
      : id = options.id,
        renderingId = 'thumbnail${options.id}',
        viewport = options.defaultViewport,
        pdfPageRotate = options.defaultViewport.rotation,
        optionalContentConfig = options.optionalContentConfig,
        maxCanvasPixels = options.maxCanvasPixels ??
            (AppOptions.get('maxCanvasPixels') as num).toInt(),
        maxCanvasDim = options.maxCanvasDim ??
            (AppOptions.get('maxCanvasDim') as num).toInt(),
        pageColors = options.pageColors,
        eventBus = options.eventBus,
        linkService = options.linkService,
        renderingQueue = options.renderingQueue {
    div = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'thumbnail'
      ..setAttribute('page-number', '$id');
    imageContainer = web.document.createElement('div') as web.HTMLDivElement
      ..classList.add('thumbnailImageContainer')
      ..classList.add('missingThumbnailImage')
      ..setAttribute('role', 'button')
      ..tabIndex = -1
      ..draggable = false
      ..setAttribute('page-number', '$id')
      ..setAttribute('data-l10n-id', 'pdfjs-thumb-page-title1')
      ..setAttribute('data-l10n-args', _getPageL10nArgs(hasTotal: true));
    image = web.document.createElement('img') as web.HTMLImageElement;
    imageContainer.append(image);
    div.append(imageContainer);
    if (options.enableSplitMerge) {
      checkbox = web.document.createElement('input') as web.HTMLInputElement
        ..type = 'checkbox'
        ..tabIndex = -1
        ..setAttribute('data-l10n-id', 'pdfjs-thumb-page-checkbox1')
        ..setAttribute('data-l10n-args', _getPageL10nArgs());
      div.append(checkbox!);
    }
    _updateDims();
    options.container.append(div);
  }

  int id;
  @override
  String renderingId;
  String? pageLabel;
  ThumbnailPdfPage? pdfPage;
  int rotation = 0;
  pdfjs.PageViewport viewport;
  int pdfPageRotate;
  final Future<Object?>? optionalContentConfig;
  final int maxCanvasPixels;
  final int maxCanvasDim;
  final PageColors? pageColors;
  final EventBus eventBus;
  final ThumbnailLinkService linkService;
  final PDFRenderingQueue renderingQueue;

  late final web.HTMLDivElement div;
  late final web.HTMLDivElement imageContainer;
  late web.HTMLImageElement image;
  web.HTMLInputElement? checkbox;
  web.HTMLButtonElement? pasteButton;
  web.HTMLButtonElement? prevPasteButton;
  Object? placeholder;
  late int canvasWidth;
  late int canvasHeight;
  late double scale;
  ThumbnailRenderTask? renderTask;
  RenderingState _renderingState = RenderingState.initial;
  void Function()? _resume;

  @override
  RenderingState get renderingState => _renderingState;
  @override
  set renderingState(RenderingState value) => _renderingState = value;
  @override
  void Function()? get resume => _resume;
  @override
  set resume(void Function()? value) => _resume = value;

  PDFThumbnailView clone(web.HTMLDivElement container, int newId) {
    final cloned = PDFThumbnailView(PDFThumbnailViewOptions(
      container: container,
      eventBus: eventBus,
      id: newId,
      defaultViewport: viewport,
      optionalContentConfig: optionalContentConfig,
      linkService: linkService,
      renderingQueue: renderingQueue,
      maxCanvasPixels: maxCanvasPixels,
      maxCanvasDim: maxCanvasDim,
      pageColors: pageColors,
      enableSplitMerge: checkbox != null,
    ));
    if (!imageContainer.classList.contains('missingThumbnailImage')) {
      final copied = image.cloneNode(true) as web.HTMLImageElement;
      cloned.image.replaceWith(copied);
      cloned.image = copied;
      cloned.imageContainer.classList.remove('missingThumbnailImage');
    }
    return cloned;
  }

  void addPasteButton(void Function(int page) pasteCallback) {
    if (pasteButton != null) return;
    final button = pasteButton = web.document.createElement('button')
        as web.HTMLButtonElement
      ..classList.add('thumbnailPasteButton')
      ..classList.add('viewsManagerButton')
      ..tabIndex = 0
      ..setAttribute('data-l10n-id', 'pdfjs-views-manager-paste-button-after')
      ..setAttribute('data-l10n-args', jsonEncode({'page': pageLabel ?? id}));
    button.append(web.document.createElement('span')
      ..setAttribute('data-l10n-id', 'pdfjs-views-manager-paste-button-label'));
    button.addEventListener('click', ((web.Event _) => pasteCallback(id)).toJS);
    if (id == 1) {
      final previous =
          prevPasteButton = button.cloneNode(true) as web.HTMLButtonElement
            ..setAttribute(
                'data-l10n-id', 'pdfjs-views-manager-paste-button-before');
      previous.addEventListener(
          'click', ((web.Event _) => pasteCallback(0)).toJS);
      imageContainer.before(previous);
    }
    imageContainer.after(button);
  }

  void removePasteButton() {
    pasteButton?.remove();
    pasteButton = null;
    prevPasteButton?.remove();
    prevPasteButton = null;
  }

  void toggleSelected(bool selected) {
    final input = checkbox;
    if (input != null) input.checked = selected;
  }

  void updateId(int newId) {
    id = newId;
    renderingId = 'thumbnail$newId';
    div.setAttribute('page-number', '$newId');
    imageContainer.setAttribute('page-number', '$newId');
    setPageLabel(pageLabel);
  }

  void setPdfPage(ThumbnailPdfPage page) {
    pdfPage = page;
    pdfPageRotate = page.rotate;
    viewport =
        page.getViewport(scale: 1, rotation: (rotation + pdfPageRotate) % 360);
    reset();
  }

  void reset() {
    cancelRendering();
    renderingState = RenderingState.initial;
    _updateDims();
    final url = image.src;
    if (url.isNotEmpty) {
      web.URL.revokeObjectURL(url);
      image.src = '';
      imageContainer
        ..removeAttribute('data-l10n-id')
        ..removeAttribute('data-l10n-args')
        ..classList.add('missingThumbnailImage');
    }
  }

  void destroy() {
    reset();
    toggleCurrent(false);
    div.remove();
  }

  void update({int? rotation}) {
    if (rotation != null) this.rotation = rotation;
    viewport = viewport.clone(
        scale: 1, rotation: (this.rotation + pdfPageRotate) % 360);
    reset();
  }

  void toggleCurrent(bool current) {
    if (current) {
      imageContainer.setAttribute('aria-current', 'page');
      imageContainer.tabIndex = 0;
      if (checkbox != null) checkbox!.tabIndex = 0;
    } else {
      imageContainer.setAttribute('aria-current', 'false');
      imageContainer.tabIndex = -1;
      if (checkbox != null) checkbox!.tabIndex = -1;
    }
  }

  void cancelRendering() {
    renderTask?.cancel();
    renderTask = null;
    resume = null;
  }

  @override
  Future<void> draw() async {
    if (renderingState != RenderingState.initial) return;
    final page = pdfPage;
    if (page == null) {
      renderingState = RenderingState.finished;
      throw StateError('pdfPage is not loaded');
    }
    renderingState = RenderingState.running;
    final drawContext = _getPageDrawContext(drawUpscaleFactor);
    final drawViewport = viewport.clone(scale: drawUpscaleFactor * scale);
    final task = renderTask = page.render(ThumbnailRenderContext(
      canvas: drawContext.canvas,
      viewport: drawViewport,
      transform: drawContext.transform,
      optionalContentConfig: optionalContentConfig,
      pageColors: pageColors,
    ));
    task.onContinue = (continueRendering) {
      if (!renderingQueue.isHighestPriority(this)) {
        renderingState = RenderingState.paused;
        resume = () {
          renderingState = RenderingState.running;
          continueRendering();
        };
        return;
      }
      continueRendering();
    };

    Object? error;
    try {
      await task.promise;
    } on pdfjs.RenderingCancelledException {
      return;
    } catch (reason) {
      error = reason;
    } finally {
      if (identical(task, renderTask)) renderTask = null;
    }
    renderingState = RenderingState.finished;
    await _convertCanvasToImage(drawContext.canvas);
    eventBus.dispatch('thumbnailrendered', {
      'source': this,
      'pageNumber': id,
      'pdfPage': page,
    });
    if (error != null) throw error;
  }

  Future<void> setImage(ThumbnailSourcePageView pageView) async {
    if (renderingState != RenderingState.initial) return;
    final canvas = pageView.thumbnailCanvas;
    if (canvas == null) return;
    if (pdfPage == null) setPdfPage(pageView.pdfPage);
    if (pageView.scale < scale) return;
    renderingState = RenderingState.finished;
    await _convertCanvasToImage(canvas);
  }

  void setPageLabel(Object? label) {
    pageLabel = label is String ? label : null;
    imageContainer.setAttribute(
        'data-l10n-args', _getPageL10nArgs(hasTotal: true));
    image.setAttribute('data-l10n-args', _getPageL10nArgs());
    checkbox?.setAttribute('data-l10n-args', _getPageL10nArgs());
  }

  void _updateDims() {
    final ratio = viewport.width / viewport.height;
    canvasWidth = thumbnailWidth;
    canvasHeight = (canvasWidth / ratio).truncate();
    scale = canvasWidth / viewport.width;
    imageContainer.style.height = '${canvasHeight}px';
  }

  _DrawContext _getPageDrawContext([int upscaleFactor = 1]) {
    final outputScale = OutputScale();
    final width = upscaleFactor * canvasWidth;
    final height = upscaleFactor * canvasHeight;
    outputScale.limitCanvas(width.toDouble(), height.toDouble(),
        maxCanvasPixels.toDouble(), maxCanvasDim.toDouble());
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = (width * outputScale.sx).truncate()
      ..height = (height * outputScale.sy).truncate();
    return _DrawContext(
      canvas,
      outputScale.scaled
          ? <num>[outputScale.sx, 0, 0, outputScale.sy, 0, 0]
          : null,
    );
  }

  Future<void> _convertCanvasToImage(web.HTMLCanvasElement canvas) async {
    if (renderingState != RenderingState.finished) {
      throw StateError('Rendering has not finished.');
    }
    final reduced = _reduceImage(canvas);
    final completer = Completer<web.Blob>();
    reduced.toBlob(((web.Blob? blob) {
      if (blob == null) {
        completer.completeError(StateError('Canvas conversion failed.'));
      } else {
        completer.complete(blob);
      }
    }).toJS);
    final blob = await completer.future;
    image.src = web.URL.createObjectURL(blob);
    image
      ..setAttribute('data-l10n-id', 'pdfjs-thumb-page-canvas')
      ..setAttribute('data-l10n-args', _getPageL10nArgs());
    imageContainer.classList.remove('missingThumbnailImage');
  }

  web.HTMLCanvasElement _reduceImage(web.HTMLCanvasElement source) {
    final target = _getPageDrawContext().canvas;
    final context = target.getContext('2d') as web.CanvasRenderingContext2D;
    if (source.width <= 2 * target.width) {
      context.drawImage(source, 0, 0, source.width, source.height, 0, 0,
          target.width, target.height);
      return target;
    }
    var reducedWidth = target.width << maxNumScalingSteps;
    var reducedHeight = target.height << maxNumScalingSteps;
    final outputScale = OutputScale(sx: 1, sy: 1)
      ..limitCanvas(reducedWidth.toDouble(), reducedHeight.toDouble(),
          maxCanvasPixels.toDouble(), maxCanvasDim.toDouble());
    reducedWidth = (reducedWidth * outputScale.sx).truncate();
    reducedHeight = (reducedHeight * outputScale.sy).truncate();
    final temporary =
        web.document.createElement('canvas') as web.HTMLCanvasElement
          ..width = reducedWidth
          ..height = reducedHeight;
    final temporaryContext =
        temporary.getContext('2d') as web.CanvasRenderingContext2D
          ..save()
          ..fillStyle = 'rgb(255, 255, 255)'.toJS
          ..fillRect(0, 0, reducedWidth, reducedHeight)
          ..restore();
    while (reducedWidth > source.width || reducedHeight > source.height) {
      reducedWidth >>= 1;
      reducedHeight >>= 1;
    }
    temporaryContext.drawImage(source, 0, 0, source.width, source.height, 0, 0,
        reducedWidth, reducedHeight);
    while (reducedWidth > 2 * target.width) {
      temporaryContext.drawImage(temporary, 0, 0, reducedWidth, reducedHeight,
          0, 0, reducedWidth >> 1, reducedHeight >> 1);
      reducedWidth >>= 1;
      reducedHeight >>= 1;
    }
    context.drawImage(temporary, 0, 0, reducedWidth, reducedHeight, 0, 0,
        target.width, target.height);
    return target;
  }

  String _getPageL10nArgs({bool hasTotal = false}) => jsonEncode({
        'page': pageLabel ?? id,
        if (hasTotal) 'total': linkService.pagesCount,
      });
}
