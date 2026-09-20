// Copyright 2021 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.
// Ported from pdf.js/web/text_highlighter.js.

import 'package:web/web.dart' as web;

import 'event_utils.dart';
import 'pdf_find_controller.dart';
import 'text_layer_builder.dart';

/// Read-only find state needed by [TextHighlighter].
abstract interface class TextHighlighterFindController {
  bool get highlightMatches;
  bool get highlightAll;
  int get selectedPageIndex;
  int get selectedMatchIndex;
  List<int>? matchesForPage(int pageIndex);
  List<int>? matchLengthsForPage(int pageIndex);
  void scrollMatchIntoView({
    required web.HTMLElement element,
    required int pageIndex,
    required int matchIndex,
  });
}

/// Adapts the viewer find controller without exposing its mutable internals.
final class PDFFindHighlighterAdapter implements TextHighlighterFindController {
  const PDFFindHighlighterAdapter(this.controller);

  final PDFFindController controller;

  @override
  bool get highlightMatches => controller.highlightMatches;
  @override
  bool get highlightAll => controller.state?.highlightAll ?? false;
  @override
  int get selectedPageIndex => controller.selected.pageIndex;
  @override
  int get selectedMatchIndex => controller.selected.matchIndex;
  @override
  List<int>? matchesForPage(int pageIndex) =>
      pageIndex < controller.pageMatches.length
          ? controller.pageMatches[pageIndex]
          : null;
  @override
  List<int>? matchLengthsForPage(int pageIndex) =>
      pageIndex < controller.pageMatchesLength.length
          ? controller.pageMatchesLength[pageIndex]
          : null;

  @override
  void scrollMatchIntoView({
    required web.HTMLElement element,
    required int pageIndex,
    required int matchIndex,
  }) {
    controller.scrollMatchIntoView(
      element: _ScrollableElement(element),
      pageIndex: pageIndex,
      matchIndex: matchIndex,
    );
  }
}

final class _ScrollableElement implements FindScrollableElement {
  const _ScrollableElement(this.element);
  final web.HTMLElement element;

  @override
  void scrollIntoView({String block = 'start', String inline = 'center'}) {
    element.scrollIntoView();
  }
}

final class TextMatchPosition {
  const TextMatchPosition({required this.divIndex, required this.offset});
  final int divIndex;
  final int offset;
}

final class TextMatch {
  const TextMatch({required this.begin, required this.end});
  final TextMatchPosition begin;
  final TextMatchPosition end;
}

/// Highlights search matches across text-layer spans and XFA text nodes.
final class TextHighlighter implements TextHighlighterController {
  TextHighlighter({
    required this.findController,
    required this.eventBus,
    required this.pageIndex,
  });

  final TextHighlighterFindController findController;
  final EventBus eventBus;
  final int pageIndex;
  List<TextMatch> matches = [];
  List<web.Node>? textDivs;
  List<String>? textContentItemsStr;
  bool enabled = false;
  void Function(Object?)? _eventListener;

  @override
  void setTextMapping(List<web.Node> textDivs, List<String> texts) {
    if (textDivs.length != texts.length) {
      throw ArgumentError('Text divs and strings must have equal lengths.');
    }
    this.textDivs = textDivs;
    textContentItemsStr = texts;
  }

  @override
  void enable() {
    if (textDivs == null || textContentItemsStr == null) {
      throw StateError('Text divs and strings have not been set.');
    }
    if (enabled) throw StateError('TextHighlighter is already enabled.');
    enabled = true;
    _eventListener ??= (Object? event) {
      final eventPage = event is Map ? event['pageIndex'] : null;
      if (eventPage == pageIndex || eventPage == -1) updateMatches();
    };
    eventBus.internalOn('updatetextlayermatches', _eventListener!);
    updateMatches();
  }

  @override
  void disable() {
    if (!enabled) return;
    enabled = false;
    final listener = _eventListener;
    if (listener != null) {
      eventBus.internalOff('updatetextlayermatches', listener);
      _eventListener = null;
    }
    updateMatches(reset: true);
  }

  List<TextMatch> convertMatches(List<int>? positions, List<int>? lengths) {
    if (positions == null || lengths == null || positions.isEmpty) return [];
    if (positions.length != lengths.length) {
      throw ArgumentError('Match positions and lengths must correspond.');
    }
    final texts = textContentItemsStr!;
    if (texts.isEmpty) return [];
    var item = 0;
    var itemStart = 0;
    final end = texts.length - 1;
    final result = <TextMatch>[];
    for (var matchIndex = 0; matchIndex < positions.length; matchIndex++) {
      var position = positions[matchIndex];
      while (item != end && position >= itemStart + texts[item].length) {
        itemStart += texts[item].length;
        item++;
      }
      final begin = TextMatchPosition(
        divIndex: item,
        offset: (position - itemStart).clamp(0, texts[item].length),
      );
      position += lengths[matchIndex];
      while (item != end && position > itemStart + texts[item].length) {
        itemStart += texts[item].length;
        item++;
      }
      result.add(TextMatch(
        begin: begin,
        end: TextMatchPosition(
          divIndex: item,
          offset: (position - itemStart).clamp(0, texts[item].length),
        ),
      ));
    }
    return result;
  }

  void updateMatches({bool reset = false}) {
    if (!enabled && !reset) return;
    final nodes = textDivs!;
    final texts = textContentItemsStr!;
    var clearedUntil = -1;
    for (final match in matches) {
      final begin = match.begin.divIndex > clearedUntil
          ? match.begin.divIndex
          : clearedUntil;
      for (var index = begin; index <= match.end.divIndex; index++) {
        final node = nodes[index];
        node.textContent = texts[index];
        if (node is web.Element) node.className = '';
      }
      clearedUntil = match.end.divIndex + 1;
    }
    matches = [];
    if (!findController.highlightMatches || reset) return;
    matches = convertMatches(
      findController.matchesForPage(pageIndex),
      findController.matchLengthsForPage(pageIndex),
    );
    _renderMatches(matches);
  }

  void _renderMatches(List<TextMatch> matches) {
    if (matches.isEmpty) return;
    final nodes = textDivs!;
    final texts = textContentItemsStr!;
    final selectedPage = pageIndex == findController.selectedPageIndex;
    final selectedIndex = findController.selectedMatchIndex;
    var first = selectedIndex;
    var last = first + 1;
    if (findController.highlightAll) {
      first = 0;
      last = matches.length;
    } else if (!selectedPage || first < 0 || first >= matches.length) {
      return;
    }
    TextMatchPosition? previousEnd;
    var lastDiv = -1;
    var lastOffset = -1;
    for (var index = first; index < last; index++) {
      final match = matches[index];
      if (match.begin.divIndex == lastDiv && match.begin.offset == lastOffset) {
        continue;
      }
      lastDiv = match.begin.divIndex;
      lastOffset = match.begin.offset;
      final selected = selectedPage && index == selectedIndex;
      final suffix = selected ? ' selected' : '';
      web.HTMLElement? selectedSpan;
      if (previousEnd == null || match.begin.divIndex != previousEnd.divIndex) {
        if (previousEnd != null) {
          _appendText(nodes, texts, previousEnd.divIndex, previousEnd.offset,
              null, null);
        }
        _beginText(nodes, texts, match.begin, null);
      } else {
        _appendText(
          nodes,
          texts,
          previousEnd.divIndex,
          previousEnd.offset,
          match.begin.offset,
          null,
        );
      }
      if (match.begin.divIndex == match.end.divIndex) {
        selectedSpan = _appendText(
          nodes,
          texts,
          match.begin.divIndex,
          match.begin.offset,
          match.end.offset,
          'highlight$suffix',
        );
      } else {
        selectedSpan = _appendText(
          nodes,
          texts,
          match.begin.divIndex,
          match.begin.offset,
          null,
          'highlight begin$suffix',
        );
        for (var middle = match.begin.divIndex + 1;
            middle < match.end.divIndex;
            middle++) {
          final element = _ensureElement(nodes, middle);
          element.className = 'highlight middle$suffix';
        }
        _beginText(nodes, texts, match.end, 'highlight end$suffix');
      }
      previousEnd = match.end;
      if (selected && selectedSpan != null) {
        findController.scrollMatchIntoView(
          element: selectedSpan,
          pageIndex: pageIndex,
          matchIndex: selectedIndex,
        );
      }
    }
    if (previousEnd != null) {
      _appendText(
          nodes, texts, previousEnd.divIndex, previousEnd.offset, null, null);
    }
  }

  web.HTMLElement? _beginText(
    List<web.Node> nodes,
    List<String> texts,
    TextMatchPosition begin,
    String? className,
  ) {
    final element = _ensureElement(nodes, begin.divIndex);
    element.textContent = '';
    return _appendText(
        nodes, texts, begin.divIndex, 0, begin.offset, className);
  }

  web.HTMLElement? _appendText(
    List<web.Node> nodes,
    List<String> texts,
    int divIndex,
    int from,
    int? to,
    String? className,
  ) {
    final element = _ensureElement(nodes, divIndex);
    final text = texts[divIndex];
    final content =
        text.substring(from.clamp(0, text.length), to?.clamp(0, text.length));
    final textNode = web.document.createTextNode(content);
    if (className == null || className.isEmpty) {
      element.append(textNode);
      return null;
    }
    final span = web.document.createElement('span') as web.HTMLSpanElement;
    span.className = '$className appended';
    span.append(textNode);
    element.append(span);
    return className.contains('selected') ? span : null;
  }

  web.HTMLElement _ensureElement(List<web.Node> nodes, int index) {
    final node = nodes[index];
    if (node is web.HTMLElement) return node;
    final span = web.document.createElement('span') as web.HTMLSpanElement;
    node.parentNode?.insertBefore(span, node);
    span.append(node);
    nodes[index] = span;
    return span;
  }
}
