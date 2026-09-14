// Copyright 2017 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:pdfjs/src/core/base_stream.dart';
import 'package:pdfjs/src/core/document.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/stream.dart';

class XRefMockEntry {
  final Ref ref;
  final dynamic data;

  XRefMockEntry({required this.ref, required this.data});
}

class XRefMock {
  final Map<String, dynamic> _map = {};
  int? _newTemporaryRefNum;
  int? _newPersistentRefNum;
  BaseStream stream = NullStream();

  XRefMock([List<dynamic>? array]) {
    if (array != null) {
      for (final item in array) {
        if (item is XRefMockEntry) {
          _map[item.ref.toString()] = item.data;
        } else if (item is Map) {
          final ref = item['ref'] as Ref;
          _map[ref.toString()] = item['data'];
        }
      }
    }
  }

  Ref getNewPersistentRef([dynamic obj]) {
    _newPersistentRefNum ??= _map.length == 0 ? 1 : _map.length;
    final ref = Ref.get(_newPersistentRefNum!, 0);
    _newPersistentRefNum = _newPersistentRefNum! + 1;
    _map[ref.toString()] = obj;
    return ref;
  }

  Ref getNewTemporaryRef() {
    _newTemporaryRefNum ??= _map.length == 0 ? 1 : _map.length;
    final ref = Ref.get(_newTemporaryRefNum!, 0);
    _newTemporaryRefNum = _newTemporaryRefNum! + 1;
    return ref;
  }

  void resetNewTemporaryRef() {
    _newTemporaryRefNum = null;
  }

  dynamic fetch(dynamic ref, [bool suppressEncryption = false]) {
    return _map[ref.toString()];
  }

  Future<dynamic> fetchAsync(dynamic ref,
      [bool suppressEncryption = false]) async {
    return fetch(ref, suppressEncryption);
  }

  dynamic fetchIfRef(dynamic obj, [bool suppressEncryption = false]) {
    if (obj is Ref) {
      return fetch(obj, suppressEncryption);
    }
    return obj;
  }

  Future<dynamic> fetchIfRefAsync(dynamic obj,
      [bool suppressEncryption = false]) async {
    return fetchIfRef(obj, suppressEncryption);
  }
}
