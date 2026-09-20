@TestOn('browser')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/sidebar.dart';

final class RecordingSidebar extends Sidebar {
  RecordingSidebar(
    super.elements, {
    required super.ltr,
    required super.isResizerOnTheLeft,
    super.globalAbortSignal,
  });

  int starts = 0;
  int stops = 0;
  final List<double> widths = [];

  @override
  void onStartResizing() => starts++;
  @override
  void onStopResizing() => stops++;
  @override
  void onResizing(double newWidth) => widths.add(newWidth);
}

void main() {
  late web.HTMLDivElement host;
  late web.HTMLElement element;
  late web.HTMLElement resizer;
  late web.HTMLButtonElement toggle;
  late RecordingSidebar sidebar;

  setUp(() {
    host = web.document.createElement('div') as web.HTMLDivElement;
    element = web.document.createElement('aside') as web.HTMLElement
      ..style.setProperty('--sidebar-width', '200')
      ..style.setProperty('--sidebar-min-width', '100')
      ..style.setProperty('--sidebar-max-width', '500')
      ..style.width = '200px'
      ..style.height = '100px';
    resizer = web.document.createElement('div') as web.HTMLElement
      ..tabIndex = 0;
    toggle = web.document.createElement('button') as web.HTMLButtonElement;
    element.append(resizer);
    host
      ..append(element)
      ..append(toggle);
    web.document.body!.append(host);
    sidebar = RecordingSidebar(
      SidebarElements(sidebar: element, resizer: resizer, toggleButton: toggle),
      ltr: true,
      isResizerOnTheLeft: false,
    );
  });

  tearDown(() {
    sidebar.destroy();
    host.remove();
  });

  Future<void> frame() async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

  test('initializes accessibility range and starts closed', () {
    expect(sidebar.width, 200);
    expect(sidebar.isOpen, isFalse);
    expect(element.hasAttribute('hidden'), isTrue);
    expect(resizer.getAttribute('aria-valuemin'), '100');
    expect(resizer.getAttribute('aria-valuemax'), '500');
    expect(resizer.getAttribute('aria-valuenow'), '200');
  });

  test('toggle supports implicit and explicit visibility', () {
    toggle.click();
    expect(sidebar.isOpen, isTrue);
    expect(element.hasAttribute('hidden'), isFalse);
    sidebar.toggle(false);
    expect(sidebar.isOpen, isFalse);
    sidebar.toggle(true);
    expect(sidebar.isOpen, isTrue);
    sidebar.toggle(true);
    expect(sidebar.isOpen, isTrue);
  });

  test('width setter is observed and lifecycle receives new width', () async {
    sidebar.toggle(true);
    sidebar.width = 275;
    await frame();
    expect(element.style.width, '275px');
    expect(sidebar.width, closeTo(275, 0.5));
    expect(resizer.getAttribute('aria-valuenow'), '275');
    expect(sidebar.widths.last, closeTo(275, 0.5));
  });

  test('arrow keyboard resizing starts and stops after debounce', () async {
    resizer.dispatchEvent(web.KeyboardEvent(
      'keydown',
      web.KeyboardEventInit(key: 'ArrowRight', bubbles: true),
    ));
    expect(sidebar.starts, 1);
    expect(element.classList.contains('resizing'), isTrue);
    expect(element.style.width, '201px');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(sidebar.stops, 1);
    expect(element.classList.contains('resizing'), isFalse);
  });

  test('control-arrow changes by ten pixels and consumes event', () {
    final event = web.KeyboardEvent(
      'keydown',
      web.KeyboardEventInit(
          key: 'ArrowLeft', ctrlKey: true, bubbles: true, cancelable: true),
    );
    final accepted = resizer.dispatchEvent(event);
    expect(element.style.width, '190px');
    expect(event.defaultPrevented, isTrue);
    expect(accepted, isFalse);
  });

  test('irrelevant key does not begin resizing', () {
    resizer.dispatchEvent(web.KeyboardEvent(
        'keydown', web.KeyboardEventInit(key: 'Enter', bubbles: true)));
    expect(sidebar.starts, 0);
    expect(element.classList.contains('resizing'), isFalse);
    expect(element.style.width, '200px');
  });

  test('pointer gesture installs listeners and pointerup ends resize', () {
    resizer.dispatchEvent(web.PointerEvent(
      'pointerdown',
      web.PointerEventInit(clientX: 100, bubbles: true, cancelable: true),
    ));
    expect(sidebar.starts, 1);
    expect(element.classList.contains('resizing'), isTrue);
    web.window.dispatchEvent(web.PointerEvent(
      'pointermove',
      web.PointerEventInit(clientX: 130, bubbles: true, cancelable: true),
    ));
    expect(element.style.width, '230px');
    web.window.dispatchEvent(web.PointerEvent(
      'pointerup',
      web.PointerEventInit(clientX: 130, bubbles: true, cancelable: true),
    ));
    expect(sidebar.stops, 1);
    expect(element.classList.contains('resizing'), isFalse);
  });

  test('second pointerdown cancels an active resize', () {
    final down = web.PointerEvent(
      'pointerdown',
      web.PointerEventInit(clientX: 100, bubbles: true, cancelable: true),
    );
    resizer.dispatchEvent(down);
    resizer.dispatchEvent(web.PointerEvent(
      'pointerdown',
      web.PointerEventInit(clientX: 100, bubbles: true, cancelable: true),
    ));
    expect(sidebar.starts, 1);
    expect(sidebar.stops, 1);
    expect(element.classList.contains('resizing'), isFalse);
  });

  test('global abort destroys observer and active pointer listeners', () async {
    final controller = web.AbortController();
    sidebar.destroy();
    sidebar = RecordingSidebar(
      SidebarElements(sidebar: element, resizer: resizer, toggleButton: toggle),
      ltr: true,
      isResizerOnTheLeft: false,
      globalAbortSignal: controller.signal,
    );
    final widthBeforeAbort = sidebar.width;
    controller.abort();
    sidebar.width = 310;
    await frame();
    expect(sidebar.width, widthBeforeAbort,
        reason: 'destroyed observer no longer updates');
  });
}
