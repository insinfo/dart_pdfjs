@TestOn('browser')
library;

import 'dart:async';

import 'package:pdfjs/pdfjs.dart' as pdfjs;
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/event_utils.dart';
import '../../example/src/pdf_rendering_queue.dart';
import '../../example/src/pdf_thumbnail_view.dart';
import '../../example/src/pdf_thumbnail_viewer.dart';
import '../../example/src/renderable_view.dart';

final class TestLinkService implements ThumbnailViewerLinkService {
  TestLinkService(this.pagesCount);
  @override
  final int pagesCount;
  final List<int> navigations = [];
  @override
  void goToPage(int pageNumber) => navigations.add(pageNumber);
}

final class TestTask implements ThumbnailRenderTask {
  @override
  Future<void> get promise => Future<void>.value();
  @override
  set onContinue(void Function(void Function())? value) {}
  @override
  void cancel() {}
}

final class TestPage implements ThumbnailPdfPage {
  TestPage(this.number);
  final int number;
  @override
  int get rotate => 0;
  @override
  pdfjs.PageViewport getViewport({required double scale, int? rotation}) =>
      pdfjs.PageViewport(
          viewBox: const [0, 0, 600, 800],
          scale: scale,
          rotation: rotation ?? 0);
  @override
  ThumbnailRenderTask render(ThumbnailRenderContext context) => TestTask();
}

final class TestMapper implements ThumbnailPagesMapper {
  TestMapper(this.pagesNumber);
  @override
  int pagesNumber;
  bool altered = false;
  final List<(List<int>, int)> moves = [];
  @override
  Object? getPageMappingForSaving() => ['mapping'];
  @override
  bool hasBeenAltered() => altered;
  @override
  void movePages(List<int> pageNumbers, int insertionIndex) {
    moves.add((List<int>.of(pageNumbers), insertionIndex));
    altered = true;
  }
}

final class TestDocument implements ThumbnailDocument {
  TestDocument(this.numPages, [this.pagesMapper]);
  @override
  final int numPages;
  @override
  final TestMapper? pagesMapper;
  final List<int> requestedPages = [];
  @override
  Future<Object?> getOptionalContentConfig() async => 'optional';
  @override
  Future<ThumbnailPdfPage> getPage(int pageNumber) async {
    requestedPages.add(pageNumber);
    return TestPage(pageNumber);
  }
}

final class ControlledQueue extends PDFRenderingQueue {
  RenderableView? priority;
  final List<RenderableView> rendered = [];
  int highestPriorityCalls = 0;

  @override
  RenderableView? getHighestPriority(
      VisiblePages visible, List<RenderableView> views, bool scrolledDown,
      {bool preRenderExtra = false, bool ignoreDetailViews = false}) {
    highestPriorityCalls++;
    return priority;
  }

  @override
  bool renderView(RenderableView view) {
    rendered.add(view);
    return true;
  }
}

void main() {
  late web.HTMLDivElement scrollContainer;
  late web.HTMLDivElement container;
  late EventBus bus;
  late ControlledQueue queue;
  late TestLinkService links;
  late PDFThumbnailViewer viewer;
  late ThumbnailManageMenuOptions menuOptions;

  web.HTMLButtonElement button(String id) =>
      web.document.createElement('button') as web.HTMLButtonElement..id = id;

  PDFThumbnailViewer create({bool splitMerge = true}) => PDFThumbnailViewer(
        PDFThumbnailViewerOptions(
          container: container,
          eventBus: bus,
          linkService: links,
          renderingQueue: queue,
          maxCanvasPixels: 33554432,
          maxCanvasDim: 32767,
          enableSplitMerge: splitMerge,
          manageMenu: menuOptions,
        ),
      );

  setUp(() {
    scrollContainer = web.document.createElement('div') as web.HTMLDivElement
      ..style.width = '300px'
      ..style.height = '500px'
      ..style.overflow = 'auto';
    container = web.document.createElement('div') as web.HTMLDivElement;
    scrollContainer.append(container);
    web.document.body!.append(scrollContainer);
    final menu = web.document.createElement('div') as web.HTMLDivElement;
    menuOptions = ThumbnailManageMenuOptions(
      button: button('manage'),
      menu: menu,
      copy: button('copy'),
      cut: button('cut'),
      delete: button('delete'),
      exportSelected: button('export'),
    );
    scrollContainer.append(menuOptions.button);
    for (final item in [
      menuOptions.copy,
      menuOptions.cut,
      menuOptions.delete,
      menuOptions.exportSelected,
    ]) {
      menu.append(item);
    }
    scrollContainer.append(menu);
    bus = EventBus();
    queue = ControlledQueue();
    links = TestLinkService(4);
    viewer = create();
  });

  tearDown(() {
    viewer.destroy();
    queue.dispose();
    scrollContainer.remove();
  });

  Future<TestDocument> load([int count = 4]) async {
    final document = TestDocument(count, TestMapper(count));
    viewer.setDocument(document);
    await viewer.documentLoaded;
    return document;
  }

  test('setDocument creates thumbnails, primes page one and dispatches loaded',
      () async {
    var loaded = 0;
    bus.on('thumbnailsloaded', (_) => loaded++);
    final document = await load();
    expect(viewer.thumbnailsCount, 4);
    expect(document.requestedPages, [1]);
    expect(viewer.getThumbnail(0)!.pdfPage, isNotNull);
    expect(viewer.getThumbnail(0)!.imageContainer.getAttribute('aria-current'),
        'page');
    expect(container.children.length, 4);
    expect(loaded, 1);
  });

  test('replacement document clears old DOM and null document resets',
      () async {
    await load(4);
    final replacement = TestDocument(2);
    viewer.setDocument(replacement);
    await viewer.documentLoaded;
    expect(viewer.thumbnailsCount, 2);
    expect(container.children.length, 2);
    viewer.setDocument(null);
    expect(viewer.thumbnailsCount, 0);
    expect(container.children.length, 0);
  });

  test('page labels accept exact document length and reject invalid length',
      () async {
    await load(3);
    viewer.setPageLabels(['i', 'ii', 'iii']);
    expect(viewer.getThumbnail(1)!.pageLabel, 'ii');
    viewer.setPageLabels(['only']);
    expect(viewer.getThumbnail(0)!.pageLabel, isNull);
    expect(viewer.getThumbnail(2)!.pageLabel, isNull);
  });

  test('rotation validates values and updates every thumbnail', () async {
    await load(2);
    viewer.pagesRotation = 90;
    expect(viewer.pagesRotation, 90);
    expect(viewer.getThumbnail(0)!.rotation, 90);
    expect(viewer.getThumbnail(1)!.rotation, 90);
    expect(() => viewer.pagesRotation = 45, throwsArgumentError);
  });

  test('image activation navigates and current thumbnail changes', () async {
    await load();
    viewer.getThumbnail(2)!.imageContainer.click();
    expect(links.navigations, [3]);
    viewer.scrollThumbnailIntoView(3);
    expect(viewer.currentPageNumber, 3);
    expect(viewer.getThumbnail(0)!.imageContainer.getAttribute('aria-current'),
        'false');
    expect(viewer.getThumbnail(2)!.imageContainer.getAttribute('aria-current'),
        'page');
  });

  test('checkbox selection updates model, menu and event payload', () async {
    await load();
    final events = <Map>[];
    bus.on('thumbnailselectionchanged', (data) => events.add(data as Map));
    final checkbox = viewer.getThumbnail(1)!.checkbox!;
    checkbox.checked = true;
    checkbox.click();
    // click toggles checked before bubbling; set explicitly through public API.
    viewer.selectPage(2, true);
    expect(viewer.selectedPages, {2});
    expect(menuOptions.copy.disabled, isFalse);
    expect(menuOptions.delete.disabled, isFalse);
    expect(events.last['selectedPages'], {2});
    viewer.clearSelection();
    expect(viewer.selectedPages, isEmpty);
    expect(menuOptions.copy.disabled, isTrue);
  });

  test('selecting every page disables destructive actions', () async {
    await load(2);
    viewer.selectPage(1, true);
    viewer.selectPage(2, true);
    expect(menuOptions.copy.disabled, isFalse);
    expect(menuOptions.exportSelected.disabled, isFalse);
    expect(menuOptions.cut.disabled, isTrue);
    expect(menuOptions.delete.disabled, isTrue);
  });

  test('management actions dispatch sorted selected page numbers', () async {
    await load();
    viewer.selectPage(3, true);
    viewer.selectPage(1, true);
    final copyEvents = <Map>[];
    final saveEvents = <Map>[];
    bus
      ..on('copypages', (data) => copyEvents.add(data as Map))
      ..on('saveextractedpages', (data) => saveEvents.add(data as Map));
    menuOptions.copy.click();
    menuOptions.exportSelected.click();
    expect(copyEvents.single['pageNumbers'], [1, 3]);
    expect(saveEvents.single['pageNumbers'], [1, 3]);
  });

  test('keyboard Home End and arrows move focus; Enter navigates', () async {
    await load();
    final second = viewer.getThumbnail(1)!.imageContainer;
    second.focus();
    second.dispatchEvent(web.KeyboardEvent('keydown',
        web.KeyboardEventInit(key: 'End', bubbles: true, cancelable: true)));
    expect(
        web.document.activeElement!
            .isSameNode(viewer.getThumbnail(3)!.imageContainer),
        isTrue);
    viewer.getThumbnail(2)!.imageContainer.dispatchEvent(web.KeyboardEvent(
        'keydown', web.KeyboardEventInit(key: 'ArrowLeft', bubbles: true)));
    expect(
        web.document.activeElement!
            .isSameNode(viewer.getThumbnail(1)!.imageContainer),
        isTrue);
    viewer.getThumbnail(1)!.imageContainer.dispatchEvent(web.KeyboardEvent(
        'keydown', web.KeyboardEventInit(key: 'Enter', bubbles: true)));
    expect(links.navigations.last, 2);
  });

  test('forceRendering asks queue and lazily loads selected page', () async {
    final document = await load();
    for (var i = 0; i < viewer.thumbnailsCount; i++) {
      viewer.getThumbnail(i)!.div.style
        ..width = '126px'
        ..height = '168px';
    }
    queue.priority = viewer.getThumbnail(2);
    expect(viewer.forceRendering(), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(document.requestedPages, contains(3));
    expect(queue.rendered, [viewer.getThumbnail(2)]);
  });

  test('structural change delegates to pages mapper', () async {
    final document = await load();
    expect(viewer.hasStructuralChanges(), isFalse);
    document.pagesMapper!.altered = true;
    expect(viewer.hasStructuralChanges(), isTrue);
    expect(viewer.getStructuralChanges(), ['mapping']);
  });

  test(
      'dragging multiple selected thumbnails preserves current page and mapping',
      () async {
    final document = await load();
    final first = viewer.getThumbnail(0)!;
    final second = viewer.getThumbnail(1)!;
    final third = viewer.getThumbnail(2)!;
    final fourth = viewer.getThumbnail(3)!;
    for (final thumbnail in [first, second, third, fourth]) {
      thumbnail.div.style
        ..display = 'block'
        ..width = '126px'
        ..height = '168px';
      thumbnail.imageContainer.style
        ..display = 'block'
        ..width = '126px'
        ..height = '168px';
    }
    viewer
      ..selectPage(2, true)
      ..selectPage(3, true)
      ..scrollThumbnailIntoView(4);
    expect(viewer.currentPageNumber, 4);

    final edited = <Map>[];
    bus.on('pagesedited', (data) => edited.add(data as Map));
    final startRect = second.imageContainer.getBoundingClientRect();
    final endRect = fourth.div.getBoundingClientRect();
    second.imageContainer.dispatchEvent(web.PointerEvent(
      'pointerdown',
      web.PointerEventInit(
        pointerId: 17,
        button: 0,
        clientX: (startRect.left + 10).round(),
        clientY: (startRect.top + 10).round(),
        bubbles: true,
        cancelable: true,
      ),
    ));
    container.dispatchEvent(web.PointerEvent(
      'pointermove',
      web.PointerEventInit(
        pointerId: 17,
        clientX: (endRect.left + endRect.width / 2).round(),
        clientY: (endRect.bottom + 10).round(),
        bubbles: true,
        cancelable: true,
      ),
    ));
    web.window.dispatchEvent(web.PointerEvent(
      'pointerup',
      web.PointerEventInit(
        pointerId: 17,
        button: 0,
        clientX: (endRect.left + endRect.width / 2).round(),
        clientY: (endRect.bottom + 10).round(),
        bubbles: true,
        cancelable: true,
      ),
    ));

    expect(document.pagesMapper!.moves, hasLength(1));
    expect(document.pagesMapper!.moves.single.$1, [2, 3]);
    expect(document.pagesMapper!.moves.single.$2, 4);
    expect(viewer.getThumbnail(0), same(first));
    expect(viewer.getThumbnail(1), same(fourth));
    expect(viewer.getThumbnail(2), same(second));
    expect(viewer.getThumbnail(3), same(third));
    expect([
      for (var index = 0; index < viewer.thumbnailsCount; index++)
        viewer.getThumbnail(index)!.id,
    ], [
      1,
      2,
      3,
      4
    ]);
    expect(viewer.selectedPages, isEmpty);
    expect(second.checkbox!.checked, isFalse);
    expect(third.checkbox!.checked, isFalse);
    expect(viewer.currentPageNumber, 2);
    expect(fourth.imageContainer.getAttribute('aria-current'), 'page');
    expect(edited, hasLength(1));
    expect(edited.single['pageNumbers'], [2, 3]);
    expect(edited.single['insertAfter'], 4);
    expect(edited.single['type'], 'move');
  });

  test('cleanup resets unfinished thumbnails only', () async {
    await load(2);
    viewer.getThumbnail(0)!.renderingState = RenderingState.finished;
    viewer.getThumbnail(1)!.renderingState = RenderingState.running;
    viewer.cleanup();
    expect(viewer.getThumbnail(0)!.renderingState, RenderingState.finished);
    expect(viewer.getThumbnail(1)!.renderingState, RenderingState.initial);
  });

  test('destroy removes DOM and lifecycle listeners', () async {
    await load();
    viewer.destroy();
    expect(viewer.thumbnailsCount, 0);
    expect(container.children.length, 0);
    menuOptions.button.click();
    expect(menuOptions.button.getAttribute('aria-expanded'), isNot('true'));
  });
}
