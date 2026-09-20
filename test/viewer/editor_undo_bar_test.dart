@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/editor_undo_bar.dart';
import '../../example/src/event_utils.dart';

void main() {
  late web.HTMLDivElement container;
  late web.HTMLSpanElement message;
  late web.HTMLButtonElement undo;
  late web.HTMLButtonElement close;
  late EventBus eventBus;
  late EditorUndoBar bar;

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement
      ..tabIndex = -1
      ..hidden = true.toJS;
    message = web.document.createElement('span') as web.HTMLSpanElement;
    undo = web.document.createElement('button') as web.HTMLButtonElement;
    close = web.document.createElement('button') as web.HTMLButtonElement;
    container
      ..append(message)
      ..append(undo)
      ..append(close);
    web.document.body!.append(container);
    eventBus = EventBus();
    bar = EditorUndoBar(
      container: container,
      message: message,
      undoButton: undo,
      closeButton: close,
      eventBus: eventBus,
    );
  });

  tearDown(() {
    bar.destroy();
    container.remove();
  });

  test('shows the localized editor message and invokes undo once', () {
    var calls = 0;
    bar.show(() => calls++, 'highlight');
    expect(bar.isOpen, isTrue);
    expect((container.hidden as JSBoolean).toDart, isFalse);
    expect(
      message.getAttribute('data-l10n-id'),
      'pdfjs-editor-undo-bar-message-highlight',
    );

    undo.click();
    undo.click();
    expect(calls, 1);
    expect(bar.isOpen, isFalse);
    expect((container.hidden as JSBoolean).toDart, isTrue);
  });

  test('uses plural message data and replaces old undo action', () {
    var oldCalls = 0;
    var newCalls = 0;
    bar.show(() => oldCalls++, 'ink');
    bar.show(() => newCalls++, 3);

    expect(
      message.getAttribute('data-l10n-id'),
      'pdfjs-editor-undo-bar-message-multiple',
    );
    expect(jsonDecode(message.getAttribute('data-l10n-args')!), {'count': 3});
    undo.click();
    expect(oldCalls, 0);
    expect(newCalls, 1);
  });

  test('close button and viewer events hide the bar', () {
    bar.show(() {}, 'stamp');
    close.click();
    expect(bar.isOpen, isFalse);

    bar.show(() {}, 'freetext');
    eventBus.dispatch('beforeprint');
    expect(bar.isOpen, isFalse);

    bar.show(() {}, 'signature');
    eventBus.dispatch('download');
    expect(bar.isOpen, isFalse);
  });

  test('prevents the context menu and focuses after delay', () async {
    bar.show(() {}, 'comment');
    final event = web.MouseEvent(
      'contextmenu',
      web.MouseEventInit(cancelable: true),
    );
    expect(container.dispatchEvent(event), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 130));
    expect(web.document.activeElement, container);
  });

  test('destroy detaches persistent event listeners', () {
    bar.show(() {}, 'ink');
    bar.destroy();
    expect(bar.isOpen, isFalse);

    bar.show(() {}, 'ink');
    bar.destroy();
    eventBus.dispatch('download');
    expect(bar.isOpen, isFalse);
  });
}
