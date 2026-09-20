import 'dart:async';

import 'package:pdfjs/pdfjs.dart';
import 'package:test/test.dart';

import '../../example/src/pdf_rendering_queue.dart';
import '../../example/src/renderable_view.dart';

class FakeView implements RenderableView {
  FakeView(this.renderingId, {this.onDraw});

  @override
  final String renderingId;
  final Future<void> Function()? onDraw;
  int drawCalls = 0;
  int resumeCalls = 0;

  @override
  RenderingState renderingState = RenderingState.initial;

  @override
  void Function()? resume;

  @override
  Future<void> draw() async {
    drawCalls++;
    await onDraw?.call();
  }

  void installResume() {
    resume = () {
      resumeCalls++;
      renderingState = RenderingState.running;
    };
  }
}

final class FakeDetailView extends FakeView implements DetailRenderableView {
  FakeDetailView(super.renderingId, {this.detailView});

  @override
  final RenderableView? detailView;
}

final class FakeViewer implements PDFViewerRenderingTarget {
  FakeViewer(this.results);
  final List<bool> results;
  int calls = 0;
  VisiblePages? lastVisible;

  @override
  bool forceRendering([VisiblePages? currentlyVisiblePages]) {
    lastVisible = currentlyVisiblePages;
    final index = calls++;
    return index < results.length ? results[index] : false;
  }
}

final class FakeThumbnailViewer implements PDFThumbnailRenderingTarget {
  FakeThumbnailViewer(this.results);
  final List<bool> results;
  int calls = 0;

  @override
  bool forceRendering() {
    final index = calls++;
    return index < results.length ? results[index] : false;
  }
}

VisiblePages visible(List<FakeView> views, {Set<int>? ids}) => VisiblePages(
      views: [
        for (var index = 0; index < views.length; index++)
          VisibleView(id: index + 1, view: views[index]),
      ],
      ids: ids,
    );

void main() {
  group('VisiblePages', () {
    test('derives ids and endpoints from entries', () {
      final first = FakeView('page1');
      final second = FakeView('page2');
      final snapshot = visible([first, second]);

      expect(snapshot.ids, {1, 2});
      expect(snapshot.first.view, same(first));
      expect(snapshot.last.view, same(second));
      expect(() => snapshot.ids.add(3), throwsUnsupportedError);
      expect(() => snapshot.views.add(snapshot.first), throwsUnsupportedError);
    });

    test('empty snapshot has no endpoints', () {
      final snapshot = VisiblePages.empty();
      expect(snapshot.views, isEmpty);
      expect(() => snapshot.first, throwsStateError);
      expect(() => snapshot.last, throwsStateError);
    });

    test('rejects endpoints outside the id set', () {
      final view = FakeView('page1');
      expect(
        () => VisiblePages(
          views: [VisibleView(id: 1, view: view)],
          ids: {1},
          first: VisibleView(id: 2, view: view),
        ),
        throwsArgumentError,
      );
    });
  });

  group('getHighestPriority', () {
    late PDFRenderingQueue queue;

    setUp(() => queue = PDFRenderingQueue());
    tearDown(() => queue.dispose());

    test('returns null for no visible pages', () {
      expect(queue.getHighestPriority(VisiblePages.empty(), [], true), isNull);
    });

    test('selects first unfinished visible page in visible order', () {
      final one = FakeView('page1')..renderingState = RenderingState.finished;
      final two = FakeView('page2')..renderingState = RenderingState.running;
      final three = FakeView('page3');
      expect(
        queue.getHighestPriority(
            visible([one, two, three]), [one, two, three], true),
        same(two),
      );
    });

    test('a paused visible page is unfinished', () {
      final page = FakeView('page1')..renderingState = RenderingState.paused;
      expect(
          queue.getHighestPriority(visible([page]), [page], true), same(page));
    });

    test('selects detail view after all visible parent views finish', () {
      final detail = FakeView('page1-detail');
      final page = FakeDetailView('page1', detailView: detail)
        ..renderingState = RenderingState.finished;
      expect(queue.getHighestPriority(visible([page]), [page], true),
          same(detail));
    });

    test('skips finished detail view', () {
      final detail = FakeView('page1-detail')
        ..renderingState = RenderingState.finished;
      final page = FakeDetailView('page1', detailView: detail)
        ..renderingState = RenderingState.finished;
      expect(queue.getHighestPriority(visible([page]), [page], true), isNull);
    });

    test('can ignore unfinished detail views', () {
      final detail = FakeView('page1-detail');
      final page = FakeDetailView('page1', detailView: detail)
        ..renderingState = RenderingState.finished;
      expect(
        queue.getHighestPriority(
          visible([page]),
          [page],
          true,
          ignoreDetailViews: true,
        ),
        isNull,
      );
    });

    test('finds a layout hole in downward order', () {
      final pages = List.generate(5, (i) => FakeView('page${i + 1}'));
      for (final index in [0, 2, 4]) {
        pages[index].renderingState = RenderingState.finished;
      }
      final snapshot = VisiblePages(
        views: [
          VisibleView(id: 1, view: pages[0]),
          VisibleView(id: 3, view: pages[2]),
          VisibleView(id: 5, view: pages[4]),
        ],
        ids: {1, 3, 5},
      );
      expect(queue.getHighestPriority(snapshot, pages, true), same(pages[1]));
    });

    test('finds a layout hole in upward order', () {
      final pages = List.generate(5, (i) => FakeView('page${i + 1}'));
      for (final index in [0, 2, 4]) {
        pages[index].renderingState = RenderingState.finished;
      }
      final snapshot = VisiblePages(
        views: [
          VisibleView(id: 1, view: pages[0]),
          VisibleView(id: 3, view: pages[2]),
          VisibleView(id: 5, view: pages[4]),
        ],
        ids: {1, 3, 5},
      );
      expect(queue.getHighestPriority(snapshot, pages, false), same(pages[3]));
    });

    test('skips a finished hole and finds another', () {
      final pages = List.generate(5, (i) => FakeView('page${i + 1}'));
      pages[0].renderingState = RenderingState.finished;
      pages[1].renderingState = RenderingState.finished;
      pages[2].renderingState = RenderingState.finished;
      pages[4].renderingState = RenderingState.finished;
      final snapshot = VisiblePages(
        views: [
          VisibleView(id: 1, view: pages[0]),
          VisibleView(id: 3, view: pages[2]),
          VisibleView(id: 5, view: pages[4]),
        ],
        ids: {1, 3, 5},
      );
      expect(queue.getHighestPriority(snapshot, pages, true), same(pages[3]));
    });

    test('pre-renders page after visible range when scrolling down', () {
      final pages = List.generate(3, (i) => FakeView('page${i + 1}'));
      pages[0].renderingState = RenderingState.finished;
      pages[1].renderingState = RenderingState.finished;
      expect(
        queue.getHighestPriority(visible(pages.take(2).toList()), pages, true),
        same(pages[2]),
      );
    });

    test('pre-renders page before visible range when scrolling up', () {
      final pages = List.generate(3, (i) => FakeView('page${i + 1}'));
      pages[1].renderingState = RenderingState.finished;
      pages[2].renderingState = RenderingState.finished;
      final snapshot = VisiblePages(
        views: [
          VisibleView(id: 2, view: pages[1]),
          VisibleView(id: 3, view: pages[2]),
        ],
      );
      expect(queue.getHighestPriority(snapshot, pages, false), same(pages[0]));
    });

    test('preRenderExtra skips one finished adjacent page', () {
      final pages = List.generate(4, (i) => FakeView('page${i + 1}'));
      pages[0].renderingState = RenderingState.finished;
      pages[1].renderingState = RenderingState.finished;
      pages[2].renderingState = RenderingState.finished;
      expect(
        queue.getHighestPriority(
          visible(pages.take(2).toList()),
          pages,
          true,
          preRenderExtra: true,
        ),
        same(pages[3]),
      );
    });
  });

  group('renderView', () {
    test('does not render an already finished view', () {
      final queue = PDFRenderingQueue();
      final view = FakeView('page1')..renderingState = RenderingState.finished;
      expect(queue.renderView(view), isFalse);
      expect(view.drawCalls, 0);
      queue.dispose();
    });

    test('resumes paused view and raises its priority', () {
      final queue = PDFRenderingQueue();
      final view = FakeView('page1')
        ..renderingState = RenderingState.paused
        ..installResume();
      expect(queue.renderView(view), isTrue);
      expect(view.resumeCalls, 1);
      expect(view.renderingState, RenderingState.running);
      expect(queue.isHighestPriority(view), isTrue);
      queue.dispose();
    });

    test('rejects malformed paused view with no continuation', () {
      final queue = PDFRenderingQueue();
      final view = FakeView('page1')..renderingState = RenderingState.paused;
      expect(() => queue.renderView(view), throwsStateError);
      queue.dispose();
    });

    test('running view becomes highest priority without redrawing', () {
      final queue = PDFRenderingQueue();
      final view = FakeView('page1')..renderingState = RenderingState.running;
      expect(queue.renderView(view), isTrue);
      expect(queue.isHighestPriority(view), isTrue);
      expect(view.drawCalls, 0);
      queue.dispose();
    });

    test('initial view is drawn and queue continues after completion',
        () async {
      final target = FakeViewer([false]);
      final queue = PDFRenderingQueue()..setViewer(target);
      final view = FakeView('page1');
      expect(queue.renderView(view), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(view.drawCalls, 1);
      expect(target.calls, 1);
      queue.dispose();
    });

    test('cancelled draw does not report rendering error', () async {
      final errors = <Object>[];
      final queue = PDFRenderingQueue(
        onRenderingError: (error, stack) => errors.add(error),
      )..setViewer(FakeViewer([false]));
      final view = FakeView(
        'page1',
        onDraw: () => Future.error(RenderingCancelledException('cancelled')),
      );
      queue.renderView(view);
      await Future<void>.delayed(Duration.zero);
      expect(errors, isEmpty);
      queue.dispose();
    });

    test('non-cancellation draw error is reported', () async {
      final errors = <Object>[];
      final queue = PDFRenderingQueue(
        onRenderingError: (error, stack) => errors.add(error),
      )..setViewer(FakeViewer([false]));
      final failure = StateError('broken renderer');
      queue.renderView(FakeView('page1', onDraw: () => Future.error(failure)));
      await Future<void>.delayed(Duration.zero);
      expect(errors, [same(failure)]);
      queue.dispose();
    });
  });

  group('renderHighestPriority', () {
    test('pages run before thumbnails', () {
      final viewer = FakeViewer([true]);
      final thumbnails = FakeThumbnailViewer([true]);
      final queue = PDFRenderingQueue()
        ..setViewer(viewer)
        ..setThumbnailViewer(thumbnails)
        ..isThumbnailViewEnabled = true;
      queue.renderHighestPriority(VisiblePages.empty());
      expect(viewer.calls, 1);
      expect(thumbnails.calls, 0);
      queue.dispose();
    });

    test('thumbnail runs when pages have no work', () {
      final viewer = FakeViewer([false]);
      final thumbnails = FakeThumbnailViewer([true]);
      final queue = PDFRenderingQueue()
        ..setViewer(viewer)
        ..setThumbnailViewer(thumbnails)
        ..isThumbnailViewEnabled = true;
      queue.renderHighestPriority();
      expect(viewer.calls, 1);
      expect(thumbnails.calls, 1);
      queue.dispose();
    });

    test('disabled thumbnail viewer is skipped', () {
      final thumbnails = FakeThumbnailViewer([true]);
      final queue = PDFRenderingQueue(cleanupTimeout: Duration.zero)
        ..setViewer(FakeViewer([false]))
        ..setThumbnailViewer(thumbnails);
      queue.renderHighestPriority();
      expect(thumbnails.calls, 0);
      queue.dispose();
    });

    test('schedules idle callback when no rendering work remains', () async {
      var idleCalls = 0;
      final queue = PDFRenderingQueue(cleanupTimeout: Duration.zero)
        ..setViewer(FakeViewer([false]))
        ..onIdle = () => idleCalls++;
      queue.renderHighestPriority();
      expect(queue.hasPendingIdleCallback, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(idleCalls, 1);
      expect(queue.hasPendingIdleCallback, isFalse);
      queue.dispose();
    });

    test('printing suppresses idle scheduling', () async {
      var idleCalls = 0;
      final queue = PDFRenderingQueue(cleanupTimeout: Duration.zero)
        ..setViewer(FakeViewer([false]))
        ..printing = true
        ..onIdle = () => idleCalls++;
      queue.renderHighestPriority();
      await Future<void>.delayed(Duration.zero);
      expect(idleCalls, 0);
      expect(queue.hasPendingIdleCallback, isFalse);
      queue.dispose();
    });

    test('new scheduling attempt cancels prior idle timer', () async {
      var idleCalls = 0;
      final viewer = FakeViewer([false, true]);
      final queue = PDFRenderingQueue(cleanupTimeout: Duration(milliseconds: 5))
        ..setViewer(viewer)
        ..onIdle = () => idleCalls++;
      queue.renderHighestPriority();
      expect(queue.hasPendingIdleCallback, isTrue);
      queue.renderHighestPriority();
      expect(queue.hasPendingIdleCallback, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(idleCalls, 0);
      queue.dispose();
    });

    test('dispose cancels idle timer and rejects later work', () async {
      var idleCalls = 0;
      final queue = PDFRenderingQueue(cleanupTimeout: Duration.zero)
        ..setViewer(FakeViewer([false]))
        ..onIdle = () => idleCalls++;
      queue.renderHighestPriority();
      queue.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(idleCalls, 0);
      expect(() => queue.renderHighestPriority(), throwsStateError);
    });
  });
}
