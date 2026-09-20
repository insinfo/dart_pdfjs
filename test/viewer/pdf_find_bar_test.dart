@TestOn('browser')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/event_utils.dart';
import '../../example/src/pdf_find_bar.dart';
import '../../example/src/pdf_find_controller.dart';

void main() {
  late web.HTMLDivElement host;
  late web.HTMLDivElement mainContainer;
  late web.HTMLDivElement barElement;
  late web.HTMLButtonElement toggleButton;
  late web.HTMLInputElement findField;
  late web.HTMLInputElement highlightAll;
  late web.HTMLInputElement caseSensitive;
  late web.HTMLInputElement matchDiacritics;
  late web.HTMLInputElement entireWord;
  late web.HTMLElement findMsg;
  late web.HTMLElement results;
  late web.HTMLButtonElement previousButton;
  late web.HTMLButtonElement nextButton;
  late EventBus eventBus;
  late PDFFindBar findBar;
  late List<Map> findEvents;
  late List<Map> closeEvents;

  setUp(() {
    host = web.document.createElement('div') as web.HTMLDivElement;
    mainContainer = web.document.createElement('div') as web.HTMLDivElement;
    barElement = web.document.createElement('div') as web.HTMLDivElement;
    toggleButton =
        web.document.createElement('button') as web.HTMLButtonElement;
    findField = web.document.createElement('input') as web.HTMLInputElement;
    highlightAll = web.document.createElement('input') as web.HTMLInputElement;
    caseSensitive = web.document.createElement('input') as web.HTMLInputElement;
    matchDiacritics =
        web.document.createElement('input') as web.HTMLInputElement;
    entireWord = web.document.createElement('input') as web.HTMLInputElement;
    findMsg = web.document.createElement('span') as web.HTMLElement;
    results = web.document.createElement('span') as web.HTMLElement;
    previousButton =
        web.document.createElement('button') as web.HTMLButtonElement;
    nextButton = web.document.createElement('button') as web.HTMLButtonElement;

    for (final checkbox in [
      highlightAll,
      caseSensitive,
      matchDiacritics,
      entireWord,
    ]) {
      checkbox.type = 'checkbox';
    }
    final firstRow = web.document.createElement('div') as web.HTMLDivElement;
    firstRow.append(findField);
    barElement
      ..classList.add('hidden')
      ..append(firstRow)
      ..append(highlightAll)
      ..append(caseSensitive)
      ..append(matchDiacritics)
      ..append(entireWord)
      ..append(findMsg)
      ..append(results)
      ..append(previousButton)
      ..append(nextButton);
    host
      ..append(toggleButton)
      ..append(barElement)
      ..append(mainContainer);
    web.document.body!.append(host);

    eventBus = EventBus();
    findEvents = <Map>[];
    closeEvents = <Map>[];
    eventBus
      ..on('find', (value) => findEvents.add(value as Map))
      ..on('findbarclose', (value) => closeEvents.add(value as Map));
    findBar = PDFFindBar(
      PDFFindBarOptions(
        bar: barElement,
        toggleButton: toggleButton,
        findField: findField,
        highlightAllCheckbox: highlightAll,
        caseSensitiveCheckbox: caseSensitive,
        matchDiacriticsCheckbox: matchDiacritics,
        entireWordCheckbox: entireWord,
        findMsg: findMsg,
        findResultsCount: results,
        findPreviousButton: previousButton,
        findNextButton: nextButton,
      ),
      mainContainer,
      eventBus,
    );
  });

  tearDown(() {
    findBar.dispose();
    host.remove();
  });

  void click(web.EventTarget target) {
    target.dispatchEvent(
        web.MouseEvent('click', web.MouseEventInit(bubbles: true)));
  }

  void key(web.EventTarget target, int keyCode, {bool shift = false}) {
    target.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(
          bubbles: true,
          keyCode: keyCode,
          shiftKey: shift,
        ),
      ),
    );
  }

  test('open reveals bar, expands button and focuses field', () {
    findBar.open();
    expect(findBar.opened, isTrue);
    expect(barElement.classList.contains('hidden'), isFalse);
    expect(toggleButton.classList.contains('toggled'), isTrue);
    expect(toggleButton.getAttribute('aria-expanded'), 'true');
    expect(web.document.activeElement, same(findField));
  });

  test('open is idempotent and toggle closes', () {
    findBar.open();
    findBar.open();
    findBar.toggle();
    expect(findBar.opened, isFalse);
    expect(closeEvents, hasLength(1));
    expect(closeEvents.single['source'], same(findBar));
  });

  test('close when already closed does not dispatch', () {
    findBar.close();
    expect(closeEvents, isEmpty);
  });

  test('toggle button opens and closes bar', () {
    click(toggleButton);
    expect(findBar.opened, isTrue);
    click(toggleButton);
    expect(findBar.opened, isFalse);
  });

  test('input dispatches complete find payload', () {
    findField.value = 'needle';
    caseSensitive.checked = true;
    entireWord.checked = true;
    highlightAll.checked = true;
    matchDiacritics.checked = true;
    findField.dispatchEvent(web.InputEvent('input'));

    expect(findEvents, hasLength(1));
    expect(findEvents.single, containsPair('source', findBar));
    expect(findEvents.single['type'], '');
    expect(findEvents.single['query'], 'needle');
    expect(findEvents.single['caseSensitive'], isTrue);
    expect(findEvents.single['entireWord'], isTrue);
    expect(findEvents.single['highlightAll'], isTrue);
    expect(findEvents.single['matchDiacritics'], isTrue);
    expect(findEvents.single['findPrevious'], isFalse);
  });

  test('previous and next buttons repeat in the proper direction', () {
    click(previousButton);
    click(nextButton);
    expect(findEvents.map((event) => event['type']), ['again', 'again']);
    expect(findEvents.map((event) => event['findPrevious']), [true, false]);
  });

  test('enter in field repeats search and honors shift', () {
    key(findField, 13, shift: true);
    expect(findEvents.single['type'], 'again');
    expect(findEvents.single['findPrevious'], isTrue);
  });

  test('escape closes an opened find bar', () {
    findBar.open();
    key(findField, 27);
    expect(findBar.opened, isFalse);
    expect(closeEvents, hasLength(1));
  });

  test('clicking each checkbox dispatches its matching event type', () {
    click(highlightAll);
    click(caseSensitive);
    click(entireWord);
    click(matchDiacritics);
    expect(findEvents.map((event) => event['type']), [
      'highlightallchange',
      'casesensitivitychange',
      'entirewordchange',
      'diacriticmatchingchange',
    ]);
  });

  test('enter on checkbox toggles it and dispatches preference event', () {
    expect(caseSensitive.checked, isFalse);
    key(caseSensitive, 13);
    expect(caseSensitive.checked, isTrue);
    expect(findEvents.single['type'], 'casesensitivitychange');
  });

  test('found state clears statuses and localization message', () {
    findMsg
      ..setAttribute('data-l10n-id', 'old')
      ..textContent = 'old';
    findBar.updateUIState(FindState.found);
    expect(findField.getAttribute('data-status'), '');
    expect(findField.getAttribute('aria-invalid'), 'false');
    expect(findMsg.getAttribute('data-status'), '');
    expect(findMsg.hasAttribute('data-l10n-id'), isFalse);
    expect(findMsg.textContent, '');
  });

  test('pending state is reflected by field and message', () {
    findBar.updateUIState(FindState.pending);
    expect(findField.getAttribute('data-status'), 'pending');
    expect(findMsg.getAttribute('data-status'), 'pending');
    expect(findField.getAttribute('aria-invalid'), 'false');
  });

  test('not found state marks field invalid and localizes message', () {
    findBar.updateUIState(FindState.notFound);
    expect(findField.getAttribute('data-status'), 'notFound');
    expect(findField.getAttribute('aria-invalid'), 'true');
    expect(findMsg.getAttribute('data-l10n-id'), 'pdfjs-find-not-found');
  });

  test('wrapped state distinguishes forward and previous direction', () {
    findBar.updateUIState(FindState.wrapped, false);
    expect(
      findMsg.getAttribute('data-l10n-id'),
      'pdfjs-find-reached-bottom',
    );
    findBar.updateUIState(FindState.wrapped, true);
    expect(findMsg.getAttribute('data-l10n-id'), 'pdfjs-find-reached-top');
  });

  test('normal result count sets Fluent localization attributes', () {
    findBar.updateResultsCount({'current': 4, 'total': 17});
    expect(results.getAttribute('data-l10n-id'), 'pdfjs-find-match-count');
    expect(jsonDecode(results.getAttribute('data-l10n-args')!), {
      'limit': 1000,
      'current': 4,
      'total': 17,
    });
  });

  test('large result count uses capped-count localization', () {
    findBar.updateResultsCount(
      const FindMatchesCount(current: 8, total: 1001),
    );
    expect(
      results.getAttribute('data-l10n-id'),
      'pdfjs-find-match-count-limit',
    );
  });

  test('zero results clears count localization and content', () {
    results
      ..setAttribute('data-l10n-id', 'old')
      ..textContent = 'old';
    findBar.updateResultsCount({'current': 0, 'total': 0});
    expect(results.hasAttribute('data-l10n-id'), isFalse);
    expect(results.textContent, '');
  });

  test('reset restores default UI state', () {
    findBar.updateUIState(FindState.notFound, false, {
      'current': 0,
      'total': 0,
    });
    findBar.reset();
    expect(findField.getAttribute('data-status'), '');
    expect(findField.getAttribute('aria-invalid'), 'false');
  });

  test('refreshLayout removes stale wrap class', () {
    barElement.style.height = '20px';
    (barElement.firstElementChild! as web.HTMLElement).style.height = '20px';
    barElement.classList.add('wrapContainers');
    findBar.refreshLayout();
    expect(barElement.classList.contains('wrapContainers'), isFalse);
  });

  test('dispose closes open bar and removes listeners', () {
    findBar.open();
    findBar.dispose();
    expect(findBar.opened, isFalse);
    findEvents.clear();
    findField.dispatchEvent(web.InputEvent('input'));
    click(nextButton);
    expect(findEvents, isEmpty);
  });
}
