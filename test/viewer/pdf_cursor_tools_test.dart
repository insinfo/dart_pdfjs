@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/event_utils.dart';
import '../../example/src/pdf_cursor_tools.dart';
import '../../example/src/ui_utils.dart';

void main() {
  late EventBus eventBus;
  late web.HTMLDivElement container;
  late PDFCursorTools tools;
  late List<Map> changes;

  setUp(() {
    eventBus = EventBus();
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body!.append(container);
    changes = <Map>[];
    eventBus.on('cursortoolchanged', (value) => changes.add(value as Map));
  });

  tearDown(() {
    tools.dispose();
    container.remove();
  });

  test('starts with select and switches to hand', () {
    tools = PDFCursorTools(container: container, eventBus: eventBus);
    expect(tools.activeTool, CursorTool.select);

    tools.switchTool(CursorTool.hand);
    expect(tools.activeTool, CursorTool.hand);
    expect(container.classList.contains('grab-to-pan-grab'), isTrue);
    expect(changes.single['tool'], CursorTool.hand);
    expect(changes.single['disabled'], isFalse);
  });

  test('switching back to select deactivates hand panning', () {
    tools = PDFCursorTools(container: container, eventBus: eventBus);
    tools.switchTool(CursorTool.hand);
    tools.switchTool(CursorTool.select);

    expect(tools.activeTool, CursorTool.select);
    expect(container.classList.contains('grab-to-pan-grab'), isFalse);
    expect(changes.map((e) => e['tool']), [CursorTool.hand, CursorTool.select]);
  });

  test('unsupported and zoom tools leave state unchanged', () {
    tools = PDFCursorTools(container: container, eventBus: eventBus);
    tools.switchTool(CursorTool.zoom);
    tools.switchTool(99);
    expect(tools.activeTool, CursorTool.select);
    expect(changes, isEmpty);
  });

  test('switchcursortool event changes active tool', () {
    tools = PDFCursorTools(container: container, eventBus: eventBus);
    eventBus.dispatch('switchcursortool', {'tool': CursorTool.hand});
    expect(tools.activeTool, CursorTool.hand);
  });

  test('annotation editor disables hand and restores it later', () {
    tools = PDFCursorTools(container: container, eventBus: eventBus);
    tools.switchTool(CursorTool.hand);
    changes.clear();

    eventBus.dispatch('annotationeditormodechanged', {'mode': 3});
    expect(tools.disabled, isTrue);
    expect(tools.activeTool, CursorTool.select);
    expect(changes.single['disabled'], isTrue);

    eventBus.dispatch('annotationeditormodechanged', {'mode': 0});
    expect(tools.disabled, isFalse);
    expect(tools.activeTool, CursorTool.hand);
    expect(changes.last['disabled'], isFalse);
  });

  test('presentation fullscreen disables and normal restores hand', () {
    tools = PDFCursorTools(container: container, eventBus: eventBus);
    tools.switchTool(CursorTool.hand);

    eventBus.dispatch('presentationmodechanged', {
      'state': PresentationModeState.fullscreen,
    });
    expect(tools.activeTool, CursorTool.select);
    expect(tools.disabled, isTrue);

    eventBus.dispatch('presentationmodechanged', {
      'state': PresentationModeState.normal,
    });
    expect(tools.activeTool, CursorTool.hand);
    expect(tools.disabled, isFalse);
  });

  test('changing presentation state ignores transitional state', () {
    tools = PDFCursorTools(container: container, eventBus: eventBus);
    tools.switchTool(CursorTool.hand);
    eventBus.dispatch('presentationmodechanged', {
      'state': PresentationModeState.changing,
    });
    expect(tools.activeTool, CursorTool.hand);
  });

  test('both blockers must clear before previous tool is restored', () {
    tools = PDFCursorTools(container: container, eventBus: eventBus);
    tools.switchTool(CursorTool.hand);
    eventBus.dispatch('annotationeditormodechanged', {'mode': 3});
    eventBus.dispatch('presentationmodechanged', {
      'state': PresentationModeState.fullscreen,
    });

    eventBus.dispatch('annotationeditormodechanged', {'mode': 0});
    expect(tools.activeTool, CursorTool.select);
    expect(tools.disabled, isTrue);

    eventBus.dispatch('presentationmodechanged', {
      'state': PresentationModeState.normal,
    });
    expect(tools.activeTool, CursorTool.hand);
  });

  test('reset clears blockers and restores previous tool', () {
    tools = PDFCursorTools(container: container, eventBus: eventBus);
    tools.switchTool(CursorTool.hand);
    eventBus.dispatch('annotationeditormodechanged', {'mode': 3});

    eventBus.dispatch('switchcursortool', {'reset': true});
    expect(tools.activeTool, CursorTool.hand);
    expect(tools.disabled, isFalse);
  });

  test('tool switching is blocked while disabled', () {
    tools = PDFCursorTools(container: container, eventBus: eventBus);
    tools.switchTool(CursorTool.hand);
    eventBus.dispatch('annotationeditormodechanged', {'mode': 3});
    tools.switchTool(CursorTool.hand);
    expect(tools.activeTool, CursorTool.select);
  });

  test('deferred cursorToolOnLoad permits listener registration', () async {
    tools = PDFCursorTools(
      container: container,
      eventBus: eventBus,
      cursorToolOnLoad: CursorTool.hand,
    );
    expect(tools.activeTool, CursorTool.select);
    await Future<void>.delayed(Duration.zero);
    expect(tools.activeTool, CursorTool.hand);
    expect(changes.single['source'], same(tools));
  });

  test('dispose unregisters bus listeners and hand tool', () {
    tools = PDFCursorTools(container: container, eventBus: eventBus);
    tools.switchTool(CursorTool.hand);
    tools.dispose();
    expect(container.classList.contains('grab-to-pan-grab'), isFalse);

    eventBus.dispatch('switchcursortool', {'tool': CursorTool.select});
    expect(tools.activeTool, CursorTool.hand);
  });
}
