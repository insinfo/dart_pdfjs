@TestOn('browser')
library;

import 'dart:async';

import 'package:pdfjs/pdfjs.dart' as pdfjs;
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/event_utils.dart';
import '../../example/src/pdf_rendering_queue.dart';
import '../../example/src/pdf_thumbnail_view.dart';
import '../../example/src/renderable_view.dart';

final class TestLinkService implements ThumbnailLinkService {
  TestLinkService(this.pagesCount);
  @override
  int pagesCount;
}

final class TestRenderTask implements ThumbnailRenderTask {
  final Completer<void> completer = Completer<void>();
  void Function(void Function())? continuation;
  bool cancelled = false;

  @override
  Future<void> get promise => completer.future;
  @override
  set onContinue(void Function(void Function())? value) => continuation = value;
  @override
  void cancel() {
    cancelled = true;
    if (!completer.isCompleted) {
      completer.completeError(pdfjs.RenderingCancelledException('cancelled'));
    }
  }

  void finish() {
    if (!completer.isCompleted) completer.complete();
  }
}

final class TestPage implements ThumbnailPdfPage {
  TestPage({this.rotate = 0, this.failWith});
  @override
  final int rotate;
  final Object? failWith;
  final List<ThumbnailRenderContext> contexts = [];
  TestRenderTask? lastTask;

  @override
  pdfjs.PageViewport getViewport({required double scale, int? rotation}) =>
      pdfjs.PageViewport(
        viewBox: const [0, 0, 600, 800],
        scale: scale,
        rotation: rotation ?? rotate,
      );

  @override
  ThumbnailRenderTask render(ThumbnailRenderContext context) {
    contexts.add(context);
    final task = lastTask = TestRenderTask();
    scheduleMicrotask(() {
      if (failWith case final error?) {
        task.completer.completeError(error);
      } else {
        task.finish();
      }
    });
    return task;
  }
}

final class ControlledPage extends TestPage {
  ControlledPage();

  @override
  ThumbnailRenderTask render(ThumbnailRenderContext context) {
    contexts.add(context);
    return lastTask = TestRenderTask();
  }
}

final class TestQueue extends PDFRenderingQueue {
  bool highest = true;
  @override
  bool isHighestPriority(RenderableView view) => highest;
}

final class TestSourcePageView implements ThumbnailSourcePageView {
  TestSourcePageView(this.thumbnailCanvas, this.pdfPage, this.scale);
  @override
  final web.HTMLCanvasElement? thumbnailCanvas;
  @override
  final ThumbnailPdfPage pdfPage;
  @override
  final double scale;
}

void main() {
  late web.HTMLDivElement container;
  late EventBus eventBus;
  late TestQueue queue;
  late TestLinkService linkService;
  late PDFThumbnailView view;

  pdfjs.PageViewport viewport({int rotation = 0}) => pdfjs.PageViewport(
        viewBox: const [0, 0, 600, 800],
        scale: 1,
        rotation: rotation,
      );

  PDFThumbnailView create({
    int id = 1,
    bool splitMerge = false,
    pdfjs.PageViewport? defaultViewport,
  }) {
    return PDFThumbnailView(PDFThumbnailViewOptions(
      container: container,
      eventBus: eventBus,
      id: id,
      defaultViewport: defaultViewport ?? viewport(),
      linkService: linkService,
      renderingQueue: queue,
      maxCanvasPixels: 33554432,
      maxCanvasDim: 32767,
      enableSplitMerge: splitMerge,
    ));
  }

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body!.append(container);
    eventBus = EventBus();
    queue = TestQueue();
    linkService = TestLinkService(12);
    view = create();
  });

  tearDown(() {
    view.destroy();
    container.remove();
    queue.dispose();
  });

  test('constructor builds localized thumbnail DOM and dimensions', () {
    expect(view.id, 1);
    expect(view.renderingId, 'thumbnail1');
    expect(view.renderingState, RenderingState.initial);
    expect(view.div.className, 'thumbnail');
    expect(view.div.getAttribute('page-number'), '1');
    expect(view.imageContainer.getAttribute('role'), 'button');
    expect(view.imageContainer.tabIndex, -1);
    expect(view.imageContainer.classList.contains('missingThumbnailImage'),
        isTrue);
    expect(view.imageContainer.getAttribute('data-l10n-args'),
        '{"page":1,"total":12}');
    expect(view.canvasWidth, thumbnailWidth);
    expect(view.canvasHeight, 168);
    expect(view.scale, closeTo(0.21, 0.0001));
    expect(view.imageContainer.style.height, '168px');
    expect(container.firstElementChild, same(view.div));
  });

  test('split/merge checkbox and current state stay keyboard accessible', () {
    view.destroy();
    view = create(splitMerge: true);
    expect(view.checkbox, isNotNull);
    expect(view.checkbox!.type, 'checkbox');
    expect(view.checkbox!.tabIndex, -1);
    view.toggleSelected(true);
    expect(view.checkbox!.checked, isTrue);
    view.toggleCurrent(true);
    expect(view.imageContainer.getAttribute('aria-current'), 'page');
    expect(view.imageContainer.tabIndex, 0);
    expect(view.checkbox!.tabIndex, 0);
    view.toggleCurrent(false);
    expect(view.imageContainer.getAttribute('aria-current'), 'false');
    expect(view.checkbox!.tabIndex, -1);
  });

  test('labels and updateId refresh all localization arguments', () {
    view.destroy();
    view = create(splitMerge: true);
    view.setPageLabel('iv');
    expect(view.pageLabel, 'iv');
    expect(view.imageContainer.getAttribute('data-l10n-args'),
        '{"page":"iv","total":12}');
    expect(view.image.getAttribute('data-l10n-args'), '{"page":"iv"}');
    expect(view.checkbox!.getAttribute('data-l10n-args'), '{"page":"iv"}');
    view.updateId(7);
    expect(view.id, 7);
    expect(view.renderingId, 'thumbnail7');
    expect(view.div.getAttribute('page-number'), '7');
    view.setPageLabel(42);
    expect(view.pageLabel, isNull);
    expect(view.imageContainer.getAttribute('data-l10n-args'),
        '{"page":7,"total":12}');
  });

  test('paste buttons invoke after/before positions and can be removed', () {
    final pages = <int>[];
    view.addPasteButton(pages.add);
    expect(view.pasteButton, isNotNull);
    expect(view.prevPasteButton, isNotNull);
    view.pasteButton!.click();
    view.prevPasteButton!.click();
    expect(pages, [1, 0]);
    final original = view.pasteButton;
    view.addPasteButton(pages.add);
    expect(view.pasteButton, same(original));
    view.removePasteButton();
    expect(view.pasteButton, isNull);
    expect(view.prevPasteButton, isNull);
    expect(container.querySelector('.thumbnailPasteButton'), isNull);
  });

  test('setPdfPage applies combined rotation and resets state', () {
    final page = TestPage(rotate: 90);
    view.rotation = 90;
    view.renderingState = RenderingState.finished;
    view.setPdfPage(page);
    expect(view.pdfPage, same(page));
    expect(view.pdfPageRotate, 90);
    expect(view.viewport.rotation, 180);
    expect(view.renderingState, RenderingState.initial);
  });

  test('update handles zero rotation and recomputes portrait dimensions', () {
    view.update(rotation: 90);
    expect(view.rotation, 90);
    expect(view.viewport.rotation, 90);
    expect(view.canvasHeight, 94);
    view.update(rotation: 0);
    expect(view.rotation, 0);
    expect(view.canvasHeight, 168);
  });

  test('draw without a page finishes and reports an error', () async {
    await expectLater(view.draw(), throwsStateError);
    expect(view.renderingState, RenderingState.finished);
  });

  test('draw renders at upscale factor, converts image and dispatches event',
      () async {
    final page = TestPage();
    final events = <Map>[];
    eventBus.on('thumbnailrendered', (data) => events.add(data as Map));
    view.setPdfPage(page);
    await view.draw();
    expect(view.renderingState, RenderingState.finished);
    expect(view.renderTask, isNull);
    expect(page.contexts, hasLength(1));
    expect(page.contexts.single.canvas.width, 252);
    expect(page.contexts.single.canvas.height, 336);
    expect(page.contexts.single.viewport.scale, closeTo(0.42, 0.0001));
    expect(view.image.src, startsWith('blob:'));
    expect(view.image.getAttribute('data-l10n-id'), 'pdfjs-thumb-page-canvas');
    expect(view.imageContainer.classList.contains('missingThumbnailImage'),
        isFalse);
    expect(events.single['source'], same(view));
    expect(events.single['pageNumber'], 1);
    expect(events.single['pdfPage'], same(page));
  });

  test('render error still produces thumbnail and is rethrown', () async {
    final failure = StateError('bad render');
    final page = TestPage(failWith: failure);
    view.setPdfPage(page);
    await expectLater(view.draw(), throwsA(same(failure)));
    expect(view.renderingState, RenderingState.finished);
    expect(view.image.src, startsWith('blob:'));
  });

  test('continuation pauses when not highest priority and resume continues',
      () async {
    final page = ControlledPage();
    queue.highest = false;
    view.setPdfPage(page);
    final drawing = view.draw();
    await Future<void>.delayed(Duration.zero);
    var continued = false;
    page.lastTask!.continuation!(() => continued = true);
    expect(view.renderingState, RenderingState.paused);
    expect(continued, isFalse);
    expect(view.resume, isNotNull);
    view.resume!();
    expect(view.renderingState, RenderingState.running);
    expect(continued, isTrue);
    page.lastTask!.finish();
    await drawing;
  });

  test('cancelRendering cancels task and draw treats cancellation silently',
      () async {
    final page = ControlledPage();
    view.setPdfPage(page);
    final drawing = view.draw();
    await Future<void>.delayed(Duration.zero);
    final task = page.lastTask!;
    view.cancelRendering();
    await drawing;
    expect(task.cancelled, isTrue);
    expect(view.renderTask, isNull);
    expect(view.resume, isNull);
    expect(view.renderingState, RenderingState.running,
        reason: 'upstream cancellation exits before FINISHED');
  });

  test('reset cancels work and clears a rendered object URL', () async {
    final page = TestPage();
    view.setPdfPage(page);
    await view.draw();
    expect(view.image.src, isNotEmpty);
    view.reset();
    expect(view.renderingState, RenderingState.initial);
    expect(view.image.getAttribute('src'), isEmpty);
    expect(view.imageContainer.hasAttribute('data-l10n-id'), isFalse);
    expect(view.imageContainer.classList.contains('missingThumbnailImage'),
        isTrue);
  });

  test('setImage imports sufficiently large page canvas', () async {
    final source = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = 600
      ..height = 800;
    final page = TestPage();
    await view.setImage(TestSourcePageView(source, page, 1));
    expect(view.pdfPage, same(page));
    expect(view.renderingState, RenderingState.finished);
    expect(view.image.src, startsWith('blob:'));
  });

  test('setImage rejects absent, underscaled, and already-rendered sources',
      () async {
    final page = TestPage();
    await view.setImage(TestSourcePageView(null, page, 1));
    expect(view.pdfPage, isNull);
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = 10
      ..height = 10;
    await view.setImage(TestSourcePageView(canvas, page, 0.01));
    expect(view.renderingState, RenderingState.initial);
    view.renderingState = RenderingState.finished;
    await view.setImage(TestSourcePageView(canvas, page, 1));
    expect(view.image.getAttribute('src'), anyOf(isNull, isEmpty));
  });

  test('clone preserves rendered image and split/merge capability', () async {
    view.destroy();
    view = create(splitMerge: true);
    final page = TestPage();
    view.setPdfPage(page);
    await view.draw();
    final cloneContainer =
        web.document.createElement('div') as web.HTMLDivElement;
    container.append(cloneContainer);
    final cloned = view.clone(cloneContainer, 5);
    addTearDown(cloned.destroy);
    expect(cloned.id, 5);
    expect(cloned.checkbox, isNotNull);
    expect(cloned.image.src, view.image.src);
    expect(cloned.imageContainer.classList.contains('missingThumbnailImage'),
        isFalse);
  });

  test('destroy removes DOM and clears current state', () {
    view.toggleCurrent(true);
    final node = view.div;
    view.destroy();
    expect(node.isConnected, isFalse);
    expect(view.imageContainer.getAttribute('aria-current'), 'false');
  });
}
