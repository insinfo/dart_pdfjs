// Copyright 2012 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'event_utils.dart';
import 'pdf_find_controller.dart';
import 'ui_utils.dart';

const int matchesCountLimit = 1000;

final class PDFFindBarOptions {
  const PDFFindBarOptions({
    required this.bar,
    required this.toggleButton,
    required this.findField,
    required this.highlightAllCheckbox,
    required this.caseSensitiveCheckbox,
    required this.matchDiacriticsCheckbox,
    required this.entireWordCheckbox,
    required this.findMsg,
    required this.findResultsCount,
    required this.findPreviousButton,
    required this.findNextButton,
  });

  final web.HTMLDivElement bar;
  final web.HTMLButtonElement toggleButton;
  final web.HTMLInputElement findField;
  final web.HTMLInputElement highlightAllCheckbox;
  final web.HTMLInputElement caseSensitiveCheckbox;
  final web.HTMLInputElement matchDiacriticsCheckbox;
  final web.HTMLInputElement entireWordCheckbox;
  final web.HTMLElement findMsg;
  final web.HTMLElement findResultsCount;
  final web.HTMLButtonElement findPreviousButton;
  final web.HTMLButtonElement findNextButton;
}

/// DOM controller for the viewer find bar.
class PDFFindBar {
  PDFFindBar(
    PDFFindBarOptions options,
    this.mainContainer,
    this.eventBus,
  )   : bar = options.bar,
        toggleButton = options.toggleButton,
        findField = options.findField,
        highlightAll = options.highlightAllCheckbox,
        caseSensitive = options.caseSensitiveCheckbox,
        matchDiacritics = options.matchDiacriticsCheckbox,
        entireWord = options.entireWordCheckbox,
        findMsg = options.findMsg,
        findResultsCount = options.findResultsCount,
        findPreviousButton = options.findPreviousButton,
        findNextButton = options.findNextButton {
    _resizeObserver = web.ResizeObserver(
      ((JSArray<web.ResizeObserverEntry> _, web.ResizeObserver __) {
        refreshLayout();
      }).toJS,
    );
    _addEventListeners();
  }

  final web.HTMLDivElement bar;
  final web.HTMLButtonElement toggleButton;
  final web.HTMLInputElement findField;
  final web.HTMLInputElement highlightAll;
  final web.HTMLInputElement caseSensitive;
  final web.HTMLInputElement matchDiacritics;
  final web.HTMLInputElement entireWord;
  final web.HTMLElement findMsg;
  final web.HTMLElement findResultsCount;
  final web.HTMLButtonElement findPreviousButton;
  final web.HTMLButtonElement findNextButton;
  final web.HTMLElement mainContainer;
  final EventBus eventBus;

  late final web.ResizeObserver _resizeObserver;
  final List<
          ({web.EventTarget target, String type, web.EventListener listener})>
      _domListeners = [];
  bool opened = false;
  bool _disposed = false;

  void reset() => updateUIState();

  void dispatchEvent([String type = '', bool findPrevious = false]) {
    eventBus.dispatch('find', {
      'source': this,
      'type': type,
      'query': findField.value,
      'caseSensitive': caseSensitive.checked,
      'entireWord': entireWord.checked,
      'highlightAll': highlightAll.checked,
      'findPrevious': findPrevious,
      'matchDiacritics': matchDiacritics.checked,
    });
  }

  void updateUIState([
    FindState? state,
    bool previous = false,
    Object? matchesCount,
  ]) {
    var findMessageId = '';
    var status = '';
    switch (state) {
      case FindState.found:
      case null:
        break;
      case FindState.pending:
        status = 'pending';
      case FindState.notFound:
        findMessageId = 'pdfjs-find-not-found';
        status = 'notFound';
      case FindState.wrapped:
        findMessageId =
            previous ? 'pdfjs-find-reached-top' : 'pdfjs-find-reached-bottom';
    }
    findField
      ..setAttribute('data-status', status)
      ..setAttribute('aria-invalid', '${state == FindState.notFound}');
    findMsg.setAttribute('data-status', status);
    if (findMessageId.isNotEmpty) {
      findMsg.setAttribute('data-l10n-id', findMessageId);
    } else {
      findMsg.removeAttribute('data-l10n-id');
      findMsg.textContent = '';
    }
    updateResultsCount(matchesCount);
  }

  void updateResultsCount([Object? matchesCount]) {
    var current = 0;
    var total = 0;
    if (matchesCount is FindMatchesCount) {
      current = matchesCount.current;
      total = matchesCount.total;
    } else if (matchesCount is Map) {
      current = matchesCount['current'] as int? ?? 0;
      total = matchesCount['total'] as int? ?? 0;
    }

    if (total > 0) {
      findResultsCount.setAttribute(
        'data-l10n-id',
        total > matchesCountLimit
            ? 'pdfjs-find-match-count-limit'
            : 'pdfjs-find-match-count',
      );
      findResultsCount.setAttribute(
        'data-l10n-args',
        jsonEncode({
          'limit': matchesCountLimit,
          'current': current,
          'total': total,
        }),
      );
    } else {
      findResultsCount.removeAttribute('data-l10n-id');
      findResultsCount.textContent = '';
    }
  }

  void open() {
    if (_disposed) return;
    if (!opened) {
      _resizeObserver
        ..observe(mainContainer)
        ..observe(bar);
      opened = true;
      toggleExpandedBtn(toggleButton, true, bar);
    }
    findField
      ..select()
      ..focus();
  }

  void close() {
    if (!opened) return;
    _resizeObserver.disconnect();
    opened = false;
    toggleExpandedBtn(toggleButton, false, bar);
    eventBus.dispatch('findbarclose', {'source': this});
  }

  void toggle() => opened ? close() : open();

  /// Recomputes whether all find controls must wrap to a second row.
  /// Public for deterministic tests and embedding layouts.
  void refreshLayout() {
    bar.classList.remove('wrapContainers');
    final first = bar.firstElementChild;
    if (first is web.HTMLElement && bar.clientHeight > first.clientHeight) {
      bar.classList.add('wrapContainers');
    }
  }

  void _listen(
    web.EventTarget target,
    String type,
    void Function(web.Event event) callback,
  ) {
    final listener = callback.toJS;
    target.addEventListener(type, listener);
    _domListeners.add((target: target, type: type, listener: listener));
  }

  void _addEventListeners() {
    final checkedInputs = <web.HTMLInputElement, String>{
      highlightAll: 'highlightallchange',
      caseSensitive: 'casesensitivitychange',
      entireWord: 'entirewordchange',
      matchDiacritics: 'diacriticmatchingchange',
    };
    _listen(toggleButton, 'click', (_) => toggle());
    _listen(findField, 'input', (_) => dispatchEvent());
    _listen(bar, 'keydown', (rawEvent) {
      final event = rawEvent as web.KeyboardEvent;
      switch (event.keyCode) {
        case 13:
          if (event.target == findField) {
            dispatchEvent('again', event.shiftKey);
          } else {
            final target = event.target;
            if (target is web.HTMLInputElement &&
                checkedInputs.containsKey(target)) {
              target.checked = !target.checked;
              dispatchEvent(checkedInputs[target]!);
            }
          }
        case 27:
          close();
      }
    });
    _listen(
      findPreviousButton,
      'click',
      (_) => dispatchEvent('again', true),
    );
    _listen(
      findNextButton,
      'click',
      (_) => dispatchEvent('again', false),
    );
    for (final entry in checkedInputs.entries) {
      _listen(entry.key, 'click', (_) => dispatchEvent(entry.value));
    }
  }

  void dispose() {
    if (_disposed) return;
    if (opened) close();
    _disposed = true;
    _resizeObserver.disconnect();
    for (final record in _domListeners) {
      record.target.removeEventListener(record.type, record.listener);
    }
    _domListeners.clear();
  }
}
