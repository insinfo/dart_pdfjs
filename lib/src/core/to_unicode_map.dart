// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import '../shared/util.dart';

abstract class BaseToUnicodeMap {
  int get length;
  void forEach(void Function(int charCode, int codePoint) callback);
  bool has(int i);
  String? get(int i);
  int charCodeOf(dynamic value);
  void amend(Map<int, String> map);
}

class ToUnicodeMap implements BaseToUnicodeMap {
  final Map<int, String> _map;

  ToUnicodeMap([Map<int, String>? cmap]) : _map = cmap ?? <int, String>{};

  @override
  int get length => _map.length;

  @override
  void forEach(void Function(int charCode, int codePoint) callback) {
    _map.forEach((charCode, value) {
      if (value.isNotEmpty) {
        callback(charCode, value.codeUnitAt(0));
      }
    });
  }

  @override
  bool has(int i) => _map.containsKey(i);

  @override
  String? get(int i) => _map[i];

  @override
  int charCodeOf(dynamic value) {
    // In JS this received string.
    for (final entry in _map.entries) {
      if (entry.value == value) {
        return entry.key;
      }
    }
    return -1;
  }

  @override
  void amend(Map<int, String> map) {
    map.forEach((charCode, value) {
      _map[charCode] = value;
    });
  }
}

class IdentityToUnicodeMap implements BaseToUnicodeMap {
  final int firstChar;
  final int lastChar;

  IdentityToUnicodeMap(this.firstChar, this.lastChar);

  @override
  int get length => lastChar + 1 - firstChar;

  @override
  void forEach(void Function(int charCode, int codePoint) callback) {
    for (int i = firstChar, ii = lastChar; i <= ii; i++) {
      callback(i, i);
    }
  }

  @override
  bool has(int i) => firstChar <= i && i <= lastChar;

  @override
  String? get(int i) {
    if (firstChar <= i && i <= lastChar) {
      return String.fromCharCode(i);
    }
    return null;
  }

  @override
  int charCodeOf(dynamic v) {
    if (v is int) {
      if (v >= firstChar && v <= lastChar) {
        return v;
      }
    } else if (v is String && v.isNotEmpty) {
      final codePoint = v.codeUnitAt(0);
      if (codePoint >= firstChar && codePoint <= lastChar) {
        return codePoint;
      }
    }
    return -1;
  }

  @override
  void amend(Map<int, String> map) {
    unreachable("Should not call amend()");
  }
}
