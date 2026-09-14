// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import '../shared/util.dart';

/// Parse and validate a URL property for the PDF source.
/// Returns a [Uri] for the given value.
Uri getUrlProp(dynamic val) {
  if (val is Uri) {
    return val;
  }
  if (val is String) {
    final parsed = Uri.tryParse(val);
    if (parsed != null) {
      return parsed;
    }
  }
  throw ArgumentError(
    'Invalid PDF url data: '
    'either String or Uri is expected in the url property.',
  );
}

/// Convert various binary data types to [Uint8List].
Uint8List getDataProp(dynamic val) {
  if (val is Uint8List) {
    return val;
  }
  if (val is String) {
    return stringToBytes(val);
  }
  if (val is List<int>) {
    return Uint8List.fromList(val);
  }
  if (val is ByteBuffer) {
    return val.asUint8List();
  }
  throw ArgumentError(
    'Invalid PDF binary data: either Uint8List, '
    'String, or List<int> is expected in the data property.',
  );
}

/// Validate a factory URL, ensuring it ends with '/'.
String? getFactoryUrlProp(dynamic val) {
  if (val is! String) {
    return null;
  }
  if (val.endsWith('/')) {
    return val;
  }
  throw ArgumentError('Invalid factory url: "$val" must include trailing slash.');
}

/// Check if [v] is a valid Ref proxy object.
bool isRefProxy(dynamic v) {
  if (v is Map) {
    final num_ = v['num'];
    final gen = v['gen'];
    return num_ is int && num_ >= 0 && gen is int && gen >= 0;
  }
  return false;
}

/// Check if [v] is a valid Name proxy object.
bool isNameProxy(dynamic v) {
  if (v is Map) {
    return v['name'] is String;
  }
  return false;
}

/// Validate an explicit destination using proxy checks.
bool isValidExplicitDest(dynamic dest) {
  return isValidExplicitDestFn(isRefProxy, isNameProxy, dest);
}

/// A loopback port that simulates message passing within the same isolate.
class LoopbackPort {
  final Map<Function, Function?> _listeners = {};

  void postMessage(dynamic obj, [List<dynamic>? transfer]) {
    final event = {'data': obj};
    Future.microtask(() {
      for (final listener in _listeners.keys.toList()) {
        listener(event);
      }
    });
  }

  void addEventListener(String name, Function listener,
      [Map<String, dynamic>? options]) {
    _listeners[listener] = null;
  }

  void removeEventListener(String name, Function listener) {
    _listeners.remove(listener);
  }

  void terminate() {
    _listeners.clear();
  }
}
