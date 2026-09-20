// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'base_tree_viewer.dart';
import 'pdf_link_service.dart';
import 'ui_utils.dart' show SidebarView;

/// Renders and controls the document outline sidebar.
class PDFOutlineViewer extends BaseTreeViewer {
  PDFOutlineViewer({
    required super.container,
    required super.eventBus,
    required super.l10n,
    required this.linkService,
    required this.downloadManager,
  }) {
    eventBus.internalOn('toggleoutlinetree', (_) => toggleAllTreeItems());
    eventBus.internalOn('currentoutlineitem', (_) {
      unawaited(_currentOutlineItem());
    });
    eventBus.internalOn('pagechanging', (event) {
      final value = _eventValue(event, 'pageNumber');
      if (value is num) _currentPageNumber = value.toInt();
    });
    eventBus.internalOn('pagesloaded', (event) {
      final count = _eventValue(event, 'pagesCount');
      _isPagesLoaded = count is num && count != 0;
      final completer = _currentOutlineItemCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete(_isPagesLoaded!);
      }
    });
    eventBus.internalOn('sidebarviewchanged', (event) {
      final value = _eventValue(event, 'view');
      if (value is num) _sidebarView = value.toInt();
    });
  }

  final PDFLinkService linkService;
  final ViewerDownloadManager downloadManager;

  List<Map<String, dynamic>>? _outline;
  Future<Map<int, String>?>? _pageNumberToDestHashFuture;
  int _currentPageNumber = 1;
  bool? _isPagesLoaded;
  int? _sidebarView;
  Completer<bool>? _currentOutlineItemCompleter;

  @override
  void reset() {
    super.reset();
    _outline = null;
    _pageNumberToDestHashFuture = null;
    _currentPageNumber = 1;
    _isPagesLoaded = null;
    final oldCompleter = _currentOutlineItemCompleter;
    if (oldCompleter != null && !oldCompleter.isCompleted) {
      oldCompleter.complete(false);
    }
    _currentOutlineItemCompleter = null;
  }

  @override
  void dispatchLoadedEvent(int count) {
    final completer = Completer<bool>();
    _currentOutlineItemCompleter = completer;
    final document = pdfDocument;
    if (count == 0 ||
        (document is OutlineDocument && document.disableAutoFetch)) {
      completer.complete(false);
    } else if (_isPagesLoaded != null) {
      completer.complete(_isPagesLoaded!);
    }
    eventBus.dispatch('outlineloaded', <String, Object?>{
      'source': this,
      'outlineCount': count,
      'currentOutlineItemPromise': completer.future,
    });
  }

  @override
  void bindLink(web.HTMLAnchorElement element, Map<String, dynamic> item) {
    final url = item['url'];
    if (url is String && url.isNotEmpty) {
      linkService.addLinkAttributes(
        HtmlAnchorElementAdapter(element),
        url,
        newWindow: item['newWindow'] == true,
      );
      return;
    }
    final action = item['action'];
    if (action is String && action.isNotEmpty) {
      element.href = linkService.getAnchorUrl('');
      element.onclick = ((web.MouseEvent event) {
        event.preventDefault();
        linkService.executeNamedAction(action);
      }).toJS;
      return;
    }
    final attachment = item['attachment'];
    if (attachment is Map) {
      element.href = linkService.getAnchorUrl('');
      element.onclick = ((web.MouseEvent event) {
        event.preventDefault();
        downloadManager.openOrDownloadData(
          attachment['content'],
          attachment['filename']?.toString() ?? '',
        );
      }).toJS;
      return;
    }
    final setOCGState = item['setOCGState'];
    if (setOCGState is Map) {
      element.href = linkService.getAnchorUrl('');
      element.onclick = ((web.MouseEvent event) {
        event.preventDefault();
        unawaited(linkService.executeSetOCGState(
          Map<String, dynamic>.from(setOCGState),
        ));
      }).toJS;
      return;
    }

    final destination = item['dest'];
    element.href = linkService.getDestinationHash(destination);
    element.onclick = ((web.MouseEvent event) {
      event.preventDefault();
      updateCurrentTreeItem(element.parentElement as web.HTMLDivElement?);
      if (destination != null) {
        unawaited(linkService.goToDestination(destination));
      }
    }).toJS;
  }

  void _setStyles(web.HTMLAnchorElement element, Map<String, dynamic> item) {
    if (item['bold'] == true) element.style.fontWeight = 'bold';
    if (item['italic'] == true) element.style.fontStyle = 'italic';
  }

  void _addOutlineToggleButton(
    web.HTMLDivElement div,
    Map<String, dynamic> item,
  ) {
    var hidden = false;
    final count = item['count'];
    final items = _itemsOf(item);
    if (count is num && count < 0) {
      var totalCount = items.length;
      final queue = List<Map<String, dynamic>>.of(items);
      while (queue.isNotEmpty) {
        final child = queue.removeAt(0);
        final nestedCount = child['count'];
        final nestedItems = _itemsOf(child);
        if (nestedCount is num && nestedCount > 0 && nestedItems.isNotEmpty) {
          totalCount += nestedItems.length;
          queue.addAll(nestedItems);
        }
      }
      hidden = count.abs() == totalCount;
    }
    addToggleButton(div, hidden: hidden);
  }

  @override
  void toggleAllTreeItems() {
    if (_outline == null) return;
    super.toggleAllTreeItems();
  }

  /// Renders [outline], accepting the map-shaped values returned by Catalog.
  void render({
    required List<dynamic>? outline,
    required OutlineDocument? document,
  }) {
    if (_outline != null) reset();
    _outline = outline
        ?.whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    pdfDocument = document;
    if (_outline == null || _outline!.isEmpty) {
      dispatchLoadedEvent(0);
      return;
    }

    final fragment = web.document.createDocumentFragment();
    final queue = <_OutlineLevel>[
      _OutlineLevel(fragment, _outline!),
    ];
    var outlineCount = 0;
    var hasAnyNesting = false;
    while (queue.isNotEmpty) {
      final level = queue.removeAt(0);
      for (final item in level.items) {
        final div = web.document.createElement('div') as web.HTMLDivElement;
        div.className = 'treeItem';
        final link = web.document.createElement('a') as web.HTMLAnchorElement;
        bindLink(link, item);
        _setStyles(link, item);
        link.textContent = normalizeTextContent(item['title']);
        div.append(link);

        final items = _itemsOf(item);
        if (items.isNotEmpty) {
          hasAnyNesting = true;
          _addOutlineToggleButton(div, item);
          final itemsDiv =
              web.document.createElement('div') as web.HTMLDivElement;
          itemsDiv.className = 'treeItems';
          div.append(itemsDiv);
          queue.add(_OutlineLevel(itemsDiv, items));
        }
        level.parent.appendChild(div);
        outlineCount++;
      }
    }
    finishRendering(
      fragment,
      outlineCount,
      hasAnyNesting: hasAnyNesting,
    );
  }

  Future<void> _currentOutlineItem() async {
    if (_isPagesLoaded != true) {
      throw StateError('_currentOutlineItem: All pages have not been loaded.');
    }
    final outline = _outline;
    final document = pdfDocument;
    if (outline == null || document is! OutlineDocument) return;
    final pageNumberToDestHash = await _getPageNumberToDestHash(document);
    if (pageNumberToDestHash == null) return;
    updateCurrentTreeItem();
    if (_sidebarView != SidebarView.outline) return;
    for (var page = _currentPageNumber; page > 0; page--) {
      final hash = pageNumberToDestHash[page];
      if (hash == null) continue;
      final links = container.querySelectorAll('a');
      for (var index = 0; index < links.length; index++) {
        final link = links.item(index);
        if (link is web.HTMLAnchorElement &&
            link.getAttribute('href') == hash) {
          scrollToCurrentTreeItem(link.parentElement as web.HTMLDivElement?);
          return;
        }
      }
    }
  }

  Future<Map<int, String>?> _getPageNumberToDestHash(
    OutlineDocument document,
  ) {
    return _pageNumberToDestHashFuture ??= _buildPageNumberToDestHash(document);
  }

  Future<Map<int, String>?> _buildPageNumberToDestHash(
    OutlineDocument document,
  ) async {
    final result = <int, String>{};
    final nestingByPage = <int, int>{};
    final queue = <_OutlineNesting>[
      _OutlineNesting(0, _outline ?? const []),
    ];
    while (queue.isNotEmpty) {
      final level = queue.removeAt(0);
      for (final item in level.items) {
        final destination = item['dest'];
        List<dynamic>? explicitDestination;
        if (destination is String) {
          explicitDestination = await document.getDestination(destination);
          if (!identical(document, pdfDocument)) return null;
        } else if (destination is List) {
          explicitDestination = List<dynamic>.from(destination);
        }
        if (explicitDestination != null && explicitDestination.isNotEmpty) {
          final reference = explicitDestination.first;
          int? pageNumber;
          if (reference != null && reference is! num) {
            pageNumber = document.cachedPageNumber(reference);
          } else if (reference is int) {
            pageNumber = reference + 1;
          }
          if (pageNumber != null &&
              (!result.containsKey(pageNumber) ||
                  level.nesting > (nestingByPage[pageNumber] ?? -1))) {
            result[pageNumber] = linkService.getDestinationHash(destination);
            nestingByPage[pageNumber] = level.nesting;
          }
        }
        final items = _itemsOf(item);
        if (items.isNotEmpty) {
          queue.add(_OutlineNesting(level.nesting + 1, items));
        }
      }
    }
    return result.isEmpty ? null : result;
  }
}

/// Extra document state needed by outline synchronization.
abstract interface class OutlineDocument implements PDFLinkDocument {
  bool get disableAutoFetch;
}

Object? _eventValue(Object? event, String key) {
  if (event is Map) return event[key];
  return null;
}

List<Map<String, dynamic>> _itemsOf(Map<String, dynamic> item) {
  final items = item['items'];
  if (items is! List) return const [];
  return items
      .whereType<Map>()
      .map((child) => Map<String, dynamic>.from(child))
      .toList();
}

final class _OutlineLevel {
  const _OutlineLevel(this.parent, this.items);
  final web.Node parent;
  final List<Map<String, dynamic>> items;
}

final class _OutlineNesting {
  const _OutlineNesting(this.nesting, this.items);
  final int nesting;
  final List<Map<String, dynamic>> items;
}
