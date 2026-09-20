// Copyright 2017 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:async';

import 'package:pdfjs/src/shared/util.dart' show AnnotationEditorType;
import 'package:web/web.dart' as web;

import 'event_utils.dart';
import 'grab_to_pan.dart';
import 'ui_utils.dart';

/// Coordinates the select and hand cursor modes used by the PDF viewer.
class PDFCursorTools {
  PDFCursorTools({
    required this.container,
    required this.eventBus,
    int cursorToolOnLoad = CursorTool.select,
  }) : _cursorToolOnLoad = cursorToolOnLoad {
    _addEventListeners();
    scheduleMicrotask(() {
      if (!_disposed) switchTool(_cursorToolOnLoad);
    });
  }

  final web.HTMLDivElement container;
  final EventBus eventBus;
  final int _cursorToolOnLoad;

  int _active = CursorTool.select;
  int? _previousActive;
  int _annotationEditorMode = AnnotationEditorType.none;
  int _presentationModeState = PresentationModeState.normal;
  GrabToPan? _handToolValue;
  bool _disposed = false;

  late final EventBusListener _switchCursorToolListener;
  late final EventBusListener _annotationEditorModeListener;
  late final EventBusListener _presentationModeListener;

  int get activeTool => _active;
  bool get disabled => _previousActive != null;

  GrabToPan get handTool => _handToolValue ??= GrabToPan(element: container);

  /// Switches cursor tool unless editor or presentation mode has disabled it.
  void switchTool(int tool) {
    if (_disposed || _previousActive != null) return;
    _switchTool(tool);
  }

  void _switchTool(int tool, {bool disabled = false}) {
    if (tool == _active) {
      if (_previousActive != null) {
        _dispatchChanged(tool, disabled: disabled);
      }
      return;
    }

    void disableActiveTool() {
      if (_active == CursorTool.hand) _handToolValue?.deactivate();
    }

    switch (tool) {
      case CursorTool.select:
        disableActiveTool();
      case CursorTool.hand:
        disableActiveTool();
        handTool.activate();
      case CursorTool.zoom:
        return;
      default:
        return;
    }
    _active = tool;
    _dispatchChanged(tool, disabled: disabled);
  }

  void _dispatchChanged(int tool, {required bool disabled}) {
    eventBus.dispatch('cursortoolchanged', {
      'source': this,
      'tool': tool,
      'disabled': disabled,
    });
  }

  void _disableActive() {
    _previousActive ??= _active;
    _switchTool(CursorTool.select, disabled: true);
  }

  void _enableActive() {
    final previous = _previousActive;
    if (previous != null &&
        _annotationEditorMode == AnnotationEditorType.none &&
        _presentationModeState == PresentationModeState.normal) {
      _switchTool(previous);
      _previousActive = null;
    }
  }

  void _addEventListeners() {
    _switchCursorToolListener = (Object? value) {
      final event = value is Map ? value : const <String, Object?>{};
      if (event['reset'] != true) {
        final tool = event['tool'];
        if (tool is int) switchTool(tool);
      } else if (_previousActive != null) {
        _annotationEditorMode = AnnotationEditorType.none;
        _presentationModeState = PresentationModeState.normal;
        _enableActive();
      }
    };
    _annotationEditorModeListener = (Object? value) {
      final event = value is Map ? value : const <String, Object?>{};
      final mode = event['mode'];
      if (mode is! int) return;
      _annotationEditorMode = mode;
      if (mode == AnnotationEditorType.none) {
        _enableActive();
      } else {
        _disableActive();
      }
    };
    _presentationModeListener = (Object? value) {
      final event = value is Map ? value : const <String, Object?>{};
      final state = event['state'];
      if (state is! int) return;
      _presentationModeState = state;
      if (state == PresentationModeState.normal) {
        _enableActive();
      } else if (state == PresentationModeState.fullscreen) {
        _disableActive();
      }
    };

    eventBus
      ..internalOn('switchcursortool', _switchCursorToolListener)
      ..internalOn(
        'annotationeditormodechanged',
        _annotationEditorModeListener,
      )
      ..internalOn('presentationmodechanged', _presentationModeListener);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    eventBus
      ..internalOff('switchcursortool', _switchCursorToolListener)
      ..internalOff(
        'annotationeditormodechanged',
        _annotationEditorModeListener,
      )
      ..internalOff('presentationmodechanged', _presentationModeListener);
    _handToolValue?.dispose();
  }
}
