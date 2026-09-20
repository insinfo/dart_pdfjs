// Copyright 2012 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:async';
import 'dart:js_interop';

import 'package:pdfjs/src/display/display_utils.dart' show PDFDateString;
import 'package:web/web.dart' as web;

import 'event_utils.dart';
import 'l10n.dart';
import 'overlay_manager.dart';
import 'ui_utils.dart';

const Set<String> _nonMetricLocales = {'en-us', 'en-lr', 'my'};
const Map<String, String> _usPageNames = {
  '8.5x11': 'pdfjs-document-properties-page-size-name-letter',
  '8.5x14': 'pdfjs-document-properties-page-size-name-legal',
};
const Map<String, String> _metricPageNames = {
  '297x420': 'pdfjs-document-properties-page-size-name-a-three',
  '210x297': 'pdfjs-document-properties-page-size-name-a-four',
};

abstract interface class DocumentPropertiesMetadata {
  Object? get(String name);
}

final class DocumentMetadataResult {
  const DocumentMetadataResult({
    required this.info,
    this.metadata,
    this.contentLength,
  });

  final Map<String, Object?> info;
  final DocumentPropertiesMetadata? metadata;
  final int? contentLength;
}

abstract interface class DocumentPropertiesPage {
  List<num> get view;
  num get userUnit;
  int get rotate;
}

abstract interface class DocumentPropertiesDocument {
  int get numPages;
  Future<DocumentMetadataResult> getMetadata();
  Future<DocumentPropertiesPage> getPage(int pageNumber);
  Future<int> getDownloadLength();
}

typedef DocumentPropertyLookup = FutureOr<String?> Function();

/// Populates and controls the document-properties dialog.
class PDFDocumentProperties {
  PDFDocumentProperties({
    required this.dialog,
    required this.fields,
    required web.HTMLButtonElement closeButton,
    required this.overlayManager,
    required this.eventBus,
    required this.l10n,
    required DocumentPropertyLookup fileNameLookup,
    required DocumentPropertyLookup titleLookup,
  })  : _fileNameLookup = fileNameLookup,
        _titleLookup = titleLookup {
    _reset();
    closeButton.addEventListener(
      'click',
      ((web.Event _) => unawaited(close())).toJS,
    );
    unawaited(overlayManager.register(dialog));
    eventBus.internalOn('pagechanging', (data) {
      final value = _eventValue(data, 'pageNumber');
      if (value is num) _currentPageNumber = value.toInt();
    });
    eventBus.internalOn('rotationchanging', (data) {
      final value = _eventValue(data, 'pagesRotation');
      if (value is num) _pagesRotation = value.toInt();
    });
  }

  final web.HTMLDialogElement dialog;
  final Map<String, web.HTMLElement> fields;
  final OverlayManager overlayManager;
  final EventBus eventBus;
  final L10n l10n;
  final DocumentPropertyLookup _fileNameLookup;
  final DocumentPropertyLookup _titleLookup;

  DocumentPropertiesDocument? pdfDocument;
  Map<String, Object?>? _fieldData;
  late Completer<void> _dataAvailable;
  int _currentPageNumber = 1;
  int _pagesRotation = 0;

  static Object? _eventValue(Object? data, String key) {
    return data is Map<Object?, Object?> ? data[key] : null;
  }

  Future<void> open() async {
    await Future.wait<void>([
      overlayManager.open(dialog),
      _dataAvailable.future,
    ]);
    final document = pdfDocument;
    if (document == null) return;
    final pageNumber = _currentPageNumber;
    final rotation = _pagesRotation;
    final oldData = _fieldData;
    if (oldData != null &&
        oldData['_currentPageNumber'] == pageNumber &&
        oldData['_pagesRotation'] == rotation) {
      _updateUI();
      return;
    }

    final results = await Future.wait<Object>([
      document.getMetadata(),
      document.getPage(pageNumber),
    ]);
    final metadataResult = results[0] as DocumentMetadataResult;
    final page = results[1] as DocumentPropertiesPage;
    final info = metadataResult.info;
    final metadata = metadataResult.metadata;

    final fileName = await _fileNameLookup();
    final fileSize = await _parseFileSize(metadataResult.contentLength);
    final title = await _titleLookup();
    final creationDate = await _parseDate(
      metadata?.get('xmp:createdate'),
      info['CreationDate'],
    );
    final modificationDate = await _parseDate(
      metadata?.get('xmp:modifydate'),
      info['ModDate'],
    );
    final pageSize = await _parsePageSize(
      getPageSizeInches(
        view: page.view,
        userUnit: page.userUnit,
        rotate: page.rotate,
      ),
      rotation,
    );
    final linearized = await _parseLinearization(info['IsLinearized'] == true);

    _fieldData = Map<String, Object?>.unmodifiable({
      'fileName': fileName,
      'fileSize': fileSize,
      'title': title,
      'author': _joinedMetadata(metadata?.get('dc:creator')) ?? info['Author'],
      'subject':
          _joinedMetadata(metadata?.get('dc:subject')) ?? info['Subject'],
      'keywords': metadata?.get('pdf:keywords') ?? info['Keywords'],
      'creationDate': creationDate,
      'modificationDate': modificationDate,
      'creator': metadata?.get('xmp:creatortool') ?? info['Creator'],
      'producer': metadata?.get('pdf:producer') ?? info['Producer'],
      'version': info['PDFFormatVersion'],
      'pageCount': document.numPages,
      'pageSize': pageSize,
      'linearized': linearized,
      '_currentPageNumber': pageNumber,
      '_pagesRotation': rotation,
    });
    _updateUI();

    final length = await document.getDownloadLength();
    if (metadataResult.contentLength == length) return;
    _fieldData = Map<String, Object?>.unmodifiable({
      ..._fieldData!,
      'fileSize': await _parseFileSize(length),
    });
    _updateUI();
  }

  Future<void> close() => overlayManager.close(dialog);

  void setDocument(DocumentPropertiesDocument? document) {
    if (pdfDocument != null) {
      _reset();
      _updateUI();
    }
    if (document == null) return;
    pdfDocument = document;
    if (!_dataAvailable.isCompleted) _dataAvailable.complete();
  }

  void _reset() {
    pdfDocument = null;
    _fieldData = null;
    _dataAvailable = Completer<void>();
    _currentPageNumber = 1;
    _pagesRotation = 0;
  }

  void _updateUI() {
    if (_fieldData != null && !identical(overlayManager.active, dialog)) return;
    for (final entry in fields.entries) {
      final content = _fieldData?[entry.key];
      entry.value.textContent =
          content == null || (content is String && content.isEmpty)
              ? '-'
              : '$content';
    }
  }

  Future<String?> _parseFileSize(int? bytes) async {
    final b = bytes ?? 0;
    final kb = b / 1024;
    final mb = kb / 1024;
    if (kb == 0) return null;
    return l10n.get(
      mb >= 1
          ? 'pdfjs-document-properties-size-mb'
          : 'pdfjs-document-properties-size-kb',
      args: {'mb': mb, 'kb': kb, 'b': b},
    );
  }

  static String? _pageName(
    PageSize size,
    bool portrait,
    Map<String, String> pageNames,
  ) {
    final width = portrait ? size.width : size.height;
    final height = portrait ? size.height : size.width;
    return pageNames['${_plainNumber(width)}x${_plainNumber(height)}'];
  }

  static String _plainNumber(num value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';

  Future<String?> _parsePageSize(PageSize? pageSize, int rotation) async {
    if (pageSize == null) return null;
    if (rotation % 180 != 0) {
      pageSize = PageSize(width: pageSize.height, height: pageSize.width);
    }
    final portrait = isPortraitOrientation(pageSize);
    final nonMetric = _nonMetricLocales.contains(l10n.getLanguage());
    var inches = PageSize(
      width: (pageSize.width * 100).round() / 100,
      height: (pageSize.height * 100).round() / 100,
    );
    var millimeters = PageSize(
      width: (pageSize.width * 25.4 * 10).round() / 10,
      height: (pageSize.height * 25.4 * 10).round() / 10,
    );
    var nameId = _pageName(inches, portrait, _usPageNames) ??
        _pageName(millimeters, portrait, _metricPageNames);

    final integralMetric = millimeters.width == millimeters.width.round() &&
        millimeters.height == millimeters.height.round();
    if (nameId == null && !integralMetric) {
      final exactWidth = pageSize.width * 25.4;
      final exactHeight = pageSize.height * 25.4;
      final intMetric = PageSize(
        width: millimeters.width.roundToDouble(),
        height: millimeters.height.roundToDouble(),
      );
      if ((exactWidth - intMetric.width).abs() < 0.1 &&
          (exactHeight - intMetric.height).abs() < 0.1) {
        nameId = _pageName(intMetric, portrait, _metricPageNames);
        if (nameId != null) {
          inches = PageSize(
            width: (intMetric.width / 25.4 * 100).round() / 100,
            height: (intMetric.height / 25.4 * 100).round() / 100,
          );
          millimeters = intMetric;
        }
      }
    }

    final size = nonMetric ? inches : millimeters;
    final unit = await l10n.get(
      nonMetric
          ? 'pdfjs-document-properties-page-size-unit-inches'
          : 'pdfjs-document-properties-page-size-unit-millimeters',
    );
    final name = nameId == null ? null : await l10n.get(nameId);
    final orientation = await l10n.get(
      portrait
          ? 'pdfjs-document-properties-page-size-orientation-portrait'
          : 'pdfjs-document-properties-page-size-orientation-landscape',
    );
    return l10n.get(
      name == null
          ? 'pdfjs-document-properties-page-size-dimension-string'
          : 'pdfjs-document-properties-page-size-dimension-name-string',
      args: {
        'width': size.width,
        'height': size.height,
        'unit': unit,
        'name': name,
        'orientation': orientation,
      },
    );
  }

  Future<String?> _parseDate(Object? metadataDate, Object? infoDate) {
    DateTime? date;
    if (metadataDate is String) date = DateTime.tryParse(metadataDate);
    date ??= PDFDateString.toDateObject(infoDate);
    if (date == null) return Future<String?>.value();
    return l10n.get(
      'pdfjs-document-properties-date-time-string',
      args: {'dateObj': date.millisecondsSinceEpoch},
    );
  }

  Future<String?> _parseLinearization(bool linearized) => l10n.get(
        linearized
            ? 'pdfjs-document-properties-linearized-yes'
            : 'pdfjs-document-properties-linearized-no',
      );

  static String? _joinedMetadata(Object? value) {
    if (value is Iterable) {
      final result = value.map((item) => '$item').join('\n');
      return result.isEmpty ? null : result;
    }
    return value is String && value.isNotEmpty ? value : null;
  }
}
