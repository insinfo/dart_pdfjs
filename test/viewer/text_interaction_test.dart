@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/caret_browsing.dart';
import '../../example/src/event_utils.dart';
import '../../example/src/text_accessibility.dart';
import '../../example/src/text_highlighter.dart';

final class FakeFindController implements TextHighlighterFindController {
  @override
  bool highlightMatches = true;
  @override
  bool highlightAll = true;
  @override
  int selectedPageIndex = 0;
  @override
  int selectedMatchIndex = 0;
  final Map<int, List<int>> pageMatches = {};
  final Map<int, List<int>> pageLengths = {};
  web.HTMLElement? scrolledElement;

  @override
  List<int>? matchLengthsForPage(int pageIndex) => pageLengths[pageIndex];
  @override
  List<int>? matchesForPage(int pageIndex) => pageMatches[pageIndex];
  @override
  void scrollMatchIntoView({
    required web.HTMLElement element,
    required int pageIndex,
    required int matchIndex,
  }) {
    scrolledElement = element;
  }
}

web.HTMLSpanElement span(String text, [String id = '']) {
  final element = web.document.createElement('span') as web.HTMLSpanElement;
  element
    ..textContent = text
    ..id = id;
  return element;
}

void main() {
  group('TextHighlighter', () {
    test('converts matches spanning multiple text nodes', () {
      final highlighter = TextHighlighter(
        findController: FakeFindController(),
        eventBus: EventBus(),
        pageIndex: 0,
      );
      highlighter.setTextMapping(
        <web.Node>[span('abc'), span('def'), span('ghi')],
        const ['abc', 'def', 'ghi'],
      );
      final matches = highlighter.convertMatches([2, 6], [3, 2]);
      expect(matches, hasLength(2));
      expect(matches.first.begin.divIndex, 0);
      expect(matches.first.begin.offset, 2);
      expect(matches.first.end.divIndex, 1);
      expect(matches.first.end.offset, 2);
      expect(matches.last.begin.divIndex, 2);
      expect(matches.last.begin.offset, 0);
    });

    test('renders begin/middle/end highlights and restores original text', () {
      final find = FakeFindController()
        ..pageMatches[0] = [1]
        ..pageLengths[0] = [7];
      final nodes = <web.Node>[span('abc'), span('def'), span('ghi')];
      final highlighter = TextHighlighter(
        findController: find,
        eventBus: EventBus(),
        pageIndex: 0,
      )..setTextMapping(nodes, const ['abc', 'def', 'ghi']);
      highlighter.enable();
      expect((nodes[0] as web.Element).querySelector('.highlight.begin'),
          isNotNull);
      expect((nodes[1] as web.Element).className, contains('highlight middle'));
      expect(
          (nodes[2] as web.Element).querySelector('.highlight.end'), isNotNull);
      expect(find.scrolledElement?.className, contains('selected'));
      highlighter.disable();
      expect(nodes.map((node) => node.textContent).toList(),
          ['abc', 'def', 'ghi']);
      expect(highlighter.enabled, isFalse);
    });

    test('responds only to matching page events', () {
      final bus = EventBus();
      final find = FakeFindController()
        ..pageMatches[1] = [0]
        ..pageLengths[1] = [1];
      final node = span('word');
      final highlighter = TextHighlighter(
        findController: find,
        eventBus: bus,
        pageIndex: 1,
      )..setTextMapping(<web.Node>[node], const ['word']);
      highlighter.enable();
      node.textContent = 'sentinel';
      bus.dispatch('updatetextlayermatches', {'pageIndex': 0});
      expect(node.textContent, 'sentinel');
      bus.dispatch('updatetextlayermatches', {'pageIndex': -1});
      expect(node.querySelector('.highlight'), isNotNull);
      highlighter.disable();
    });

    test('rejects invalid lifecycle and mapping', () {
      final highlighter = TextHighlighter(
        findController: FakeFindController(),
        eventBus: EventBus(),
        pageIndex: 0,
      );
      expect(highlighter.enable, throwsStateError);
      expect(
        () => highlighter.setTextMapping(<web.Node>[span('a')], const []),
        throwsArgumentError,
      );
    });
  });

  group('TextAccessibilityManager', () {
    test('queues pointers before enable and restores presentation on removal',
        () {
      final host = web.document.createElement('div') as web.HTMLDivElement;
      final text = span('text')..setAttribute('role', 'presentation');
      final annotation = span('', 'annotation-1');
      host
        ..append(text)
        ..append(annotation);
      web.document.body?.append(host);
      addTearDown(() => host.remove());
      final manager = TextAccessibilityManager()..setTextMapping([text]);
      expect(
        manager.addPointerInTextLayer(annotation, isRemovable: false),
        isNull,
      );
      manager.enable();
      expect(text.getAttribute('aria-owns'), 'annotation-1');
      expect(text.hasAttribute('role'), isFalse);
      manager.removePointerInTextLayer(annotation);
      expect(text.hasAttribute('aria-owns'), isFalse);
      expect(text.getAttribute('role'), 'presentation');
      manager.disable();
      expect(manager.enabled, isFalse);
    });

    test('returns marked-content structure id', () {
      final marked = span('', 'marked')..className = 'markedContent';
      final text = span('text');
      marked.append(text);
      final annotation = span('', 'annotation-2');
      final manager = TextAccessibilityManager()
        ..setTextMapping([text])
        ..enable();
      expect(
        manager.addPointerInTextLayer(annotation, isRemovable: false),
        'marked',
      );
    });

    test('moves an element without duplicating it', () {
      final container = web.document.createElement('div') as web.HTMLDivElement;
      final first = span('first');
      final moving = span('moving');
      container
        ..append(first)
        ..append(moving);
      final manager = TextAccessibilityManager()
        ..setTextMapping([first])
        ..enable();
      manager.moveElementInDOM(
        container,
        moving,
        moving,
        isRemovable: true,
      );
      expect(container.querySelectorAll('span').length, 2);
    });

    test('guards lifecycle misuse', () {
      final manager = TextAccessibilityManager();
      expect(manager.enable, throwsStateError);
      manager.setTextMapping([]);
      manager.enable();
      expect(manager.enable, throwsStateError);
    });
  });

  group('CaretBrowsingMode', () {
    late web.HTMLDivElement mainContainer;
    late web.HTMLDivElement viewerContainer;
    late web.AbortController abortController;

    setUp(() {
      mainContainer = web.document.createElement('div') as web.HTMLDivElement;
      viewerContainer = web.document.createElement('div') as web.HTMLDivElement;
      mainContainer.append(viewerContainer);
      web.document.body?.append(mainContainer);
      abortController = web.AbortController();
    });
    tearDown(() {
      abortController.abort();
      mainContainer.remove();
      web.document.getSelection()?.removeAllRanges();
    });

    test('geometry helpers follow line and vertical rules', () {
      final mode = CaretBrowsingMode(
        abortController.signal,
        mainContainer,
        viewerContainer,
      );
      final first = web.DOMRect(10, 10, 40, 10);
      final sameLine = web.DOMRect(60, 12, 20, 10);
      final below = web.DOMRect(10, 40, 40, 10);
      expect(mode.isOnSameLine(first, sameLine), isTrue);
      expect(mode.isOnSameLine(first, below), isFalse);
      expect(mode.isUnderOrOver(below, 20, 20, isUp: false), isTrue);
      expect(mode.isUnderOrOver(first, 100, 20, isUp: false), isFalse);
    });

    test('ignores selection outside a text layer', () {
      final outside = span('outside');
      mainContainer.append(outside);
      final selection = web.document.getSelection()!;
      final range = web.document.createRange()
        ..setStart(outside.firstChild!, 0)
        ..collapse(true);
      selection
        ..removeAllRanges()
        ..addRange(range);
      final mode = CaretBrowsingMode(
        abortController.signal,
        mainContainer,
        viewerContainer,
      );
      mode.moveCaret(isUp: false, select: false);
      expect(selection.focusNode, same(outside.firstChild));
    });

    test('crosses to the following page text layer', () {
      web.HTMLDivElement page(int number, String text) {
        final page = web.document.createElement('div') as web.HTMLDivElement;
        page
          ..className = 'page'
          ..setAttribute('data-page-number', '$number');
        final layer = web.document.createElement('div') as web.HTMLDivElement;
        layer.className = 'textLayer';
        layer.append(span(text));
        page.append(layer);
        return page;
      }

      final firstPage = page(1, 'first');
      final secondPage = page(2, 'second');
      viewerContainer
        ..append(firstPage)
        ..append(secondPage);
      final firstText = firstPage.querySelector('span')!.firstChild!;
      final selection = web.document.getSelection()!;
      selection.setPosition(firstText, 2);
      final mode = CaretBrowsingMode(
        abortController.signal,
        mainContainer,
        viewerContainer,
      );
      mode.moveCaret(isUp: false, select: true);
      expect(selection.rangeCount, greaterThanOrEqualTo(1));
    });
  });
}
