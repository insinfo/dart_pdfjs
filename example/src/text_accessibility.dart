// Copyright 2022 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.
// Ported from pdf.js/web/text_accessibility.js.

import 'package:web/web.dart' as web;

import 'text_layer_builder.dart';
import 'ui_utils.dart';

/// Associates annotations/editors with text in visual reading order.
final class TextAccessibilityManager implements TextAccessibilityController {
  bool _enabled = false;
  List<web.HTMLElement>? _textChildren;
  final Map<String, int> _textNodes = {};
  final Map<web.HTMLElement, bool> _waitingElements = {};

  bool get enabled => _enabled;

  @override
  void setTextMapping(List<web.HTMLElement> textDivs) {
    _textChildren = textDivs;
  }

  @override
  void enable() {
    if (_enabled) {
      throw StateError('TextAccessibilityManager is already enabled.');
    }
    final children = _textChildren;
    if (children == null) {
      throw StateError('Text divs have not been set.');
    }
    _enabled = true;
    _textChildren = List.of(children)..sort(compareElementPositions);

    for (final entry in _textNodes.entries.toList()) {
      final element = web.document.getElementById(entry.key);
      if (element == null) {
        _textNodes.remove(entry.key);
        continue;
      }
      final ordered = _textChildren!;
      if (entry.value < ordered.length) {
        _addIdToAriaOwns(entry.key, ordered[entry.value]);
      }
    }
    for (final entry in _waitingElements.entries.toList()) {
      addPointerInTextLayer(entry.key, isRemovable: entry.value);
    }
    _waitingElements.clear();
  }

  @override
  void disable() {
    if (!_enabled) return;
    _waitingElements.clear();
    _textChildren = null;
    _enabled = false;
  }

  void removePointerInTextLayer(web.HTMLElement element) {
    if (!_enabled) {
      _waitingElements.remove(element);
      return;
    }
    final children = _textChildren;
    if (children == null || children.isEmpty) return;
    final id = element.id;
    final nodeIndex = _textNodes.remove(id);
    if (nodeIndex == null || nodeIndex >= children.length) return;
    final node = children[nodeIndex];
    final owns = node.getAttribute('aria-owns');
    if (owns == null) return;
    final values =
        owns.split(RegExp(r'\s+')).where((value) => value != id).toList();
    if (values.isEmpty) {
      node
        ..removeAttribute('aria-owns')
        ..setAttribute('role', 'presentation');
    } else {
      node.setAttribute('aria-owns', values.join(' '));
    }
  }

  String? addPointerInTextLayer(
    web.HTMLElement element, {
    required bool isRemovable,
  }) {
    final id = element.id;
    if (id.isEmpty) return null;
    if (!_enabled) {
      _waitingElements[element] = isRemovable;
      return null;
    }
    if (isRemovable) removePointerInTextLayer(element);
    final children = _textChildren;
    if (children == null || children.isEmpty) return null;
    final index = binarySearchFirstItem(
      children,
      (node) => compareElementPositions(element, node) < 0,
    );
    final nodeIndex = (index - 1).clamp(0, children.length - 1);
    final child = children[nodeIndex];
    _addIdToAriaOwns(id, child);
    _textNodes[id] = nodeIndex;
    final parent = child.parentElement;
    return parent?.classList.contains('markedContent') == true
        ? parent!.id
        : null;
  }

  String? moveElementInDOM(
    web.HTMLElement container,
    web.HTMLElement element,
    web.HTMLElement contentElement, {
    required bool isRemovable,
  }) {
    final structId = addPointerInTextLayer(
      contentElement,
      isRemovable: isRemovable,
    );
    if (!container.hasChildNodes()) {
      container.append(element);
      return structId;
    }
    final children = <web.HTMLElement>[];
    for (var index = 0; index < container.children.length; index++) {
      final child = container.children.item(index);
      if (child is web.HTMLElement && child != element) children.add(child);
    }
    if (children.isEmpty) return structId;
    final index = binarySearchFirstItem(
      children,
      (node) => compareElementPositions(element, node) < 0,
    );
    if (index == 0) {
      container.insertBefore(element, children.first);
    } else if (index >= children.length) {
      container.append(element);
    } else {
      container.insertBefore(element, children[index]);
    }
    return structId;
  }

  static void _addIdToAriaOwns(String id, web.HTMLElement node) {
    final owns = node.getAttribute('aria-owns');
    final ids = owns
            ?.split(RegExp(r'\s+'))
            .where((value) => value.isNotEmpty)
            .toSet() ??
        <String>{};
    if (ids.add(id)) node.setAttribute('aria-owns', ids.join(' '));
    node.removeAttribute('role');
  }

  /// Visual-order comparator shared by pointer placement and DOM reordering.
  static int compareElementPositions(web.Element first, web.Element second) {
    final firstRect = first.getBoundingClientRect();
    final secondRect = second.getBoundingClientRect();
    if (firstRect.width == 0 && firstRect.height == 0) return 1;
    if (secondRect.width == 0 && secondRect.height == 0) return -1;
    final firstMiddle = firstRect.y + firstRect.height / 2;
    final secondMiddle = secondRect.y + secondRect.height / 2;
    if (firstMiddle <= secondRect.y && secondMiddle >= firstRect.bottom) {
      return -1;
    }
    if (secondMiddle <= firstRect.y && firstMiddle >= secondRect.bottom) {
      return 1;
    }
    final delta = (firstRect.x + firstRect.width / 2) -
        (secondRect.x + secondRect.width / 2);
    return delta.sign.toInt();
  }
}
