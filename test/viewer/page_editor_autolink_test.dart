@TestOn('browser')
library;

import 'dart:async';

import 'package:pdfjs/pdfjs.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/annotation_editor_layer_builder.dart';
import '../../example/src/autolinker.dart';
import '../../example/src/base_pdf_page_view.dart';
import '../../example/src/event_utils.dart';
import '../../example/src/pdf_page_detail_view.dart';
import '../../example/src/renderable_view.dart';
import '../../example/src/text_highlighter.dart';

PageViewport viewport([double scale = 1]) => PageViewport(
      viewBox: const [0, 0, 1000, 800],
      scale: scale,
      rotation: 0,
    );

final class FakeFind implements TextHighlighterFindController {
  @override
  bool highlightAll = false;
  @override
  bool highlightMatches = false;
  @override
  int selectedMatchIndex = -1;
  @override
  int selectedPageIndex = -1;
  @override
  List<int>? matchLengthsForPage(int pageIndex) => null;
  @override
  List<int>? matchesForPage(int pageIndex) => null;
  @override
  void scrollMatchIntoView({
    required web.HTMLElement element,
    required int pageIndex,
    required int matchIndex,
  }) {}
}

final class FakeAutolinkPage implements AutolinkPageView {
  FakeAutolinkPage(this.textHighlighter)
      : textLayerDiv = web.document.createElement('div') as web.HTMLDivElement;
  @override
  final TextHighlighter textHighlighter;
  @override
  final web.HTMLDivElement textLayerDiv;
  @override
  List<double> getPagePoint(double x, double y) => [x * 2, 800 - y * 2];
}

final class FakeEditor implements AnnotationEditor {
  FakeEditor(this.id);
  @override
  final String id;
  int updates = 0;
  bool destroyed = false;
  late final web.HTMLDivElement element;
  @override
  web.HTMLElement render() {
    element = web.document.createElement('div') as web.HTMLDivElement;
    element.textContent = id;
    return element;
  }

  @override
  void update(PageViewport viewport) => updates++;
  @override
  void destroy() => destroyed = true;
}

final class FakeEditorManager implements AnnotationEditorUIManager {
  FakeEditorManager(this.editors);
  final List<FakeEditor> editors;
  @override
  String direction = 'ltr';
  @override
  bool isVisible = true;
  final List<(String, int)> events = [];
  @override
  void attachLayer(int pageIndex, AnnotationEditorLayer layer) {
    events.add(('attach', pageIndex));
  }

  @override
  void detachLayer(int pageIndex, AnnotationEditorLayer layer) {
    events.add(('detach', pageIndex));
  }

  @override
  Iterable<AnnotationEditor> editorsForPage(int pageIndex) => editors;
}

final class FakeClasses implements PageClassList {
  final Set<String> values = {};
  @override
  void add(String token) => values.add(token);
  @override
  bool contains(String token) => values.contains(token);
  @override
  void remove(Iterable<String> tokens) => values.removeAll(tokens);
}

final class FakeContainer implements PageViewContainer {
  @override
  final FakeClasses classes = FakeClasses();
}

final class FakeDetailCanvas implements DetailPageCanvas {
  @override
  int width = 0;
  @override
  int height = 0;
  bool removed = false;
  bool ariaHidden = false;
  bool detailClass = false;
  List<double>? position;
  @override
  Object get renderingContext => this;
  @override
  PageCanvas clone() => FakeDetailCanvas()
    ..width = width
    ..height = height;
  @override
  void drawCanvas(PageCanvas source) {}
  @override
  void remove() => removed = true;
  @override
  void replaceWith(PageCanvas replacement) {}
  @override
  void setAriaHidden() => ariaHidden = true;
  @override
  void setDetailClass() => detailClass = true;
  @override
  void setPosition({
    required double widthPercent,
    required double heightPercent,
    required double topPercent,
    required double leftPercent,
  }) {
    position = [widthPercent, heightPercent, topPercent, leftPercent];
  }
}

final class FakeCanvasFactory implements PageCanvasFactory {
  final List<FakeDetailCanvas> canvases = [];
  @override
  PageCanvas create() {
    final canvas = FakeDetailCanvas();
    canvases.add(canvas);
    return canvas;
  }
}

final class FakeTask implements ViewerRenderTask {
  final Completer<void> completer = Completer<void>();
  @override
  Future<void> get promise => completer.future;
  @override
  Object? recordedBBoxes;
  void Function(Object)? error;
  bool cancelled = false;
  @override
  set onContinue(void Function(void Function())? callback) {}
  @override
  set onError(void Function(Object error)? callback) => error = callback;
  @override
  void cancel([int extraDelay = 0]) {
    cancelled = true;
    if (!completer.isCompleted) {
      final exception = RenderingCancelledException('cancelled', extraDelay);
      error?.call(exception);
      completer.completeError(exception);
    }
  }
}

final class FakeSource implements PageRenderSource {
  final List<FakeTask> tasks = [];
  RenderParameters? options;
  @override
  Object? get imageCoordinates => null;
  @override
  ViewerRenderTask render(RenderParameters options) {
    this.options = options;
    final task = FakeTask();
    tasks.add(task);
    return task;
  }
}

final class FakeEvents implements ViewerEventBus {
  final List<String> names = [];
  @override
  void dispatch(String name, Map<String, Object?> detail) => names.add(name);
}

final class FakeDetailHost implements DetailPageHost {
  FakeDetailHost() {
    baseViewOptions = BasePDFPageViewOptions(
      eventBus: events,
      id: 4,
      renderSource: source,
      container: container,
      canvasFactory: canvasFactory,
      minDurationToUpdateCanvas: Duration.zero,
    );
  }
  final FakeEvents events = FakeEvents();
  final FakeSource source = FakeSource();
  final FakeContainer container = FakeContainer();
  final FakeCanvasFactory canvasFactory = FakeCanvasFactory();
  @override
  late final BasePDFPageViewOptions baseViewOptions;
  @override
  PageViewport viewport = PDFPageDetailViewTestViewport.value;
  @override
  double maxCanvasPixels = 1000000;
  @override
  double capCanvasAreaFactor = -1;
  @override
  bool pdfPageLoaded = true;
  @override
  RenderingState renderingState = RenderingState.finished;
  @override
  PDFPageDetailView? detailView;
  final List<DetailPageCanvas> inserted = [];
  @override
  RenderParameters createDetailRenderParameters({
    required DetailPageCanvas canvas,
    required List<num> transform,
    required bool Function(int index)? operationsFilter,
  }) =>
      RenderParameters(
        canvasContext: canvas.renderingContext,
        viewport: viewport,
        transform: transform,
        operationsFilter: operationsFilter,
      );
  @override
  void insertDetailCanvas(DetailPageCanvas canvas) => inserted.add(canvas);
  @override
  void setPdfPage(Object page) => pdfPageLoaded = true;
}

abstract final class PDFPageDetailViewTestViewport {
  static final value = viewport();
}

void main() {
  group('Autolinker', () {
    test('detects web URLs, www links, mailto and unicode e-mail', () {
      final links = Autolinker.findLinks(
        'See https://example.com/a, www.mozilla.org and usuário@exemplo.com.',
      );
      expect(links.map((link) => link.url), [
        'https://example.com/a',
        'http://www.mozilla.org',
        'mailto:usu%C3%A1rio@exemplo.com',
      ]);
      expect(links.first.index, 4);
      expect(links.first.length, 'https://example.com/a'.length);
    });

    test('rejects numeric TLDs and unsupported schemes', () {
      final links = Autolinker.findLinks(
        'bad user@example.123 javascript:alert(1) ftp://example.com',
      );
      expect(links, isEmpty);
    });

    test('maps nested text offsets depth-first', () {
      final paragraph = web.document.createElement('p');
      paragraph.append(web.document.createTextNode('abc'));
      final nested = web.document.createElement('span')
        ..append(web.document.createTextNode('def'));
      paragraph
        ..append(nested)
        ..append(web.document.createTextNode('ghi'));
      final position = Autolinker.textPosition(paragraph, 5);
      expect(position.$1.data, 'def');
      expect(position.$2, 2);
      expect(() => Autolinker.textPosition(paragraph, 20), throwsRangeError);
    });

    test('processes empty and unmapped layers safely', () {
      final highlighter = TextHighlighter(
        findController: FakeFind(),
        eventBus: EventBus(),
        pageIndex: 0,
      );
      expect(Autolinker.processLinks(FakeAutolinkPage(highlighter)), isEmpty);
    });
  });

  group('AnnotationEditorLayerBuilder', () {
    test('renders, updates, hides, shows and changes page index', () async {
      final editor = FakeEditor('editor-1');
      final manager = FakeEditorManager([editor]);
      web.HTMLDivElement? appended;
      final builder = AnnotationEditorLayerBuilder(
        uiManager: manager,
        pageIndex: 0,
        onAppend: (div) => appended = div,
      );
      await builder.render(viewport: viewport());
      expect(appended, same(builder.div));
      expect(builder.div?.querySelector('#editor-1'), isNotNull);
      expect(builder.div?.hasAttribute('hidden'), isFalse);
      builder.hide();
      expect(builder.div?.hasAttribute('hidden'), isTrue);
      expect(builder.annotationEditorLayer?.paused, isTrue);
      builder.show();
      expect(builder.annotationEditorLayer?.paused, isFalse);
      await builder.render(viewport: viewport(2));
      expect(editor.updates, 1);
      builder.updatePageIndex(3);
      expect(manager.events, containsAll([('detach', 0), ('attach', 3)]));
      builder.cancel();
      expect(editor.destroyed, isTrue);
    });

    test('honors print intent, cancellation and manager visibility', () async {
      final manager = FakeEditorManager([])..isVisible = false;
      final builder = AnnotationEditorLayerBuilder(
        uiManager: manager,
        pageIndex: 0,
      );
      await builder.render(viewport: viewport(), intent: 'print');
      expect(builder.div, isNull);
      await builder.render(viewport: viewport());
      expect(builder.div?.hasAttribute('hidden'), isTrue);
      builder.cancel();
      expect(builder.cancelled, isTrue);
    });
  });

  group('PDFPageDetailView', () {
    test('calculates padded area and avoids redundant updates', () {
      final host = FakeDetailHost();
      final detail = PDFPageDetailView(pageView: host);
      host.detailView = detail;
      const visible = VisibleDetailArea(
        minX: 300,
        minY: 200,
        maxX: 500,
        maxY: 400,
      );
      detail.update(visibleArea: visible);
      final area = detail.detailArea!;
      expect(area.minX, lessThanOrEqualTo(visible.minX));
      expect(area.maxX, greaterThanOrEqualTo(visible.maxX));
      expect(detail.shouldRenderDifferentArea(visible), isFalse);
      expect(
        detail.shouldRenderDifferentArea(const VisibleDetailArea(
          minX: 0,
          minY: 0,
          maxX: 900,
          maxY: 700,
        )),
        isTrue,
      );
    });

    test('draws detail canvas and dispatches lifecycle events', () async {
      final host = FakeDetailHost();
      final detail = PDFPageDetailView(pageView: host);
      host.detailView = detail;
      detail.update(
          visibleArea: const VisibleDetailArea(
        minX: 100,
        minY: 100,
        maxX: 300,
        maxY: 250,
      ));
      final drawing = detail.draw();
      expect(host.source.tasks, hasLength(1));
      expect(host.events.names, contains('pagerender'));
      final canvas = host.canvasFactory.canvases.single;
      expect(canvas.ariaHidden, isTrue);
      expect(canvas.width, greaterThan(0));
      host.source.tasks.single.completer.complete();
      await drawing;
      expect(detail.renderingState, RenderingState.finished);
      expect(host.events.names, contains('pagerendered'));
      expect(host.inserted, isNotEmpty);
    });

    test('underlying update cancels an active render', () async {
      final host = FakeDetailHost();
      final detail = PDFPageDetailView(pageView: host);
      host.detailView = detail;
      detail.update(
          visibleArea: const VisibleDetailArea(
        minX: 10,
        minY: 10,
        maxX: 100,
        maxY: 100,
      ));
      final drawing = detail.draw();
      detail.update(underlyingViewUpdated: true);
      expect(host.source.tasks.single.cancelled, isTrue);
      await drawing;
      expect(detail.renderingState, RenderingState.initial);
    });

    test('inactive detail view and unloaded page are handled', () async {
      final host = FakeDetailHost();
      final detail = PDFPageDetailView(pageView: host);
      await detail.draw();
      expect(host.source.tasks, isEmpty);
      host.detailView = detail;
      host.pdfPageLoaded = false;
      detail.update(
          visibleArea: const VisibleDetailArea(
        minX: 0,
        minY: 0,
        maxX: 50,
        maxY: 50,
      ));
      await expectLater(detail.draw(), throwsStateError);
    });
  });
}
