// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'primitives.dart';

class AnnotationGlobals {
  final Dict? acroForm;
  AnnotationGlobals({this.acroForm});
}

class AnnotationFactory {
  static AnnotationGlobals createGlobals(dynamic pdfManager) {
    return AnnotationGlobals();
  }

  static Future<dynamic> create(
    dynamic xref,
    dynamic ref,
    dynamic globals, [
    dynamic idFactory,
    bool collectFields = false,
    dynamic orphanFields,
    dynamic collectByType,
    dynamic pageRef,
  ]) async {
    return null;
  }

  static Future<Map<String, dynamic>> saveNewAnnotations(
    dynamic evaluator,
    dynamic xref,
    dynamic task,
    dynamic annotations,
    dynamic imagePromises,
    dynamic changes,
  ) async {
    return {'annotations': <Map<String, dynamic>>[]};
  }
}

class PopupAnnotation {}

class WidgetAnnotation {}
