// Copyright 2022 Mozilla Foundation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:js_interop';

import 'package:pdfjs/src/shared/util.dart' show AnnotationEditorParamsType;
import 'package:web/web.dart' as web;

import 'event_utils.dart';

/// DOM controls used to change annotation-editor parameters.
final class AnnotationEditorParamsOptions {
  const AnnotationEditorParamsOptions({
    required this.editorFreeTextFontSize,
    required this.editorFreeTextColor,
    required this.editorInkColor,
    required this.editorInkThickness,
    required this.editorInkOpacity,
    required this.editorStampAddImage,
    required this.editorFreeHighlightThickness,
    required this.editorHighlightShowAll,
    required this.editorSignatureAddSignature,
  });

  final web.HTMLInputElement editorFreeTextFontSize;
  final web.HTMLInputElement editorFreeTextColor;
  final web.HTMLInputElement editorInkColor;
  final web.HTMLInputElement editorInkThickness;
  final web.HTMLInputElement editorInkOpacity;
  final web.HTMLButtonElement editorStampAddImage;
  final web.HTMLInputElement editorFreeHighlightThickness;
  final web.HTMLButtonElement editorHighlightShowAll;
  final web.HTMLButtonElement editorSignatureAddSignature;
}

/// Keeps annotation-editor parameter controls and the editor UI in sync.
///
/// This is the Dart port of PDF.js' `AnnotationEditorParams`. Unlike the
/// upstream singleton-oriented implementation, [destroy] explicitly detaches
/// every listener so embedding applications can recreate a viewer without
/// retaining old controls.
final class AnnotationEditorParams {
  AnnotationEditorParams(this.options, this.eventBus) {
    _bindListeners();
  }

  final AnnotationEditorParamsOptions options;
  final EventBus eventBus;
  final List<_DomListener> _domListeners = <_DomListener>[];

  late final EventBusListener _paramsChangedListener;
  bool _destroyed = false;

  void _bindListeners() {
    _listen(options.editorFreeTextFontSize, 'input', (_) {
      _dispatchParam(
        AnnotationEditorParamsType.freetextSize,
        options.editorFreeTextFontSize.valueAsNumber,
      );
    });
    _listen(options.editorFreeTextColor, 'input', (_) {
      _dispatchParam(
        AnnotationEditorParamsType.freetextColor,
        options.editorFreeTextColor.value,
      );
    });
    _listen(options.editorInkColor, 'input', (_) {
      _dispatchParam(
        AnnotationEditorParamsType.inkColor,
        options.editorInkColor.value,
      );
    });
    _listen(options.editorInkThickness, 'input', (_) {
      _dispatchParam(
        AnnotationEditorParamsType.inkThickness,
        options.editorInkThickness.valueAsNumber,
      );
    });
    _listen(options.editorInkOpacity, 'input', (_) {
      _dispatchParam(
        AnnotationEditorParamsType.inkOpacity,
        options.editorInkOpacity.valueAsNumber,
      );
    });
    _listen(options.editorStampAddImage, 'click', (_) {
      eventBus.dispatch('reporttelemetry', {
        'source': this,
        'details': {
          'type': 'editing',
          'data': {'action': 'pdfjs.image.add_image_click'},
        },
      });
      _dispatchParam(AnnotationEditorParamsType.create, null);
    });
    _listen(options.editorFreeHighlightThickness, 'input', (_) {
      _dispatchParam(
        AnnotationEditorParamsType.highlightThickness,
        options.editorFreeHighlightThickness.valueAsNumber,
      );
    });
    _listen(options.editorHighlightShowAll, 'click', (_) {
      final pressed =
          options.editorHighlightShowAll.getAttribute('aria-pressed') == 'true';
      final value = !pressed;
      options.editorHighlightShowAll.setAttribute('aria-pressed', '$value');
      _dispatchParam(AnnotationEditorParamsType.highlightShowAll, value);
    });
    _listen(options.editorSignatureAddSignature, 'click', (_) {
      _dispatchParam(AnnotationEditorParamsType.create, null);
    });

    _paramsChangedListener = _onParamsChanged;
    eventBus.internalOn(
      'annotationeditorparamschanged',
      _paramsChangedListener,
    );
  }

  void _listen(
    web.EventTarget target,
    String type,
    void Function(web.Event event) callback,
  ) {
    final listener = callback.toJS;
    target.addEventListener(type, listener);
    _domListeners.add(_DomListener(target, type, listener));
  }

  void _dispatchParam(int type, Object? value) {
    eventBus.dispatch('switchannotationeditorparams', {
      'source': this,
      'type': type,
      'value': value,
    });
  }

  void _onParamsChanged(Object? event) {
    if (event is! Map<Object?, Object?>) {
      return;
    }
    final details = event['details'];
    if (details is! Iterable<Object?>) {
      return;
    }

    for (final detail in details) {
      final pair = switch (detail) {
        List<Object?> values when values.length >= 2 => values,
        MapEntry<Object?, Object?>(:final key, :final value) => <Object?>[
            key,
            value
          ],
        _ => null,
      };
      if (pair == null || pair[0] is! int) {
        continue;
      }
      _applyChange(pair[0] as int, pair[1]);
    }
  }

  void _applyChange(int type, Object? value) {
    switch (type) {
      case AnnotationEditorParamsType.freetextSize:
        options.editorFreeTextFontSize.value = '$value';
      case AnnotationEditorParamsType.freetextColor:
        options.editorFreeTextColor.value = '$value';
      case AnnotationEditorParamsType.inkColor:
        options.editorInkColor.value = '$value';
      case AnnotationEditorParamsType.inkThickness:
        options.editorInkThickness.value = '$value';
      case AnnotationEditorParamsType.inkOpacity:
        options.editorInkOpacity.value = '$value';
      case AnnotationEditorParamsType.highlightColor:
        eventBus.dispatch('mainhighlightcolorpickerupdatecolor', {
          'source': this,
          'value': value,
        });
      case AnnotationEditorParamsType.highlightThickness:
        options.editorFreeHighlightThickness.value = '$value';
      case AnnotationEditorParamsType.highlightFree:
        options.editorFreeHighlightThickness.disabled = value != true;
      case AnnotationEditorParamsType.highlightShowAll:
        options.editorHighlightShowAll
            .setAttribute('aria-pressed', value == true ? 'true' : 'false');
    }
  }

  /// Detaches all listeners owned by this controller.
  void destroy() {
    if (_destroyed) {
      return;
    }
    _destroyed = true;
    for (final registration in _domListeners) {
      registration.target.removeEventListener(
        registration.type,
        registration.listener,
      );
    }
    _domListeners.clear();
    eventBus.internalOff(
      'annotationeditorparamschanged',
      _paramsChangedListener,
    );
  }
}

final class _DomListener {
  const _DomListener(this.target, this.type, this.listener);

  final web.EventTarget target;
  final String type;
  final web.EventListener listener;
}
