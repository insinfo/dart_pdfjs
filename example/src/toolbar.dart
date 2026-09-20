// Copyright 2016 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:convert';
import 'dart:js_interop';

import 'package:pdfjs/src/shared/util.dart' show AnnotationEditorType;
import 'package:web/web.dart' as web;

import 'event_utils.dart';
import 'ui_utils.dart';

/// Adapter implemented by the annotation editor color-picker port.
abstract interface class MainHighlightColorPicker {
  web.HTMLElement renderMainDropdown();
  void updateColor(Object? value);
}

typedef MainHighlightColorPickerFactory = MainHighlightColorPicker Function(
    Object uiManager);

final class ToolbarOptions {
  const ToolbarOptions({
    required this.container,
    required this.numPages,
    required this.pageNumber,
    required this.scaleSelect,
    required this.customScaleOption,
    required this.previous,
    required this.next,
    required this.zoomIn,
    required this.zoomOut,
    required this.print,
    required this.download,
    required this.editorCommentButton,
    required this.editorCommentParamsToolbar,
    required this.editorFreeTextButton,
    required this.editorFreeTextParamsToolbar,
    required this.editorHighlightButton,
    required this.editorHighlightParamsToolbar,
    required this.editorInkButton,
    required this.editorInkParamsToolbar,
    required this.editorStampButton,
    required this.editorStampParamsToolbar,
    required this.editorSignatureButton,
    required this.editorSignatureParamsToolbar,
    this.editorHighlightColorPicker,
  });

  final web.HTMLDivElement container;
  final web.HTMLElement numPages;
  final web.HTMLInputElement pageNumber;
  final web.HTMLSelectElement scaleSelect;
  final web.HTMLOptionElement customScaleOption;
  final web.HTMLButtonElement previous;
  final web.HTMLButtonElement next;
  final web.HTMLButtonElement zoomIn;
  final web.HTMLButtonElement zoomOut;
  final web.HTMLButtonElement print;
  final web.HTMLButtonElement download;
  final web.HTMLButtonElement editorCommentButton;
  final web.HTMLElement editorCommentParamsToolbar;
  final web.HTMLButtonElement editorFreeTextButton;
  final web.HTMLElement editorFreeTextParamsToolbar;
  final web.HTMLButtonElement editorHighlightButton;
  final web.HTMLElement editorHighlightParamsToolbar;
  final web.HTMLButtonElement editorInkButton;
  final web.HTMLElement editorInkParamsToolbar;
  final web.HTMLButtonElement editorStampButton;
  final web.HTMLElement editorStampParamsToolbar;
  final web.HTMLButtonElement editorSignatureButton;
  final web.HTMLElement editorSignatureParamsToolbar;
  final web.HTMLElement? editorHighlightColorPicker;
}

final class _ToolbarButton {
  const _ToolbarButton(this.element, this.eventName,
      {this.details, this.telemetry});
  final web.HTMLButtonElement element;
  final String eventName;
  final Map<String, Object?> Function()? details;
  final Map<String, Object?>? telemetry;
}

/// Primary viewer toolbar controller.
final class Toolbar {
  Toolbar(
    this.options,
    this.eventBus, {
    int toolbarDensity = 0,
    this.colorPickerFactory,
  }) {
    _bindListeners();
    _updateToolbarDensity({'value': toolbarDensity});
    reset();
  }

  final ToolbarOptions options;
  final EventBus eventBus;
  final MainHighlightColorPickerFactory? colorPickerFactory;
  MainHighlightColorPicker? _colorPicker;

  int pageNumber = 0;
  String? pageLabel;
  bool hasPageLabels = false;
  int pagesCount = 0;
  String pageScaleValue = defaultScaleValue;
  double pageScale = defaultScale;

  void setPageNumber(int value, [String? label]) {
    pageNumber = value;
    pageLabel = label;
    _updateUIState();
  }

  void setPagesCount(int value, bool labels) {
    pagesCount = value;
    hasPageLabels = labels;
    _updateUIState(resetNumPages: true);
  }

  void setPageScale(String? value, double scale) {
    pageScaleValue = (value == null || value.isEmpty) ? '$scale' : value;
    pageScale = scale;
    _updateUIState();
  }

  void reset() {
    _colorPicker = null;
    pageNumber = 0;
    pageLabel = null;
    hasPageLabels = false;
    pagesCount = 0;
    pageScaleValue = defaultScaleValue;
    pageScale = defaultScale;
    _updateUIState(resetNumPages: true);
    updateLoadingIndicatorState();
    _editorModeChanged({'mode': AnnotationEditorType.disable});
  }

  void updateLoadingIndicatorState([bool loading = false]) {
    options.pageNumber.classList.toggle('loading', loading);
  }

  void _bindListeners() {
    final buttons = <_ToolbarButton>[
      _ToolbarButton(options.previous, 'previouspage'),
      _ToolbarButton(options.next, 'nextpage'),
      _ToolbarButton(options.zoomIn, 'zoomin'),
      _ToolbarButton(options.zoomOut, 'zoomout'),
      _ToolbarButton(options.print, 'print'),
      _ToolbarButton(options.download, 'download'),
      _editorButton(options.editorCommentButton, AnnotationEditorType.popup),
      _editorButton(
          options.editorFreeTextButton, AnnotationEditorType.freetext),
      _editorButton(
          options.editorHighlightButton, AnnotationEditorType.highlight),
      _editorButton(options.editorInkButton, AnnotationEditorType.ink),
      _editorButton(
        options.editorStampButton,
        AnnotationEditorType.stamp,
        telemetry: {
          'type': 'editing',
          'data': {'action': 'pdfjs.image.icon_click'},
        },
      ),
      _editorButton(
          options.editorSignatureButton, AnnotationEditorType.signature),
    ];
    for (final button in buttons) {
      button.element.addEventListener(
        'click',
        ((web.Event event) {
          final mouse = event as web.MouseEvent;
          eventBus.dispatch(button.eventName, {
            'source': this,
            ...?button.details?.call(),
            'isFromKeyboard': mouse.detail == 0,
          });
          if (button.telemetry case final telemetry?) {
            eventBus.dispatch('reporttelemetry', {
              'source': this,
              'details': telemetry,
            });
          }
        }).toJS,
      );
    }

    options.pageNumber.addEventListener(
      'click',
      ((web.Event _) => options.pageNumber.select()).toJS,
    );
    options.pageNumber.addEventListener(
      'change',
      ((web.Event _) => eventBus.dispatch('pagenumberchanged', {
            'source': this,
            'value': options.pageNumber.value,
          })).toJS,
    );
    options.scaleSelect.addEventListener(
      'change',
      ((web.Event _) {
        if (options.scaleSelect.value != 'custom') {
          eventBus.dispatch('scalechanged', {
            'source': this,
            'value': options.scaleSelect.value,
          });
        }
      }).toJS,
    );
    options.scaleSelect.addEventListener(
      'click',
      ((web.Event event) {
        final target = event.target;
        if (options.scaleSelect.value == pageScaleValue &&
            target is web.HTMLOptionElement) {
          options.scaleSelect.blur();
        }
      }).toJS,
    );
    options.scaleSelect.oncontextmenu = ((web.Event event) {
      event.preventDefault();
    }).toJS;

    eventBus.internalOn('pagesedited', (data) {
      final map = data as Map;
      final mapper = map['pagesMapper'];
      final count = mapper is PagesMapper
          ? mapper.pagesNumber
          : (mapper as Map)['pagesNumber'] as int;
      if (count != pagesCount) setPagesCount(count, hasPageLabels);
    });
    eventBus.internalOn('annotationeditormodechanged',
        (data) => _editorModeChanged(data as Map));
    eventBus.internalOn('showannotationeditorui', (data) {
      if ((data as Map)['mode'] == AnnotationEditorType.highlight) {
        options.editorHighlightButton.click();
      }
    });
    eventBus.internalOn(
        'toolbardensity', (data) => _updateToolbarDensity(data as Map));

    if (options.editorHighlightColorPicker != null) {
      eventBus.internalOn('annotationeditoruimanager', (data) {
        final manager = (data as Map)['uiManager'];
        final factory = colorPickerFactory;
        if (manager == null || factory == null) return;
        final picker = _colorPicker = factory(manager);
        if (manager is MainHighlightColorPickerOwner) {
          manager.setMainHighlightColorPicker(picker);
        }
        options.editorHighlightColorPicker!.append(picker.renderMainDropdown());
      });
      eventBus.internalOn('mainhighlightcolorpickerupdatecolor', (data) {
        _colorPicker?.updateColor((data as Map)['value']);
      });
    }
  }

  _ToolbarButton _editorButton(web.HTMLButtonElement button, int mode,
      {Map<String, Object?>? telemetry}) {
    return _ToolbarButton(
      button,
      'switchannotationeditormode',
      details: () => {
        'mode': button.classList.contains('toggled')
            ? AnnotationEditorType.none
            : mode,
      },
      telemetry: telemetry,
    );
  }

  void _updateToolbarDensity(Map data) {
    final value = data['value'];
    final name = value == 1 ? 'compact' : (value == 2 ? 'touch' : 'normal');
    web.document.documentElement?.setAttribute('data-toolbar-density', name);
  }

  void _editorModeChanged(Map data) {
    final mode = data['mode'] as int;
    final entries = <(web.HTMLButtonElement, int, web.HTMLElement)>[
      (
        options.editorCommentButton,
        AnnotationEditorType.popup,
        options.editorCommentParamsToolbar
      ),
      (
        options.editorFreeTextButton,
        AnnotationEditorType.freetext,
        options.editorFreeTextParamsToolbar
      ),
      (
        options.editorHighlightButton,
        AnnotationEditorType.highlight,
        options.editorHighlightParamsToolbar
      ),
      (
        options.editorInkButton,
        AnnotationEditorType.ink,
        options.editorInkParamsToolbar
      ),
      (
        options.editorStampButton,
        AnnotationEditorType.stamp,
        options.editorStampParamsToolbar
      ),
      (
        options.editorSignatureButton,
        AnnotationEditorType.signature,
        options.editorSignatureParamsToolbar
      ),
    ];
    for (final (button, buttonMode, toolbar) in entries) {
      toggleExpandedBtn(button, mode == buttonMode, toolbar);
      button.disabled = mode == AnnotationEditorType.disable;
    }
  }

  void _updateUIState({bool resetNumPages = false}) {
    if (resetNumPages) {
      if (hasPageLabels) {
        options.pageNumber.type = 'text';
        options.numPages.setAttribute('data-l10n-id', 'pdfjs-page-of-pages');
      } else {
        options.pageNumber.type = 'number';
        options.numPages
          ..setAttribute('data-l10n-id', 'pdfjs-of-pages')
          ..setAttribute(
              'data-l10n-args', jsonEncode({'pagesCount': pagesCount}));
      }
      options.pageNumber.max = '$pagesCount';
    }
    if (hasPageLabels) {
      options.pageNumber.value = pageLabel ?? '';
      options.numPages.setAttribute('data-l10n-args',
          jsonEncode({'pageNumber': pageNumber, 'pagesCount': pagesCount}));
    } else {
      options.pageNumber.value = '$pageNumber';
    }
    options.previous.disabled = pageNumber <= 1;
    options.next.disabled = pageNumber >= pagesCount;
    options.zoomOut.disabled = pageScale <= minScale;
    options.zoomIn.disabled = pageScale >= maxScale;

    var found = false;
    for (var index = 0; index < options.scaleSelect.options.length; index++) {
      final option =
          options.scaleSelect.options.item(index)! as web.HTMLOptionElement;
      option.selected = option.value == pageScaleValue;
      found |= option.selected;
    }
    if (!found) {
      options.customScaleOption
        ..selected = true
        ..setAttribute('data-l10n-args',
            jsonEncode({'scale': (pageScale * 10000).round() / 100}));
    }
  }
}

abstract interface class PagesMapper {
  int get pagesNumber;
}

abstract interface class MainHighlightColorPickerOwner {
  void setMainHighlightColorPicker(MainHighlightColorPicker picker);
}
