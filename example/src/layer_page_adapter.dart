// Copyright 2026 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'package:pdfjs/pdfjs.dart';

/// Typed page contract consumed by the viewer overlay builders.
///
/// The core [PDFPageProxy] currently exposes text extraction but does not yet
/// expose annotations, tagged structure, or XFA. Keeping those operations in
/// this interface avoids spreading `dynamic` calls throughout the viewer.
abstract interface class LayerPage {
  Future<List<Map<String, dynamic>>> getAnnotations({String intent});

  Future<Map<String, dynamic>> getTextContent({
    bool includeMarkedContent,
    bool disableNormalization,
  });

  Future<Map<String, dynamic>?> getStructTree();

  Future<Map<String, dynamic>?> getXfa();
}

typedef AnnotationLoader = Future<List<Map<String, dynamic>>> Function(
  String intent,
);
typedef StructTreeLoader = Future<Map<String, dynamic>?> Function();
typedef XfaLoader = Future<Map<String, dynamic>?> Function();

/// Bridges the public PDF page API to the complete layer-page contract.
///
/// Loaders are explicit and required for data not yet surfaced by
/// [PDFPageProxy], so missing functionality fails at construction rather than
/// much later during rendering.
final class PDFPageLayerAdapter implements LayerPage {
  PDFPageLayerAdapter({
    required this.page,
    required AnnotationLoader annotations,
    required StructTreeLoader structTree,
    required XfaLoader xfa,
  })  : _annotations = annotations,
        _structTree = structTree,
        _xfa = xfa;

  final PDFPageProxy page;
  final AnnotationLoader _annotations;
  final StructTreeLoader _structTree;
  final XfaLoader _xfa;

  @override
  Future<List<Map<String, dynamic>>> getAnnotations({
    String intent = 'display',
  }) =>
      _annotations(intent);

  @override
  Future<Map<String, dynamic>> getTextContent({
    bool includeMarkedContent = true,
    bool disableNormalization = true,
  }) =>
      page.getTextContent(includeMarkedContent: includeMarkedContent);

  @override
  Future<Map<String, dynamic>?> getStructTree() => _structTree();

  @override
  Future<Map<String, dynamic>?> getXfa() => _xfa();
}
