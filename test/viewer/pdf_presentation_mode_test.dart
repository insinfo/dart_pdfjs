@TestOn('browser')
library;

import 'dart:async';

import 'package:pdfjs/src/shared/util.dart' show AnnotationEditorType;
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/event_utils.dart';
import '../../example/src/pdf_presentation_mode.dart';
import '../../example/src/ui_utils.dart';

void main() {
  late web.HTMLDivElement container;
  late EventBus eventBus;
  late _Viewer viewer;
  late _Fullscreen fullscreen;
  late PDFPresentationMode mode;
  late List<Map<Object?, Object?>> changes;

  Future<void> pump() async {
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body!.append(container);
    eventBus = EventBus();
    viewer = _Viewer();
    fullscreen = _Fullscreen();
    changes = <Map<Object?, Object?>>[];
    eventBus.on('presentationmodechanged', (data) {
      changes.add(data! as Map<Object?, Object?>);
    });
    mode = PDFPresentationMode(
      container: container,
      pdfViewer: viewer,
      eventBus: eventBus,
      fullscreen: fullscreen,
    );
  });

  tearDown(() {
    mode.dispose();
    container.remove();
  });

  group('request', () {
    test('rejects empty documents', () async {
      viewer.pagesCount = 0;
      expect(await mode.request(), isFalse);
      expect(fullscreen.requests, 0);
      expect(changes, isEmpty);
    });

    test('rejects browsers without fullscreen support', () async {
      fullscreen.supported = false;
      expect(await mode.request(), isFalse);
      expect(fullscreen.requests, 0);
    });

    test('enters fullscreen and notifies state in order', () async {
      expect(await mode.request(), isTrue);
      await pump();

      expect(fullscreen.requests, 1);
      expect(viewer.focusCalls, 1);
      expect(mode.active, isTrue);
      expect(mode.state, PresentationModeState.fullscreen);
      expect(changes.map((event) => event['state']), [
        PresentationModeState.changing,
        PresentationModeState.fullscreen,
      ]);
      expect(
          changes.every((event) => identical(event['source'], mode)), isTrue);
    });

    test('refuses a second request while active', () async {
      expect(await mode.request(), isTrue);
      expect(await mode.request(), isFalse);
      expect(fullscreen.requests, 1);
    });

    test('recovers cleanly when requestFullscreen rejects', () async {
      fullscreen.failure = StateError('denied');
      expect(await mode.request(), isFalse);
      expect(mode.active, isFalse);
      expect(mode.state, PresentationModeState.normal);
      expect(changes.map((event) => event['state']), [
        PresentationModeState.changing,
        PresentationModeState.normal,
      ]);

      fullscreen.failure = null;
      expect(await mode.request(), isTrue);
    });
  });

  group('viewer state', () {
    test('sets page mode, page-fit, and disables editor on entry', () async {
      viewer
        ..currentPageNumber = 4
        ..currentScaleValue = '175%'
        ..scrollMode = ScrollMode.wrapped
        ..annotationEditorMode = AnnotationEditorType.ink;

      await mode.request();
      await pump();

      expect(viewer.currentPageNumber, 4);
      expect(viewer.currentScaleValue, 'page-fit');
      expect(viewer.scrollMode, ScrollMode.page);
      expect(viewer.annotationEditorMode, AnnotationEditorType.none);
      expect(container.classList.contains('pdfPresentationMode'), isTrue);
      expect(mode.controlsVisible, isTrue);
    });

    test('restores scale, modes and editor while keeping exit page', () async {
      viewer
        ..currentPageNumber = 3
        ..currentScaleValue = '125%'
        ..scrollMode = ScrollMode.horizontal
        ..spreadMode = SpreadMode.odd
        ..pageViewsReady = false
        ..annotationEditorMode = AnnotationEditorType.highlight;

      await mode.request();
      await pump();
      expect(viewer.spreadMode, SpreadMode.none);
      viewer.currentPageNumber = 7;
      fullscreen.exit();
      await pump();

      expect(mode.active, isFalse);
      expect(viewer.currentPageNumber, 7);
      expect(viewer.currentScaleValue, '125%');
      expect(viewer.scrollMode, ScrollMode.horizontal);
      expect(viewer.spreadMode, SpreadMode.odd);
      expect(viewer.annotationEditorMode, AnnotationEditorType.highlight);
      expect(container.classList.contains('pdfPresentationMode'), isFalse);
    });

    test('keeps spread mode for ready equal-sized pages', () async {
      viewer
        ..spreadMode = SpreadMode.even
        ..pageViewsReady = true
        ..hasEqualPageSizes = true;

      await mode.request();
      await pump();
      expect(viewer.spreadMode, SpreadMode.even);

      viewer.spreadMode = SpreadMode.odd;
      fullscreen.exit();
      await pump();
      // It was not presentation-owned and is therefore not restored.
      expect(viewer.spreadMode, SpreadMode.odd);
    });

    test('leaves disabled annotation editor untouched', () async {
      viewer.annotationEditorMode = AnnotationEditorType.disable;
      await mode.request();
      await pump();
      expect(viewer.annotationEditorMode, AnnotationEditorType.disable);

      fullscreen.exit();
      await pump();
      expect(viewer.annotationEditorMode, AnnotationEditorType.disable);
    });
  });

  group('mouse input', () {
    setUp(() async {
      await mode.request();
      await pump();
    });

    test('left click advances and shift-click goes back', () {
      final start = viewer.currentPageNumber;
      web.window.dispatchEvent(web.MouseEvent('mousedown'));
      expect(viewer.currentPageNumber, start + 1);

      web.window.dispatchEvent(
        web.MouseEvent('mousedown', web.MouseEventInit(shiftKey: true)),
      );
      expect(viewer.currentPageNumber, start);
    });

    test('other mouse buttons do not navigate', () {
      web.window.dispatchEvent(
        web.MouseEvent('mousedown', web.MouseEventInit(button: 1)),
      );
      expect(viewer.nextCalls, 0);
      expect(viewer.previousCalls, 0);
    });

    test('internal links remain clickable', () {
      final wrapper = web.document.createElement('span') as web.HTMLElement
        ..setAttribute('data-internal-link', '');
      final link = web.document.createElement('a') as web.HTMLAnchorElement
        ..href = '#page=2';
      wrapper.append(link);
      container.append(wrapper);

      link.dispatchEvent(
          web.MouseEvent('mousedown', web.MouseEventInit(bubbles: true)));
      expect(viewer.nextCalls, 0);
      wrapper.remove();
    });

    test('first click after context menu only closes the menu', () {
      web.window.dispatchEvent(web.MouseEvent('contextmenu'));
      expect(mode.contextMenuOpen, isTrue);

      web.window.dispatchEvent(web.MouseEvent('mousedown'));
      expect(mode.contextMenuOpen, isFalse);
      expect(viewer.nextCalls, 0);
    });

    test('mouse movement reveals controls', () {
      container.classList.remove('pdfPresentationModeControls');
      web.window.dispatchEvent(web.MouseEvent('mousemove'));
      expect(mode.controlsVisible, isTrue);
    });
  });

  group('wheel navigation', () {
    setUp(() async {
      await mode.request();
      await pump();
    });

    test('accumulates small deltas until threshold', () {
      mode.handleWheelDelta(-0.04, timestamp: 1000);
      mode.handleWheelDelta(-0.04, timestamp: 1000);
      expect(viewer.nextCalls, 0);
      mode.handleWheelDelta(-0.03, timestamp: 1000);
      expect(viewer.nextCalls, 1);
      expect(mode.mouseScrollDelta, 0);
    });

    test('positive delta selects previous page', () {
      mode.handleWheelDelta(0.11, timestamp: 1000);
      expect(viewer.previousCalls, 1);
    });

    test('direction change resets accumulated delta', () {
      mode.handleWheelDelta(-0.08, timestamp: 1000);
      mode.handleWheelDelta(0.08, timestamp: 1000);
      expect(viewer.previousCalls, 0);
      expect(viewer.nextCalls, 0);
      expect(mode.mouseScrollDelta, closeTo(0.08, 0.0001));
    });

    test('cooldown prevents rapid repeated page switches', () {
      mode.handleWheelDelta(-0.11, timestamp: 1000);
      mode.handleWheelDelta(-0.11, timestamp: 1020);
      expect(viewer.nextCalls, 1);
      mode.handleWheelDelta(-0.11, timestamp: 1060);
      expect(viewer.nextCalls, 2);
    });

    test('keydown resets accumulated wheel state', () {
      mode.handleWheelDelta(-0.08, timestamp: 1000);
      web.window.dispatchEvent(web.KeyboardEvent('keydown'));
      expect(mode.mouseScrollDelta, 0);
      expect(mode.mouseScrollTimeStamp, 0);
    });

    test('does not start cooldown when page cannot change', () {
      viewer.nextResult = false;
      mode.handleWheelDelta(-0.11, timestamp: 1000);
      expect(mode.mouseScrollTimeStamp, 0);
    });
  });

  group('touch navigation', () {
    setUp(() async {
      await mode.request();
      await pump();
    });

    test('horizontal swipes navigate in both directions', () {
      mode.handleTouch('touchstart', [(x: 100, y: 30)]);
      mode.handleTouch('touchmove', [(x: 20, y: 32)]);
      mode.handleTouch('touchend', const []);
      expect(viewer.nextCalls, 1);

      mode.handleTouch('touchstart', [(x: 20, y: 30)]);
      mode.handleTouch('touchmove', [(x: 100, y: 32)]);
      mode.handleTouch('touchend', const []);
      expect(viewer.previousCalls, 1);
    });

    test('vertical swipes navigate in both directions', () {
      mode.handleTouch('touchstart', [(x: 30, y: 100)]);
      mode.handleTouch('touchmove', [(x: 32, y: 20)]);
      mode.handleTouch('touchend', const []);
      expect(viewer.nextCalls, 1);

      mode.handleTouch('touchstart', [(x: 30, y: 20)]);
      mode.handleTouch('touchmove', [(x: 32, y: 100)]);
      mode.handleTouch('touchend', const []);
      expect(viewer.previousCalls, 1);
    });

    test('short and diagonal gestures are ignored', () {
      mode.handleTouch('touchstart', [(x: 10, y: 10)]);
      mode.handleTouch('touchmove', [(x: 40, y: 40)]);
      mode.handleTouch('touchend', const []);
      expect(viewer.nextCalls, 0);
      expect(viewer.previousCalls, 0);
    });

    test('multiple touch points cancel swipe', () {
      mode.handleTouch('touchstart', [(x: 100, y: 10)]);
      mode.handleTouch('touchmove', [(x: 80, y: 10), (x: 90, y: 20)]);
      mode.handleTouch('touchend', const []);
      expect(viewer.nextCalls, 0);
    });

    test('touchmove requests browser gesture suppression', () {
      var prevented = false;
      mode.handleTouch('touchstart', [(x: 100, y: 10)]);
      mode.handleTouch(
        'touchmove',
        [(x: 20, y: 10)],
        preventDefault: () => prevented = true,
      );
      expect(prevented, isTrue);
    });
  });

  group('cleanup', () {
    test('exit removes window listeners and presentation classes', () async {
      await mode.request();
      await pump();
      fullscreen.exit();
      await pump();

      final page = viewer.currentPageNumber;
      web.window.dispatchEvent(web.MouseEvent('mousedown'));
      expect(viewer.currentPageNumber, page);
      expect(mode.controlsVisible, isFalse);
      expect(mode.contextMenuOpen, isFalse);
      expect(mode.state, PresentationModeState.normal);
    });

    test('dispose removes listeners and is idempotent', () async {
      await mode.request();
      await pump();
      mode.dispose();
      mode.dispose();

      expect(mode.active, isFalse);
      expect(mode.controlsVisible, isFalse);
      expect(container.classList.contains('pdfPresentationMode'), isFalse);
      final calls = viewer.nextCalls;
      web.window.dispatchEvent(web.MouseEvent('mousedown'));
      expect(viewer.nextCalls, calls);
    });
  });
}

final class _Fullscreen implements PresentationFullscreen {
  @override
  bool supported = true;
  bool _active = false;
  Object? failure;
  int requests = 0;

  @override
  bool get active => _active;

  @override
  Future<void> request(web.HTMLElement element) async {
    requests++;
    if (failure != null) throw failure!;
    _active = true;
    web.window.dispatchEvent(web.Event('fullscreenchange'));
  }

  void exit() {
    _active = false;
    web.window.dispatchEvent(web.Event('fullscreenchange'));
  }
}

final class _Viewer implements PDFPresentationViewer {
  @override
  int pagesCount = 10;
  @override
  int currentPageNumber = 2;
  @override
  String currentScaleValue = 'auto';
  @override
  int scrollMode = ScrollMode.vertical;
  @override
  int spreadMode = SpreadMode.none;
  @override
  bool pageViewsReady = true;
  @override
  bool hasEqualPageSizes = true;
  @override
  int annotationEditorMode = AnnotationEditorType.disable;

  int focusCalls = 0;
  int previousCalls = 0;
  int nextCalls = 0;
  bool previousResult = true;
  bool nextResult = true;

  @override
  void focus() => focusCalls++;

  @override
  bool nextPage() {
    nextCalls++;
    if (nextResult && currentPageNumber < pagesCount) currentPageNumber++;
    return nextResult;
  }

  @override
  bool previousPage() {
    previousCalls++;
    if (previousResult && currentPageNumber > 1) currentPageNumber--;
    return previousResult;
  }
}
