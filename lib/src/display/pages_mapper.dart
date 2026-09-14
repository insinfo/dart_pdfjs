// Copyright 2026 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import '../shared/math_clamp.dart';

/// Maps between page IDs and page numbers, allowing bidirectional conversion.
/// When [_pageNumberToId] is null, the mapping is the identity (page N has ID N).
class PagesMapper {
  Uint32List? _pageNumberToId;
  Int32List? _prevPageNumbers;
  int _pagesNumber = 0;

  /// Clipboard state for copy/paste operations.
  Map<String, Uint32List>? _clipboard;

  /// Saved state for undoing a delete.
  Map<String, dynamic>? _savedData;

  int get pagesNumber => _pagesNumber;

  set pagesNumber(int n) {
    if (_pagesNumber == n) return;
    _pagesNumber = n;
    _pageNumberToId = null;
    _prevPageNumbers = null;
  }

  void _ensureInit() {
    if (_pageNumberToId != null) return;
    final n = _pagesNumber;
    final pageNumberToId = Uint32List(n);
    for (var i = 0; i < n; i++) {
      pageNumberToId[i] = i + 1;
    }
    _pageNumberToId = pageNumberToId;
    _prevPageNumbers = Int32List.fromList(pageNumberToId.buffer.asInt32List());
  }

  Map<int, List<int>> _buildIdToPageNumber() {
    final idToPageNumber = <int, List<int>>{};
    final pageNumberToId = _pageNumberToId!;
    for (var i = 0; i < _pagesNumber; i++) {
      final id = pageNumberToId[i];
      idToPageNumber.putIfAbsent(id, () => []).add(i + 1);
    }
    return idToPageNumber;
  }

  /// Move a set of pages to a new position.
  void movePages(Set<int> selectedPages, List<int> pagesToMove, int index) {
    _ensureInit();
    final pageNumberToId = _pageNumberToId!;
    final prevIdToPageNumber = _buildIdToPageNumber();
    final movedCount = pagesToMove.length;
    final mappedPagesToMove = Uint32List(movedCount);
    var removedBeforeTarget = 0;

    for (var i = 0; i < movedCount; i++) {
      final pageIndex = pagesToMove[i] - 1;
      mappedPagesToMove[i] = pageNumberToId[pageIndex];
      if (pageIndex < index) {
        removedBeforeTarget++;
      }
    }

    final pagesNumber = _pagesNumber;
    final remainingLen = pagesNumber - movedCount;
    final adjustedTarget = mathClamp(
      index - removedBeforeTarget,
      0,
      remainingLen,
    ).toInt();

    // Compact: keep only non-moved pages.
    var r = 0;
    for (var i = 0; i < pagesNumber; i++) {
      if (!selectedPages.contains(i + 1)) {
        pageNumberToId[r++] = pageNumberToId[i];
      }
    }

    // Make room at the target and insert.
    for (var i = remainingLen - 1; i >= adjustedTarget; i--) {
      pageNumberToId[i + movedCount] = pageNumberToId[i];
    }
    for (var i = 0; i < movedCount; i++) {
      pageNumberToId[adjustedTarget + i] = mappedPagesToMove[i];
    }

    _updatePrevPageNumbers(prevIdToPageNumber);

    if (_isIdentity(pageNumberToId)) {
      _pageNumberToId = null;
    }
  }

  /// Delete a set of pages.
  void deletePages(List<int> pagesToDelete) {
    _ensureInit();
    final pageNumberToId = _pageNumberToId!;
    final prevIdToPageNumber = _buildIdToPageNumber();

    _savedData = {
      'pageNumberToId': Uint32List.fromList(pageNumberToId),
      'pagesNumber': _pagesNumber,
      'prevPageNumbers': Int32List.fromList(_prevPageNumbers!),
    };

    final newN = _pagesNumber - pagesToDelete.length;
    _pagesNumber = newN;
    final newPageNumberToId = Uint32List(newN);
    _prevPageNumbers = Int32List(newN);

    var sourceIndex = 0;
    var destIndex = 0;
    for (final pageNumber in pagesToDelete) {
      final pageIndex = pageNumber - 1;
      if (pageIndex != sourceIndex) {
        for (var i = sourceIndex; i < pageIndex; i++) {
          newPageNumberToId[destIndex++] = pageNumberToId[i];
        }
      }
      sourceIndex = pageIndex + 1;
    }
    if (sourceIndex < pageNumberToId.length) {
      for (var i = sourceIndex; i < pageNumberToId.length; i++) {
        newPageNumberToId[destIndex++] = pageNumberToId[i];
      }
    }

    _pageNumberToId = newPageNumberToId;
    _updatePrevPageNumbers(prevIdToPageNumber, pagesToDelete.toSet());
  }

  /// Cancel the last delete operation.
  void cancelDelete() {
    if (_savedData != null) {
      _pageNumberToId = _savedData!['pageNumberToId'] as Uint32List;
      _pagesNumber = _savedData!['pagesNumber'] as int;
      _prevPageNumbers = _savedData!['prevPageNumbers'] as Int32List;
      _savedData = null;
    }
  }

  /// Confirm the delete and discard the saved state.
  void confirmDelete() {
    _savedData = null;
  }

  /// Copy pages to clipboard.
  void copyPages(List<int> pageNumbers) {
    _ensureInit();
    final pageNumberToId = _pageNumberToId!;
    final n = pageNumbers.length;
    final pageIds = Uint32List(n);
    final pageNums = Uint32List(n);
    for (var i = 0; i < n; i++) {
      final pageNum = pageNumbers[i];
      pageNums[i] = pageNum;
      pageIds[i] = pageNumberToId[pageNum - 1];
    }
    _clipboard = {
      'pageNumbers': pageNums,
      'pageIds': pageIds,
    };
  }

  /// Paste pages from clipboard at the given index.
  void pastePages(int index) {
    if (_clipboard == null) return;
    _ensureInit();

    final pageNumberToId = _pageNumberToId!;
    final prevIdToPageNumber = _buildIdToPageNumber();
    final pageIds = _clipboard!['pageIds']!;
    final pasteCount = pageIds.length;

    final newN = _pagesNumber + pasteCount;
    final newPageNumberToId = Uint32List(newN);
    _prevPageNumbers = Int32List(newN);

    // Copy before insertion point.
    for (var i = 0; i < index; i++) {
      newPageNumberToId[i] = pageNumberToId[i];
    }
    // Insert pasted pages.
    for (var i = 0; i < pasteCount; i++) {
      newPageNumberToId[index + i] = pageIds[i];
    }
    // Copy after insertion point.
    for (var i = index; i < _pagesNumber; i++) {
      newPageNumberToId[i + pasteCount] = pageNumberToId[i];
    }

    _pagesNumber = newN;
    _pageNumberToId = newPageNumberToId;

    _updatePrevPageNumbers(prevIdToPageNumber, null, true);
  }

  /// Get the page ID for a given page number (1-indexed).
  int getPageId(int pageNumber) {
    if (_pageNumberToId == null) return pageNumber;
    return _pageNumberToId![pageNumber - 1];
  }

  /// Get the page numbers for a given page ID.
  List<int>? getPageNumbers(int pageId) {
    if (_pageNumberToId == null) {
      return pageId >= 1 && pageId <= _pagesNumber ? [pageId] : null;
    }
    final result = <int>[];
    for (var i = 0; i < _pagesNumber; i++) {
      if (_pageNumberToId![i] == pageId) {
        result.add(i + 1);
      }
    }
    return result.isEmpty ? null : result;
  }

  /// Get the previous page number for a given position.
  int? getPrevPageNumber(int pageNumber) {
    if (_prevPageNumbers == null) return pageNumber;
    if (pageNumber < 1 || pageNumber > _pagesNumber) return null;
    return _prevPageNumbers![pageNumber - 1];
  }

  void _updatePrevPageNumbers(Map<int, List<int>> prevIdToPageNumber,
      [Set<int>? deletedPages, bool isPaste = false]) {
    final pageNumberToId = _pageNumberToId!;
    final prevPageNumbers = _prevPageNumbers!;

    for (var i = 0; i < _pagesNumber; i++) {
      final id = pageNumberToId[i];
      final prevPages = prevIdToPageNumber[id];
      if (prevPages != null && prevPages.isNotEmpty) {
        if (isPaste && i >= prevPages.length) {
          // Copied page - mark with negative.
          prevPageNumbers[i] = -(prevPages[0]);
        } else {
          prevPageNumbers[i] = prevPages.removeAt(0);
        }
      } else {
        prevPageNumbers[i] = 0;
      }
    }
  }

  bool _isIdentity(Uint32List arr) {
    for (var i = 0; i < arr.length; i++) {
      if (arr[i] != i + 1) return false;
    }
    return true;
  }
}
