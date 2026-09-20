// Copyright 2020 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'event_utils.dart';
import 'l10n.dart';
import 'ui_utils.dart' show removeNullCharacters;

const String treeItemSelectedClass = 'selected';

/// Operations used by outline and attachment entries to open embedded data.
abstract interface class ViewerDownloadManager {
  void openOrDownloadData(Object? content, String filename);
}

/// Shared DOM tree behavior for the outline and attachment sidebars.
///
/// This is the Dart counterpart of PDF.js' `BaseTreeViewer`. Subclasses own
/// their data model and link behavior; this class owns expansion, selection,
/// localization observation and final insertion into the document.
abstract class BaseTreeViewer {
  BaseTreeViewer({
    required this.container,
    required this.eventBus,
    required L10n l10n,
  }) : _l10n = l10n {
    _resetBase();
  }

  final web.HTMLDivElement container;
  final EventBus eventBus;
  final L10n _l10n;

  /// Localization service exposed to specialized tree viewers.
  L10n get l10n => _l10n;

  Object? pdfDocument;
  bool lastToggleIsShow = true;
  web.HTMLDivElement? currentTreeItem;
  JSFunction? _treeClickListener;

  void _resetBase() {
    pdfDocument = null;
    lastToggleIsShow = true;
    currentTreeItem = null;
    container.textContent = '';
    container.classList.remove('withNesting');
    final listener = _treeClickListener;
    if (listener != null) {
      container.removeEventListener('click', listener);
      _treeClickListener = null;
    }
  }

  /// Clears both the data-independent DOM state and subclass state.
  void reset() => _resetBase();

  void dispatchLoadedEvent(int count);

  void bindLink(web.HTMLAnchorElement element, Map<String, dynamic> item);

  /// Converts control characters to spaces, and uses an en dash for an empty
  /// title. This matches PDF.js and avoids invisible tree entries.
  String normalizeTextContent(Object? value) {
    final normalized = removeNullCharacters(
      value?.toString() ?? '',
      replaceInvisible: true,
    );
    return normalized.isEmpty ? '\u2013' : normalized;
  }

  /// Prepends the standard expansion button to [div].
  void addToggleButton(web.HTMLDivElement div, {bool hidden = false}) {
    final toggler = web.document.createElement('div') as web.HTMLDivElement;
    toggler.className = 'treeItemToggler';
    if (hidden) toggler.classList.add('treeItemsHidden');
    div.prepend(toggler);
  }

  /// Expands or collapses every nested branch below [root].
  void toggleTreeItem(web.Element root, {bool show = false}) {
    _l10n.pause();
    try {
      lastToggleIsShow = show;
      final togglers = root.querySelectorAll('.treeItemToggler');
      for (var index = 0; index < togglers.length; index++) {
        final toggler = togglers.item(index);
        if (toggler is web.Element) {
          toggler.classList.toggle('treeItemsHidden', !show);
        }
      }
    } finally {
      _l10n.resume();
    }
  }

  void toggleAllTreeItems() {
    toggleTreeItem(container, show: !lastToggleIsShow);
  }

  /// Completes rendering and installs the delegated expansion listener.
  void finishRendering(
    web.DocumentFragment fragment,
    int count, {
    bool hasAnyNesting = false,
  }) {
    if (hasAnyNesting) {
      container.classList.add('withNesting');
      lastToggleIsShow = fragment.querySelector('.treeItemsHidden') == null;

      final listener = ((web.Event event) {
        final target = event.target;
        if (target is! web.Element ||
            !target.classList.contains('treeItemToggler')) {
          return;
        }
        event
          ..preventDefault()
          ..stopPropagation();
        target.classList.toggle('treeItemsHidden');
        if (event is web.MouseEvent && event.shiftKey) {
          final parent = target.parentElement;
          if (parent != null) {
            toggleTreeItem(
              parent,
              show: !target.classList.contains('treeItemsHidden'),
            );
          }
        }
      }).toJS;
      _treeClickListener = listener;
      container.addEventListener('click', listener);
    }

    _l10n.pause();
    try {
      container.append(fragment);
    } finally {
      _l10n.resume();
    }
    dispatchLoadedEvent(count);
  }

  void updateCurrentTreeItem([web.HTMLDivElement? treeItem]) {
    currentTreeItem?.classList.remove(treeItemSelectedClass);
    currentTreeItem = null;
    if (treeItem != null) {
      treeItem.classList.add(treeItemSelectedClass);
      currentTreeItem = treeItem;
    }
  }

  /// Opens every ancestor and scrolls the selected entry into view.
  void scrollToCurrentTreeItem(web.HTMLDivElement? treeItem) {
    if (treeItem == null) return;
    _l10n.pause();
    try {
      web.Node? currentNode = treeItem.parentNode;
      while (currentNode != null && !identical(currentNode, container)) {
        if (currentNode is web.Element &&
            currentNode.classList.contains('treeItem')) {
          currentNode.firstElementChild?.classList.remove('treeItemsHidden');
        }
        currentNode = currentNode.parentNode;
      }
    } finally {
      _l10n.resume();
    }
    updateCurrentTreeItem(treeItem);
    treeItem.scrollIntoView();
  }
}
