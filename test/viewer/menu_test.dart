@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/menu.dart';

void main() {
  late web.HTMLDivElement host;
  late web.HTMLButtonElement trigger;
  late web.HTMLDivElement popup;
  late List<web.HTMLButtonElement> items;
  late Menu menu;

  void key(web.EventTarget target, String value) => target.dispatchEvent(
        web.KeyboardEvent(
            'keydown',
            web.KeyboardEventInit(
              key: value,
              bubbles: true,
              cancelable: true,
            )),
      );

  setUp(() {
    host = web.document.createElement('div') as web.HTMLDivElement;
    trigger = web.document.createElement('button') as web.HTMLButtonElement;
    popup = web.document.createElement('div') as web.HTMLDivElement;
    items = ['Alpha', 'Beta', 'Charlie']
        .map((text) =>
            web.document.createElement('button') as web.HTMLButtonElement
              ..textContent = text)
        .toList();
    for (final item in items) popup.append(item);
    host
      ..append(trigger)
      ..append(popup);
    web.document.body!.append(host);
    menu = Menu(popup, trigger);
  });

  tearDown(() {
    menu.destroy();
    host.remove();
  });

  test('discovers buttons and toggles with triggering click', () {
    expect(menu.menuItems, hasLength(3));
    trigger.click();
    expect(menu.isOpen, isTrue);
    expect(trigger.getAttribute('aria-expanded'), 'true');
    trigger.click();
    expect(menu.isOpen, isFalse);
    expect(trigger.getAttribute('aria-expanded'), 'false');
  });

  test('trigger keyboard opens and focuses first or last enabled item', () {
    items.first.disabled = true;
    key(trigger, 'ArrowDown');
    expect(menu.isOpen, isTrue);
    expect(web.document.activeElement, same(items[1]));
    menu.close();
    key(trigger, 'ArrowUp');
    expect(web.document.activeElement, same(items.last));
  });

  test('menu arrows wrap while skipping disabled and hidden items', () {
    items[1].disabled = true;
    items[2].classList.add('hidden');
    items.first.focus();
    key(popup, 'ArrowDown');
    expect(web.document.activeElement, same(items.first));
    items[2].classList.remove('hidden');
    key(popup, 'ArrowUp');
    expect(web.document.activeElement, same(items.last));
  });

  test('Home, End and letter navigation choose matching enabled items', () {
    menu.open();
    items[1].focus();
    key(popup, 'Home');
    expect(web.document.activeElement, same(items.first));
    key(popup, 'End');
    expect(web.document.activeElement, same(items.last));
    key(popup, 'b');
    expect(web.document.activeElement, same(items[1]));
  });

  test('Escape and menu click close the popup', () {
    menu.open();
    key(popup, 'Escape');
    expect(menu.isOpen, isFalse);
    menu.open();
    items.first.click();
    expect(menu.isOpen, isFalse);
  });

  test('outside pointer closes while inside pointer does not', () {
    menu.open();
    items.first.dispatchEvent(web.PointerEvent('pointerdown'));
    expect(menu.isOpen, isTrue);
    host.remove();
    web.document.body!.dispatchEvent(
        web.PointerEvent('pointerdown', web.PointerEventInit(bubbles: true)));
    expect(menu.isOpen, isFalse);
  });

  test('context menu is suppressed', () {
    final event = web.MouseEvent(
        'contextmenu', web.MouseEventInit(bubbles: true, cancelable: true));
    final result = popup.dispatchEvent(event);
    expect(result, isFalse);
    expect(event.defaultPrevented, isTrue);
  });

  test('destroy removes permanent and open listeners', () {
    menu.open();
    menu.destroy();
    expect(menu.isOpen, isFalse);
    trigger.click();
    expect(menu.isOpen, isFalse);
  });
}
