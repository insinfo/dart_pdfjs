// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'operator_list.dart';
import 'xref.dart';

class PartialEvaluator {
  final XRef xref;
  final dynamic handler;
  final int pageIndex;
  final dynamic idFactory;
  final dynamic fontCache;
  final dynamic builtInCMapCache;
  final dynamic standardFontDataCache;
  final dynamic globalColorSpaceCache;
  final dynamic globalImageCache;
  final dynamic systemFontCache;
  final Map<String, dynamic> options;

  PartialEvaluator({
    required this.xref,
    this.handler,
    required this.pageIndex,
    this.idFactory,
    this.fontCache,
    this.builtInCMapCache,
    this.standardFontDataCache,
    this.globalColorSpaceCache,
    this.globalImageCache,
    this.systemFontCache,
    this.options = const {},
  });

  Future<void> getOperatorList({
    required dynamic contentStream,
    required dynamic executionContext,
    required OperatorList operatorList,
    dynamic resources,
  }) async {}

  Future<Map<String, dynamic>> getTextContent({
    required dynamic contentStream,
    dynamic resources,
  }) async {
    return {'items': <dynamic>[], 'styles': <String, dynamic>{}};
  }

  Future<void> handleSetFont(
    dynamic resources,
    List<dynamic> fontArgs,
    dynamic fontRef,
    OperatorList operatorList,
    dynamic task,
    dynamic state, [
    dynamic fallbackFontDict,
    dynamic cssFontInfo,
  ]) async {}
}
