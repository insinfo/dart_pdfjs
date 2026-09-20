// Copyright 2014 Mozilla Foundation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:collection';

import 'event_utils.dart';
import 'ui_utils.dart';

/// Minimal contract required by [PDFPageViewBuffer].
///
/// The full viewer's page view implements the same `id`/`destroy` surface.
/// Keeping this contract independent lets the cache be used before the large
/// `PDFViewer` class itself has finished being ported.
abstract interface class BufferedPageView {
  int get id;

  void destroy();
}

/// Least-recently-used cache for rendered page views.
///
/// This is the insertion-ordered `PDFPageViewBuffer` from `pdf_viewer.js`.
/// Pushing an existing view moves it to the newest position. Evicted views are
/// destroyed immediately, which is important for releasing canvases and GPU
/// resources in long documents.
final class PDFPageViewBuffer<T extends BufferedPageView>
    extends IterableBase<T> {
  PDFPageViewBuffer(int size) : _size = _validateSize(size);

  final LinkedHashSet<T> _buffer = LinkedHashSet<T>.identity();
  int _size;

  int get capacity => _size;

  @override
  int get length => _buffer.length;

  @override
  Iterator<T> get iterator => _buffer.iterator;

  void push(T view) {
    if (_buffer.remove(view)) {
      // Reinsert at the end, preserving the upstream LRU semantics.
    }
    _buffer.add(view);
    if (_buffer.length > _size) {
      _destroyFirstView();
    }
  }

  /// Changes the cache capacity and optionally delays eviction of [idsToKeep].
  ///
  /// Protected views are moved to the end in their existing order. They are
  /// still evicted when their number exceeds [newSize], matching PDF.js.
  void resize(int newSize, {Set<int>? idsToKeep}) {
    _size = _validateSize(newSize);
    if (idsToKeep != null && idsToKeep.isNotEmpty) {
      final snapshot = List<T>.of(_buffer);
      for (final view in snapshot) {
        if (idsToKeep.contains(view.id)) {
          _buffer
            ..remove(view)
            ..add(view);
        }
      }
    }
    while (_buffer.length > _size) {
      _destroyFirstView();
    }
  }

  bool has(T view) => _buffer.contains(view);

  void _destroyFirstView() {
    if (_buffer.isEmpty) return;
    final first = _buffer.first;
    first.destroy();
    _buffer.remove(first);
  }

  static int _validateSize(int size) {
    if (size < 0) {
      throw RangeError.range(size, 0, null, 'size');
    }
    return size;
  }
}

/// Visible-page data used when deciding how far Page Up/Down should move.
final class NavigationVisiblePage {
  const NavigationVisiblePage({
    required this.id,
    required this.y,
    required this.percent,
    required this.widthPercent,
  });

  final int id;
  final int y;
  final int percent;
  final int widthPercent;
}

typedef VisiblePagesProvider = List<NavigationVisiblePage> Function();
typedef CurrentPageResetter = void Function(int pageNumber);
typedef PageLabelUpdater = void Function(int pageNumber, String? label);

/// Page-number, label and layout-aware navigation extracted from `PDFViewer`.
///
/// It ports the navigation state machine independently of page rendering. The
/// eventual Dart `PDFViewer` can delegate these operations to this controller,
/// while the current example can already share correct wrapped/spread rules.
final class PDFViewerNavigation {
  PDFViewerNavigation({
    required this.pagesCount,
    required this.eventBus,
    VisiblePagesProvider? visiblePagesProvider,
    CurrentPageResetter? resetCurrentPageView,
    PageLabelUpdater? updatePageLabel,
  })  : _visiblePagesProvider = visiblePagesProvider ?? _noVisiblePages,
        _resetCurrentPageView = resetCurrentPageView,
        _updatePageLabel = updatePageLabel {
    if (pagesCount <= 0) {
      throw RangeError.range(pagesCount, 1, null, 'pagesCount');
    }
  }

  final int pagesCount;
  final EventBus eventBus;
  final VisiblePagesProvider _visiblePagesProvider;
  final CurrentPageResetter? _resetCurrentPageView;
  final PageLabelUpdater? _updatePageLabel;

  int _currentPageNumber = 1;
  List<String>? _pageLabels;
  int _scrollMode = ScrollMode.vertical;
  int _spreadMode = SpreadMode.none;

  int get currentPageNumber => _currentPageNumber;

  set currentPageNumber(int value) {
    setCurrentPageNumber(value, resetCurrentPageView: true);
  }

  String? get currentPageLabel => _pageLabels?[_currentPageNumber - 1];

  set currentPageLabel(String? value) {
    if (value == null) return;
    var page = int.tryParse(value) ?? 0;
    final labels = _pageLabels;
    if (labels != null) {
      final index = labels.indexOf(value);
      if (index >= 0) page = index + 1;
    }
    setCurrentPageNumber(page, resetCurrentPageView: true);
  }

  int get scrollMode => _scrollMode;

  set scrollMode(int mode) {
    if (_scrollMode == mode) return;
    if (!isValidScrollMode(mode)) {
      throw ArgumentError.value(mode, 'mode', 'Invalid scroll mode');
    }
    _scrollMode = mode;
    eventBus.dispatch('scrollmodechanged', <String, Object>{
      'source': this,
      'mode': mode,
    });
    _resetCurrentPageView?.call(_currentPageNumber);
  }

  int get spreadMode => _spreadMode;

  set spreadMode(int mode) {
    if (_spreadMode == mode) return;
    if (!isValidSpreadMode(mode)) {
      throw ArgumentError.value(mode, 'mode', 'Invalid spread mode');
    }
    _spreadMode = mode;
    eventBus.dispatch('spreadmodechanged', <String, Object>{
      'source': this,
      'mode': mode,
    });
    _resetCurrentPageView?.call(_currentPageNumber);
  }

  /// Updates the current page and emits PDF.js' `pagechanging` event.
  bool setCurrentPageNumber(
    int value, {
    bool resetCurrentPageView = false,
  }) {
    if (_currentPageNumber == value) {
      if (resetCurrentPageView) _resetCurrentPageView?.call(value);
      return true;
    }
    if (value <= 0 || value > pagesCount) return false;

    final previous = _currentPageNumber;
    _currentPageNumber = value;
    eventBus.dispatch('pagechanging', <String, Object?>{
      'source': this,
      'pageNumber': value,
      'pageLabel': _pageLabels?[value - 1],
      'previous': previous,
    });
    if (resetCurrentPageView) _resetCurrentPageView?.call(value);
    return true;
  }

  /// Installs page labels and propagates them to all existing page views.
  ///
  /// A non-null list must contain exactly one label per page, like the
  /// upstream `setPageLabels` method.
  void setPageLabels(List<String>? labels) {
    if (labels != null && labels.length != pagesCount) {
      throw ArgumentError.value(
        labels,
        'labels',
        'The number of labels must match pagesCount',
      );
    }
    _pageLabels = labels == null ? null : List<String>.unmodifiable(labels);
    for (var index = 0; index < pagesCount; index++) {
      _updatePageLabel?.call(index + 1, _pageLabels?[index]);
    }
  }

  int? pageLabelToPageNumber(String label) {
    final labels = _pageLabels;
    if (labels == null) return null;
    final index = labels.indexOf(label);
    return index < 0 ? null : index + 1;
  }

  /// Moves to the next logical page/spread.
  bool nextPage() {
    if (_currentPageNumber >= pagesCount) return false;
    final advance = _getPageAdvance(_currentPageNumber);
    currentPageNumber = (_currentPageNumber + advance).clamp(1, pagesCount);
    return true;
  }

  /// Moves to the previous logical page/spread.
  bool previousPage() {
    if (_currentPageNumber <= 1) return false;
    final advance = _getPageAdvance(_currentPageNumber, previous: true);
    currentPageNumber = (_currentPageNumber - advance).clamp(1, pagesCount);
    return true;
  }

  int _getPageAdvance(int currentPageNumber, {bool previous = false}) {
    switch (_scrollMode) {
      case ScrollMode.wrapped:
        final pageLayout = LinkedHashMap<int, List<int>>();
        for (final view in _visiblePagesProvider()) {
          if (view.percent == 0 || view.widthPercent < 100) continue;
          pageLayout.putIfAbsent(view.y, () => <int>[]).add(view.id);
        }
        for (final row in pageLayout.values) {
          final currentIndex = row.indexOf(currentPageNumber);
          if (currentIndex < 0) continue;
          if (row.length == 1) break;

          if (previous) {
            for (var index = currentIndex - 1; index >= 0; index--) {
              final currentId = row[index];
              final expectedId = row[index + 1] - 1;
              if (currentId < expectedId) {
                return currentPageNumber - expectedId;
              }
            }
          } else {
            for (var index = currentIndex + 1; index < row.length; index++) {
              final currentId = row[index];
              final expectedId = row[index - 1] + 1;
              if (currentId > expectedId) {
                return expectedId - currentPageNumber;
              }
            }
          }

          if (previous) {
            final firstId = row.first;
            if (firstId < currentPageNumber) {
              return currentPageNumber - firstId + 1;
            }
          } else {
            final lastId = row.last;
            if (lastId > currentPageNumber) {
              return lastId - currentPageNumber + 1;
            }
          }
          break;
        }
      case ScrollMode.horizontal:
        break;
      case ScrollMode.page:
      case ScrollMode.vertical:
        if (_spreadMode == SpreadMode.none) break;
        final parity = _spreadMode - 1;
        if (previous && currentPageNumber % 2 != parity) break;
        if (!previous && currentPageNumber % 2 == parity) break;

        final expectedId =
            previous ? currentPageNumber - 1 : currentPageNumber + 1;
        for (final view in _visiblePagesProvider()) {
          if (view.id != expectedId) continue;
          if (view.percent > 0 && view.widthPercent == 100) return 2;
          break;
        }
    }
    return 1;
  }

  static List<NavigationVisiblePage> _noVisiblePages() =>
      const <NavigationVisiblePage>[];
}
