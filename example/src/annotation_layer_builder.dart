// Copyright 2014 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.
// Ported from pdf.js/web/annotation_layer_builder.js.

import 'dart:async';

import 'package:pdfjs/pdfjs.dart';
import 'package:pdfjs/src/display/annotation_layer.dart';
import 'package:pdfjs/src/shared/util.dart' show AnnotationType, Util;
import 'package:web/web.dart' as web;

import 'layer_page_adapter.dart';
import 'pdf_link_service.dart';
import 'struct_tree_layer_builder.dart';
import 'ui_utils.dart';

typedef LayerAppended = void Function(web.HTMLDivElement element);

final class _LinkAdapter implements AnnotationLinkService {
  _LinkAdapter(this.service);
  final PDFLinkService service;

  @override
  void executeNamedAction(String action) => service.executeNamedAction(action);

  @override
  void navigateTo(dynamic destination) {
    unawaited(service.goToDestination(destination));
  }
}

/// Creates and owns the interactive annotation DOM for one page.
final class AnnotationLayerBuilder {
  AnnotationLayerBuilder({
    required this.pdfPage,
    required this.linkService,
    this.annotationStorage,
    this.imageResourcesPath = '',
    this.renderForms = true,
    this.enableComment = false,
    this.enableScripting = false,
    Future<bool>? hasJSActions,
    Future<Map<String, List<Map<String, dynamic>>>?>? fieldObjects,
    this.onAppend,
  })  : hasJSActions = hasJSActions ?? Future<bool>.value(false),
        fieldObjects = fieldObjects ??
            Future<Map<String, List<Map<String, dynamic>>>?>.value(null);

  final LayerPage pdfPage;
  final PDFLinkService linkService;
  final AnnotationStorage? annotationStorage;
  final String imageResourcesPath;
  final bool renderForms;
  final bool enableComment;
  final bool enableScripting;
  final Future<bool> hasJSActions;
  final Future<Map<String, List<Map<String, dynamic>>>?> fieldObjects;
  final LayerAppended? onAppend;

  AnnotationLayer? annotationLayer;
  web.HTMLDivElement? div;
  List<Map<String, dynamic>>? _annotations;
  bool _cancelled = false;
  bool _externalHide = false;
  bool _linksInjected = false;
  void Function(Object?)? _presentationListener;

  bool get cancelled => _cancelled;

  Future<void> render({
    required PageViewport viewport,
    String intent = 'display',
    StructTreeLayerBuilder? structTreeLayer,
  }) async {
    final existing = div;
    if (existing != null) {
      if (_cancelled || annotationLayer == null) return;
      annotationLayer!.update(viewport: viewport.clone(dontFlip: true));
      return;
    }

    final results = await Future.wait<Object?>([
      pdfPage.getAnnotations(intent: intent),
      hasJSActions,
      fieldObjects,
    ]);
    if (_cancelled) return;
    final annotations = results[0]! as List<Map<String, dynamic>>;

    final container = web.document.createElement('div') as web.HTMLDivElement;
    container.className = 'annotationLayer';
    div = container;
    onAppend?.call(container);
    annotationLayer = AnnotationLayer(
      div: container,
      viewport: viewport.clone(dontFlip: true),
      annotationStorage: annotationStorage,
      linkService: _LinkAdapter(linkService),
    );

    if (annotations.isEmpty) {
      _annotations = annotations;
      _setDimensions(container, viewport);
      return;
    }
    await annotationLayer!.render(AnnotationLayerParameters(
      annotations: annotations,
      imageResourcesPath: imageResourcesPath,
      renderForms: renderForms,
    ));
    if (_cancelled) return;
    _annotations = annotations;

    if (linkService.isInPresentationMode) {
      _updatePresentationModeState(PresentationModeState.fullscreen);
    }
    _presentationListener ??= (Object? event) {
      if (event is Map && event['state'] is int) {
        _updatePresentationModeState(event['state'] as int);
      }
    };
    linkService.eventBus.internalOn(
      'presentationmodechanged',
      _presentationListener!,
    );
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listener = _presentationListener;
    if (listener != null) {
      linkService.eventBus.internalOff('presentationmodechanged', listener);
      _presentationListener = null;
    }
  }

  void hide({bool internal = false}) {
    _externalHide = !internal;
    div?.setAttribute('hidden', '');
  }

  bool hasEditableAnnotations() =>
      annotationLayer?.elements.any((element) {
        final type = element.data['annotationType'];
        return type == AnnotationType.widget &&
            element.data['readOnly'] != true;
      }) ??
      false;

  Future<void> injectLinkAnnotations(
    List<Map<String, dynamic>> inferredLinks,
  ) async {
    final annotations = _annotations;
    if (annotations == null) {
      throw StateError(
        'render must be called before injectLinkAnnotations.',
      );
    }
    if (_cancelled || _linksInjected) return;
    _linksInjected = true;
    final links = annotations.isEmpty
        ? inferredLinks
        : _checkInferredLinks(inferredLinks, annotations);
    if (links.isEmpty || annotationLayer == null) return;

    // AnnotationLayer does not yet expose upstream addLinkAnnotations. Render
    // only the accepted links and preserve all previously rendered children.
    final scratch = web.document.createElement('div') as web.HTMLDivElement;
    final added = AnnotationLayer(
      div: scratch,
      viewport: annotationLayer!.viewport,
      annotationStorage: annotationStorage,
      linkService: _LinkAdapter(linkService),
    );
    await added.render(AnnotationLayerParameters(
      annotations: links,
      imageResourcesPath: imageResourcesPath,
      renderForms: renderForms,
    ));
    while (scratch.firstChild != null) {
      div!.append(scratch.firstChild!);
    }
    if (!_externalHide) div!.removeAttribute('hidden');
  }

  void _updatePresentationModeState(int state) {
    final container = div;
    if (container == null ||
        (state != PresentationModeState.fullscreen &&
            state != PresentationModeState.normal)) {
      return;
    }
    final disabled = state == PresentationModeState.fullscreen;
    for (var i = 0; i < container.children.length; i++) {
      final section = container.children.item(i);
      if (section == null || section.hasAttribute('data-internal-link')) {
        continue;
      }
      if (disabled) {
        section.setAttribute('inert', '');
      } else {
        section.removeAttribute('inert');
      }
    }
  }

  static void _setDimensions(web.HTMLDivElement div, PageViewport viewport) {
    div.style
      ..width = '${viewport.width}px'
      ..height = '${viewport.height}px'
      ..position = 'absolute';
    div.setAttribute('data-main-rotation', '${viewport.rotation}');
  }

  static List<Map<String, dynamic>> _checkInferredLinks(
    List<Map<String, dynamic>> inferred,
    List<Map<String, dynamic>> annotations,
  ) {
    return inferred.where((link) {
      final linkRects = _annotationRects(link);
      final linkArea = _area(linkRects);
      if (linkArea == 0) return true;
      for (final annotation in annotations) {
        if (annotation['annotationType'] != AnnotationType.link ||
            annotation['url'] == null) {
          continue;
        }
        final intersections = <List<num>>[];
        for (final first in _annotationRects(annotation)) {
          for (final second in linkRects) {
            final hit = Util.intersect(first, second);
            if (hit != null) intersections.add(hit);
          }
        }
        if (_area(intersections) / linkArea > .5) return false;
      }
      return true;
    }).toList();
  }

  static List<List<num>> _annotationRects(Map<String, dynamic> annotation) {
    final quads = annotation['quadPoints'];
    if (quads is List && quads.length >= 8) {
      final result = <List<num>>[];
      for (var index = 2; index < quads.length; index += 8) {
        if (index + 3 >= quads.length) break;
        result.add([
          quads[index + 2] as num,
          quads[index + 3] as num,
          quads[index] as num,
          quads[index + 1] as num,
        ]);
      }
      return result;
    }
    final rect = annotation['rect'];
    return rect is List && rect.length == 4
        ? [rect.cast<num>()]
        : const <List<num>>[];
  }

  static double _area(List<List<num>> rects) => rects.fold<double>(
        0,
        (sum, rect) => sum + ((rect[2] - rect[0]) * (rect[3] - rect[1])).abs(),
      );
}
