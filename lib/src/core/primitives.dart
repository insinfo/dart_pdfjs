// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

final Object circularRef = Object();
final Object eof = Object();

final Map<String, Cmd> _cmdCache = {};
final Map<String, Name> _nameCache = {};
final Map<String, Ref> _refCache = {};

void clearPrimitiveCaches() {
  _cmdCache.clear();
  _nameCache.clear();
  _refCache.clear();
}

class Name {
  final String name;
  const Name._(this.name);

  factory Name.get(String name) {
    return _nameCache.putIfAbsent(name, () => Name._(name));
  }
}

class Cmd {
  final String cmd;
  const Cmd._(this.cmd);

  factory Cmd.get(String cmd) {
    return _cmdCache.putIfAbsent(cmd, () => Cmd._(cmd));
  }
}

class Dict {
  final Map<String, dynamic> _map = {};
  dynamic objId;
  bool suppressEncryption = false;
  dynamic xref;

  Dict([this.xref]);

  void assignXref(dynamic newXref) {
    xref = newXref;
  }

  int get size => _map.length;

  dynamic _getValue(bool isAsync, String key1, [String? key2, String? key3]) {
    dynamic value = _map[key1];
    if (value == null && key2 != null) {
      value = _map[key2];
      if (value == null && key3 != null) {
        value = _map[key3];
      }
    }
    if (value is Ref && xref != null) {
      return isAsync
          ? xref.fetchAsync(value, suppressEncryption)
          : xref.fetch(value, suppressEncryption);
    }
    return value;
  }

  dynamic get(String key1, [String? key2, String? key3]) {
    return _getValue(false, key1, key2, key3);
  }

  Future<dynamic> getAsync(String key1, [String? key2, String? key3]) async {
    return _getValue(true, key1, key2, key3);
  }

  dynamic getArray(String key1, [String? key2, String? key3]) {
    dynamic value = _getValue(false, key1, key2, key3);
    if (value is List) {
      value = List<dynamic>.from(value);
      for (int i = 0, ii = value.length; i < ii; i++) {
        if (value[i] is Ref && xref != null) {
          value[i] = xref.fetch(value[i], suppressEncryption);
        }
      }
    }
    return value;
  }

  dynamic getRaw(String key) {
    return _map[key];
  }

  Iterable<String> getKeys() {
    return _map.keys;
  }

  Iterable<dynamic> getRawValues() {
    return _map.values;
  }

  Iterable<MapEntry<String, dynamic>> getRawEntries() {
    return _map.entries;
  }

  void set(String key, dynamic value) {
    if (value == null) {
      throw ArgumentError('Dict.set: The "value" cannot be null.');
    }
    _map[key] = value;
  }

  void setIfNotExists(String key, dynamic value) {
    if (!has(key)) {
      set(key, value);
    }
  }

  void setIfNumber(String key, dynamic value) {
    if (value is num) {
      set(key, value);
    }
  }

  void setIfArray(String key, dynamic value) {
    // ArrayBuffer isView equivalent handles by typed data lists being Lists
    if (value is List) {
      set(key, value);
    }
  }

  void setIfDefined(String key, dynamic value) {
    if (value != null) {
      set(key, value);
    }
  }

  void setIfName(String key, dynamic value) {
    if (value is String) {
      set(key, Name.get(value));
    } else if (value is Name) {
      set(key, value);
    }
  }

  void setIfDict(String key, dynamic value) {
    if (value is Dict) {
      set(key, value);
    }
  }

  bool has(String key) {
    return _map.containsKey(key);
  }

  Iterable<List<dynamic>> get iterable sync* {
    for (final entry in _map.entries) {
      yield [
        entry.key,
        (entry.value is Ref && xref != null)
            ? xref.fetch(entry.value, suppressEncryption)
            : entry.value
      ];
    }
  }

  static final Dict empty = _EmptyDict();

  static Dict merge(
      {required dynamic xref,
      required List<dynamic> dictArray,
      bool mergeSubDicts = false}) {
    final mergedDict = Dict(xref);
    final properties = <String, List<dynamic>>{};

    for (final dict in dictArray) {
      if (dict is! Dict) continue;
      for (final entry in dict.getRawEntries()) {
        final key = entry.key;
        final value = entry.value;
        var property = properties[key];
        if (property == null) {
          property = <dynamic>[];
          properties[key] = property;
        } else if (!mergeSubDicts || value is! Dict) {
          continue;
        }
        property.add(value);
      }
    }
    for (final entry in properties.entries) {
      final name = entry.key;
      final values = entry.value;
      if (values.length == 1 || values[0] is! Dict) {
        mergedDict.set(name, values[0]);
        continue;
      }
      final subDict = Dict(xref);
      for (final dict in values) {
        for (final subEntry in (dict as Dict).getRawEntries()) {
          subDict.setIfNotExists(subEntry.key, subEntry.value);
        }
      }
      if (subDict.size > 0) {
        mergedDict.set(name, subDict);
      }
    }
    properties.clear();
    return mergedDict.size > 0 ? mergedDict : Dict.empty;
  }

  Dict clone() {
    final dict = Dict(xref);
    for (final entry in _map.entries) {
      dict.set(entry.key, entry.value);
    }
    return dict;
  }

  void delete(String key) {
    _map.remove(key);
  }
}

class _EmptyDict extends Dict {
  _EmptyDict() : super(null);

  @override
  void set(String key, dynamic value) {
    throw UnsupportedError("Should not call `set` on the empty dictionary.");
  }
}

class Ref {
  final int num;
  final int gen;
  const Ref._(this.num, this.gen);

  @override
  String toString() {
    if (gen == 0) {
      return "${num}R";
    }
    return "${num}R$gen";
  }

  static Ref? fromString(String str) {
    final cached = _refCache[str];
    if (cached != null) return cached;
    final m = RegExp(r'^(\d+)R(\d*)$').firstMatch(str);
    if (m == null || m.group(1) == "0") return null;
    final numStr = m.group(1)!;
    final genStr = m.group(2);
    final ref = Ref._(int.parse(numStr),
        (genStr == null || genStr.isEmpty) ? 0 : int.parse(genStr));
    _refCache[str] = ref;
    return ref;
  }

  factory Ref.get(int num, int gen) {
    final key = gen == 0 ? "${num}R" : "${num}R$gen";
    return _refCache.putIfAbsent(key, () => Ref._(num, gen));
  }
}

class RefSet {
  final Set<String> _set;

  RefSet([RefSet? parent])
      : _set = parent != null ? Set<String>.from(parent._set) : <String>{};

  bool has(dynamic ref) {
    return _set.contains(ref.toString());
  }

  void put(dynamic ref) {
    _set.add(ref.toString());
  }

  void remove(dynamic ref) {
    _set.remove(ref.toString());
  }

  Iterable<String> get iterable => _set;

  void clear() {
    _set.clear();
  }
}

class RefSetCache {
  final Map<String, dynamic> _map = {};

  int get size => _map.length;

  dynamic get(dynamic ref) {
    return _map[ref.toString()];
  }

  bool has(dynamic ref) {
    return _map.containsKey(ref.toString());
  }

  void put(dynamic ref, dynamic obj) {
    _map[ref.toString()] = obj;
  }

  void putAlias(dynamic ref, dynamic aliasRef) {
    _map[ref.toString()] = get(aliasRef);
  }

  Iterable<dynamic> get values => _map.values;

  Iterable<List<dynamic>> get items sync* {
    for (final entry in _map.entries) {
      yield [Ref.fromString(entry.key), entry.value];
    }
  }

  Iterable<Ref?> get keys sync* {
    for (final ref in _map.keys) {
      yield Ref.fromString(ref);
    }
  }

  void clear() {
    _map.clear();
  }
}

bool isName(dynamic v, [String? name]) {
  return v is Name && (name == null || v.name == name);
}

bool isCmd(dynamic v, [String? cmd]) {
  return v is Cmd && (cmd == null || v.cmd == cmd);
}

bool isDict(dynamic v, [String? type]) {
  return v is Dict && (type == null || isName(v.get("Type"), type));
}

bool isRefsEqual(dynamic v1, dynamic v2) {
  if (v1 is! Ref || v2 is! Ref) return false;
  return v1.num == v2.num && v1.gen == v2.gen;
}
