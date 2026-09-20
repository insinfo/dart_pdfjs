// Copyright 2017 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:js_interop';

import 'package:web/web.dart' as web;
import '../../example/src/event_utils.dart';
import 'package:test/test.dart';

void main() {
  group('EventBus', () {
    test('dispatches an event', () {
      final eventBus = EventBus();
      var count = 0;
      eventBus.on('test', (event) {
        expect(event, isNull);
        count++;
      });

      eventBus.dispatch('test');
      expect(count, 1);
    });

    test('dispatches an event with arguments', () {
      final eventBus = EventBus();
      var count = 0;
      eventBus.on('test', (event) {
        expect(event, <String, int>{'abc': 123});
        count++;
      });

      eventBus.dispatch('test', <String, int>{'abc': 123});
      expect(count, 1);
    });

    test('does not dispatch a different event', () {
      final eventBus = EventBus();
      var count = 0;
      eventBus.on('test', (_) => count++);

      eventBus.dispatch('not-test');
      expect(count, 0);
    });

    test('dispatches an event multiple times', () {
      final eventBus = EventBus();
      var count = 0;
      eventBus.dispatch('test');
      eventBus.on('test', (_) => count++);

      eventBus.dispatch('test');
      eventBus.dispatch('test');
      expect(count, 2);
    });

    test('dispatches to multiple handlers', () {
      final eventBus = EventBus();
      var count = 0;
      eventBus.on('test', (_) => count++);
      eventBus.on('test', (_) => count++);

      eventBus.dispatch('test');
      expect(count, 2);
    });

    test('does not dispatch to a detached handler', () {
      final eventBus = EventBus();
      var count = 0;
      void listener(Object? _) => count++;
      eventBus.on('test', listener);

      eventBus.dispatch('test');
      eventBus.off('test', listener);
      eventBus.dispatch('test');
      expect(count, 1);
    });

    test('ignores detaching a different handler', () {
      final eventBus = EventBus();
      var count = 0;
      void listener(Object? _) => count++;
      void otherListener(Object? _) => count++;
      eventBus.on('test', listener);

      eventBus.dispatch('test');
      eventBus.off('test', otherListener);
      eventBus.dispatch('test');
      expect(count, 2);
    });

    test('uses a snapshot when handlers detach during dispatch', () {
      final eventBus = EventBus();
      var count = 0;
      late EventBusListener listener1;
      late EventBusListener listener2;
      listener1 = (_) {
        eventBus.off('test', listener2);
        count++;
      };
      listener2 = (_) {
        eventBus.off('test', listener1);
        count++;
      };
      eventBus.on('test', listener1);
      eventBus.on('test', listener2);

      eventBus.dispatch('test');
      eventBus.dispatch('test');
      expect(count, 2);
    });

    test('supports handlers with and without once', () {
      final eventBus = EventBus();
      var multipleCount = 0;
      var onceCount = 0;
      eventBus.on('test', (_) => multipleCount++);
      eventBus.on(
        'test',
        (_) => onceCount++,
        const EventBusListenerOptions(once: true),
      );

      eventBus.dispatch('test');
      eventBus.dispatch('test');
      eventBus.dispatch('test');
      expect(multipleCount, 3);
      expect(onceCount, 1);
    });

    test('removes a once handler before invoking it', () {
      final eventBus = EventBus();
      var count = 0;
      eventBus.on(
        'test',
        (_) {
          count++;
          eventBus.dispatch('test');
        },
        const EventBusListenerOptions(once: true),
      );

      eventBus.dispatch('test');
      expect(count, 1);
    });

    test('runs internal handlers before external handlers', () {
      final eventBus = EventBus();
      final calls = <String>[];
      eventBus.on('test', (_) => calls.add('external-first'));
      eventBus.internalOn('test', (_) => calls.add('internal'));
      eventBus.on('test', (_) => calls.add('external-last'));

      eventBus.dispatch('test');
      expect(calls, <String>['internal', 'external-first', 'external-last']);
    });

    test('adding a handler during dispatch affects only the next dispatch', () {
      final eventBus = EventBus();
      final calls = <String>[];
      var added = false;
      eventBus.on('test', (_) {
        calls.add('first');
        if (!added) {
          added = true;
          eventBus.on('test', (_) => calls.add('added'));
        }
      });

      eventBus.dispatch('test');
      expect(calls, <String>['first']);
      eventBus.dispatch('test');
      expect(calls, <String>['first', 'first', 'added']);
    });

    test('removes a handler when its signal is aborted', () {
      final eventBus = EventBus();
      final controller = web.AbortController();
      var count = 0;
      eventBus.on(
        'test',
        (_) => count++,
        EventBusListenerOptions(signal: controller.signal),
      );

      controller.abort();
      eventBus.dispatch('test');
      expect(count, 0);
    });

    test('does not register with an already aborted signal', () {
      final eventBus = EventBus();
      final controller = web.AbortController()..abort();
      var count = 0;
      eventBus.on(
        'test',
        (_) => count++,
        EventBusListenerOptions(signal: controller.signal),
      );

      eventBus.dispatch('test');
      expect(count, 0);
    });

    test('does not re-dispatch ordinary EventBus events to the DOM', () {
      final eventBus = EventBus();
      var domCount = 0;
      final listener = ((web.Event _) => domCount++).toJS;
      web.document.addEventListener('pdfjs-test-event', listener);
      addTearDown(
        () => web.document.removeEventListener('pdfjs-test-event', listener),
      );

      eventBus.dispatch('pdfjs-test-event');
      expect(domCount, 0);
    });
  });

  group('waitOnEventOrTimeout', () {
    test('rejects an empty event name', () {
      expect(
        () => waitOnEventOrTimeout(target: EventBus(), name: ''),
        throwsArgumentError,
      );
    });

    test('rejects a negative timeout', () {
      expect(
        () => waitOnEventOrTimeout(
          target: EventBus(),
          name: 'pagerendered',
          delay: const Duration(milliseconds: -1),
        ),
        throwsArgumentError,
      );
    });

    test('resolves on an EventBus event', () async {
      final eventBus = EventBus();
      final pageRendered = waitOnEventOrTimeout(
        target: eventBus,
        name: 'pagerendered',
        delay: const Duration(seconds: 10),
      );
      eventBus.dispatch('pagerendered');

      expect(await pageRendered, WaitOnType.event);
    });

    test('resolves on timeout using an EventBus', () async {
      final eventBus = EventBus();
      final pageRendered = waitOnEventOrTimeout(
        target: eventBus,
        name: 'pagerendered',
        delay: const Duration(milliseconds: 10),
      );

      expect(await pageRendered, WaitOnType.timeout);
    });

    test('removes the listener after timeout', () async {
      final eventBus = EventBus();
      final result = await waitOnEventOrTimeout(
        target: eventBus,
        name: 'pagerendered',
        delay: Duration.zero,
      );
      expect(result, WaitOnType.timeout);

      // The late event must neither throw nor attempt to complete the future.
      eventBus.dispatch('pagerendered');
    });

    test('the first event wins when dispatched more than once', () async {
      final eventBus = EventBus();
      final result = waitOnEventOrTimeout(
        target: eventBus,
        name: 'pagerendered',
        delay: const Duration(seconds: 1),
      );
      eventBus.dispatch('pagerendered');
      eventBus.dispatch('pagerendered');

      expect(await result, WaitOnType.event);
    });

    test('resolves on a DOM event', () async {
      final button =
          web.document.createElement('button') as web.HTMLButtonElement;
      final clicked = waitOnDomEventOrTimeout(
        target: button,
        name: 'click',
        delay: const Duration(seconds: 10),
      );
      button.click();

      expect(await clicked, WaitOnType.event);
    });

    test('resolves on timeout using a DOM target', () async {
      final button = web.document.createElement('button');
      final clicked = waitOnDomEventOrTimeout(
        target: button,
        name: 'click',
        delay: const Duration(milliseconds: 10),
      );

      expect(await clicked, WaitOnType.timeout);
    });
  });
}
