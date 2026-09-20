@TestOn('browser')
library;

import 'package:test/test.dart';

import '../../example/src/event_utils.dart';
import '../../example/src/pdf_viewer_navigation.dart';
import '../../example/src/ui_utils.dart';

void main() {
  group('PDFPageViewBuffer', () {
    test('evicts and destroys the oldest view', () {
      final first = _FakePageView(1);
      final second = _FakePageView(2);
      final third = _FakePageView(3);
      final buffer = PDFPageViewBuffer<_FakePageView>(2);

      buffer
        ..push(first)
        ..push(second)
        ..push(third);

      expect(first.destroyCount, 1);
      expect(second.destroyCount, 0);
      expect(buffer.toList(), orderedEquals([second, third]));
    });

    test('pushing an existing view refreshes its LRU position', () {
      final first = _FakePageView(1);
      final second = _FakePageView(2);
      final third = _FakePageView(3);
      final buffer = PDFPageViewBuffer<_FakePageView>(2)
        ..push(first)
        ..push(second)
        ..push(first)
        ..push(third);

      expect(second.destroyCount, 1);
      expect(first.destroyCount, 0);
      expect(buffer.toList(), orderedEquals([first, third]));
      expect(buffer.has(first), isTrue);
    });

    test('resize postpones destruction of requested page ids', () {
      final views = List.generate(5, (index) => _FakePageView(index + 1));
      final buffer = PDFPageViewBuffer<_FakePageView>(5);
      for (final view in views) {
        buffer.push(view);
      }

      buffer.resize(3, idsToKeep: {1, 3});

      expect(buffer.map((view) => view.id), orderedEquals([5, 1, 3]));
      expect(views[1].destroyCount, 1);
      expect(views[3].destroyCount, 1);
      expect(views[0].destroyCount, 0);
      expect(views[2].destroyCount, 0);
    });
  });

  group('PDFViewerNavigation page state', () {
    test('dispatches pagechanging and resets the current page view', () {
      final bus = EventBus();
      final events = <Map<dynamic, dynamic>>[];
      final resets = <int>[];
      bus.on('pagechanging', (event) {
        events.add(event! as Map<dynamic, dynamic>);
      });
      final navigation = PDFViewerNavigation(
        pagesCount: 5,
        eventBus: bus,
        resetCurrentPageView: resets.add,
      );

      navigation.currentPageNumber = 3;

      expect(navigation.currentPageNumber, 3);
      expect(resets, [3]);
      expect(events, hasLength(1));
      expect(events.single['pageNumber'], 3);
      expect(events.single['previous'], 1);
      expect(events.single['pageLabel'], isNull);
    });

    test('page labels map in both directions and propagate to page views', () {
      final updates = <(int, String?)>[];
      final navigation = PDFViewerNavigation(
        pagesCount: 4,
        eventBus: EventBus(),
        updatePageLabel: (page, label) => updates.add((page, label)),
      );

      navigation.setPageLabels(['i', 'ii', '1', '2']);
      navigation.currentPageLabel = 'ii';

      expect(navigation.currentPageNumber, 2);
      expect(navigation.currentPageLabel, 'ii');
      expect(navigation.pageLabelToPageNumber('2'), 4);
      expect(navigation.pageLabelToPageNumber('missing'), isNull);
      expect(updates, [(1, 'i'), (2, 'ii'), (3, '1'), (4, '2')]);

      navigation.setPageLabels(null);
      expect(updates.skip(4), [(1, null), (2, null), (3, null), (4, null)]);
    });

    test('mode changes dispatch events and reject unknown values', () {
      final bus = EventBus();
      final changes = <String>[];
      bus.on('scrollmodechanged', (_) => changes.add('scroll'));
      bus.on('spreadmodechanged', (_) => changes.add('spread'));
      final navigation = PDFViewerNavigation(
        pagesCount: 2,
        eventBus: bus,
      );

      navigation
        ..scrollMode = ScrollMode.horizontal
        ..spreadMode = SpreadMode.odd;

      expect(changes, ['scroll', 'spread']);
      expect(
        () => navigation.scrollMode = ScrollMode.unknown,
        throwsArgumentError,
      );
      expect(
        () => navigation.spreadMode = SpreadMode.unknown,
        throwsArgumentError,
      );
    });
  });

  group('PDFViewerNavigation page advances', () {
    test('normal vertical mode advances one page and respects boundaries', () {
      final navigation = PDFViewerNavigation(
        pagesCount: 3,
        eventBus: EventBus(),
      );

      expect(navigation.previousPage(), isFalse);
      expect(navigation.nextPage(), isTrue);
      expect(navigation.currentPageNumber, 2);
      expect(navigation.nextPage(), isTrue);
      expect(navigation.currentPageNumber, 3);
      expect(navigation.nextPage(), isFalse);
    });

    test('visible companion page makes vertical spread advance by two', () {
      var visible = const <NavigationVisiblePage>[
        NavigationVisiblePage(
          id: 2,
          y: 0,
          percent: 100,
          widthPercent: 100,
        ),
      ];
      final navigation = PDFViewerNavigation(
        pagesCount: 8,
        eventBus: EventBus(),
        visiblePagesProvider: () => visible,
      )..spreadMode = SpreadMode.odd;

      expect(navigation.nextPage(), isTrue);
      expect(navigation.currentPageNumber, 3);

      visible = const [
        NavigationVisiblePage(
          id: 2,
          y: 0,
          percent: 75,
          widthPercent: 100,
        ),
      ];
      expect(navigation.previousPage(), isTrue);
      expect(navigation.currentPageNumber, 1);
    });

    test('wrapped mode advances across a complete visible row', () {
      final navigation = PDFViewerNavigation(
        pagesCount: 9,
        eventBus: EventBus(),
        visiblePagesProvider: () => const [
          NavigationVisiblePage(
            id: 1,
            y: 10,
            percent: 100,
            widthPercent: 100,
          ),
          NavigationVisiblePage(
            id: 2,
            y: 10,
            percent: 100,
            widthPercent: 100,
          ),
          NavigationVisiblePage(
            id: 3,
            y: 10,
            percent: 100,
            widthPercent: 100,
          ),
        ],
      )..scrollMode = ScrollMode.wrapped;

      navigation.nextPage();
      expect(navigation.currentPageNumber, 4);
      navigation.previousPage();
      expect(navigation.currentPageNumber, 3);
    });

    test('wrapped mode detects a gap caused by varying page sizes', () {
      final navigation = PDFViewerNavigation(
        pagesCount: 10,
        eventBus: EventBus(),
        visiblePagesProvider: () => const [
          NavigationVisiblePage(
            id: 3,
            y: 20,
            percent: 100,
            widthPercent: 100,
          ),
          NavigationVisiblePage(
            id: 5,
            y: 20,
            percent: 100,
            widthPercent: 100,
          ),
        ],
      )..scrollMode = ScrollMode.wrapped;

      navigation.currentPageNumber = 3;
      navigation.nextPage();
      expect(navigation.currentPageNumber, 4);

      navigation.currentPageNumber = 5;
      navigation.previousPage();
      expect(navigation.currentPageNumber, 4);
    });
  });
}

final class _FakePageView implements BufferedPageView {
  _FakePageView(this.id);

  @override
  final int id;

  int destroyCount = 0;

  @override
  void destroy() => destroyCount++;
}
