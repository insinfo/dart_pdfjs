// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import '../shared/util.dart';

abstract class BaseToUnicodeMap {
  int get length;
  void forEach(void Function(dynamic charCode, int codePoint) callback);
  bool has(int i);
  String? get(int i);
  int charCodeOf(dynamic value);
  void amend(Map<dynamic, String> map);
}

class ToUnicodeMap implements BaseToUnicodeMap {
  final dynamic _map;

  ToUnicodeMap([dynamic cmap]) : _map = cmap ?? <int, String>{};

  @override
  int get length => _map.length;

  @override
  void forEach(void Function(dynamic charCode, int codePoint) callback) {
    if (_map is Map) {
      (_map as Map).forEach((k, v) {
        if (v is String && v.isNotEmpty) {
          callback(k.toString(), v.runes.first);
        }
      });
    } else if (_map is List) {
      final list = _map as List;
      for (var i = 0; i < list.length; i++) {
        final v = list[i];
        if (v != null && v is String && v.isNotEmpty) {
          callback(i.toString(), v.runes.first);
        }
      }
    }
  }

  @override
  bool has(int i) {
    if (_map is Map) return (_map as Map).containsKey(i);
    if (_map is List) {
      final list = _map as List;
      return i >= 0 && i < list.length && list[i] != null;
    }
    return false;
  }

  @override
  String? get(int i) {
    if (_map is Map) return (_map as Map)[i] as String?;
    if (_map is List) {
      final list = _map as List;
      return (i >= 0 && i < list.length) ? list[i] as String? : null;
    }
    return null;
  }

  @override
  int charCodeOf(dynamic value) {
    if (_map is List) {
      return (_map as List).indexOf(value);
    }
    if (_map is Map) {
      for (final entry in (_map as Map).entries) {
        if (entry.value == value) {
          return entry.key is int
              ? entry.key as int
              : int.tryParse(entry.key.toString()) ?? -1;
        }
      }
    }
    return -1;
  }

  @override
  void amend(Map<dynamic, String> map) {
    if (_map is Map) {
      map.forEach((k, v) {
        (_map as Map)[k] = v;
      });
    } else if (_map is List) {
      map.forEach((k, v) {
        final idx = k is int ? k : int.tryParse(k.toString());
        if (idx != null) {
          while ((_map as List).length <= idx) {
            (_map as List).add(null);
          }
          (_map as List)[idx] = v;
        }
      });
    }
  }
}

class IdentityToUnicodeMap implements BaseToUnicodeMap {
  final int firstChar;
  final int lastChar;

  IdentityToUnicodeMap(this.firstChar, this.lastChar);

  @override
  int get length => lastChar + 1 - firstChar;

  @override
  void forEach(void Function(dynamic charCode, int codePoint) callback) {
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
  void amend(Map<dynamic, String> map) {
    unreachable("Should not call amend()");
  }
}
