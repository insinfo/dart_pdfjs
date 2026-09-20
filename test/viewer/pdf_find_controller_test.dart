import 'dart:async';

import 'package:test/test.dart';

import '../../example/src/event_utils.dart';
import '../../example/src/pdf_find_controller.dart';

final class _FakeTextItem {
  const _FakeTextItem(this.str, {this.hasEOL = false});
  final String str;
  final bool hasEOL;
}

final class _FakePage {
  const _FakePage(this.items, {this.failure});
  final List<_FakeTextItem> items;
  final Object? failure;

  Future<Map<String, Object>> getTextContent() async {
    if (failure != null) throw failure!;
    return {
      'items': [
        for (final item in items) {'str': item.str, 'hasEOL': item.hasEOL},
      ],
    };
  }
}

final class _FakeDocument {
  const _FakeDocument(this.pages);
  final List<_FakePage> pages;
  int get numPages => pages.length;
  Future<_FakePage> getPage(int number) async => pages[number - 1];
}

final class _FakeLinkService {
  _FakeLinkService(this.document);
  final _FakeDocument document;
  int page = 1;
  int get pagesCount => document.numPages;
}

final class _Scrollable implements FindScrollableElement {
  int calls = 0;
  @override
  void scrollIntoView({String block = 'start', String inline = 'center'}) {
    expect(block, 'start');
    expect(inline, 'center');
    calls++;
  }
}

FindParameters _parameters(
  Object query, {
  String type = '',
  bool caseSensitive = false,
  bool entireWord = false,
  bool previous = false,
  bool matchDiacritics = false,
  bool highlightAll = false,
}) =>
    FindParameters(
      query: query,
      type: type,
      caseSensitive: caseSensitive,
      entireWord: entireWord,
      findPrevious: previous,
      matchDiacritics: matchDiacritics,
      highlightAll: highlightAll,
    );

({EventBus bus, PDFFindController controller, _FakeLinkService links}) _create(
  List<String> pages, {
  bool progressive = true,
}) {
  final document = _FakeDocument([
    for (final text in pages) _FakePage([_FakeTextItem(text)]),
  ]);
  final links = _FakeLinkService(document);
  final bus = EventBus();
  final controller = PDFFindController(
    linkService: links,
    eventBus: bus,
    updateMatchesCountOnProgress: progressive,
    findDelay: Duration.zero,
  )..setDocument(document);
  return (bus: bus, controller: controller, links: links);
}

Future<Map> _search(
  EventBus bus,
  FindParameters parameters, {
  FindState terminal = FindState.found,
}) {
  final done = Completer<Map>();
  late EventBusListener listener;
  listener = (event) {
    final data = event! as Map;
    if (data['state'] != terminal) return;
    bus.off('updatefindcontrolstate', listener);
    if (!done.isCompleted) done.complete(data);
  };
  bus.on('updatefindcontrolstate', listener);
  bus.dispatch('find', parameters);
  return done.future.timeout(const Duration(seconds: 3));
}

void main() {
  group('normalizeFindText', () {
    test('normalizes punctuation, fractions, ligatures, and fullwidth text',
        () {
      final data = normalizeFindText('“½” oﬃce ＡＢＣ');
      expect(data.text, '"1/2" office ABC');
      expect(data.originalRange(1, 3), (1, 1));
      expect(data.originalRange(7, 3), (5, 1));
    });

    test('decomposes Latin accents and retains their source range', () {
      final data = normalizeFindText('café déjà');
      expect(data.text, 'cafe\u0301 de\u0301ja\u0300');
      expect(data.hasDiacritics, isTrue);
      expect(data.originalRange(3, 2), (3, 1));
    });

    test('joins probable words split with a dash at end of line', () {
      final data = normalizeFindText('opti-\nmize');
      expect(data.text, 'optimize');
      expect(data.originalRange(0, data.text.length), (0, 10));
    });

    test('keeps compound dash, replaces ordinary EOL, removes CJK EOL', () {
      expect(normalizeFindText('42-\nnext').text, '42-next');
      expect(normalizeFindText('hello\nworld').text, 'hello world');
      expect(normalizeFindText('検\n知').text, '検知');
    });

    test('decomposes Hangul syllables algorithmically', () {
      final data = normalizeFindText('한');
      expect(data.text.runes, [0x1112, 0x1161, 0x11ab]);
      expect(data.originalRange(0, data.text.length), (0, 1));
    });

    test('tracks supplementary Unicode source widths', () {
      final data = normalizeFindText('A𠮷B');
      expect(data.originalRange(1, 2), (1, 2));
    });
  });

  group('PDFFindController', () {
    test('performs a normal forward search and reports page matches', () async {
      final setup = _create(['Dynamic x Dynamic', 'none', 'dynamic']);
      await _search(setup.bus, _parameters('Dynamic'));

      expect(setup.controller.pageMatches, [
        [0, 10],
        <int>[],
        [0],
      ]);
      expect(setup.controller.pageMatchesLength, [
        [7, 7],
        <int>[],
        [7],
      ]);
      expect(setup.controller.selected.pageIndex, 0);
      expect(setup.controller.selected.matchIndex, 0);
    });

    test('performs a backwards search starting at the last page', () async {
      final setup = _create(['nothing here', 'conference twice conference']);
      await _search(
        setup.bus,
        _parameters('conference', previous: true),
        terminal: FindState.wrapped,
      );
      expect(setup.controller.selected.pageIndex, 1);
      expect(setup.controller.selected.matchIndex, 1);
    });

    test('honors case sensitivity', () async {
      final setup = _create(['Dynamic dynamic DYNAMIC']);
      await _search(
        setup.bus,
        _parameters('Dynamic', caseSensitive: true),
      );
      expect(setup.controller.pageMatches.single, [0]);
    });

    test('honors entire-word boundaries', () async {
      final setup = _create(['Government Governmental preGovernment']);
      await _search(setup.bus, _parameters('Government', entireWord: true));
      expect(setup.controller.pageMatches.single, [0]);
    });

    test('finds multiple terms longest-first without duplicate positions',
        () async {
      final setup = _create(['alternate solution, then solution']);
      await _search(setup.bus, _parameters(['alternate solution', 'solution']));
      expect(setup.controller.pageMatches.single, [0, 25]);
      expect(setup.controller.pageMatchesLength.single, [18, 8]);
    });

    test('maps fraction and ligature matches to original offsets', () async {
      final setup = _create(['A ½ fraction and oﬃce']);
      await _search(setup.bus, _parameters('1/2'));
      expect(setup.controller.pageMatches.single, [2]);
      expect(setup.controller.pageMatchesLength.single, [1]);

      await _search(setup.bus, _parameters('office', type: 'again'));
      expect(setup.controller.pageMatches.single, [17]);
      expect(setup.controller.pageMatchesLength.single, [4]);
    });

    test('ignores ordinary diacritics unless explicitly requested', () async {
      final setup = _create(['àáâä a e ë']);
      await _search(setup.bus, _parameters('a'));
      expect(setup.controller.pageMatches.single, [0, 1, 2, 3, 5]);

      await _search(
        setup.bus,
        _parameters('ë', type: 'again', matchDiacritics: true),
      );
      expect(setup.controller.pageMatches.single, [9]);
    });

    test('matches across ordinary, hyphenated, and CJK line endings', () async {
      final document = _FakeDocument([
        const _FakePage([
          _FakeTextItem('user', hasEOL: true),
          _FakeTextItem('experience'),
        ]),
        const _FakePage([
          _FakeTextItem('opti-', hasEOL: true),
          _FakeTextItem('mize'),
        ]),
        const _FakePage([
          _FakeTextItem('検', hasEOL: true),
          _FakeTextItem('知'),
        ]),
      ]);
      final links = _FakeLinkService(document);
      final bus = EventBus();
      final controller = PDFFindController(
        linkService: links,
        eventBus: bus,
        findDelay: Duration.zero,
      )..setDocument(document);

      await _search(bus, _parameters('user experience'));
      expect(controller.pageMatches[0], [0]);
      await _search(bus, _parameters('optimize', type: 'again'));
      expect(controller.pageMatches[1], [0]);
      await _search(bus, _parameters('検知', type: 'again'));
      expect(controller.pageMatches[2], [0]);
    });

    test('find again advances, wraps, and updates link-service page', () async {
      final setup = _create(['foo foo', 'foo']);
      await _search(setup.bus, _parameters('foo'));
      expect(setup.controller.selected.matchIndex, 0);

      await _search(setup.bus, _parameters('foo', type: 'again'));
      expect(setup.controller.selected.matchIndex, 1);

      await _search(setup.bus, _parameters('foo', type: 'again'));
      expect(setup.controller.selected.pageIndex, 1);
      expect(setup.links.page, 2);

      final wrapped = await _search(
        setup.bus,
        _parameters('foo', type: 'again'),
        terminal: FindState.wrapped,
      );
      expect(wrapped['state'], FindState.wrapped);
      expect(setup.controller.selected.pageIndex, 0);
    });

    test('scrolls only the currently selected match and only once', () async {
      final setup = _create(['foo']);
      await _search(setup.bus, _parameters('foo'));
      final element = _Scrollable();
      setup.controller.scrollMatchIntoView(
        element: element,
        pageIndex: 0,
        matchIndex: 0,
      );
      setup.controller.scrollMatchIntoView(
        element: element,
        pageIndex: 0,
        matchIndex: 0,
      );
      expect(element.calls, 1);
    });

    test('findbarclose disables highlighting and refreshes all text layers',
        () async {
      final setup = _create(['foo']);
      await _search(setup.bus, _parameters('foo'));
      final updates = <Map>[];
      setup.bus
          .on('updatetextlayermatches', (event) => updates.add(event! as Map));
      setup.bus.dispatch('findbarclose');
      await Future<void>.delayed(Duration.zero);
      expect(setup.controller.highlightMatches, isFalse);
      expect(updates.last['pageIndex'], -1);
    });

    test('reports not-found and tolerates page extraction failures', () async {
      final document = _FakeDocument([
        _FakePage(const [], failure: StateError('broken page')),
      ]);
      final links = _FakeLinkService(document);
      final bus = EventBus();
      final controller = PDFFindController(
        linkService: links,
        eventBus: bus,
        findDelay: Duration.zero,
      )..setDocument(document);
      final result = await _search(
        bus,
        _parameters('missing'),
        terminal: FindState.notFound,
      );
      expect(result['matchesCount'], {'current': 0, 'total': 0});
      expect(controller.pageMatches.single, isEmpty);
    });

    test('can defer count events until every page has completed', () async {
      final setup = _create(['foo', 'foo', 'none'], progressive: false);
      var countEvents = 0;
      setup.bus.on('updatefindmatchescount', (_) => countEvents++);
      final done = Completer<void>();
      setup.bus.on('updatefindmatchescount', (event) {
        final count = (event! as Map)['matchesCount'] as Map;
        if (count['total'] == 2 && !done.isCompleted) done.complete();
      });
      setup.bus.dispatch('find', _parameters('foo'));
      await done.future.timeout(const Duration(seconds: 3));
      expect(countEvents, 1);
    });
  });
}
