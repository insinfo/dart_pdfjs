// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';

class _DataObj {
  final Completer<void> completer = Completer<void>();
  bool resolved = false;
  dynamic data;
}

/// A PDF document and page is built of many objects (fonts, images, etc.).
/// This class implements the basic methods to manage these objects and
/// resolve them asynchronously.
class PDFObjects {
  final Map<String, _DataObj> _objs = {};

  dynamic get(String objId, [void Function(dynamic data)? callback]) {
    final obj = _objs.putIfAbsent(objId, () => _DataObj());
    if (callback != null) {
      obj.completer.future.then((_) => callback(obj.data));
      return null;
    }
    if (!obj.resolved) {
      throw StateError("Requesting object that isn't resolved yet $objId.");
    }
    return obj.data;
  }

  Future<dynamic> getAsync(String objId) async {
    final obj = _objs.putIfAbsent(objId, () => _DataObj());
    if (obj.resolved) {
      return obj.data;
    }
    await obj.completer.future;
    return obj.data;
  }

  bool has(String objId) {
    final obj = _objs[objId];
    return obj != null && obj.resolved;
  }

  bool delete(String objId) {
    final obj = _objs[objId];
    if (obj == null || !obj.resolved) {
      return false;
    }
    _objs.remove(objId);
    return true;
  }

  void resolve(String objId, [dynamic data]) {
    final obj = _objs.putIfAbsent(objId, () => _DataObj());
    if (obj.resolved) {
      throw StateError('Object already resolved $objId.');
    }
    obj.data = data;
    obj.resolved = true;
    obj.completer.complete();
  }

  void clear() {
    _objs.clear();
  }

  Iterable<MapEntry<String, dynamic>> get entries sync* {
    for (final entry in _objs.entries) {
      if (entry.value.resolved) {
        yield MapEntry(entry.key, entry.value.data);
      }
    }
  }
}
