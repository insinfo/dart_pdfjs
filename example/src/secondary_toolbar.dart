// Copyright 2012 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'event_utils.dart';
import 'ui_utils.dart';

/// Matches `BaseViewer.PagesCountLimit.FORCE_SCROLL_MODE_PAGE`.
const int forceScrollModePageLimit = 15000;

final class SecondaryToolbarOptions {
  const SecondaryToolbarOptions({
    required this.toolbar,
    required this.toggleButton,
    required this.presentationModeButton,
    required this.openFileButton,
    required this.printButton,
    required this.downloadButton,
    required this.viewBookmarkButton,
    required this.firstPageButton,
    required this.lastPageButton,
    required this.pageRotateCwButton,
    required this.pageRotateCcwButton,
    required this.cursorSelectToolButton,
    required this.cursorHandToolButton,
    required this.scrollPageButton,
    required this.scrollVerticalButton,
    required this.scrollHorizontalButton,
    required this.scrollWrappedButton,
    required this.spreadNoneButton,
    required this.spreadOddButton,
    required this.spreadEvenButton,
    required this.imageAltTextSettingsButton,
    required this.documentPropertiesButton,
  });

  final web.HTMLElement toolbar;
  final web.HTMLButtonElement toggleButton;
  final web.HTMLButtonElement presentationModeButton;
  final web.HTMLButtonElement openFileButton;
  final web.HTMLButtonElement printButton;
  final web.HTMLButtonElement downloadButton;
  final web.HTMLAnchorElement viewBookmarkButton;
  final web.HTMLButtonElement firstPageButton;
  final web.HTMLButtonElement lastPageButton;
  final web.HTMLButtonElement pageRotateCwButton;
  final web.HTMLButtonElement pageRotateCcwButton;
  final web.HTMLButtonElement cursorSelectToolButton;
  final web.HTMLButtonElement cursorHandToolButton;
  final web.HTMLButtonElement scrollPageButton;
  final web.HTMLButtonElement scrollVerticalButton;
  final web.HTMLButtonElement scrollHorizontalButton;
  final web.HTMLButtonElement scrollWrappedButton;
  final web.HTMLButtonElement spreadNoneButton;
  final web.HTMLButtonElement spreadOddButton;
  final web.HTMLButtonElement spreadEvenButton;
  final web.HTMLButtonElement imageAltTextSettingsButton;
  final web.HTMLButtonElement documentPropertiesButton;
}

final class _SecondaryButton {
  const _SecondaryButton(this.element, this.eventName, this.close,
      [this.details = const {}]);
  final web.HTMLElement element;
  final String? eventName;
  final bool close;
  final Map<String, Object?> details;
}

/// Controller for the viewer's overflow toolbar.
final class SecondaryToolbar {
  SecondaryToolbar(this.options, this.eventBus) {
    _bindListeners();
    reset();
  }

  final SecondaryToolbarOptions options;
  final EventBus eventBus;
  bool opened = false;
  int pageNumber = 0;
  int pagesCount = 0;

  bool get isOpen => opened;

  void setPageNumber(int value) {
    pageNumber = value;
    _updateUIState();
  }

  void setPagesCount(int value) {
    pagesCount = value;
    _updateUIState();
  }

  void reset() {
    pageNumber = 0;
    pagesCount = 0;
    _updateUIState();
    eventBus.dispatch('switchcursortool', {'source': this, 'reset': true});
    _scrollModeChanged({'mode': ScrollMode.vertical});
    _spreadModeChanged({'mode': SpreadMode.none});
  }

  void open() {
    if (opened) return;
    opened = true;
    toggleExpandedBtn(options.toggleButton, true, options.toolbar);
  }

  void close() {
    if (!opened) return;
    opened = false;
    toggleExpandedBtn(options.toggleButton, false, options.toolbar);
  }

  void toggle() => opened ? close() : open();

  void _updateUIState() {
    options.firstPageButton.disabled = pageNumber <= 1;
    options.lastPageButton.disabled = pageNumber >= pagesCount;
    options.pageRotateCwButton.disabled = pagesCount == 0;
    options.pageRotateCcwButton.disabled = pagesCount == 0;
  }

  void _bindListeners() {
    final buttons = <_SecondaryButton>[
      _SecondaryButton(
          options.presentationModeButton, 'presentationmode', true),
      _SecondaryButton(options.printButton, 'print', true),
      _SecondaryButton(options.downloadButton, 'download', true),
      _SecondaryButton(options.viewBookmarkButton, null, true),
      _SecondaryButton(options.firstPageButton, 'firstpage', true),
      _SecondaryButton(options.lastPageButton, 'lastpage', true),
      _SecondaryButton(options.pageRotateCwButton, 'rotatecw', false),
      _SecondaryButton(options.pageRotateCcwButton, 'rotateccw', false),
      _SecondaryButton(options.cursorSelectToolButton, 'switchcursortool', true,
          {'tool': CursorTool.select}),
      _SecondaryButton(options.cursorHandToolButton, 'switchcursortool', true,
          {'tool': CursorTool.hand}),
      _SecondaryButton(options.scrollPageButton, 'switchscrollmode', true,
          {'mode': ScrollMode.page}),
      _SecondaryButton(options.scrollVerticalButton, 'switchscrollmode', true,
          {'mode': ScrollMode.vertical}),
      _SecondaryButton(options.scrollHorizontalButton, 'switchscrollmode', true,
          {'mode': ScrollMode.horizontal}),
      _SecondaryButton(options.scrollWrappedButton, 'switchscrollmode', true,
          {'mode': ScrollMode.wrapped}),
      _SecondaryButton(options.spreadNoneButton, 'switchspreadmode', true,
          {'mode': SpreadMode.none}),
      _SecondaryButton(options.spreadOddButton, 'switchspreadmode', true,
          {'mode': SpreadMode.odd}),
      _SecondaryButton(options.spreadEvenButton, 'switchspreadmode', true,
          {'mode': SpreadMode.even}),
      _SecondaryButton(
          options.imageAltTextSettingsButton, 'imagealttextsettings', true),
      _SecondaryButton(
          options.documentPropertiesButton, 'documentproperties', true),
      _SecondaryButton(options.openFileButton, 'openfile', true),
    ];
    options.toggleButton
        .addEventListener('click', ((web.Event _) => toggle()).toJS);
    for (final button in buttons) {
      button.element.addEventListener(
          'click',
          ((web.Event _) {
            if (button.eventName case final eventName?) {
              eventBus.dispatch(eventName, {
                'source': this,
                ...button.details,
              });
            }
            if (button.close) close();
            eventBus.dispatch('reporttelemetry', {
              'source': this,
              'details': {
                'type': 'buttons',
                'data': {'id': button.element.id},
              },
            });
          }).toJS);
    }
    eventBus.internalOn(
        'cursortoolchanged', (data) => _cursorToolChanged(data as Map));
    eventBus.internalOn(
        'scrollmodechanged', (data) => _scrollModeChanged(data as Map));
    eventBus.internalOn(
        'spreadmodechanged', (data) => _spreadModeChanged(data as Map));
  }

  void _cursorToolChanged(Map data) {
    final tool = data['tool'];
    final disabled = data['disabled'] == true;
    toggleCheckedBtn(options.cursorSelectToolButton, tool == CursorTool.select);
    toggleCheckedBtn(options.cursorHandToolButton, tool == CursorTool.hand);
    options.cursorSelectToolButton.disabled = disabled;
    options.cursorHandToolButton.disabled = disabled;
  }

  void _scrollModeChanged(Map data) {
    final mode = data['mode'];
    toggleCheckedBtn(options.scrollPageButton, mode == ScrollMode.page);
    toggleCheckedBtn(options.scrollVerticalButton, mode == ScrollMode.vertical);
    toggleCheckedBtn(
        options.scrollHorizontalButton, mode == ScrollMode.horizontal);
    toggleCheckedBtn(options.scrollWrappedButton, mode == ScrollMode.wrapped);

    final forced = pagesCount > forceScrollModePageLimit;
    options.scrollPageButton.disabled = forced;
    options.scrollVerticalButton.disabled = forced;
    options.scrollHorizontalButton.disabled = forced;
    options.scrollWrappedButton.disabled = forced;

    final horizontal = mode == ScrollMode.horizontal;
    options.spreadNoneButton.disabled = horizontal;
    options.spreadOddButton.disabled = horizontal;
    options.spreadEvenButton.disabled = horizontal;
  }

  void _spreadModeChanged(Map data) {
    final mode = data['mode'];
    toggleCheckedBtn(options.spreadNoneButton, mode == SpreadMode.none);
    toggleCheckedBtn(options.spreadOddButton, mode == SpreadMode.odd);
    toggleCheckedBtn(options.spreadEvenButton, mode == SpreadMode.even);
  }
}
