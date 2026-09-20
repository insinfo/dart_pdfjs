// Copyright 2015 Mozilla Foundation
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

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:pdfjs/src/display/api_utils.dart' show isValidExplicitDest;
import 'package:web/web.dart' as web;

import 'event_utils.dart';
import 'ui_utils.dart' show parseQueryString;

const String defaultLinkRel = 'noopener noreferrer nofollow';

/// Values accepted by [PDFLinkService.externalLinkTarget].
enum LinkTarget {
  none,
  self,
  blank,
  parent,
  top;

  String get htmlValue => switch (this) {
        LinkTarget.none => '',
        LinkTarget.self => '_self',
        LinkTarget.blank => '_blank',
        LinkTarget.parent => '_parent',
        LinkTarget.top => '_top',
      };
}

/// A DOM-independent hyperlink target.
///
/// Keeping the service dependent on this small interface makes its navigation
/// logic testable on the Dart VM. Browser callers can use
/// [HtmlAnchorElementAdapter].
abstract interface class LinkElement {
  set href(String value);
  set title(String value);
  set target(String value);
  set rel(String value);

  /// Prevents activation after external links have been disabled.
  void disableActivation();
}

/// Adapts a package:web anchor to [LinkElement].
final class HtmlAnchorElementAdapter implements LinkElement {
  HtmlAnchorElementAdapter(this.element);

  final web.HTMLAnchorElement element;
  JSFunction? _disabledListener;

  @override
  set href(String value) => element.href = value;

  @override
  set title(String value) => element.title = value;

  @override
  set target(String value) => element.target = value;

  @override
  set rel(String value) => element.rel = value;

  @override
  void disableActivation() {
    if (_disabledListener != null) return;
    final listener = ((web.Event event) {
      event.preventDefault();
    }).toJS;
    _disabledListener = listener;
    element.addEventListener('click', listener);
  }
}

/// Document operations used by internal-link navigation.
abstract interface class PDFLinkDocument {
  int get pagesCount;
  Future<List<dynamic>?> getDestination(String name);
  int? cachedPageNumber(Object reference);
  Future<int> getPageIndex(Object reference);
}

/// A callback adapter for connecting a concrete PDF document implementation.
final class CallbackPDFLinkDocument implements PDFLinkDocument {
  CallbackPDFLinkDocument({
    required this.pagesCount,
    required FutureOr<List<dynamic>?> Function(String name) getDestination,
    required int? Function(Object reference) cachedPageNumber,
    required FutureOr<int> Function(Object reference) getPageIndex,
  })  : _getDestination = getDestination,
        _cachedPageNumber = cachedPageNumber,
        _getPageIndex = getPageIndex;

  @override
  final int pagesCount;
  final FutureOr<List<dynamic>?> Function(String name) _getDestination;
  final int? Function(Object reference) _cachedPageNumber;
  final FutureOr<int> Function(Object reference) _getPageIndex;

  @override
  Future<List<dynamic>?> getDestination(String name) async =>
      _getDestination(name);

  @override
  int? cachedPageNumber(Object reference) => _cachedPageNumber(reference);

  @override
  Future<int> getPageIndex(Object reference) async => _getPageIndex(reference);
}

/// Fully describes a request to reveal a page or PDF destination.
final class PDFViewerScrollRequest {
  const PDFViewerScrollRequest({
    required this.pageNumber,
    this.destination,
    this.ignoreDestinationZoom = false,
    this.allowNegativeOffset = false,
  });

  final int pageNumber;
  final List<dynamic>? destination;
  final bool ignoreDestinationZoom;
  final bool allowNegativeOffset;
}

/// Optional-content configuration behavior required by the link service.
abstract interface class PDFOptionalContentConfig {
  void setOCGState(Map<String, dynamic> action);
}

/// Viewer operations used by [PDFLinkService].
abstract interface class PDFLinkViewer {
  int get currentPageNumber;
  set currentPageNumber(int value);
  int get pagesRotation;
  set pagesRotation(int value);
  bool get isInPresentationMode;
  int? pageLabelToPageNumber(String label);
  void scrollPageIntoView(PDFViewerScrollRequest request);
  void nextPage();
  void previousPage();
  Future<PDFOptionalContentConfig> get optionalContentConfig;
  void replaceOptionalContentConfig(PDFOptionalContentConfig config);
}

/// Browser-history operations used during navigation.
abstract interface class PDFLinkHistory {
  void pushCurrentPosition();
  void pushDestination({
    String? namedDestination,
    required List<dynamic> explicitDestination,
    required int pageNumber,
  });
  void pushPage(int pageNumber);
  void back();
  void forward();
}

/// Typed payload for the viewer's `textlayerrendered` event.
final class TextLayerRenderedEvent {
  const TextLayerRenderedEvent({
    required this.pageNumber,
    required this.focusTextLayer,
  });

  final int pageNumber;
  final void Function() focusTextLayer;
}

typedef PDFLinkErrorHandler = void Function(String message);

/// Performs navigation inside a PDF and configures external hyperlinks.
class PDFLinkService {
  PDFLinkService({
    EventBus? eventBus,
    this.externalLinkTarget,
    this.externalLinkRel,
    bool ignoreDestinationZoom = false,
    PDFLinkErrorHandler? onError,
  })  : eventBus = eventBus ?? EventBus(),
        _ignoreDestinationZoom = ignoreDestinationZoom,
        _onError = onError ?? _defaultErrorHandler;

  final EventBus eventBus;
  LinkTarget? externalLinkTarget;
  String? externalLinkRel;
  bool externalLinkEnabled = true;
  final bool _ignoreDestinationZoom;
  final PDFLinkErrorHandler _onError;

  String? baseUrl;
  PDFLinkDocument? pdfDocument;
  PDFLinkViewer? pdfViewer;
  PDFLinkHistory? pdfHistory;

  static void _defaultErrorHandler(String message) {
    // Keep malformed PDF navigation non-fatal, as in the web viewer.
    // ignore: avoid_print
    print(message);
  }

  void setDocument(PDFLinkDocument? document, [String? documentBaseUrl]) {
    baseUrl = documentBaseUrl;
    pdfDocument = document;
  }

  void setViewer(PDFLinkViewer? viewer) => pdfViewer = viewer;

  void setHistory(PDFLinkHistory? history) => pdfHistory = history;

  int get pagesCount => pdfDocument?.pagesCount ?? 0;

  int get page => pdfDocument == null ? 1 : pdfViewer?.currentPageNumber ?? 1;

  set page(int value) {
    if (pdfDocument != null) pdfViewer?.currentPageNumber = value;
  }

  int get rotation => pdfDocument == null ? 0 : pdfViewer?.pagesRotation ?? 0;

  set rotation(int value) {
    if (pdfDocument != null) pdfViewer?.pagesRotation = value;
  }

  bool get isInPresentationMode =>
      pdfDocument != null && (pdfViewer?.isInPresentationMode ?? false);

  /// Navigates to a named, explicit, or asynchronously resolved destination.
  Future<void> goToDestination(FutureOr<Object?> destination) async {
    final document = pdfDocument;
    final viewer = pdfViewer;
    if (document == null || viewer == null) return;

    final resolved = await destination;
    final String? namedDestination;
    final List<dynamic>? explicitDestination;
    if (resolved is String) {
      namedDestination = resolved;
      explicitDestination = await document.getDestination(resolved);
    } else {
      namedDestination = null;
      explicitDestination =
          resolved is List ? List<dynamic>.from(resolved) : null;
    }
    if (explicitDestination == null) {
      _onError(
        'goToDestination: "$resolved" is not a valid destination array, '
        'for dest="$destination".',
      );
      return;
    }

    final destinationReference =
        explicitDestination.isEmpty ? null : explicitDestination.first;
    int? pageNumber;
    if (destinationReference != null && destinationReference is! num) {
      pageNumber = document.cachedPageNumber(destinationReference);
      if (pageNumber == null || pageNumber == 0) {
        try {
          pageNumber = await document.getPageIndex(destinationReference) + 1;
        } catch (_) {
          _onError(
            'goToDestination: "$destinationReference" is not a valid page '
            'reference, for dest="$destination".',
          );
          return;
        }
      }
    } else if (destinationReference is int) {
      pageNumber = destinationReference + 1;
    }
    if (pageNumber == null || pageNumber < 1 || pageNumber > pagesCount) {
      _onError(
        'goToDestination: "$pageNumber" is not a valid page number, '
        'for dest="$destination".',
      );
      return;
    }

    final history = pdfHistory;
    if (history != null) {
      history.pushCurrentPosition();
      history.pushDestination(
        namedDestination: namedDestination,
        explicitDestination: explicitDestination,
        pageNumber: pageNumber,
      );
    }
    viewer.scrollPageIntoView(
      PDFViewerScrollRequest(
        pageNumber: pageNumber,
        destination: explicitDestination,
        ignoreDestinationZoom: _ignoreDestinationZoom,
      ),
    );

    late final EventBusListener listener;
    listener = (Object? event) {
      if (event is TextLayerRenderedEvent && event.pageNumber == pageNumber) {
        event.focusTextLayer();
        eventBus.internalOff('textlayerrendered', listener);
      }
    };
    eventBus.internalOn('textlayerrendered', listener);
  }

  /// Navigates to a page number or page label.
  void goToPage(Object value) {
    final viewer = pdfViewer;
    if (pdfDocument == null || viewer == null) return;
    final pageNumber = value is String
        ? viewer.pageLabelToPageNumber(value) ?? _toInt32(value)
        : _toInt32(value);
    if (pageNumber <= 0 || pageNumber > pagesCount) {
      _onError('PDFLinkService.goToPage: "$value" is not a valid page.');
      return;
    }
    pdfHistory
      ?..pushCurrentPosition()
      ..pushPage(pageNumber);
    viewer.scrollPageIntoView(PDFViewerScrollRequest(pageNumber: pageNumber));
  }

  /// Scrolls to page coordinates while preserving the current zoom.
  void goToXY(
    int pageNumber,
    num x,
    num y, {
    bool allowNegativeOffset = false,
  }) {
    pdfViewer?.scrollPageIntoView(
      PDFViewerScrollRequest(
        pageNumber: pageNumber,
        destination: <dynamic>[
          null,
          <String, dynamic>{'name': 'XYZ'},
          x,
          y,
        ],
        ignoreDestinationZoom: true,
        allowNegativeOffset: allowNegativeOffset,
      ),
    );
  }

  /// Adds href, title, target, and rel attributes to [link].
  void addLinkAttributes(
    LinkElement link,
    String url, {
    bool newWindow = false,
  }) {
    if (url.isEmpty) {
      throw ArgumentError.value(url, 'url', 'A valid URL must be provided.');
    }
    final target = newWindow ? LinkTarget.blank : externalLinkTarget;
    final displayUrl = _removeUserInfo(url);
    if (externalLinkEnabled) {
      link.href = url;
      link.title = displayUrl;
    } else {
      link.href = '';
      link.title = 'Disabled: $displayUrl';
      link.disableActivation();
    }
    link.target = (target ?? LinkTarget.none).htmlValue;
    link.rel = externalLinkRel ?? defaultLinkRel;
  }

  String getDestinationHash(Object? destination) {
    if (destination is String && destination.isNotEmpty) {
      return getAnchorUrl('#${_legacyEscape(destination)}');
    }
    if (destination is List) {
      final value = jsonEncode(destination);
      if (value.isNotEmpty) return getAnchorUrl('#${_legacyEscape(value)}');
    }
    return getAnchorUrl('');
  }

  String getAnchorUrl(String anchor) =>
      baseUrl == null ? anchor : '${baseUrl!}$anchor';

  /// Applies an Adobe-style PDF open-parameter hash.
  void setHash(String hash) {
    if (pdfDocument == null) return;
    int? pageNumber;
    List<dynamic>? destination;
    if (hash.contains('=')) {
      final parameters = parseQueryString(hash);
      final search = parameters['search'];
      if (search != null) {
        final query = search.replaceAll('"', '');
        final phrase = parameters['phrase'] == 'true';
        eventBus.dispatch('findfromurlhash', <String, Object?>{
          'source': this,
          'query': phrase
              ? query
              : RegExp(r'\S+')
                  .allMatches(query)
                  .map((match) => match.group(0)!)
                  .toList(),
        });
      }
      if (parameters.containsKey('page')) {
        pageNumber = _toInt32(parameters['page']);
        if (pageNumber == 0) pageNumber = 1;
      }
      final zoom = parameters['zoom'];
      if (zoom != null) {
        destination = _parseZoomDestination(zoom);
      }
      final viewer = pdfViewer;
      if (destination != null && viewer != null) {
        viewer.scrollPageIntoView(
          PDFViewerScrollRequest(
            pageNumber: pageNumber ?? page,
            destination: destination,
            allowNegativeOffset: true,
          ),
        );
      } else if (pageNumber != null) {
        page = pageNumber;
      }
      final pageMode = parameters['pagemode'];
      if (pageMode != null) {
        eventBus.dispatch('pagemode', <String, Object?>{
          'source': this,
          'mode': pageMode,
        });
      }
      final namedDestination = parameters['nameddest'];
      if (namedDestination != null) {
        unawaited(goToDestination(namedDestination));
      }
      return;
    }

    final unescaped = _legacyUnescape(hash);
    Object? parsedDestination = unescaped;
    try {
      final decoded = jsonDecode(unescaped);
      parsedDestination = decoded is List ? decoded : decoded.toString();
    } on FormatException {
      // A normal named destination is not JSON.
    }
    if (parsedDestination is String || isValidExplicitDest(parsedDestination)) {
      unawaited(goToDestination(parsedDestination));
      return;
    }
    _onError(
      'PDFLinkService.setHash: "$unescaped" is not a valid destination.',
    );
  }

  void executeNamedAction(String action) {
    if (pdfDocument == null) return;
    switch (action) {
      case 'GoBack':
        pdfHistory?.back();
      case 'GoForward':
        pdfHistory?.forward();
      case 'NextPage':
        pdfViewer?.nextPage();
      case 'PrevPage':
        pdfViewer?.previousPage();
      case 'LastPage':
        page = pagesCount;
      case 'FirstPage':
        page = 1;
    }
    eventBus.dispatch('namedaction', <String, Object?>{
      'source': this,
      'action': action,
    });
  }

  Future<void> executeSetOCGState(Map<String, dynamic> action) async {
    final document = pdfDocument;
    final viewer = pdfViewer;
    if (document == null || viewer == null) return;
    final config = await viewer.optionalContentConfig;
    if (!identical(document, pdfDocument)) return;
    config.setOCGState(action);
    viewer.replaceOptionalContentConfig(config);
  }

  List<dynamic>? _parseZoomDestination(String value) {
    final arguments = value.split(',');
    final zoom = arguments.first;
    final numericZoom = double.tryParse(zoom);
    if (!zoom.contains('Fit')) {
      return <dynamic>[
        null,
        <String, dynamic>{'name': 'XYZ'},
        arguments.length > 1 ? _toInt32(arguments[1]) : null,
        arguments.length > 2 ? _toInt32(arguments[2]) : null,
        numericZoom != null && numericZoom != 0 ? numericZoom / 100 : zoom,
      ];
    }
    if (zoom == 'Fit' || zoom == 'FitB') {
      return <dynamic>[
        null,
        <String, dynamic>{'name': zoom}
      ];
    }
    if (const {'FitH', 'FitBH', 'FitV', 'FitBV'}.contains(zoom)) {
      return <dynamic>[
        null,
        <String, dynamic>{'name': zoom},
        arguments.length > 1 ? _toInt32(arguments[1]) : null,
      ];
    }
    if (zoom == 'FitR') {
      if (arguments.length != 5) {
        _onError('PDFLinkService.setHash: Not enough parameters for "FitR".');
        return null;
      }
      return <dynamic>[
        null,
        <String, dynamic>{'name': zoom},
        ...arguments.skip(1).map(_toInt32),
      ];
    }
    _onError('PDFLinkService.setHash: "$zoom" is not a valid zoom value.');
    return null;
  }
}

/// Link service used where navigation is intentionally unavailable.
final class SimpleLinkService extends PDFLinkService {
  SimpleLinkService({super.eventBus});

  @override
  void setDocument(PDFLinkDocument? document, [String? documentBaseUrl]) {}
}

int _toInt32(Object? value) {
  final number = value is num ? value : num.tryParse(value?.toString() ?? '');
  if (number == null || !number.isFinite) return 0;
  final integer = number.truncate();
  final unsigned = integer & 0xffffffff;
  return unsigned >= 0x80000000 ? unsigned - 0x100000000 : unsigned;
}

String _removeUserInfo(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.userInfo.isEmpty) return url;
  return uri.replace(userInfo: '').toString();
}

// ECMAScript's legacy escape/unescape is used by PDF.js destination hashes.
const String _escapeSafe =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@*_+-./';

String _legacyEscape(String value) {
  final output = StringBuffer();
  for (final codeUnit in value.codeUnits) {
    final character = String.fromCharCode(codeUnit);
    if (_escapeSafe.contains(character)) {
      output.write(character);
    } else if (codeUnit < 256) {
      output.write(
          '%${codeUnit.toRadixString(16).padLeft(2, '0').toUpperCase()}');
    } else {
      output.write(
          '%u${codeUnit.toRadixString(16).padLeft(4, '0').toUpperCase()}');
    }
  }
  return output.toString();
}

String _legacyUnescape(String value) {
  final output = StringBuffer();
  var index = 0;
  while (index < value.length) {
    if (value.codeUnitAt(index) == 0x25) {
      final unicode = index + 5 < value.length &&
          (value[index + 1] == 'u' || value[index + 1] == 'U');
      final digits = unicode ? 4 : 2;
      final start = index + (unicode ? 2 : 1);
      if (start + digits <= value.length) {
        final code = int.tryParse(
          value.substring(start, start + digits),
          radix: 16,
        );
        if (code != null) {
          output.writeCharCode(code);
          index = start + digits;
          continue;
        }
      }
    }
    output.write(value[index]);
    index++;
  }
  return output.toString();
}
