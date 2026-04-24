// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.



// Sentinelas (equivalentes a Symbol() do JS)
final Object circularRef = Object();
final Object eof = Object();

// --- Caches ---
Map<String, Cmd> _cmdCache = {};
Map<String, Name> _nameCache = {};
Map<String, Ref> _refCache = {};

void clearPrimitiveCaches() {
  _cmdCache = {};
  _nameCache = {};
  _refCache = {};
}

// --- Name ---

class Name {
  final String name;

  Name._(this.name);

  static Name get(String name) {
    return _nameCache.putIfAbsent(name, () => Name._(name));
  }

  @override
  String toString() => 'Name($name)';
}

// --- Cmd ---

class Cmd {
  final String cmd;

  Cmd._(this.cmd);

  static Cmd get(String cmd) {
    return _cmdCache.putIfAbsent(cmd, () => Cmd._(cmd));
  }

  @override
  String toString() => 'Cmd($cmd)';
}

// --- Dict ---

class Dict {
  final Map<String, dynamic> _map = {};
  String? objId;
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

  /// Automatically dereferences Ref objects.
  dynamic get(String key1, [String? key2, String? key3]) {
    return _getValue(false, key1, key2, key3);
  }

  /// Same as get(), but returns a Future.
  Future<dynamic> getAsync(String key1, [String? key2, String? key3]) async {
    return _getValue(true, key1, key2, key3);
  }

  /// Same as get(), but dereferences all elements if the result is an Array.
  dynamic getArray(String key1, [String? key2, String? key3]) {
    dynamic value = _getValue(false, key1, key2, key3);
    if (value is List) {
      value = List.from(value);
      for (int i = 0; i < value.length; i++) {
        if (value[i] is Ref && xref != null) {
          value[i] = xref.fetch(value[i], suppressEncryption);
        }
      }
    }
    return value;
  }

  /// No dereferencing.
  dynamic getRaw(String key) => _map[key];

  Iterable<String> getKeys() => _map.keys;

  Iterable<dynamic> getRawValues() => _map.values;

  Iterable<MapEntry<String, dynamic>> getRawEntries() => _map.entries;

  void set(String key, dynamic value) {
    _map[key] = value;
  }

  void setIfNotExists(String key, dynamic value) {
    if (!has(key)) set(key, value);
  }

  void setIfNumber(String key, dynamic value) {
    if (value is num) set(key, value);
  }

  void setIfArray(String key, dynamic value) {
    if (value is List) set(key, value);
  }

  void setIfDefined(String key, dynamic value) {
    if (value != null) set(key, value);
  }

  void setIfName(String key, dynamic value) {
    if (value is String) {
      set(key, Name.get(value));
    } else if (value is Name) {
      set(key, value);
    }
  }

  void setIfDict(String key, dynamic value) {
    if (value is Dict) set(key, value);
  }

  bool has(String key) => _map.containsKey(key);

  /// Iterator that dereferences Ref values.
  Iterable<MapEntry<String, dynamic>> get entries sync* {
    for (final entry in _map.entries) {
      final value = entry.value;
      yield MapEntry(
        entry.key,
        value is Ref && xref != null
            ? xref.fetch(value, suppressEncryption)
            : value,
      );
    }
  }

  static final Dict _empty = _createEmpty();

  static Dict _createEmpty() {
    final d = Dict(null);
    return d;
  }

  static Dict get empty => _empty;

  static Dict merge({
    required dynamic xref,
    required List<dynamic> dictArray,
    bool mergeSubDicts = false,
  }) {
    final mergedDict = Dict(xref);
    final properties = <String, List<dynamic>>{};

    for (final dict in dictArray) {
      if (dict is! Dict) continue;
      for (final entry in dict.getRawEntries()) {
        final key = entry.key;
        final value = entry.value;
        var property = properties[key];
        if (property == null) {
          property = [];
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
        if (dict is Dict) {
          for (final e in dict.getRawEntries()) {
            subDict.setIfNotExists(e.key, e.value);
          }
        }
      }
      if (subDict.size > 0) {
        mergedDict.set(name, subDict);
      }
    }

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

// --- Ref ---

class Ref {
  final int num;
  final int gen;

  Ref(this.num, this.gen);

  @override
  String toString() {
    if (gen == 0) return '${num}R';
    return '${num}R$gen';
  }

  static Ref? fromString(String str) {
    final ref = _refCache[str];
    if (ref != null) return ref;
    final m = RegExp(r'^(\d+)R(\d*)$').firstMatch(str);
    if (m == null || m.group(1) == '0') return null;
    final r = Ref(
      int.parse(m.group(1)!),
      m.group(2)!.isEmpty ? 0 : int.parse(m.group(2)!),
    );
    _refCache[str] = r;
    return r;
  }

  static Ref get(int num, int gen) {
    final key = gen == 0 ? '${num}R' : '${num}R$gen';
    return _refCache.putIfAbsent(key, () => Ref(num, gen));
  }
}

// --- RefSet ---

class RefSet {
  final Set<String> _set;

  RefSet([RefSet? parent]) : _set = parent != null ? Set.from(parent._set) : {};

  bool has(dynamic ref) => _set.contains(ref.toString());

  void put(dynamic ref) => _set.add(ref.toString());

  void remove(dynamic ref) => _set.remove(ref.toString());

  Iterator<String> get iterator => _set.iterator;

  void clear() => _set.clear();
}

// --- RefSetCache ---

class RefSetCache {
  final Map<String, dynamic> _map = {};

  int get size => _map.length;

  dynamic get(Ref ref) => _map[ref.toString()];

  bool has(Ref ref) => _map.containsKey(ref.toString());

  void put(Ref ref, dynamic obj) => _map[ref.toString()] = obj;

  void putAlias(Ref ref, Ref aliasRef) {
    _map[ref.toString()] = get(aliasRef);
  }

  Iterable<dynamic> get values => _map.values;

  Iterable<MapEntry<Ref?, dynamic>> get items sync* {
    for (final entry in _map.entries) {
      yield MapEntry(Ref.fromString(entry.key), entry.value);
    }
  }

  Iterable<Ref?> get keys sync* {
    for (final key in _map.keys) {
      yield Ref.fromString(key);
    }
  }

  void clear() => _map.clear();
}

// --- Helper functions ---

bool isName(dynamic v, [String? name]) {
  return v is Name && (name == null || v.name == name);
}

bool isCmd(dynamic v, [String? cmd]) {
  return v is Cmd && (cmd == null || v.cmd == cmd);
}

bool isDict(dynamic v, [String? type]) {
  return v is Dict && (type == null || isName(v.get('Type'), type));
}

bool isRefsEqual(Ref v1, Ref v2) {
  return v1.num == v2.num && v1.gen == v2.gen;
}
