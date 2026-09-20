import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'pdf_history.dart';

PDFHistoryEnvironment createPDFHistoryEnvironment() =>
    const BrowserPDFHistoryEnvironment();

/// Browser adapter for [PDFHistoryEnvironment], implemented with package:web.
final class BrowserPDFHistoryEnvironment implements PDFHistoryEnvironment {
  const BrowserPDFHistoryEnvironment();

  @override
  Map<String, dynamic>? get state => _mapFromJs(web.window.history.state);

  @override
  String get hash => web.window.location.hash;

  @override
  String get href => web.window.location.href;

  @override
  String get protocol => web.window.location.protocol;

  @override
  bool get wasReloaded {
    final entries = web.window.performance.getEntriesByType('navigation');
    if (entries.length == 0) return false;
    final entry = entries[0];
    return entry is web.PerformanceNavigationTiming && entry.type == 'reload';
  }

  @override
  void replaceState(Map<String, dynamic> state, String? url) {
    web.window.history.replaceState(state.jsify(), '', url);
  }

  @override
  void pushState(Map<String, dynamic> state, String? url) {
    web.window.history.pushState(state.jsify(), '', url);
  }

  @override
  void back() => web.window.history.back();

  @override
  void forward() => web.window.history.forward();

  @override
  HistoryEventCanceler onPopState(
    void Function(Map<String, dynamic>? state) listener,
  ) {
    final eventListener = ((web.Event event) {
      listener(_mapFromJs((event as web.PopStateEvent).state));
    }).toJS;
    web.window.addEventListener('popstate', eventListener);
    return () => web.window.removeEventListener('popstate', eventListener);
  }

  @override
  HistoryEventCanceler onPageHide(void Function() listener) {
    final eventListener = ((web.Event _) => listener()).toJS;
    web.window.addEventListener('pagehide', eventListener);
    return () => web.window.removeEventListener('pagehide', eventListener);
  }

  @override
  Future<void> waitForHashChange(Duration timeout) {
    final completer = Completer<void>();
    Timer? timer;
    late final web.EventListener eventListener;
    void finish() {
      if (completer.isCompleted) return;
      web.window.removeEventListener('hashchange', eventListener);
      timer?.cancel();
      completer.complete();
    }

    eventListener = ((web.Event _) => finish()).toJS;
    web.window.addEventListener('hashchange', eventListener);
    timer = Timer(timeout, finish);
    return completer.future;
  }
}

Map<String, dynamic>? _mapFromJs(JSAny? value) {
  if (value == null) return null;
  final dartValue = value.dartify();
  if (dartValue is! Map) return null;
  return dartValue.map(
    (key, value) => MapEntry(key.toString(), _normalizeJsValue(value)),
  );
}

Object? _normalizeJsValue(Object? value) {
  if (value is Map) {
    return value.map(
      (key, child) => MapEntry(key.toString(), _normalizeJsValue(child)),
    );
  }
  if (value is List) return value.map(_normalizeJsValue).toList();
  return value;
}
