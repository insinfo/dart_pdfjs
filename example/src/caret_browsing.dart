// Copyright 2024 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.
// Ported from pdf.js/web/caret_browsing.js.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

const double _precision = .1;

extension type _CaretPosition._(JSObject _) implements JSObject {
  external web.Node? get offsetNode;
  external int get offset;
}

/// Implements vertical caret movement within and between page text layers.
final class CaretBrowsingMode {
  CaretBrowsingMode(
    web.AbortSignal abortSignal,
    this.mainContainer,
    this.viewerContainer, [
    web.HTMLElement? toolbarContainer,
  ]) {
    if (toolbarContainer == null) return;
    _toolbarHeight = toolbarContainer.getBoundingClientRect().height.floor();
    _toolbarObserver = web.ResizeObserver(
        ((JSArray<web.ResizeObserverEntry> entries,
            web.ResizeObserver observer) {
      for (final entry in entries.toDart) {
        if (entry.target == toolbarContainer) {
          _toolbarHeight = entry.contentRect.height.floor();
          break;
        }
      }
    }).toJS);
    _toolbarObserver!.observe(toolbarContainer);
    abortSignal.addEventListener(
        'abort',
        ((web.Event _) {
          _toolbarObserver?.disconnect();
          _toolbarObserver = null;
        }).toJS,
        web.AddEventListenerOptions(once: true));
  }

  final web.HTMLElement mainContainer;
  final web.HTMLElement viewerContainer;
  int _toolbarHeight = 0;
  web.ResizeObserver? _toolbarObserver;

  int get toolbarHeight => _toolbarHeight;

  bool isOnSameLine(web.DOMRect first, web.DOMRect second) {
    final firstMiddle = first.y + first.height / 2;
    final secondMiddle = second.y + second.height / 2;
    return (first.y <= secondMiddle && secondMiddle <= first.bottom) ||
        (second.y <= firstMiddle && firstMiddle <= second.bottom);
  }

  bool isUnderOrOver(
    web.DOMRect rect,
    double x,
    double y, {
    required bool isUp,
  }) {
    final middleY = rect.y + rect.height / 2;
    return (isUp ? y >= middleY : y <= middleY) &&
        rect.x - _precision <= x &&
        x <= rect.right + _precision;
  }

  bool isVisible(web.DOMRect rect) {
    final viewportHeight = web.window.innerHeight;
    final viewportWidth = web.window.innerWidth;
    return rect.top >= _toolbarHeight &&
        rect.left >= 0 &&
        rect.bottom <= viewportHeight &&
        rect.right <= viewportWidth;
  }

  (double, double)? getCaretPosition(web.Selection selection, bool isUp) {
    final focusNode = selection.focusNode;
    if (focusNode == null) return null;
    final range = web.document.createRange()
      ..setStart(focusNode, selection.focusOffset)
      ..setEnd(focusNode, selection.focusOffset);
    final rect = range.getBoundingClientRect();
    return (rect.x, isUp ? rect.top : rect.bottom);
  }

  void moveCaret({required bool isUp, required bool select}) {
    final selection = web.document.getSelection();
    if (selection == null || selection.rangeCount == 0) return;
    final focusNode = selection.focusNode;
    if (focusNode == null) return;
    // Web extension types don't support reliable runtime `is` checks after
    // JavaScript compilation. Inspect nodeType before calling Element APIs.
    final focusElement = focusNode.nodeType == web.Node.ELEMENT_NODE
        ? focusNode as web.Element
        : focusNode.parentElement;
    final root = focusElement?.closest('.textLayer');
    if (focusElement == null || root == null) return;
    final walker = web.document.createTreeWalker(root, 4);
    walker.currentNode = focusNode;
    final focusRect = focusElement.getBoundingClientRect();
    web.HTMLElement? newLineElement;

    web.Node? nextNode() =>
        isUp ? walker.previousSibling() : walker.nextSibling();
    while (nextNode() != null) {
      final element = walker.currentNode.parentElement;
      if (element is web.HTMLElement &&
          !isOnSameLine(focusRect, element.getBoundingClientRect())) {
        newLineElement = element;
        break;
      }
    }
    if (newLineElement == null) {
      final nextPageNode = _getNodeOnNextPage(root, isUp);
      if (nextPageNode == null) return;
      if (select) {
        final boundary =
            (isUp ? walker.firstChild() : walker.lastChild()) ?? focusNode;
        selection.extend(boundary, isUp ? 0 : _nodeLength(boundary));
        final range = web.document.createRange();
        final offset = isUp ? _nodeLength(nextPageNode) : 0;
        range
          ..setStart(nextPageNode, offset)
          ..setEnd(nextPageNode, offset);
        selection.addRange(range);
        return;
      }
      final caret = getCaretPosition(selection, isUp);
      final parent = nextPageNode.parentElement;
      if (caret != null && parent is web.HTMLElement) {
        _setCaretPosition(
          select,
          selection,
          parent,
          parent.getBoundingClientRect(),
          caret.$1,
        );
      }
      return;
    }

    final caret = getCaretPosition(selection, isUp);
    if (caret == null) return;
    var candidate = newLineElement;
    final lineRect = candidate.getBoundingClientRect();
    if (isUnderOrOver(lineRect, caret.$1, caret.$2, isUp: isUp)) {
      _setCaretPosition(select, selection, candidate, lineRect, caret.$1);
      return;
    }
    while (nextNode() != null) {
      final element = walker.currentNode.parentElement;
      if (element is! web.HTMLElement) continue;
      final rect = element.getBoundingClientRect();
      if (!isOnSameLine(lineRect, rect)) break;
      if (isUnderOrOver(rect, caret.$1, caret.$2, isUp: isUp)) {
        candidate = element;
        _setCaretPosition(select, selection, candidate, rect, caret.$1);
        return;
      }
    }
    _setCaretPosition(select, selection, candidate, lineRect, caret.$1);
  }

  web.Node? _getNodeOnNextPage(web.Element textLayer, bool isUp) {
    web.Element? current = textLayer;
    while (current != null) {
      final page = current.closest('.page');
      final pageNumber =
          int.tryParse(page?.getAttribute('data-page-number') ?? '');
      if (pageNumber == null) return null;
      final nextPage = isUp ? pageNumber - 1 : pageNumber + 1;
      current = viewerContainer.querySelector(
        '.page[data-page-number="$nextPage"] .textLayer',
      );
      if (current == null) return null;
      final walker = web.document.createTreeWalker(current, 4);
      final node = isUp ? walker.lastChild() : walker.firstChild();
      if (node != null) return node;
    }
    return null;
  }

  void _setCaretPosition(
    bool select,
    web.Selection selection,
    web.HTMLElement element,
    web.DOMRect rect,
    double caretX,
  ) {
    if (isVisible(rect)) {
      _setCaretPositionHelper(selection, caretX, select, element, rect);
      return;
    }
    late final web.EventListener listener;
    listener = ((web.Event _) {
      mainContainer.removeEventListener('scrollend', listener);
      _setCaretPositionHelper(selection, caretX, select, element, null);
    }).toJS;
    mainContainer.addEventListener('scrollend', listener);
    element.scrollIntoView();
  }

  void _setCaretPositionHelper(
    web.Selection selection,
    double caretX,
    bool select,
    web.HTMLElement element,
    web.DOMRect? suppliedRect,
  ) {
    final first = element.firstChild;
    final last = element.lastChild;
    if (first == null || last == null) return;
    final rect = suppliedRect ?? element.getBoundingClientRect();
    if (caretX <= rect.x + _precision) {
      _setSelection(selection, first, 0, select);
      return;
    }
    if (rect.right - _precision <= caretX) {
      _setSelection(selection, last, _nodeLength(last), select);
      return;
    }
    final caret = web.document.caretPositionFromPoint(
      caretX,
      rect.y + rect.height / 2,
    );
    final position = caret == null ? null : _CaretPosition._(caret);
    final target = position?.offsetNode;
    if (target == null || target.parentElement != element) {
      _setSelection(selection, first, 0, select);
      return;
    }
    _setSelection(selection, target, position!.offset, select);
  }

  static void _setSelection(
    web.Selection selection,
    web.Node node,
    int offset,
    bool select,
  ) {
    if (select) {
      selection.extend(node, offset);
    } else {
      selection.setPosition(node, offset);
    }
  }

  static int _nodeLength(web.Node node) =>
      node is web.CharacterData ? node.length : node.childNodes.length;
}
