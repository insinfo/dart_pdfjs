@TestOn('browser')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/event_utils.dart';
import '../../example/src/pdf_link_service.dart';

void main() {
  group('PDFLinkService properties', () {
    test('uses safe defaults without a document', () {
      final service = PDFLinkService();

      expect(service.pagesCount, 0);
      expect(service.page, 1);
      expect(service.rotation, 0);
      expect(service.isInPresentationMode, isFalse);

      service
        ..page = 7
        ..rotation = 90;
      expect(service.page, 1);
      expect(service.rotation, 0);
    });

    test('forwards page, rotation, and presentation state to the viewer', () {
      final viewer = FakeViewer()
        ..currentPageNumber = 3
        ..pagesRotation = 90
        ..isInPresentationModeValue = true;
      final service = createService(viewer: viewer);

      expect(service.pagesCount, 8);
      expect(service.page, 3);
      expect(service.rotation, 90);
      expect(service.isInPresentationMode, isTrue);

      service
        ..page = 5
        ..rotation = 180;
      expect(viewer.currentPageNumber, 5);
      expect(viewer.pagesRotation, 180);
    });

    test('setDocument stores and clears base URL', () {
      final service = PDFLinkService();
      final document = FakeDocument();

      service.setDocument(document, 'https://example.com/viewer');
      expect(service.pdfDocument, same(document));
      expect(service.baseUrl, 'https://example.com/viewer');

      service.setDocument(null);
      expect(service.pdfDocument, isNull);
      expect(service.baseUrl, isNull);
    });
  });

  group('addLinkAttributes', () {
    PDFLinkService createLinkService({bool externalLinkEnabled = true}) {
      final service = PDFLinkService();
      service.externalLinkEnabled = externalLinkEnabled;
      return service;
    }

    test('sets href and title for a plain URL', () {
      final link = FakeLink();
      createLinkService().addLinkAttributes(
        link,
        'https://example.com/path',
      );

      expect(link.hrefValue, 'https://example.com/path');
      expect(link.titleValue, 'https://example.com/path');
      expect(link.targetValue, '');
      expect(link.relValue, defaultLinkRel);
    });

    test('strips spoofing username from the displayed URL', () {
      final link = FakeLink();
      createLinkService().addLinkAttributes(
        link,
        'https://trusted.example@attacker.example/path',
      );

      expect(link.hrefValue, 'https://trusted.example@attacker.example/path');
      expect(link.titleValue, 'https://attacker.example/path');
    });

    test('strips username and password from the displayed URL', () {
      final link = FakeLink();
      createLinkService().addLinkAttributes(
        link,
        'https://user:password@example.com/path',
      );

      expect(link.hrefValue, 'https://user:password@example.com/path');
      expect(link.titleValue, 'https://example.com/path');
    });

    test('preserves query and fragment when no userinfo is present', () {
      final link = FakeLink();
      createLinkService().addLinkAttributes(
        link,
        'https://example.com/path?q=1#anchor',
      );

      expect(link.titleValue, 'https://example.com/path?q=1#anchor');
    });

    test('disables link and sanitizes its displayed URL', () {
      final link = FakeLink();
      createLinkService(externalLinkEnabled: false).addLinkAttributes(
        link,
        'https://trusted.example@attacker.example/path',
      );

      expect(link.hrefValue, '');
      expect(link.titleValue, 'Disabled: https://attacker.example/path');
      expect(link.disabled, isTrue);
    });

    test('honors configured and forced-new-window targets and rel', () {
      final service = PDFLinkService(
        externalLinkTarget: LinkTarget.parent,
        externalLinkRel: 'external',
      );
      final normal = FakeLink();
      final newWindow = FakeLink();

      service.addLinkAttributes(normal, 'https://example.com');
      service.addLinkAttributes(
        newWindow,
        'https://example.com',
        newWindow: true,
      );

      expect(normal.targetValue, '_parent');
      expect(normal.relValue, 'external');
      expect(newWindow.targetValue, '_blank');
    });

    test('rejects an empty URL', () {
      expect(
        () => createLinkService().addLinkAttributes(FakeLink(), ''),
        throwsArgumentError,
      );
    });

    test('HTML adapter updates a real anchor', () {
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      final service = PDFLinkService(externalLinkTarget: LinkTarget.self);

      service.addLinkAttributes(
        HtmlAnchorElementAdapter(anchor),
        'https://example.com/a',
      );

      expect(anchor.getAttribute('href'), 'https://example.com/a');
      expect(anchor.title, 'https://example.com/a');
      expect(anchor.target, '_self');
      expect(anchor.rel, defaultLinkRel);
    });
  });

  group('destination hashes', () {
    test('prefixes anchors with the document base URL', () {
      final service = PDFLinkService()
        ..setDocument(FakeDocument(), 'https://example.com/viewer.html');

      expect(
        service.getDestinationHash('Chapter 1'),
        'https://example.com/viewer.html#Chapter%201',
      );
      expect(
        service.getDestinationHash(<dynamic>[
          0,
          {'name': 'Fit'}
        ]),
        'https://example.com/viewer.html#%5B0%2C%7B%22name%22%3A%22Fit%22%7D%5D',
      );
      expect(service.getDestinationHash(''), 'https://example.com/viewer.html');
    });

    test('uses legacy JavaScript escaping for Unicode names', () {
      final service = PDFLinkService();
      expect(service.getDestinationHash('résumé 章'), '#r%E9sum%E9%20%u7AE0');
    });
  });

  group('goToDestination', () {
    test('resolves a named destination and updates history before viewer',
        () async {
      final trace = <String>[];
      final document = FakeDocument(
        destinations: <String, List<dynamic>>{
          'intro': <dynamic>[
            2,
            {'name': 'Fit'}
          ],
        },
      );
      final viewer = FakeViewer(onScroll: (_) => trace.add('scroll'));
      final history = FakeHistory(trace);
      final service = createService(
        document: document,
        viewer: viewer,
        history: history,
        ignoreDestinationZoom: true,
      );

      await service.goToDestination('intro');

      expect(trace, <String>['current', 'destination', 'scroll']);
      expect(history.namedDestination, 'intro');
      expect(history.pageNumber, 3);
      expect(viewer.lastRequest!.pageNumber, 3);
      expect(viewer.lastRequest!.ignoreDestinationZoom, isTrue);
    });

    test('uses a cached page number for reference destinations', () async {
      final reference = <String, int>{'num': 10, 'gen': 0};
      final document = FakeDocument(cachedPages: {reference: 4});
      final viewer = FakeViewer();
      final service = createService(document: document, viewer: viewer);

      await service.goToDestination(<dynamic>[
        reference,
        {'name': 'XYZ'},
        0,
        10,
      ]);

      expect(viewer.lastRequest!.pageNumber, 4);
      expect(document.pageIndexCalls, 0);
    });

    test('fetches an uncached page reference and converts its zero-based index',
        () async {
      final reference = <String, int>{'num': 11, 'gen': 0};
      final document = FakeDocument(pageIndexes: {reference: 5});
      final viewer = FakeViewer();
      final service = createService(document: document, viewer: viewer);

      await service.goToDestination(<dynamic>[
        reference,
        {'name': 'Fit'}
      ]);

      expect(viewer.lastRequest!.pageNumber, 6);
      expect(document.pageIndexCalls, 1);
    });

    test('accepts a future destination', () async {
      final viewer = FakeViewer();
      final service = createService(viewer: viewer);

      await service.goToDestination(
        Future<Object?>.value(<dynamic>[
          1,
          {'name': 'Fit'}
        ]),
      );

      expect(viewer.lastRequest!.pageNumber, 2);
    });

    test('focuses the matching text layer once it is rendered', () async {
      final bus = EventBus();
      var focusCount = 0;
      final service = createService(eventBus: bus);
      await service.goToDestination(<dynamic>[
        1,
        {'name': 'Fit'}
      ]);

      bus.dispatch(
        'textlayerrendered',
        TextLayerRenderedEvent(
            pageNumber: 1, focusTextLayer: () => fail('bad')),
      );
      bus.dispatch(
        'textlayerrendered',
        TextLayerRenderedEvent(
          pageNumber: 2,
          focusTextLayer: () => focusCount++,
        ),
      );
      bus.dispatch(
        'textlayerrendered',
        TextLayerRenderedEvent(
          pageNumber: 2,
          focusTextLayer: () => focusCount++,
        ),
      );

      expect(focusCount, 1);
    });

    test('reports malformed, failed, and out-of-range destinations', () async {
      final errors = <String>[];
      final document = FakeDocument(throwPageIndex: true);
      final service = createService(document: document, errors: errors);

      await service.goToDestination(42);
      await service.goToDestination(<dynamic>[
        <String, int>{'num': 1, 'gen': 0},
        {'name': 'Fit'},
      ]);
      await service.goToDestination(<dynamic>[
        99,
        {'name': 'Fit'}
      ]);

      expect(errors, hasLength(3));
      expect(errors[0], contains('not a valid destination array'));
      expect(errors[1], contains('not a valid page reference'));
      expect(errors[2], contains('not a valid page number'));
    });
  });

  group('page navigation', () {
    test('resolves labels and pushes browser history', () {
      final viewer = FakeViewer(labels: const {'iv': 4});
      final trace = <String>[];
      final history = FakeHistory(trace);
      final service = createService(viewer: viewer, history: history);

      service.goToPage('iv');

      expect(viewer.lastRequest!.pageNumber, 4);
      expect(history.pushedPage, 4);
      expect(trace, <String>['current', 'page']);
    });

    test('coerces numeric strings and rejects invalid pages', () {
      final errors = <String>[];
      final viewer = FakeViewer();
      final service = createService(viewer: viewer, errors: errors);

      service.goToPage('2.9');
      expect(viewer.lastRequest!.pageNumber, 2);

      service.goToPage(0);
      service.goToPage(100);
      expect(errors, hasLength(2));
    });

    test('goToXY creates an XYZ destination and preserves zoom', () {
      final viewer = FakeViewer();
      final service = createService(viewer: viewer);

      service.goToXY(3, 12.5, 48, allowNegativeOffset: true);

      final request = viewer.lastRequest!;
      expect(request.pageNumber, 3);
      expect(request.destination, <dynamic>[
        null,
        {'name': 'XYZ'},
        12.5,
        48,
      ]);
      expect(request.ignoreDestinationZoom, isTrue);
      expect(request.allowNegativeOffset, isTrue);
    });
  });

  group('setHash', () {
    test('dispatches search terms, page mode, and sets a simple page', () {
      final bus = EventBus();
      Object? findEvent;
      Object? modeEvent;
      bus.on('findfromurlhash', (event) => findEvent = event);
      bus.on('pagemode', (event) => modeEvent = event);
      final viewer = FakeViewer();
      final service = createService(eventBus: bus, viewer: viewer);

      service.setHash('search=one%20two&page=3&pagemode=thumbs');

      expect((findEvent! as Map)['query'], <String>['one', 'two']);
      expect((modeEvent! as Map)['mode'], 'thumbs');
      expect(viewer.currentPageNumber, 3);
    });

    test('keeps a phrase search as one string', () {
      final bus = EventBus();
      Object? findEvent;
      bus.on('findfromurlhash', (event) => findEvent = event);
      final service = createService(eventBus: bus);

      service.setHash('search=%22one%20two%22&phrase=true');

      expect((findEvent! as Map)['query'], 'one two');
    });

    test('builds numeric XYZ destinations', () {
      final viewer = FakeViewer()..currentPageNumber = 2;
      final service = createService(viewer: viewer);

      service.setHash('page=4&zoom=150,20,30');

      final request = viewer.lastRequest!;
      expect(request.pageNumber, 4);
      expect(request.destination, <dynamic>[
        null,
        {'name': 'XYZ'},
        20,
        30,
        1.5,
      ]);
      expect(request.allowNegativeOffset, isTrue);
    });

    test('builds Fit, FitH, and FitR destinations', () {
      final viewer = FakeViewer();
      final service = createService(viewer: viewer);

      service.setHash('zoom=Fit');
      expect(viewer.lastRequest!.destination, <dynamic>[
        null,
        {'name': 'Fit'},
      ]);

      service.setHash('zoom=FitH,200');
      expect(viewer.lastRequest!.destination, <dynamic>[
        null,
        {'name': 'FitH'},
        200,
      ]);

      service.setHash('zoom=FitR,1,2,300,400');
      expect(viewer.lastRequest!.destination, <dynamic>[
        null,
        {'name': 'FitR'},
        1,
        2,
        300,
        400,
      ]);
    });

    test('reports invalid FitR and zoom arguments', () {
      final errors = <String>[];
      final service = createService(errors: errors);

      service.setHash('zoom=FitR,1,2');
      service.setHash('zoom=FitWrong');

      expect(errors, hasLength(2));
      expect(errors.first, contains('Not enough parameters'));
      expect(errors.last, contains('not a valid zoom value'));
    });

    test('handles named and JSON explicit destinations', () async {
      final document = FakeDocument(
        destinations: <String, List<dynamic>>{
          'chapter': <dynamic>[
            0,
            {'name': 'Fit'}
          ],
        },
      );
      final viewer = FakeViewer();
      final service = createService(document: document, viewer: viewer);

      service.setHash('chapter');
      await pumpEventQueue();
      expect(viewer.lastRequest!.pageNumber, 1);

      service.setHash('%5B2%2C%7B%22name%22%3A%22Fit%22%7D%5D');
      await pumpEventQueue();
      expect(viewer.lastRequest!.pageNumber, 3);
    });

    test('named destination overrides the page parameter', () async {
      final document = FakeDocument(
        destinations: <String, List<dynamic>>{
          'final': <dynamic>[
            5,
            {'name': 'Fit'}
          ],
        },
      );
      final viewer = FakeViewer();
      final service = createService(document: document, viewer: viewer);

      service.setHash('page=2&nameddest=final');
      await pumpEventQueue();

      expect(viewer.lastRequest!.pageNumber, 6);
    });
  });

  group('actions', () {
    test('executes all standard named actions and dispatches events', () {
      final bus = EventBus();
      final actions = <String>[];
      bus.on('namedaction', (event) => actions.add((event! as Map)['action']));
      final trace = <String>[];
      final viewer = FakeViewer();
      final history = FakeHistory(trace);
      final service = createService(
        eventBus: bus,
        viewer: viewer,
        history: history,
      );

      service.executeNamedAction('GoBack');
      service.executeNamedAction('GoForward');
      service.executeNamedAction('NextPage');
      service.executeNamedAction('PrevPage');
      service.executeNamedAction('LastPage');
      expect(viewer.currentPageNumber, 8);
      service.executeNamedAction('FirstPage');
      expect(viewer.currentPageNumber, 1);
      service.executeNamedAction('Unknown');

      expect(history.backCalls, 1);
      expect(history.forwardCalls, 1);
      expect(viewer.nextCalls, 1);
      expect(viewer.previousCalls, 1);
      expect(actions, <String>[
        'GoBack',
        'GoForward',
        'NextPage',
        'PrevPage',
        'LastPage',
        'FirstPage',
        'Unknown',
      ]);
    });

    test('updates optional-content state and replaces its future', () async {
      final viewer = FakeViewer();
      final service = createService(viewer: viewer);
      final action = <String, dynamic>{
        'state': <dynamic>['ON', 'layer1'],
        'preserveRB': true,
      };

      await service.executeSetOCGState(action);

      expect(viewer.config.lastAction, same(action));
      expect(viewer.replacedConfig, same(viewer.config));
    });

    test('does not install optional-content state after document changes',
        () async {
      final completer = Completer<PDFOptionalContentConfig>();
      final viewer = FakeViewer(optionalContentCompleter: completer);
      final service = createService(viewer: viewer);

      final pending = service.executeSetOCGState(<String, dynamic>{});
      service.setDocument(FakeDocument());
      completer.complete(FakeOptionalContentConfig());
      await pending;

      expect(viewer.replacedConfig, isNull);
    });
  });

  test('SimpleLinkService ignores documents', () {
    final service = SimpleLinkService();
    service.setDocument(FakeDocument(), 'https://example.com');
    expect(service.pdfDocument, isNull);
    expect(service.pagesCount, 0);
  });
}

PDFLinkService createService({
  EventBus? eventBus,
  FakeDocument? document,
  FakeViewer? viewer,
  FakeHistory? history,
  List<String>? errors,
  bool ignoreDestinationZoom = false,
}) {
  final service = PDFLinkService(
    eventBus: eventBus,
    ignoreDestinationZoom: ignoreDestinationZoom,
    onError: errors?.add,
  );
  service
    ..setDocument(document ?? FakeDocument())
    ..setViewer(viewer ?? FakeViewer())
    ..setHistory(history);
  return service;
}

final class FakeLink implements LinkElement {
  String hrefValue = '';
  String titleValue = '';
  String targetValue = '';
  String relValue = '';
  bool disabled = false;

  @override
  set href(String value) => hrefValue = value;

  @override
  set title(String value) => titleValue = value;

  @override
  set target(String value) => targetValue = value;

  @override
  set rel(String value) => relValue = value;

  @override
  void disableActivation() => disabled = true;
}

final class FakeDocument implements PDFLinkDocument {
  FakeDocument({
    this.pagesCount = 8,
    this.destinations = const {},
    this.cachedPages = const {},
    this.pageIndexes = const {},
    this.throwPageIndex = false,
  });

  @override
  final int pagesCount;
  final Map<String, List<dynamic>> destinations;
  final Map<Object, int> cachedPages;
  final Map<Object, int> pageIndexes;
  final bool throwPageIndex;
  int pageIndexCalls = 0;

  @override
  int? cachedPageNumber(Object reference) => cachedPages[reference];

  @override
  Future<List<dynamic>?> getDestination(String name) async =>
      destinations[name];

  @override
  Future<int> getPageIndex(Object reference) async {
    pageIndexCalls++;
    if (throwPageIndex || !pageIndexes.containsKey(reference)) {
      throw StateError('Unknown reference');
    }
    return pageIndexes[reference]!;
  }
}

final class FakeOptionalContentConfig implements PDFOptionalContentConfig {
  Map<String, dynamic>? lastAction;

  @override
  void setOCGState(Map<String, dynamic> action) => lastAction = action;
}

final class FakeViewer implements PDFLinkViewer {
  FakeViewer({
    this.labels = const {},
    this.onScroll,
    Completer<PDFOptionalContentConfig>? optionalContentCompleter,
  }) : _optionalContentCompleter = optionalContentCompleter;

  final Map<String, int> labels;
  final void Function(PDFViewerScrollRequest request)? onScroll;
  final Completer<PDFOptionalContentConfig>? _optionalContentCompleter;
  final FakeOptionalContentConfig config = FakeOptionalContentConfig();

  @override
  int currentPageNumber = 1;

  @override
  int pagesRotation = 0;

  bool isInPresentationModeValue = false;
  PDFViewerScrollRequest? lastRequest;
  int nextCalls = 0;
  int previousCalls = 0;
  PDFOptionalContentConfig? replacedConfig;

  @override
  bool get isInPresentationMode => isInPresentationModeValue;

  @override
  int? pageLabelToPageNumber(String label) => labels[label];

  @override
  void scrollPageIntoView(PDFViewerScrollRequest request) {
    lastRequest = request;
    onScroll?.call(request);
  }

  @override
  void nextPage() => nextCalls++;

  @override
  void previousPage() => previousCalls++;

  @override
  Future<PDFOptionalContentConfig> get optionalContentConfig =>
      _optionalContentCompleter?.future ?? Future.value(config);

  @override
  void replaceOptionalContentConfig(PDFOptionalContentConfig config) {
    replacedConfig = config;
  }
}

final class FakeHistory implements PDFLinkHistory {
  FakeHistory(this.trace);

  final List<String> trace;
  String? namedDestination;
  List<dynamic>? explicitDestination;
  int? pageNumber;
  int? pushedPage;
  int backCalls = 0;
  int forwardCalls = 0;

  @override
  void pushCurrentPosition() => trace.add('current');

  @override
  void pushDestination({
    String? namedDestination,
    required List<dynamic> explicitDestination,
    required int pageNumber,
  }) {
    trace.add('destination');
    this.namedDestination = namedDestination;
    this.explicitDestination = explicitDestination;
    this.pageNumber = pageNumber;
  }

  @override
  void pushPage(int pageNumber) {
    trace.add('page');
    pushedPage = pageNumber;
  }

  @override
  void back() {
    trace.add('back');
    backCalls++;
  }

  @override
  void forward() {
    trace.add('forward');
    forwardCalls++;
  }
}
