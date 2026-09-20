// Copyright 2012 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:pdfjs/pdfjs.dart' as pdfjs;
import 'package:web/web.dart' as web;

import 'base_pdf_page_view.dart' show PageColors;
import 'event_utils.dart';
import 'menu.dart';
import 'pdf_link_service.dart';
import 'pdf_rendering_queue.dart';
import 'pdf_thumbnail_view.dart';
import 'renderable_view.dart';
import 'ui_utils.dart';

const int dragThresholdInPixels = 5;

abstract interface class ThumbnailViewerLinkService
    implements ThumbnailLinkService {
  void goToPage(int pageNumber);
}

final class PDFThumbnailViewerLinkServiceAdapter
    implements ThumbnailViewerLinkService {
  const PDFThumbnailViewerLinkServiceAdapter(this.service);
  final PDFLinkService service;
  @override
  int get pagesCount => service.pagesCount;
  @override
  void goToPage(int pageNumber) => service.goToPage(pageNumber);
}

abstract interface class ThumbnailPagesMapper {
  int get pagesNumber;
  bool hasBeenAltered();
  Object? getPageMappingForSaving();
  void movePages(List<int> pageNumbers, int insertionIndex);
}

abstract interface class ThumbnailDocument {
  int get numPages;
  ThumbnailPagesMapper? get pagesMapper;
  Future<ThumbnailPdfPage> getPage(int pageNumber);
  Future<Object?> getOptionalContentConfig();
}

final class PdfJsThumbnailDocument implements ThumbnailDocument {
  const PdfJsThumbnailDocument(this.document);
  final pdfjs.PDFDocumentProxy document;
  @override
  int get numPages => document.numPages;
  @override
  ThumbnailPagesMapper? get pagesMapper => null;
  @override
  Future<ThumbnailPdfPage> getPage(int pageNumber) async =>
      PdfJsThumbnailPage(await document.getPage(pageNumber));
  @override
  Future<Object?> getOptionalContentConfig() async => null;
}

final class ThumbnailManageMenuOptions {
  const ThumbnailManageMenuOptions({
    required this.button,
    required this.menu,
    required this.copy,
    required this.cut,
    required this.delete,
    required this.exportSelected,
  });
  final web.HTMLButtonElement button;
  final web.HTMLElement menu;
  final web.HTMLButtonElement copy;
  final web.HTMLButtonElement cut;
  final web.HTMLButtonElement delete;
  final web.HTMLButtonElement exportSelected;
}

final class PDFThumbnailViewerOptions {
  const PDFThumbnailViewerOptions({
    required this.container,
    required this.eventBus,
    required this.linkService,
    required this.renderingQueue,
    this.maxCanvasPixels,
    this.maxCanvasDim,
    this.pageColors,
    this.abortSignal,
    this.enableSplitMerge = false,
    this.manageMenu,
  });
  final web.HTMLDivElement container;
  final EventBus eventBus;
  final ThumbnailViewerLinkService linkService;
  final PDFRenderingQueue renderingQueue;
  final int? maxCanvasPixels;
  final int? maxCanvasDim;
  final PageColors? pageColors;
  final web.AbortSignal? abortSignal;
  final bool enableSplitMerge;
  final ThumbnailManageMenuOptions? manageMenu;
}

/// Coordinates thumbnail creation, visibility, rendering priority and page
/// organization interactions.
final class PDFThumbnailViewer implements PDFThumbnailRenderingTarget {
  PDFThumbnailViewer(PDFThumbnailViewerOptions options)
      : container = options.container,
        scrollableContainer =
            options.container.parentElement as web.HTMLElement,
        eventBus = options.eventBus,
        linkService = options.linkService,
        renderingQueue = options.renderingQueue,
        maxCanvasPixels = options.maxCanvasPixels,
        maxCanvasDim = options.maxCanvasDim,
        pageColors = options.pageColors,
        enableSplitMerge = options.enableSplitMerge,
        _lifecycleController = web.AbortController() {
    _scroll = watchScroll(scrollableContainer, (_) {
      renderingQueue.renderHighestPriority();
    }, abortSignal: _lifecycleController.signal);
    _resetView();
    _setUpManageMenu(options.manageMenu);
    _addEventListeners();
    options.abortSignal?.addEventListener(
      'abort',
      ((web.Event _) => destroy()).toJS,
      web.AddEventListenerOptions(once: true),
    );
  }

  final web.HTMLDivElement container;
  final web.HTMLElement scrollableContainer;
  final EventBus eventBus;
  final ThumbnailViewerLinkService linkService;
  final PDFRenderingQueue renderingQueue;
  final int? maxCanvasPixels;
  final int? maxCanvasDim;
  final PageColors? pageColors;
  final bool enableSplitMerge;
  final web.AbortController _lifecycleController;
  late final ScrollState _scroll;

  final List<PDFThumbnailView> _thumbnails = [];
  final Set<int> _selectedPages = {};
  ThumbnailDocument? pdfDocument;
  ThumbnailPagesMapper? _pagesMapper;
  List<String?>? _pageLabels;
  int _currentPageNumber = 1;
  int _pagesRotation = 0;
  bool _destroyed = false;
  Future<void>? _documentLoad;
  Menu? _manageMenu;
  ThumbnailManageMenuOptions? _manageOptions;
  web.AbortController? _dragController;
  PDFThumbnailView? _draggedThumbnail;
  web.HTMLElement? _dragMarker;
  int? _dropIndex;

  int get currentPageNumber => _currentPageNumber;
  int get pagesRotation => _pagesRotation;
  int get thumbnailsCount => _thumbnails.length;
  Set<int> get selectedPages => Set<int>.unmodifiable(_selectedPages);
  Future<void> get documentLoaded => _documentLoad ?? Future<void>.value();

  PDFThumbnailView? getThumbnail(int index) =>
      index >= 0 && index < _thumbnails.length ? _thumbnails[index] : null;

  set pagesRotation(int rotation) {
    if (!isValidRotation(rotation)) {
      throw ArgumentError.value(rotation, 'rotation', 'Invalid rotation');
    }
    if (pdfDocument == null || rotation == _pagesRotation) return;
    _pagesRotation = rotation;
    for (final thumbnail in _thumbnails) {
      thumbnail.update(rotation: rotation);
    }
  }

  void setDocument(ThumbnailDocument? document) {
    if (pdfDocument != null) {
      _cancelRendering();
      _resetView();
    }
    pdfDocument = document;
    _pagesMapper = document?.pagesMapper;
    if (document == null) {
      _documentLoad = Future<void>.value();
      return;
    }
    final identity = document;
    _documentLoad = Future.wait<Object?>([
      document.getPage(1),
      document.getOptionalContentConfig(),
    ]).then<void>((values) {
      if (_destroyed || !identical(pdfDocument, identity)) return;
      final firstPage = values[0]! as ThumbnailPdfPage;
      final optional = Future<Object?>.value(values[1]);
      final viewport = firstPage.getViewport(scale: 1);
      final fragment = web.document.createDocumentFragment();
      final staging = web.document.createElement('div') as web.HTMLDivElement;
      for (var pageNumber = 1; pageNumber <= document.numPages; pageNumber++) {
        _thumbnails.add(PDFThumbnailView(PDFThumbnailViewOptions(
          container: staging,
          eventBus: eventBus,
          id: pageNumber,
          defaultViewport: viewport.clone(),
          optionalContentConfig: optional,
          linkService: linkService,
          renderingQueue: renderingQueue,
          maxCanvasPixels: maxCanvasPixels,
          maxCanvasDim: maxCanvasDim,
          pageColors: pageColors,
          enableSplitMerge: enableSplitMerge,
        )));
      }
      if (_thumbnails.isNotEmpty) {
        _thumbnails.first
          ..setPdfPage(firstPage)
          ..toggleCurrent(true);
      }
      while (staging.firstChild != null) {
        final child = staging.firstChild!;
        fragment.append(child);
      }
      container.append(fragment);
      eventBus.dispatch('thumbnailsloaded', {'source': this});
    }, onError: (Object error, StackTrace stack) {
      eventBus.dispatch('thumbnailserror', {
        'source': this,
        'error': error,
        'stackTrace': stack,
      });
    });
  }

  void setPageLabels(List<String?>? labels) {
    final document = pdfDocument;
    if (document == null) return;
    _pageLabels = labels != null && labels.length == document.numPages
        ? List<String?>.of(labels)
        : null;
    for (var index = 0; index < _thumbnails.length; index++) {
      _thumbnails[index].setPageLabel(_pageLabels?[index]);
    }
  }

  void scrollThumbnailIntoView(int pageNumber) {
    if (pdfDocument == null) return;
    final thumbnail = getThumbnail(pageNumber - 1);
    if (thumbnail == null) return;
    if (pageNumber != _currentPageNumber) {
      getThumbnail(_currentPageNumber - 1)?.toggleCurrent(false);
      thumbnail.toggleCurrent(true);
    }
    final visible = _getVisibleThumbs();
    var shouldScroll = visible.views.isNotEmpty &&
        (pageNumber <= visible.first!.id || pageNumber >= visible.last!.id);
    for (final item in visible.views) {
      if (item.id == pageNumber) shouldScroll = item.percent < 100;
    }
    if (shouldScroll) {
      thumbnail.div.scrollIntoView(web.ScrollIntoViewOptions(
        behavior: 'instant',
        block: 'nearest',
        inline: 'nearest',
      ));
    }
    _currentPageNumber = pageNumber;
  }

  void cleanup() {
    for (final thumbnail in _thumbnails) {
      if (thumbnail.renderingState != RenderingState.finished) {
        thumbnail.reset();
      }
    }
  }

  @override
  bool forceRendering() {
    if (_thumbnails.isEmpty) return false;
    final visible = _getVisibleThumbs();
    if (visible.views.isEmpty) return false;
    final queueVisible = VisiblePages(
      views: visible.views
          .map((item) => VisibleView(id: item.id, view: item.view.data!)),
      ids: visible.ids,
    );
    final scrollAhead = visible.first?.id == 1
        ? true
        : visible.last?.id == _thumbnails.length
            ? false
            : _scroll.down;
    final thumbnail = renderingQueue.getHighestPriority(
      queueVisible,
      _thumbnails,
      scrollAhead,
      ignoreDetailViews: true,
    );
    if (thumbnail is! PDFThumbnailView) return false;
    unawaited(_ensurePdfPageLoaded(thumbnail).then((page) {
      if (page != null) renderingQueue.renderView(thumbnail);
    }));
    return true;
  }

  bool hasStructuralChanges() => _pagesMapper?.hasBeenAltered() ?? false;
  Object? getStructuralChanges() => _pagesMapper?.getPageMappingForSaving();

  void selectPage(int pageNumber, bool selected) {
    final thumbnail = getThumbnail(pageNumber - 1);
    if (thumbnail == null || thumbnail.checkbox == null) return;
    thumbnail.toggleSelected(selected);
    selected
        ? _selectedPages.add(pageNumber)
        : _selectedPages.remove(pageNumber);
    _updateMenuEntries();
    eventBus.dispatch('thumbnailselectionchanged', {
      'source': this,
      'selectedPages': selectedPages,
    });
  }

  void clearSelection() {
    for (final page in _selectedPages.toList()) {
      getThumbnail(page - 1)?.toggleSelected(false);
    }
    _selectedPages.clear();
    _updateMenuEntries();
  }

  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    _cancelRendering();
    _dragController?.abort();
    _manageMenu?.destroy();
    _lifecycleController.abort();
    for (final thumbnail in _thumbnails) {
      thumbnail.destroy();
    }
    _thumbnails.clear();
    container.textContent = '';
  }

  Future<ThumbnailPdfPage?> _ensurePdfPageLoaded(
      PDFThumbnailView thumbnail) async {
    if (thumbnail.pdfPage case final page?) return page;
    final document = pdfDocument;
    if (document == null) return null;
    try {
      final page = await document.getPage(thumbnail.id);
      if (thumbnail.pdfPage == null) thumbnail.setPdfPage(page);
      return page;
    } catch (_) {
      return null;
    }
  }

  VisibleElements<PDFThumbnailView> _getVisibleThumbs() =>
      getVisibleElements<PDFThumbnailView>(
        scrollElement: ViewportGeometry.fromElement(scrollableContainer),
        views: _thumbnails
            .map((thumbnail) => ViewerElement<PDFThumbnailView>(
                  id: thumbnail.id,
                  div: DomElementGeometry(thumbnail.div),
                  data: thumbnail,
                ))
            .toList(),
      );

  void _resetView() {
    _thumbnails.clear();
    _selectedPages.clear();
    _currentPageNumber = 1;
    _pageLabels = null;
    _pagesRotation = 0;
    container.textContent = '';
  }

  void _cancelRendering() {
    for (final thumbnail in _thumbnails) {
      thumbnail.cancelRendering();
    }
  }

  void _setUpManageMenu(ThumbnailManageMenuOptions? options) {
    _manageOptions = options;
    if (options == null) return;
    if (!enableSplitMerge) {
      options.button.hidden = true.toJS;
      return;
    }
    _manageMenu = Menu(options.menu, options.button,
        [options.copy, options.cut, options.delete, options.exportSelected]);
    _updateMenuEntries();
    options.copy.addEventListener(
        'click',
        ((web.Event _) {
          eventBus.dispatch('copypages', {
            'source': this,
            'pageNumbers': selectedPages.toList()..sort(),
          });
        }).toJS,
        web.AddEventListenerOptions(signal: _lifecycleController.signal));
    options.cut.addEventListener(
        'click',
        ((web.Event _) {
          eventBus.dispatch('cutpages', {
            'source': this,
            'pageNumbers': selectedPages.toList()..sort(),
          });
        }).toJS,
        web.AddEventListenerOptions(signal: _lifecycleController.signal));
    options.delete.addEventListener(
        'click',
        ((web.Event _) {
          eventBus.dispatch('deletepages', {
            'source': this,
            'pageNumbers': selectedPages.toList()..sort(),
          });
        }).toJS,
        web.AddEventListenerOptions(signal: _lifecycleController.signal));
    options.exportSelected.addEventListener(
        'click',
        ((web.Event _) {
          eventBus.dispatch('saveextractedpages', {
            'source': this,
            'pageNumbers': selectedPages.toList()..sort(),
          });
        }).toJS,
        web.AddEventListenerOptions(signal: _lifecycleController.signal));
  }

  void _updateMenuEntries() {
    final options = _manageOptions;
    if (options == null) return;
    final hasSelection = _selectedPages.isNotEmpty;
    final canDelete =
        hasSelection && _selectedPages.length < _thumbnails.length;
    options.copy.disabled = !hasSelection;
    options.exportSelected.disabled = !hasSelection;
    options.cut.disabled = !canDelete;
    options.delete.disabled = !canDelete;
  }

  void _addEventListeners() {
    final signal = _lifecycleController.signal;
    container.addEventListener(
        'click',
        ((web.Event event) {
          final target = event.target as web.HTMLElement?;
          if (target != null && target.tagName == 'INPUT') {
            final input = target as web.HTMLInputElement;
            if (input.type != 'checkbox') return;
            final parent = input.parentElement;
            final page =
                int.tryParse(parent?.getAttribute('page-number') ?? '');
            if (page != null) selectPage(page, input.checked);
            return;
          }
          if (target != null &&
              target.classList.contains('thumbnailImageContainer')) {
            final page = int.tryParse(
                target.parentElement?.getAttribute('page-number') ?? '');
            if (page != null) {
              linkService.goToPage(page);
              _stopEvent(event);
            }
          }
        }).toJS,
        web.AddEventListenerOptions(signal: signal));
    container.addEventListener(
        'keydown',
        ((web.Event rawEvent) {
          final event = rawEvent as web.KeyboardEvent;
          final target = event.target as web.HTMLElement?;
          if (target == null) return;
          final checkbox = target.tagName == 'INPUT' &&
              (target as web.HTMLInputElement).type == 'checkbox';
          switch (event.key) {
            case 'Home':
              _focusThumbnail(0, checkbox);
            case 'End':
              _focusThumbnail(_thumbnails.length - 1, checkbox);
            case 'ArrowLeft':
            case 'ArrowUp':
              _focusRelative(target, -1, checkbox);
            case 'ArrowRight':
            case 'ArrowDown':
              _focusRelative(target, 1, checkbox);
            case 'Enter':
            case ' ':
              if (!checkbox)
                target.click();
              else
                return;
            case 'a':
              if (enableSplitMerge && (event.ctrlKey || event.metaKey)) {
                for (var page = 1; page <= _thumbnails.length; page++) {
                  selectPage(page, true);
                }
              } else {
                return;
              }
            default:
              return;
          }
          _stopEvent(event);
        }).toJS,
        web.AddEventListenerOptions(signal: signal));
    if (enableSplitMerge) _addDragListeners(signal);
  }

  void _focusRelative(web.HTMLElement target, int delta, bool checkbox) {
    final page =
        int.tryParse(target.parentElement?.getAttribute('page-number') ?? '') ??
            _currentPageNumber;
    _focusThumbnail(
        math.max(0, math.min(_thumbnails.length - 1, page - 1 + delta)),
        checkbox);
  }

  void _focusThumbnail(int index, bool checkbox) {
    final thumbnail = getThumbnail(index);
    if (thumbnail == null) return;
    if (checkbox && thumbnail.checkbox != null) {
      thumbnail.checkbox!.focus();
    } else {
      thumbnail.imageContainer.focus();
    }
  }

  void _addDragListeners(web.AbortSignal signal) {
    container.addEventListener(
        'pointerdown',
        ((web.Event rawEvent) {
          final event = rawEvent as web.PointerEvent;
          final target = event.target as web.HTMLElement?;
          if (event.button != 0 ||
              target == null ||
              !target.classList.contains('thumbnailImageContainer') ||
              _thumbnails.length <= 1) return;
          final page = int.tryParse(
              target.parentElement?.getAttribute('page-number') ?? '');
          if (page == null) return;
          final startX = event.clientX;
          final startY = event.clientY;
          final pointerId = event.pointerId;
          final controller = _dragController = web.AbortController();
          container.addEventListener(
              'pointermove',
              ((web.Event rawMove) {
                final move = rawMove as web.PointerEvent;
                if (move.pointerId != pointerId) return;
                if (_draggedThumbnail == null &&
                    (move.clientX - startX).abs() <= dragThresholdInPixels &&
                    (move.clientY - startY).abs() <= dragThresholdInPixels)
                  return;
                _draggedThumbnail ??= getThumbnail(page - 1);
                container.classList.add('isDragging');
                _draggedThumbnail!.div.classList.add('dragging');
                _updateDropMarker(
                    move.clientX.toDouble(), move.clientY.toDouble());
                _stopEvent(move);
              }).toJS,
              web.AddEventListenerOptions(signal: controller.signal));
          web.window.addEventListener(
              'pointerup',
              ((web.Event rawUp) {
                final up = rawUp as web.PointerEvent;
                if (up.pointerId == pointerId) _finishDrag(drop: true);
              }).toJS,
              web.AddEventListenerOptions(signal: controller.signal));
          web.window.addEventListener(
              'pointercancel',
              ((web.Event _) => _finishDrag()).toJS,
              web.AddEventListenerOptions(signal: controller.signal));
          web.window.addEventListener(
              'keydown',
              ((web.Event rawKey) {
                if ((rawKey as web.KeyboardEvent).key == 'Escape')
                  _finishDrag();
              }).toJS,
              web.AddEventListenerOptions(signal: controller.signal));
        }).toJS,
        web.AddEventListenerOptions(signal: signal));
  }

  void _updateDropMarker(double x, double y) {
    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var index = 0; index < _thumbnails.length; index++) {
      final rect = _thumbnails[index].div.getBoundingClientRect();
      final dx = x - (rect.x + rect.width / 2);
      final dy = y - (rect.y + rect.height / 2);
      final distance = dx * dx + dy * dy;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index + (y > rect.y + rect.height / 2 ? 1 : 0);
      }
    }
    _dropIndex = bestIndex;
    final marker =
        _dragMarker ??= web.document.createElement('div') as web.HTMLElement
          ..className = 'dragMarker';
    if (bestIndex >= _thumbnails.length) {
      container.append(marker);
    } else {
      container.insertBefore(marker, _thumbnails[bestIndex].div);
    }
  }

  void _finishDrag({bool drop = false}) {
    final dragged = _draggedThumbnail;
    final insertion = _dropIndex;
    if (drop && dragged != null && insertion != null) {
      final old = _thumbnails.indexOf(dragged);
      final draggedPage = old + 1;
      final pagesToMove =
          (<int>{..._selectedPages, draggedPage}.toList()..sort());
      final moved =
          pagesToMove.map((pageNumber) => _thumbnails[pageNumber - 1]).toList();
      final reordered = List<PDFThumbnailView>.of(_thumbnails)
        ..removeWhere(moved.contains);
      final removedBeforeInsertion =
          pagesToMove.where((pageNumber) => pageNumber <= insertion).length;
      final target = math.max(
        0,
        math.min(reordered.length, insertion - removedBeforeInsertion),
      );
      reordered.insertAll(target, moved);

      var changed = false;
      for (var index = 0; index < reordered.length; index++) {
        if (!identical(reordered[index], _thumbnails[index])) {
          changed = true;
          break;
        }
      }
      if (changed) {
        final currentThumbnail = getThumbnail(_currentPageNumber - 1);
        _thumbnails
          ..clear()
          ..addAll(reordered);
        for (var index = 0; index < _thumbnails.length; index++) {
          _thumbnails[index].updateId(index + 1);
          container.append(_thumbnails[index].div);
        }
        if (currentThumbnail != null) {
          _currentPageNumber = _thumbnails.indexOf(currentThumbnail) + 1;
        }
        _pagesMapper?.movePages(pagesToMove, insertion);
        eventBus.dispatch('pagesedited', {
          'source': this,
          'pagesMapper': _pagesMapper,
          'pageNumbers': pagesToMove,
          'insertAfter': insertion,
          'type': 'move',
        });
        for (final thumbnail in moved) {
          thumbnail.toggleSelected(false);
        }
        _selectedPages.clear();
        _updateMenuEntries();
      }
    }
    dragged?.div.classList.remove('dragging');
    container.classList.remove('isDragging');
    _dragMarker?.remove();
    _dragMarker = null;
    _draggedThumbnail = null;
    _dropIndex = null;
    _dragController?.abort();
    _dragController = null;
  }

  static void _stopEvent(web.Event event) {
    event
      ..preventDefault()
      ..stopPropagation();
  }
}
