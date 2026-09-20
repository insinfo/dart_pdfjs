@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/event_utils.dart';
import '../../example/src/secondary_toolbar.dart';
import '../../example/src/ui_utils.dart';

void main() {
  late web.HTMLDivElement host;
  late SecondaryToolbarOptions options;
  late EventBus bus;
  late SecondaryToolbar toolbar;

  web.HTMLButtonElement button(String id) =>
      web.document.createElement('button') as web.HTMLButtonElement..id = id;

  setUp(() {
    host = web.document.createElement('div') as web.HTMLDivElement;
    final menu = web.document.createElement('div') as web.HTMLElement;
    options = SecondaryToolbarOptions(
      toolbar: menu,
      toggleButton: button('toggle'),
      presentationModeButton: button('presentation'),
      openFileButton: button('open'),
      printButton: button('print'),
      downloadButton: button('download'),
      viewBookmarkButton:
          web.document.createElement('a') as web.HTMLAnchorElement
            ..id = 'bookmark',
      firstPageButton: button('first'),
      lastPageButton: button('last'),
      pageRotateCwButton: button('cw'),
      pageRotateCcwButton: button('ccw'),
      cursorSelectToolButton: button('select'),
      cursorHandToolButton: button('hand'),
      scrollPageButton: button('page'),
      scrollVerticalButton: button('vertical'),
      scrollHorizontalButton: button('horizontal'),
      scrollWrappedButton: button('wrapped'),
      spreadNoneButton: button('none'),
      spreadOddButton: button('odd'),
      spreadEvenButton: button('even'),
      imageAltTextSettingsButton: button('alt'),
      documentPropertiesButton: button('properties'),
    );
    host
      ..append(options.toggleButton)
      ..append(menu);
    for (final element in [
      options.presentationModeButton,
      options.openFileButton,
      options.printButton,
      options.downloadButton,
      options.viewBookmarkButton,
      options.firstPageButton,
      options.lastPageButton,
      options.pageRotateCwButton,
      options.pageRotateCcwButton,
      options.cursorSelectToolButton,
      options.cursorHandToolButton,
      options.scrollPageButton,
      options.scrollVerticalButton,
      options.scrollHorizontalButton,
      options.scrollWrappedButton,
      options.spreadNoneButton,
      options.spreadOddButton,
      options.spreadEvenButton,
      options.imageAltTextSettingsButton,
      options.documentPropertiesButton,
    ]) {
      menu.append(element);
    }
    web.document.body!.append(host);
    bus = EventBus();
    toolbar = SecondaryToolbar(options, bus);
  });

  tearDown(() => host.remove());

  test('reset and page state control navigation and rotation', () {
    expect(options.firstPageButton.disabled, isTrue);
    expect(options.lastPageButton.disabled, isTrue);
    expect(options.pageRotateCwButton.disabled, isTrue);
    toolbar.setPagesCount(9);
    toolbar.setPageNumber(1);
    expect(options.firstPageButton.disabled, isTrue);
    expect(options.lastPageButton.disabled, isFalse);
    expect(options.pageRotateCwButton.disabled, isFalse);
    toolbar.setPageNumber(9);
    expect(options.lastPageButton.disabled, isTrue);
  });

  test('open close and toggle preserve aria and hidden state', () {
    toolbar.open();
    expect(toolbar.isOpen, isTrue);
    expect(options.toggleButton.getAttribute('aria-expanded'), 'true');
    expect(options.toolbar.classList.contains('hidden'), isFalse);
    toolbar.open();
    toolbar.toggle();
    expect(toolbar.isOpen, isFalse);
    expect(options.toggleButton.getAttribute('aria-expanded'), 'false');
    expect(options.toolbar.classList.contains('hidden'), isTrue);
    options.toggleButton.click();
    expect(toolbar.isOpen, isTrue);
  });

  test('buttons dispatch mapped commands, details and telemetry', () {
    final commands = <Map>[];
    final telemetry = <Map>[];
    bus
      ..on('switchcursortool', (data) => commands.add(data as Map))
      ..on('reporttelemetry', (data) => telemetry.add(data as Map));
    toolbar.open();
    options.cursorHandToolButton.click();
    expect(commands.last['tool'], CursorTool.hand);
    expect(toolbar.isOpen, isFalse);
    expect(telemetry.last['details']['data']['id'], 'hand');

    final rotations = <Map>[];
    bus.on('rotatecw', (data) => rotations.add(data as Map));
    toolbar.setPagesCount(1);
    toolbar.open();
    options.pageRotateCwButton.click();
    expect(rotations.single['source'], same(toolbar));
    expect(toolbar.isOpen, isTrue, reason: 'rotation keeps menu open');
  });

  test('cursor mode event checks buttons and applies disabled state', () {
    bus.dispatch('cursortoolchanged', {
      'tool': CursorTool.hand,
      'disabled': true,
    });
    expect(options.cursorHandToolButton.getAttribute('aria-checked'), 'true');
    expect(
        options.cursorSelectToolButton.getAttribute('aria-checked'), 'false');
    expect(options.cursorHandToolButton.disabled, isTrue);
    expect(options.cursorSelectToolButton.disabled, isTrue);
  });

  test('scroll events update checks and horizontal spread availability', () {
    bus.dispatch('scrollmodechanged', {'mode': ScrollMode.horizontal});
    expect(options.scrollHorizontalButton.getAttribute('aria-checked'), 'true');
    expect(options.scrollVerticalButton.getAttribute('aria-checked'), 'false');
    expect(options.spreadNoneButton.disabled, isTrue);
    expect(options.spreadOddButton.disabled, isTrue);
    bus.dispatch('scrollmodechanged', {'mode': ScrollMode.vertical});
    expect(options.spreadNoneButton.disabled, isFalse);
  });

  test('very large documents permanently disable all scroll controls', () {
    toolbar.setPagesCount(forceScrollModePageLimit + 1);
    bus.dispatch('scrollmodechanged', {'mode': ScrollMode.vertical});
    expect(options.scrollPageButton.disabled, isTrue);
    expect(options.scrollVerticalButton.disabled, isTrue);
    expect(options.scrollHorizontalButton.disabled, isTrue);
    expect(options.scrollWrappedButton.disabled, isTrue);
  });

  test('spread events update checked states', () {
    bus.dispatch('spreadmodechanged', {'mode': SpreadMode.even});
    expect(options.spreadEvenButton.getAttribute('aria-checked'), 'true');
    expect(options.spreadOddButton.getAttribute('aria-checked'), 'false');
    expect(options.spreadNoneButton.getAttribute('aria-checked'), 'false');
  });

  test('bookmark closes without dispatching a command but reports telemetry',
      () {
    var telemetry = 0;
    bus.on('reporttelemetry', (_) => telemetry++);
    toolbar.open();
    options.viewBookmarkButton.dispatchEvent(web.MouseEvent('click'));
    expect(toolbar.isOpen, isFalse);
    expect(telemetry, 1);
  });
}
