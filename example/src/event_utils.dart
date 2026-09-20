// Copyright 2012 Mozilla Foundation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The result of [waitOnEventOrTimeout].
enum WaitOnType {
  event,
  timeout,
}

/// Signature used by listeners registered with [EventBus].
typedef EventBusListener = void Function(Object? data);

/// Options accepted by [EventBus.on] and [EventBus.internalOn].
///
/// [signal] mirrors the JavaScript `AbortSignal` option. An already aborted
/// signal is rejected, while a later abort removes the corresponding listener.
final class EventBusListenerOptions {
  const EventBusListenerOptions({
    this.once = false,
    this.signal,
  });

  final bool once;
  final web.AbortSignal? signal;
}

/// Simple event bus for the viewer application.
///
/// Public listeners are considered external. Internal listeners registered by
/// viewer components through [internalOn] always run before external listeners,
/// independent of their registration order. This ordering is intentional: it
/// lets components update their state before application integrations observe
/// an event.
class EventBus {
  final Map<String, List<_EventBusListenerRecord>> _listeners =
      <String, List<_EventBusListenerRecord>>{};

  /// Adds an external listener for [eventName].
  void on(
    String eventName,
    EventBusListener listener, [
    EventBusListenerOptions? options,
  ]) {
    internalOn(
      eventName,
      listener,
      external: true,
      once: options?.once ?? false,
      signal: options?.signal,
    );
  }

  /// Removes the first matching listener for [eventName].
  ///
  /// Function identity is significant, as in the JavaScript implementation.
  void off(String eventName, EventBusListener listener) {
    internalOff(eventName, listener);
  }

  /// Dispatches [data] to all listeners currently registered for [eventName].
  ///
  /// A snapshot is used so adding or removing listeners during a callback does
  /// not alter the current dispatch. `once` listeners are removed immediately
  /// before invocation, which also makes nested dispatches safe.
  void dispatch(String eventName, [Object? data]) {
    final eventListeners = _listeners[eventName];
    if (eventListeners == null || eventListeners.isEmpty) {
      return;
    }

    final externalListeners = <EventBusListener>[];
    for (final record in List<_EventBusListenerRecord>.of(eventListeners)) {
      if (record.once) {
        internalOff(eventName, record.listener);
      }
      if (record.external) {
        externalListeners.add(record.listener);
      } else {
        record.listener(data);
      }
    }

    for (final listener in externalListeners) {
      listener(data);
    }
  }

  /// Adds a listener used by viewer internals.
  ///
  /// This corresponds to PDF.js' private `_on` method but is public in Dart so
  /// independently ported viewer modules can preserve the original ordering.
  void internalOn(
    String eventName,
    EventBusListener listener, {
    bool external = false,
    bool once = false,
    web.AbortSignal? signal,
  }) {
    void Function()? removeAbortListener;
    if (signal != null) {
      if (signal.aborted) {
        // Match PDF.js: do not attach listeners to an already aborted signal.
        return;
      }

      late final web.EventListener abortListener;
      abortListener = ((web.Event _) {
        internalOff(eventName, listener);
      }).toJS;
      signal.addEventListener('abort', abortListener);
      removeAbortListener = () {
        signal.removeEventListener('abort', abortListener);
      };
    }

    final eventListeners =
        _listeners.putIfAbsent(eventName, () => <_EventBusListenerRecord>[]);
    eventListeners.add(
      _EventBusListenerRecord(
        listener: listener,
        external: external,
        once: once,
        removeAbortListener: removeAbortListener,
      ),
    );
  }

  /// Removes the first listener identical to [listener].
  void internalOff(String eventName, EventBusListener listener) {
    final eventListeners = _listeners[eventName];
    if (eventListeners == null) {
      return;
    }

    for (var index = 0; index < eventListeners.length; index++) {
      final record = eventListeners[index];
      if (identical(record.listener, listener)) {
        record.removeAbortListener?.call();
        eventListeners.removeAt(index);
        if (eventListeners.isEmpty) {
          _listeners.remove(eventName);
        }
        return;
      }
    }
  }
}

/// Bridge used by [FirefoxEventBus] to notify the embedding application.
abstract interface class FirefoxExternalServices {
  void dispatchGlobalEvent({
    required String eventName,
    required Object? detail,
  });
}

/// Firefox-specific event bus used by the built-in PDF viewer.
///
/// In automation mode, events are mirrored to `document` as bubbling,
/// cancelable `CustomEvent`s. Events selected by [globalEventNames] are also
/// forwarded to [externalServices].
final class FirefoxEventBus extends EventBus {
  FirefoxEventBus(
    Set<String>? globalEventNames,
    FirefoxExternalServices externalServices,
    bool isInAutomation,
  )   : _globalEventNames = globalEventNames,
        _externalServices = externalServices,
        _isInAutomation = isInAutomation;

  final Set<String>? _globalEventNames;
  final FirefoxExternalServices _externalServices;
  final bool _isInAutomation;

  @override
  void dispatch(String eventName, [Object? data]) {
    super.dispatch(eventName, data);

    if (_isInAutomation) {
      final detail = <String, Object?>{};
      if (data case final Map<Object?, Object?> values) {
        for (final MapEntry(:key, :value) in values.entries) {
          if (key is! String) {
            continue;
          }
          if (key == 'source') {
            // Global DOM sources have already dispatched their own event. All
            // other sources are deliberately omitted from the cloned detail.
            if (value == web.window || value == web.document) {
              return;
            }
            continue;
          }
          detail[key] = value;
        }
      }

      final event = web.CustomEvent(
        eventName,
        web.CustomEventInit(
          bubbles: true,
          cancelable: true,
          detail: detail.jsify(),
        ),
      );
      web.document.dispatchEvent(event);
    }

    if (_globalEventNames?.contains(eventName) ?? false) {
      _externalServices.dispatchGlobalEvent(
        eventName: eventName,
        detail: data,
      );
    }
  }
}

final class _EventBusListenerRecord {
  const _EventBusListenerRecord({
    required this.listener,
    required this.external,
    required this.once,
    required this.removeAbortListener,
  });

  final EventBusListener listener;
  final bool external;
  final bool once;
  final void Function()? removeAbortListener;
}

/// Waits for an [EventBus] event or [delay], whichever occurs first.
///
/// This overload is VM-safe and is also used by the browser viewer whenever
/// the target is the viewer's event bus.
Future<WaitOnType> waitOnEventOrTimeout({
  required EventBus target,
  required String name,
  Duration delay = Duration.zero,
}) {
  _validateWaitParameters(name, delay);

  final completer = Completer<WaitOnType>();
  Timer? timer;
  late final EventBusListener listener;

  void finish(WaitOnType type) {
    if (completer.isCompleted) {
      return;
    }
    target.internalOff(name, listener);
    timer?.cancel();
    completer.complete(type);
  }

  listener = (_) => finish(WaitOnType.event);
  target.internalOn(name, listener);
  timer = Timer(delay, () => finish(WaitOnType.timeout));
  return completer.future;
}

/// Waits for a DOM [target] event or [delay], whichever occurs first.
///
/// The listener is explicitly removed after either outcome, equivalent to the
/// AbortController cleanup used in the JavaScript source.
Future<WaitOnType> waitOnDomEventOrTimeout({
  required web.EventTarget target,
  required String name,
  Duration delay = Duration.zero,
}) {
  _validateWaitParameters(name, delay);

  final completer = Completer<WaitOnType>();
  Timer? timer;
  late final web.EventListener listener;

  void finish(WaitOnType type) {
    if (completer.isCompleted) {
      return;
    }
    target.removeEventListener(name, listener);
    timer?.cancel();
    completer.complete(type);
  }

  listener = ((web.Event _) => finish(WaitOnType.event)).toJS;
  target.addEventListener(name, listener);
  timer = Timer(delay, () => finish(WaitOnType.timeout));
  return completer.future;
}

void _validateWaitParameters(String name, Duration delay) {
  if (name.isEmpty || delay.isNegative) {
    throw ArgumentError('waitOnEventOrTimeout - invalid parameters.');
  }
}
