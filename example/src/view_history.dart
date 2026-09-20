// Copyright 2012 Mozilla Foundation
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'viewer_storage.dart';

const int defaultViewHistoryCacheSize = 20;

/// Persists the most recent view parameters for PDF fingerprints.
final class ViewHistory {
  ViewHistory(
    this.fingerprint, {
    int cacheSize = defaultViewHistoryCacheSize,
    ViewerStorage? storage,
    this.storageKey = 'pdfjs.history',
  })  : cacheSize = cacheSize,
        storage = storage ?? createLocalViewerStorage() {
    if (cacheSize <= 0) {
      throw ArgumentError.value(cacheSize, 'cacheSize', 'must be positive');
    }
    _initialized = _initialize();
  }

  final String fingerprint;
  final int cacheSize;
  final ViewerStorage storage;
  final String storageKey;

  late final Future<void> _initialized;
  late Map<String, Object?> file;
  late Map<String, Object?> database;

  Future<void> _initialize() async {
    final databaseString = await _readFromStorage();
    final Object? decoded = jsonDecode(databaseString ?? '{}');
    database = decoded is Map ? _stringKeyedMap(decoded) : <String, Object?>{};

    final storedFiles = database['files'];
    final files = <Map<String, Object?>>[];
    if (storedFiles is List) {
      for (final candidate in storedFiles) {
        if (candidate is Map) {
          files.add(_stringKeyedMap(candidate));
        }
      }
    }
    database['files'] = files;

    while (files.length >= cacheSize) {
      files.removeAt(0);
    }

    file = files.cast<Map<String, Object?>>().firstWhere(
      (branch) => branch['fingerprint'] == fingerprint,
      orElse: () {
        final branch = <String, Object?>{'fingerprint': fingerprint};
        files.add(branch);
        return branch;
      },
    );
  }

  Future<void> _writeToStorage() {
    return storage.setItem(storageKey, jsonEncode(database));
  }

  Future<String?> _readFromStorage() => storage.getItem(storageKey);

  Future<void> set(String name, Object? value) async {
    await _initialized;
    file[name] = value;
    await _writeToStorage();
  }

  Future<void> setMultiple(Map<String, Object?> properties) async {
    await _initialized;
    file.addAll(properties);
    await _writeToStorage();
  }

  Future<Object?> get(String name, [Object? defaultValue]) async {
    await _initialized;
    return file.containsKey(name) ? file[name] : defaultValue;
  }

  Future<Map<String, Object?>> getMultiple(
    Map<String, Object?> properties,
  ) async {
    await _initialized;
    return <String, Object?>{
      for (final entry in properties.entries)
        entry.key: file.containsKey(entry.key) ? file[entry.key] : entry.value,
    };
  }

  Future<void> get initializedPromise => _initialized;
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> source) {
  return <String, Object?>{
    for (final entry in source.entries)
      if (entry.key is String) entry.key! as String: entry.value,
  };
}
