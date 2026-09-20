// Copyright 2012 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.
// Ported from pdf.js/web/pdf_rendering_queue.js.

import 'dart:async';

import 'package:pdfjs/pdfjs.dart' show RenderingCancelledException;

import 'renderable_view.dart';

const Duration defaultCleanupTimeout = Duration(seconds: 30);

/// One visible entry produced by the viewer's visibility calculation.
final class VisibleView {
  const VisibleView({required this.id, required this.view});

  final int id;
  final RenderableView view;
}

/// Immutable visibility snapshot consumed by [PDFRenderingQueue].
final class VisiblePages {
  VisiblePages({
    required Iterable<VisibleView> views,
    Set<int>? ids,
    VisibleView? first,
    VisibleView? last,
  })  : views = List<VisibleView>.unmodifiable(views),
        ids = Set<int>.unmodifiable(
          ids ?? views.map((entry) => entry.id),
        ),
        _first = first,
        _last = last {
    if (this.views.isEmpty && (first != null || last != null)) {
      throw ArgumentError(
          'Empty visibility cannot have first or last entries.');
    }
    if (this.views.isNotEmpty) {
      if (first != null && !this.ids.contains(first.id)) {
        throw ArgumentError('The first entry must occur in ids.');
      }
      if (last != null && !this.ids.contains(last.id)) {
        throw ArgumentError('The last entry must occur in ids.');
      }
    }
  }

  factory VisiblePages.empty() => VisiblePages(views: const []);

  final List<VisibleView> views;
  final Set<int> ids;
  final VisibleView? _first;
  final VisibleView? _last;

  VisibleView get first {
    if (views.isEmpty) throw StateError('Empty visibility has no first entry.');
    return _first ?? views.first;
  }

  VisibleView get last {
    if (views.isEmpty) throw StateError('Empty visibility has no last entry.');
    return _last ?? views.last;
  }
}

/// Page-view side of the queue integration.
abstract interface class PDFViewerRenderingTarget {
  bool forceRendering([VisiblePages? currentlyVisiblePages]);
}

/// Thumbnail-view side of the queue integration.
abstract interface class PDFThumbnailRenderingTarget {
  bool forceRendering();
}

typedef RenderingErrorHandler = void Function(Object error, StackTrace stack);

/// Controls rendering order for pages and thumbnails.
class PDFRenderingQueue {
  PDFRenderingQueue({
    this.cleanupTimeout = defaultCleanupTimeout,
    this.onRenderingError,
  });

  final Duration cleanupTimeout;
  final RenderingErrorHandler? onRenderingError;

  String? _highestPriorityPage;
  Timer? _idleTimer;
  PDFThumbnailRenderingTarget? _pdfThumbnailViewer;
  PDFViewerRenderingTarget? _pdfViewer;
  bool _disposed = false;

  bool isThumbnailViewEnabled = false;
  bool printing = false;
  void Function()? onIdle;

  bool get hasViewer => _pdfViewer != null;
  bool get hasThumbnailViewer => _pdfThumbnailViewer != null;
  bool get hasPendingIdleCallback => _idleTimer?.isActive ?? false;
  String? get highestPriorityRenderingId => _highestPriorityPage;

  void setViewer(PDFViewerRenderingTarget pdfViewer) {
    _ensureNotDisposed();
    _pdfViewer = pdfViewer;
  }

  void setThumbnailViewer(PDFThumbnailRenderingTarget pdfThumbnailViewer) {
    _ensureNotDisposed();
    _pdfThumbnailViewer = pdfThumbnailViewer;
  }

  bool isHighestPriority(RenderableView view) =>
      _highestPriorityPage == view.renderingId;

  /// Attempts pages, then thumbnails, then schedules idle cleanup.
  void renderHighestPriority([VisiblePages? currentlyVisiblePages]) {
    _ensureNotDisposed();
    _idleTimer?.cancel();
    _idleTimer = null;

    final viewer = _pdfViewer;
    if (viewer != null && viewer.forceRendering(currentlyVisiblePages)) return;

    final thumbnailViewer = _pdfThumbnailViewer;
    if (isThumbnailViewEnabled &&
        thumbnailViewer != null &&
        thumbnailViewer.forceRendering()) {
      return;
    }

    if (printing) return;
    final callback = onIdle;
    if (callback != null) {
      _idleTimer = Timer(cleanupTimeout, () {
        _idleTimer = null;
        if (!_disposed) callback();
      });
    }
  }

  /// Selects the next view according to the upstream priority rules.
  RenderableView? getHighestPriority(
    VisiblePages visible,
    List<RenderableView> views,
    bool scrolledDown, {
    bool preRenderExtra = false,
    bool ignoreDetailViews = false,
  }) {
    final visibleViews = visible.views;
    final numVisible = visibleViews.length;
    if (numVisible == 0) return null;

    for (final entry in visibleViews) {
      if (!isViewFinished(entry.view)) return entry.view;
    }

    if (!ignoreDetailViews) {
      for (final entry in visibleViews) {
        final view = entry.view;
        if (view case DetailRenderableView(:final detailView?)) {
          if (!isViewFinished(detailView)) return detailView;
        }
      }
    }

    final firstId = visible.first.id;
    final lastId = visible.last.id;
    if (lastId - firstId + 1 > numVisible) {
      for (var i = 1; i < lastId - firstId; i++) {
        final holeId = scrolledDown ? firstId + i : lastId - i;
        if (visible.ids.contains(holeId)) continue;
        final index = holeId - 1;
        if (index < 0 || index >= views.length) continue;
        final holeView = views[index];
        if (!isViewFinished(holeView)) return holeView;
      }
    }

    var preRenderIndex = scrolledDown ? lastId : firstId - 2;
    var preRenderView = _viewAt(views, preRenderIndex);
    if (preRenderView != null && !isViewFinished(preRenderView)) {
      return preRenderView;
    }
    if (preRenderExtra) {
      preRenderIndex += scrolledDown ? 1 : -1;
      preRenderView = _viewAt(views, preRenderIndex);
      if (preRenderView != null && !isViewFinished(preRenderView)) {
        return preRenderView;
      }
    }
    return null;
  }

  bool isViewFinished(RenderableView view) =>
      view.renderingState == RenderingState.finished;

  /// Starts or resumes [view]. Returns false only when already finished.
  bool renderView(RenderableView view) {
    _ensureNotDisposed();
    switch (view.renderingState) {
      case RenderingState.finished:
        return false;
      case RenderingState.paused:
        _highestPriorityPage = view.renderingId;
        final resume = view.resume;
        if (resume == null) {
          throw StateError(
              'Paused view ${view.renderingId} has no continuation.');
        }
        resume();
      case RenderingState.running:
        _highestPriorityPage = view.renderingId;
      case RenderingState.initial:
        _highestPriorityPage = view.renderingId;
        unawaited(
          view.draw().then<void>(
            (_) => renderHighestPriority(),
            onError: (Object error, StackTrace stack) {
              renderHighestPriority();
              if (error is! RenderingCancelledException) {
                onRenderingError?.call(error, stack);
              }
            },
          ),
        );
    }
    return true;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _idleTimer?.cancel();
    _idleTimer = null;
    _pdfViewer = null;
    _pdfThumbnailViewer = null;
    onIdle = null;
  }

  static RenderableView? _viewAt(List<RenderableView> views, int index) =>
      index >= 0 && index < views.length ? views[index] : null;

  void _ensureNotDisposed() {
    if (_disposed) throw StateError('PDFRenderingQueue has been disposed.');
  }
}

/// Optional capability for page views that own a zoomed detail view.
abstract interface class DetailRenderableView implements RenderableView {
  RenderableView? get detailView;
}
