import 'dart:async';

import 'package:pdfjs/pdfjs.dart';
import 'package:test/test.dart';

import '../../example/src/base_pdf_page_view.dart';
import '../../example/src/pdf_rendering_queue.dart';
import '../../example/src/renderable_view.dart';

final class FakeClassList implements PageClassList {
  final Set<String> values = {};
  final List<String> operations = [];

  @override
  void add(String token) {
    values.add(token);
    operations.add('add:$token');
  }

  @override
  bool contains(String token) => values.contains(token);

  @override
  void remove(Iterable<String> tokens) {
    for (final token in tokens) {
      values.remove(token);
      operations.add('remove:$token');
    }
  }
}

final class FakeContainer implements PageViewContainer {
  @override
  final FakeClassList classes = FakeClassList();
}

final class FakeCanvas implements PageCanvas {
  FakeCanvas(this.name, {this.width = 100, this.height = 200});

  final String name;
  @override
  int width;
  @override
  int height;
  bool removed = false;
  FakeCanvas? replacement;
  final List<PageCanvas> drawn = [];

  @override
  PageCanvas clone() => FakeCanvas('$name-clone', width: width, height: height);

  @override
  void drawCanvas(PageCanvas source) => drawn.add(source);

  @override
  void remove() => removed = true;

  @override
  void replaceWith(PageCanvas replacement) {
    this.replacement = replacement as FakeCanvas;
  }
}

final class FakeCanvasFactory implements PageCanvasFactory {
  int count = 0;
  final List<FakeCanvas> created = [];

  @override
  PageCanvas create() {
    final canvas = FakeCanvas('canvas${++count}');
    created.add(canvas);
    return canvas;
  }
}

final class FakeEventBus implements ViewerEventBus {
  final List<(String, Map<String, Object?>)> events = [];

  @override
  void dispatch(String name, Map<String, Object?> detail) {
    events.add((name, detail));
  }
}

final class FakeRenderTask implements ViewerRenderTask {
  FakeRenderTask(this.completer, {this.recordedBBoxes});

  final Completer<void> completer;
  @override
  final Object? recordedBBoxes;
  void Function(void Function())? continueCallback;
  void Function(Object error)? errorCallback;
  int? cancelDelay;

  @override
  Future<void> get promise => completer.future;

  @override
  set onContinue(void Function(void Function())? callback) {
    continueCallback = callback;
  }

  @override
  set onError(void Function(Object error)? callback) {
    errorCallback = callback;
  }

  @override
  void cancel([int extraDelay = 0]) {
    cancelDelay = extraDelay;
    if (!completer.isCompleted) {
      final error = RenderingCancelledException('cancelled', extraDelay);
      errorCallback?.call(error);
      completer.completeError(error);
    }
  }

  void requestContinue(void Function() continuation) {
    continueCallback?.call(continuation);
  }

  void complete() => completer.complete();

  void fail(Object error) {
    errorCallback?.call(error);
    completer.completeError(error);
  }
}

final class FakeRenderSource implements PageRenderSource {
  FakeRenderSource({this.imageCoordinates});

  @override
  final Object? imageCoordinates;
  final List<FakeRenderTask> tasks = [];
  RenderParameters? lastOptions;

  @override
  ViewerRenderTask render(RenderParameters options) {
    lastOptions = options;
    final task = FakeRenderTask(
      Completer<void>(),
      recordedBBoxes: <String, Object?>{'page': tasks.length + 1},
    );
    tasks.add(task);
    return task;
  }
}

final class FakeViewerTarget implements PDFViewerRenderingTarget {
  @override
  bool forceRendering([VisiblePages? currentlyVisiblePages]) => false;
}

final class TestPageView extends BasePDFPageView {
  TestPageView(super.options);

  @override
  Future<void> draw() async {}
}

RenderParameters renderOptions() => RenderParameters(
      canvasContext: Object(),
      viewport: PageViewport(
        viewBox: const [0, 0, 612, 792],
        userUnit: 1,
        scale: 1,
        rotation: 0,
      ),
    );

({
  TestPageView view,
  FakeContainer container,
  FakeCanvasFactory canvasFactory,
  FakeEventBus eventBus,
  FakeRenderSource source,
}) buildView({
  PDFRenderingQueue? queue,
  PageColors? colors,
  bool optimized = false,
  int imageMinSize = -1,
  Duration minCanvasDuration = Duration.zero,
  DateTime Function()? now,
  double Function()? timestamp,
}) {
  final container = FakeContainer();
  final canvasFactory = FakeCanvasFactory();
  final eventBus = FakeEventBus();
  final source = FakeRenderSource(
    imageCoordinates: <String, Object?>{'x': 4, 'y': 8},
  );
  final view = TestPageView(
    BasePDFPageViewOptions(
      eventBus: eventBus,
      id: 3,
      renderSource: source,
      container: container,
      canvasFactory: canvasFactory,
      renderingQueue: queue,
      pageColors: colors,
      enableOptimizedPartialRendering: optimized,
      imagesRightClickMinSize: imageMinSize,
      minDurationToUpdateCanvas: minCanvasDuration,
      now: now ?? DateTime.now,
      timestamp: timestamp ?? () => 123.5,
    ),
  );
  return (
    view: view,
    container: container,
    canvasFactory: canvasFactory,
    eventBus: eventBus,
    source: source,
  );
}

void main() {
  group('rendering state', () {
    test('starts initial with page rendering id', () {
      final fixture = buildView();
      expect(fixture.view.renderingId, 'page3');
      expect(fixture.view.renderingState, RenderingState.initial);
      expect(fixture.container.classes.values, isEmpty);
    });

    test('running immediately adds loadingIcon then loading', () async {
      final fixture = buildView();
      fixture.view.renderingState = RenderingState.running;
      expect(fixture.container.classes.contains('loadingIcon'), isTrue);
      expect(fixture.container.classes.contains('loading'), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(fixture.container.classes.contains('loading'), isTrue);
    });

    test('paused removes loading and preserves loadingIcon', () async {
      final fixture = buildView();
      fixture.view.renderingState = RenderingState.running;
      await Future<void>.delayed(Duration.zero);
      fixture.view.renderingState = RenderingState.paused;
      expect(fixture.container.classes.contains('loading'), isFalse);
      expect(fixture.container.classes.contains('loadingIcon'), isTrue);
    });

    test('finished clears both loading classes', () async {
      final fixture = buildView();
      fixture.view.renderingState = RenderingState.running;
      await Future<void>.delayed(Duration.zero);
      fixture.view.renderingState = RenderingState.finished;
      expect(fixture.container.classes.contains('loading'), isFalse);
      expect(fixture.container.classes.contains('loadingIcon'), isFalse);
    });

    test('initial clears both loading classes', () async {
      final fixture = buildView();
      fixture.view.renderingState = RenderingState.running;
      await Future<void>.delayed(Duration.zero);
      fixture.view.renderingState = RenderingState.initial;
      expect(fixture.container.classes.values, isEmpty);
    });

    test('setting same state performs no class operations', () {
      final fixture = buildView();
      fixture.view.renderingState = RenderingState.initial;
      expect(fixture.container.classes.operations, isEmpty);
    });
  });

  group('canvas lifecycle', () {
    test('creates canvas but waits for first continue before showing',
        () async {
      final fixture = buildView();
      final shown = <PageCanvas>[];
      final result = fixture.view.createCanvas(shown.add);
      expect(result.canvas, same(fixture.canvasFactory.created.single));
      expect(result.previousCanvas, isNull);
      expect(shown, isEmpty);

      final drawing = fixture.view.drawCanvas(
        renderOptions(),
        onCancel: () {},
        onFinish: (_) {},
      );
      fixture.source.tasks.single.requestContinue(() {});
      expect(shown, [same(result.canvas)]);
      fixture.source.tasks.single.complete();
      await drawing;
    });

    test('hideUntilComplete shows only after render completion', () async {
      final fixture = buildView();
      final shown = <PageCanvas>[];
      fixture.view.createCanvas(shown.add, hideUntilComplete: true);
      final drawing = fixture.view.drawCanvas(
        renderOptions(),
        onCancel: () {},
        onFinish: (_) {},
      );
      fixture.source.tasks.single.requestContinue(() {});
      expect(shown, isEmpty);
      fixture.source.tasks.single.complete();
      await drawing;
      expect(shown, hasLength(1));
    });

    test('high contrast mode waits until final show', () async {
      final fixture = buildView(
        colors: const PageColors(background: '#000', foreground: '#fff'),
      );
      final shown = <PageCanvas>[];
      fixture.view.createCanvas(shown.add);
      final drawing = fixture.view.drawCanvas(
        renderOptions(),
        onCancel: () {},
        onFinish: (_) {},
      );
      fixture.source.tasks.single.requestContinue(() {});
      expect(shown, isEmpty);
      fixture.source.tasks.single.complete();
      await drawing;
      expect(shown, hasLength(1));
    });

    test('new completed canvas replaces and releases previous canvas',
        () async {
      final fixture = buildView();
      final firstShown = <PageCanvas>[];
      fixture.view.createCanvas(firstShown.add);
      final firstDrawing = fixture.view.drawCanvas(
        renderOptions(),
        onCancel: () {},
        onFinish: (_) {},
      );
      fixture.source.tasks[0].complete();
      await firstDrawing;
      final previous = fixture.canvasFactory.created[0];

      fixture.view.renderingState = RenderingState.initial;
      final result = fixture.view.createCanvas((_) {});
      final secondDrawing = fixture.view.drawCanvas(
        renderOptions(),
        onCancel: () {},
        onFinish: (_) {},
      );
      fixture.source.tasks[1].complete();
      await secondDrawing;
      expect(previous.replacement, same(result.canvas));
      expect(previous.width, 0);
      expect(previous.height, 0);
    });

    test('resetCanvas removes and zeroes current canvas', () {
      final fixture = buildView();
      fixture.view.createCanvas((_) {});
      final canvas = fixture.canvasFactory.created.single;
      fixture.view.resetCanvas();
      expect(canvas.removed, isTrue);
      expect(canvas.width, 0);
      expect(canvas.height, 0);
      expect(fixture.view.canvas, isNull);
    });
  });

  group('drawCanvas', () {
    test('completes state, invokes finish and clears render task', () async {
      final fixture = buildView();
      fixture.view.renderingState = RenderingState.running;
      ViewerRenderTask? finishedTask;
      final drawing = fixture.view.drawCanvas(
        renderOptions(),
        onCancel: () => fail('must not cancel'),
        onFinish: (task) => finishedTask = task,
      );
      final task = fixture.source.tasks.single;
      expect(fixture.view.renderTask, same(task));
      task.complete();
      await drawing;
      expect(finishedTask, same(task));
      expect(fixture.view.renderTask, isNull);
      expect(fixture.view.renderingState, RenderingState.finished);
    });

    test('captures optional render metadata', () async {
      final fixture = buildView(optimized: true, imageMinSize: 32);
      final drawing = fixture.view.drawCanvas(
        renderOptions(),
        onCancel: () {},
        onFinish: (_) {},
      );
      fixture.source.tasks.single.complete();
      await drawing;
      expect(fixture.view.recordedBBoxes, {'page': 1});
      expect(fixture.view.imageCoordinates, {'x': 4, 'y': 8});
    });

    test('propagates a non-cancellation render error after finish', () async {
      final fixture = buildView();
      var finishCalls = 0;
      final drawing = fixture.view.drawCanvas(
        renderOptions(),
        onCancel: () {},
        onFinish: (_) => finishCalls++,
      );
      fixture.source.tasks.single.fail(StateError('paint failed'));
      await expectLater(drawing, throwsStateError);
      expect(finishCalls, 1);
      expect(fixture.view.renderingState, RenderingState.finished);
    });

    test('cancellation calls onCancel and does not finish', () async {
      final fixture = buildView();
      var cancelCalls = 0;
      var finishCalls = 0;
      final drawing = fixture.view.drawCanvas(
        renderOptions(),
        onCancel: () => cancelCalls++,
        onFinish: (_) => finishCalls++,
      );
      fixture.source.tasks.single.cancel(12);
      await drawing;
      expect(cancelCalls, 1);
      expect(finishCalls, 0);
      expect(fixture.view.renderingState, RenderingState.initial);
    });

    test('cancelRendering forwards delay, clears task and continuation',
        () async {
      final fixture = buildView();
      final drawing = fixture.view.drawCanvas(
        renderOptions(),
        onCancel: () {},
        onFinish: (_) {},
      );
      fixture.view.resume = () {};
      final task = fixture.source.tasks.single;
      fixture.view.cancelRendering(cancelExtraDelay: 25);
      await drawing;
      expect(task.cancelDelay, 25);
      expect(fixture.view.renderTask, isNull);
      expect(fixture.view.resume, isNull);
    });
  });

  group('continuation and queue priority', () {
    test('continues immediately without rendering queue', () async {
      final fixture = buildView();
      final drawing = fixture.view.drawCanvas(
        renderOptions(),
        onCancel: () {},
        onFinish: (_) {},
      );
      var continuationCalls = 0;
      fixture.source.tasks.single.requestContinue(() => continuationCalls++);
      expect(continuationCalls, 1);
      fixture.source.tasks.single.complete();
      await drawing;
    });

    test('pauses when another view has higher priority', () async {
      final queue = PDFRenderingQueue()..setViewer(FakeViewerTarget());
      final other = TestPageView(
        BasePDFPageViewOptions(
          eventBus: FakeEventBus(),
          id: 99,
          renderSource: FakeRenderSource(),
          container: FakeContainer(),
          canvasFactory: FakeCanvasFactory(),
        ),
      );
      other.renderingState = RenderingState.running;
      queue.renderView(other);

      final fixture = buildView(queue: queue);
      fixture.view.renderingState = RenderingState.running;
      final drawing = fixture.view.drawCanvas(
        renderOptions(),
        onCancel: () {},
        onFinish: (_) {},
      );
      var continuationCalls = 0;
      fixture.source.tasks.single.requestContinue(() => continuationCalls++);
      expect(fixture.view.renderingState, RenderingState.paused);
      expect(continuationCalls, 0);
      expect(fixture.view.resume, isNotNull);

      queue.renderView(fixture.view);
      expect(continuationCalls, 1);
      expect(fixture.view.renderingState, RenderingState.running);
      fixture.source.tasks.single.complete();
      await drawing;
      queue.dispose();
    });
  });

  group('events', () {
    test('dispatchPageRender emits source and page number', () {
      final fixture = buildView();
      fixture.view.dispatchPageRender();
      expect(fixture.eventBus.events, hasLength(1));
      final (name, detail) = fixture.eventBus.events.single;
      expect(name, 'pagerender');
      expect(detail['source'], same(fixture.view));
      expect(detail['pageNumber'], 3);
    });

    test('dispatchPageRendered emits complete render metadata', () {
      final fixture = buildView(timestamp: () => 456.25);
      fixture.view.dispatchPageRendered(
        cssTransform: true,
        isDetailView: false,
      );
      final (name, detail) = fixture.eventBus.events.single;
      expect(name, 'pagerendered');
      expect(detail['source'], same(fixture.view));
      expect(detail['pageNumber'], 3);
      expect(detail['cssTransform'], isTrue);
      expect(detail['isDetailView'], isFalse);
      expect(detail['timestamp'], 456.25);
      expect(detail['error'], isNull);
    });
  });
}
