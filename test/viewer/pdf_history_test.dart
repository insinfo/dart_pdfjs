import 'dart:async';

import 'package:test/test.dart';

import '../../example/src/event_utils.dart';
import '../../example/src/pdf_history.dart';
import '../../example/src/pdf_link_service.dart';

void main() {
  group('isDestHashesEqual', () {
    test('rejects non-equal destination hashes', () {
      expect(isDestHashesEqual(null, 'page.157'), isFalse);
      expect(isDestHashesEqual('title.0', 'page.157'), isFalse);
      expect(isDestHashesEqual('page=1&zoom=auto', 'page.157'), isFalse);
      expect(isDestHashesEqual('nameddest-page.157', 'page.157'), isFalse);
      expect(isDestHashesEqual('page.157', 'nameddest=page.157'), isFalse);

      final destination = <dynamic>[
        <String, int>{'num': 3757, 'gen': 0},
        <String, String>{'name': 'XYZ'},
        92.918,
        748.972,
        null,
      ];
      expect(isDestHashesEqual(destination.toString(), 'page.157'), isFalse);
      expect(isDestHashesEqual('page.157', destination.toString()), isFalse);
    });

    test('accepts identical and nameddest destination hashes', () {
      expect(isDestHashesEqual('page.157', 'page.157'), isTrue);
      expect(isDestHashesEqual('nameddest=page.157', 'page.157'), isTrue);
      expect(
        isDestHashesEqual('nameddest=page.157&zoom=100', 'page.157'),
        isTrue,
      );
    });
  });

  group('isDestArraysEqual', () {
    final first = <dynamic>[
      <String, int>{'num': 1, 'gen': 0},
      <String, String>{'name': 'XYZ'},
      0,
      375,
      null,
    ];
    final second = <dynamic>[
      <String, int>{'num': 5, 'gen': 0},
      <String, String>{'name': 'XYZ'},
      0,
      375,
      null,
    ];
    final third = <dynamic>[
      <String, int>{'num': 1, 'gen': 0},
      <String, String>{'name': 'XYZ'},
      750,
      0,
      null,
    ];
    final fourth = <dynamic>[
      <String, int>{'num': 1, 'gen': 0},
      <String, String>{'name': 'XYZ'},
      0,
      375,
      1.0,
    ];
    final fifth = <dynamic>[
      <String, int>{'gen': 0, 'num': 1},
      <String, String>{'name': 'XYZ'},
      0,
      375,
      null,
    ];

    test('rejects invalid and different arrays', () {
      expect(isDestArraysEqual(first, null), isFalse);
      expect(isDestArraysEqual(first, <int>[1, 2, 3, 4, 5]), isFalse);
      expect(isDestArraysEqual(first, second), isFalse);
      expect(isDestArraysEqual(first, third), isFalse);
      expect(isDestArraysEqual(first, fourth), isFalse);
      expect(
          isDestArraysEqual(<dynamic>[
            <int>[1]
          ], <dynamic>[
            <int>[1]
          ]),
          isFalse);
    });

    test('accepts equivalent arrays and ignores map key order', () {
      expect(isDestArraysEqual(first, first), isTrue);
      expect(isDestArraysEqual(first, fifth), isTrue);
      expect(isDestArraysEqual(first, List<dynamic>.from(first)), isTrue);
      expect(isDestArraysEqual(<double>[double.nan], <double>[double.nan]),
          isTrue);
    });
  });

  group('PDFHistory', () {
    late EventBus eventBus;
    late FakeHistoryEnvironment environment;
    late FakeDocument document;
    late FakeViewer viewer;
    late PDFLinkService linkService;
    late PDFHistory history;

    setUp(() {
      eventBus = EventBus();
      environment = FakeHistoryEnvironment();
      document = FakeDocument(10);
      viewer = FakeViewer();
      linkService = PDFLinkService(eventBus: eventBus)
        ..setDocument(document, 'https://example.com/viewer')
        ..setViewer(viewer);
      history = PDFHistory(
        linkService: linkService,
        eventBus: eventBus,
        environment: environment,
        updateViewareaTimeout: const Duration(milliseconds: 10),
        hashChangeTimeout: const Duration(milliseconds: 10),
      );
      linkService.setHistory(history);
    });

    tearDown(() => history.reset());

    test('initialize replaces an empty history entry', () {
      history.initialize(fingerprint: 'document-a');

      expect(history.initialized, isTrue);
      expect(environment.entries, hasLength(1));
      expect(environment.replaceCalls, 1);
      expect(environment.state, <String, dynamic>{
        'fingerprint': 'document-a',
        'uid': 0,
        'destination': null,
      });
      expect(history.initialBookmark, isNull);
      expect(history.initialRotation, isNull);
    });

    test('initialize reads page, rotation and hash from the URL', () {
      environment.hash = '#page=4&zoom=125';
      viewer.pagesRotation = 90;
      history.initialize(fingerprint: 'document-a');

      final destination = environment.state!['destination'] as Map;
      expect(destination['hash'], 'page=4&zoom=125');
      expect(destination['page'], 4);
      expect(destination['rotation'], 90);
    });

    test('named destination in initial hash does not infer a page', () {
      environment.hash = '#page=4&nameddest=chapter';
      history.initialize(fingerprint: 'document-a');

      final destination = environment.state!['destination'] as Map;
      expect(destination['page'], isNull);
      expect(destination['hash'], 'page=4&nameddest=chapter');
    });

    test('initialize restores a valid browser state', () {
      environment.seed(<String, dynamic>{
        'fingerprint': 'document-a',
        'uid': 7,
        'destination': <String, dynamic>{
          'hash': 'page=6',
          'page': 6,
          'rotation': 180,
        },
      });
      history.initialize(fingerprint: 'document-a');

      expect(environment.replaceCalls, 0);
      expect(history.initialBookmark, 'page=6');
      expect(history.initialRotation, 180);
    });

    test('reload accepts a same-length changed fingerprint', () {
      environment
        ..wasReloaded = true
        ..seed(<String, dynamic>{
          'fingerprint': 'old-print',
          'uid': 2,
          'destination': <String, dynamic>{
            'hash': 'page=3',
            'page': 3,
            'rotation': 0,
          },
        });
      history.initialize(fingerprint: 'new-print');

      expect(environment.replaceCalls, 0);
      expect(history.initialBookmark, 'page=3');
    });

    test('resetHistory ignores reusable browser state', () {
      environment.seed(<String, dynamic>{
        'fingerprint': 'document-a',
        'uid': 2,
        'destination': <String, dynamic>{
          'hash': 'page=3',
          'page': 3,
          'rotation': 0,
        },
      });
      history.initialize(fingerprint: 'document-a', resetHistory: true);

      expect(environment.replaceCalls, 1);
      expect(environment.state!['uid'], 0);
      expect(environment.state!['destination'], isNull);
    });

    test('push creates entries and suppresses identical destination', () async {
      history.initialize(fingerprint: 'document-a');
      history.push(
        namedDest: 'chapter-2',
        explicitDest: <dynamic>[
          1,
          <String, String>{'name': 'Fit'}
        ],
        pageNumber: 2,
      );
      await Future<void>.delayed(Duration.zero);

      expect(environment.entries, hasLength(1));
      expect(environment.state!['uid'], 0);
      final destination = environment.state!['destination'] as Map;
      expect(destination['hash'], 'chapter-2');
      expect(destination['page'], 2);

      history.push(
        namedDest: 'chapter-2',
        explicitDest: <dynamic>[
          1,
          <String, String>{'name': 'Fit'}
        ],
        pageNumber: 2,
      );
      expect(environment.entries, hasLength(1));
    });

    test('pushPage validates bounds and avoids duplicates', () async {
      history.initialize(fingerprint: 'document-a');
      history.pushPage(0);
      history.pushPage(11);
      expect(environment.entries, hasLength(1));

      history.pushPage(5);
      await Future<void>.delayed(Duration.zero);
      history.pushPage(5);
      expect(environment.entries, hasLength(1));
      expect((environment.state!['destination'] as Map)['hash'], 'page=5');
    });

    test('updateUrl writes destination into non-file URL', () async {
      environment.href = 'https://example.com/viewer?file=a.pdf#old';
      history.initialize(fingerprint: 'document-a', updateUrl: true);
      history.pushPage(3);
      await Future<void>.delayed(Duration.zero);

      expect(
          environment.lastUrl, 'https://example.com/viewer?file=a.pdf#page=3');
    });

    test('updateUrl does not alter file URLs', () async {
      environment
        ..href = 'file:///tmp/viewer.html'
        ..protocol = 'file:';
      history.initialize(fingerprint: 'document-a', updateUrl: true);
      history.pushPage(3);
      await Future<void>.delayed(Duration.zero);

      expect(environment.lastUrl, isNull);
    });

    test('viewport position can be explicitly pushed', () {
      history.initialize(fingerprint: 'document-a');
      viewer.currentPageNumber = 4;
      eventBus.dispatch('updateviewarea', <String, Object?>{
        'location': const PDFHistoryLocation(
          pdfOpenParams: '#page=4&zoom=auto,0,20',
          pageNumber: 4,
          rotation: 0,
        ),
      });
      history.pushCurrentPosition();

      expect(environment.entries, hasLength(1));
      final destination = environment.state!['destination'] as Map;
      expect(destination['page'], 4);
      expect(destination['first'], 4);
      expect(destination['hash'], 'page=4&zoom=auto,0,20');
    });

    test('idle viewport stores and replaces a temporary entry', () async {
      history.initialize(fingerprint: 'document-a');
      viewer.currentPageNumber = 2;
      eventBus.dispatch('updateviewarea', <String, Object?>{
        'location': const PDFHistoryLocation(
          pdfOpenParams: '#page=2',
          pageNumber: 2,
          rotation: 0,
        ),
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(environment.entries, hasLength(1));
      expect((environment.state!['destination'] as Map)['temporary'], isTrue);

      viewer.currentPageNumber = 3;
      eventBus.dispatch('updateviewarea', <String, Object?>{
        'location': const PDFHistoryLocation(
          pdfOpenParams: '#page=3',
          pageNumber: 3,
          rotation: 0,
        ),
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(environment.entries, hasLength(1));
      expect((environment.state!['destination'] as Map)['page'], 3);
    });

    test('back and forward complete a navigation cycle', () async {
      history.initialize(fingerprint: 'document-a');
      history.pushPage(2);
      await Future<void>.delayed(Duration.zero);
      history.pushPage(7);
      await Future<void>.delayed(Duration.zero);
      expect(environment.entries, hasLength(2));

      history.back();
      await Future<void>.delayed(Duration.zero);
      expect(viewer.currentPageNumber, 2);
      expect(environment.backCalls, 1);

      history.forward();
      await Future<void>.delayed(Duration.zero);
      expect(viewer.currentPageNumber, 7);
      expect(environment.forwardCalls, 1);
    });

    test('popstate restores rotation and explicit destination', () async {
      history.initialize(fingerprint: 'document-a');
      history.push(
        explicitDest: <dynamic>[
          4,
          <String, String>{'name': 'XYZ'},
          0,
          0
        ],
        pageNumber: 5,
      );
      await Future<void>.delayed(Duration.zero);
      history.pushPage(8);
      await Future<void>.delayed(Duration.zero);
      viewer.pagesRotation = 90;

      history.back();
      await Future<void>.delayed(Duration.zero);
      expect(viewer.pagesRotation, 0);
      expect(viewer.lastRequest?.pageNumber, 5);
      expect(viewer.lastRequest?.destination, isNotNull);
    });

    test('changed hash blocks hash handling until event or timeout', () async {
      history.initialize(fingerprint: 'document-a');
      history.pushPage(2);
      await Future<void>.delayed(Duration.zero);
      history.pushPage(3);
      await Future<void>.delayed(Duration.zero);
      environment.hash = '#page=1';

      history.back();
      expect(history.popStateInProgress, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(history.popStateInProgress, isTrue);
      environment.emitHashChange();
      await Future<void>.delayed(Duration.zero);
      expect(history.popStateInProgress, isFalse);
    });

    test('null popstate converts a user hash change into state', () {
      history.initialize(fingerprint: 'document-a');
      environment
        ..hash = '#page=9'
        ..emitPopState(null);

      final destination = environment.state!['destination'] as Map;
      expect(destination['hash'], 'page=9');
      expect(destination['page'], 9);
      expect(environment.state!['uid'], 1);
    });

    test('pagesloaded threshold eventually permits position update', () {
      environment.hash = '#nameddest=chapter';
      history.initialize(fingerprint: 'document-a');
      eventBus.dispatch('pagesinit');
      eventBus.dispatch('pagesloaded', <String, Object?>{'pagesCount': 10});
      viewer.currentPageNumber = 6;
      for (var index = 0; index <= positionUpdatedThreshold; index++) {
        eventBus.dispatch('updateviewarea', <String, Object?>{
          'location': const PDFHistoryLocation(
            pdfOpenParams: '#page=6',
            pageNumber: 6,
            rotation: 0,
          ),
        });
      }
      history.pushCurrentPosition();

      expect(environment.entries, hasLength(2));
      expect((environment.state!['destination'] as Map)['page'], 6);
    });

    test('reset detaches browser and event-bus listeners', () {
      history.initialize(fingerprint: 'document-a');
      history.reset();
      final writes = environment.replaceCalls + environment.pushCalls;
      environment.emitPopState(null);
      eventBus.dispatch('updateviewarea', <String, Object?>{
        'location': const PDFHistoryLocation(
          pdfOpenParams: '#page=3',
          pageNumber: 3,
          rotation: 0,
        ),
      });

      expect(environment.replaceCalls + environment.pushCalls, writes);
      expect(history.initialized, isFalse);
      expect(history.initialBookmark, isNull);
    });
  });

  group('updateUrlHash', () {
    test('adds and replaces URL fragments', () {
      expect(updateUrlHash('https://example.com/a', 'page=2'),
          'https://example.com/a#page=2');
      expect(updateUrlHash('https://example.com/a#old', 'page=2'),
          'https://example.com/a#page=2');
    });
  });
}

final class FakeHistoryEnvironment implements PDFHistoryEnvironment {
  final List<Map<String, dynamic>> entries = <Map<String, dynamic>>[];
  int index = -1;
  int replaceCalls = 0;
  int pushCalls = 0;
  int backCalls = 0;
  int forwardCalls = 0;
  String hash = '';
  String href = 'https://example.com/viewer';
  String protocol = 'https:';
  bool wasReloaded = false;
  String? lastUrl;
  final List<void Function(Map<String, dynamic>? state)> _popListeners = [];
  final List<void Function()> _pageHideListeners = [];
  Completer<void>? _hashChangeCompleter;

  @override
  Map<String, dynamic>? get state =>
      index < 0 ? null : _cloneMap(entries[index]);

  void seed(Map<String, dynamic> value) {
    entries
      ..clear()
      ..add(_cloneMap(value));
    index = 0;
  }

  @override
  void replaceState(Map<String, dynamic> state, String? url) {
    replaceCalls++;
    lastUrl = url;
    if (index < 0) {
      entries.add(_cloneMap(state));
      index = 0;
    } else {
      entries[index] = _cloneMap(state);
    }
    _applyUrl(url);
  }

  @override
  void pushState(Map<String, dynamic> state, String? url) {
    pushCalls++;
    lastUrl = url;
    if (index + 1 < entries.length) {
      entries.removeRange(index + 1, entries.length);
    }
    entries.add(_cloneMap(state));
    index++;
    _applyUrl(url);
  }

  void _applyUrl(String? url) {
    if (url == null) return;
    href = url;
    final fragment = url.indexOf('#');
    hash = fragment < 0 ? '' : url.substring(fragment);
  }

  @override
  void back() {
    backCalls++;
    if (index <= 0) return;
    index--;
    emitPopState(state);
  }

  @override
  void forward() {
    forwardCalls++;
    if (index + 1 >= entries.length) return;
    index++;
    emitPopState(state);
  }

  @override
  HistoryEventCanceler onPopState(
      void Function(Map<String, dynamic>? state) listener) {
    _popListeners.add(listener);
    return () => _popListeners.remove(listener);
  }

  @override
  HistoryEventCanceler onPageHide(void Function() listener) {
    _pageHideListeners.add(listener);
    return () => _pageHideListeners.remove(listener);
  }

  void emitPopState(Map<String, dynamic>? value) {
    for (final listener in List.of(_popListeners)) {
      listener(value == null ? null : _cloneMap(value));
    }
  }

  void emitPageHide() {
    for (final listener in List.of(_pageHideListeners)) {
      listener();
    }
  }

  @override
  Future<void> waitForHashChange(Duration timeout) {
    final completer = _hashChangeCompleter = Completer<void>();
    Timer(timeout, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  void emitHashChange() {
    final completer = _hashChangeCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }
}

Map<String, dynamic> _cloneMap(Map<String, dynamic> source) => source.map(
      (key, value) => MapEntry(key, _cloneValue(value)),
    );

Object? _cloneValue(Object? value) {
  if (value is Map) {
    return value
        .map((key, child) => MapEntry(key.toString(), _cloneValue(child)));
  }
  if (value is List) return value.map(_cloneValue).toList();
  return value;
}

final class FakeDocument implements PDFLinkDocument {
  FakeDocument(this.pagesCount);
  @override
  final int pagesCount;
  @override
  int? cachedPageNumber(Object reference) => null;
  @override
  Future<List<dynamic>?> getDestination(String name) async => null;
  @override
  Future<int> getPageIndex(Object reference) async =>
      reference is int ? reference : 0;
}

final class FakeViewer implements PDFLinkViewer {
  @override
  int currentPageNumber = 1;
  @override
  int pagesRotation = 0;
  PDFViewerScrollRequest? lastRequest;

  @override
  bool get isInPresentationMode => false;
  @override
  void nextPage() => currentPageNumber++;
  @override
  void previousPage() => currentPageNumber--;
  @override
  int? pageLabelToPageNumber(String label) => int.tryParse(label);
  @override
  void scrollPageIntoView(PDFViewerScrollRequest request) {
    lastRequest = request;
    currentPageNumber = request.pageNumber;
  }

  @override
  Future<PDFOptionalContentConfig> get optionalContentConfig =>
      throw UnimplementedError();
  @override
  void replaceOptionalContentConfig(PDFOptionalContentConfig config) {}
}
