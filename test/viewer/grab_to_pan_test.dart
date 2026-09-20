@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/grab_to_pan.dart';

void main() {
  late web.HTMLDivElement container;
  late GrabToPan grabber;

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    container.style
      ..width = '100px'
      ..height = '100px'
      ..overflow = 'scroll';
    final content = web.document.createElement('div') as web.HTMLDivElement;
    content.style
      ..width = '500px'
      ..height = '500px';
    container.append(content);
    web.document.body!.append(container);
    grabber = GrabToPan(element: container);
  });

  tearDown(() {
    grabber.dispose();
    container.remove();
  });

  web.MouseEvent mouse(
    String type, {
    int button = 0,
    int buttons = 1,
    int x = 0,
    int y = 0,
  }) =>
      web.MouseEvent(
        type,
        web.MouseEventInit(
          bubbles: true,
          cancelable: true,
          button: button,
          buttons: buttons,
          clientX: x,
          clientY: y,
        ),
      );

  test('activate, deactivate and toggle are idempotent', () {
    expect(grabber.active, isFalse);
    grabber.activate();
    grabber.activate();
    expect(grabber.active, isTrue);
    expect(container.classList.contains(grabToPanGrabClass), isTrue);

    grabber.toggle();
    expect(grabber.active, isFalse);
    expect(container.classList.contains(grabToPanGrabClass), isFalse);
    grabber.toggle();
    expect(grabber.active, isTrue);
  });

  test('left mouse starts a pan, prevents default and blurs outside focus', () {
    final input = web.document.createElement('input') as web.HTMLInputElement;
    web.document.body!.append(input);
    input.focus();
    grabber.activate();

    final down = mouse('mousedown', x: 40, y: 50);
    final dispatched = container.dispatchEvent(down);

    expect(dispatched, isFalse);
    expect(down.defaultPrevented, isTrue);
    expect(grabber.panning, isTrue);
    expect(grabber.clientXStart, 40);
    expect(grabber.clientYStart, 50);
    expect(web.document.activeElement, isNot(same(input)));
    input.remove();
  });

  test('non-primary buttons and interactive targets are ignored', () {
    final button =
        web.document.createElement('button') as web.HTMLButtonElement;
    container.append(button);
    grabber.activate();

    container.dispatchEvent(mouse('mousedown', button: 2, buttons: 2));
    expect(grabber.panning, isFalse);

    button.dispatchEvent(mouse('mousedown'));
    expect(grabber.panning, isFalse);
    expect(grabber.ignoreTarget(button), isTrue);
  });

  test('descendants of links and buttons are ignored', () {
    final link = web.document.createElement('a') as web.HTMLAnchorElement;
    link.href = '#test';
    final span = web.document.createElement('span');
    link.append(span);
    container.append(link);

    expect(grabber.ignoreTarget(link), isTrue);
    expect(grabber.ignoreTarget(span), isTrue);
    expect(grabber.ignoreTarget(container), isFalse);
  });

  test('mouse movement scrolls and inserts grabbing overlay', () {
    container
      ..scrollLeft = 100
      ..scrollTop = 120;
    grabber.activate();
    container.dispatchEvent(mouse('mousedown', x: 50, y: 60));
    web.document.dispatchEvent(mouse('mousemove', x: 30, y: 25));

    expect(container.scrollLeft, 120);
    expect(container.scrollTop, 155);
    expect(grabber.overlay.parentNode, same(web.document.body));
    expect(
      grabber.overlay.classList.contains(grabToPanGrabbingClass),
      isTrue,
    );
  });

  test('mousemove with released primary button ends pan', () {
    grabber.activate();
    container.dispatchEvent(mouse('mousedown'));
    expect(grabber.panning, isTrue);

    web.document.dispatchEvent(mouse('mousemove', buttons: 0));
    expect(grabber.panning, isFalse);
    expect(grabber.overlay.parentNode, isNull);
  });

  test('mouseup ends pan and removes overlay', () {
    grabber.activate();
    container.dispatchEvent(mouse('mousedown'));
    web.document.dispatchEvent(mouse('mousemove', x: 2, y: 2));
    expect(grabber.overlay.parentNode, isNotNull);

    web.document.dispatchEvent(mouse('mouseup', buttons: 0));
    expect(grabber.panning, isFalse);
    expect(grabber.overlay.parentNode, isNull);
  });

  test('scroll before first mouse movement cancels pan', () {
    grabber.activate();
    container.dispatchEvent(mouse('mousedown'));
    container.dispatchEvent(web.Event('scroll'));
    expect(grabber.panning, isFalse);
  });

  test('scroll after movement no longer cancels active pan', () {
    grabber.activate();
    container.dispatchEvent(mouse('mousedown'));
    web.document.dispatchEvent(mouse('mousemove', x: 2, y: 2));
    container.dispatchEvent(web.Event('scroll'));
    expect(grabber.panning, isTrue);
  });

  test('deactivate terminates an active session', () {
    grabber.activate();
    container.dispatchEvent(mouse('mousedown'));
    web.document.dispatchEvent(mouse('mousemove', x: 2, y: 2));

    grabber.deactivate();
    expect(grabber.active, isFalse);
    expect(grabber.panning, isFalse);
    expect(grabber.overlay.parentNode, isNull);
  });
}
