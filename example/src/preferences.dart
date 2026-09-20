// Copyright 2013 Mozilla Foundation
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'app_options.dart';
import 'viewer_storage.dart';

/// Values returned by a preferences backend.
///
/// Browser preferences are accepted in addition to regular persisted
/// preferences, matching the split used by Firefox's PDF.js integration.
final class PreferenceReadResult {
  const PreferenceReadResult({
    this.browserPrefs = const <String, Object?>{},
    this.prefs = const <String, Object?>{},
  });

  final Map<String, Object?> browserPrefs;
  final Map<String, Object?> prefs;
}

abstract interface class PreferencePersistence {
  Future<PreferenceReadResult> read(Map<String, Object?> defaults);

  Future<void> write(Map<String, Object?> preferences);
}

/// JSON persistence compatible with the generic PDF.js viewer.
final class JsonPreferencePersistence implements PreferencePersistence {
  JsonPreferencePersistence({
    ViewerStorage? storage,
    this.storageKey = 'pdfjs.preferences',
  }) : storage = storage ?? createLocalViewerStorage();

  final ViewerStorage storage;
  final String storageKey;

  @override
  Future<PreferenceReadResult> read(Map<String, Object?> defaults) async {
    final encoded = await storage.getItem(storageKey);
    if (encoded == null || encoded.isEmpty) {
      return const PreferenceReadResult();
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      return const PreferenceReadResult();
    }
    return PreferenceReadResult(prefs: _stringKeyedMap(decoded));
  }

  @override
  Future<void> write(Map<String, Object?> preferences) {
    return storage.setItem(storageKey, jsonEncode(preferences));
  }
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> source) {
  return <String, Object?>{
    for (final entry in source.entries)
      if (entry.key is String) entry.key! as String: entry.value,
  };
}

/// Base class for settings applied to every opened document.
///
/// Subclasses may override [_readFromStorage] and [_writeToStorage], as the
/// JavaScript class does, or simply supply a [PreferencePersistence].
class BasePreferences {
  BasePreferences({PreferencePersistence? persistence})
      : _persistence = persistence,
        _defaults = Map<String, Object?>.unmodifiable(
          AppOptions.getAll(
            kind: OptionKind.preference,
            defaultOnly: true,
          ),
        ) {
    _initialized = _initialize();
  }

  final PreferencePersistence? _persistence;
  final Map<String, Object?> _defaults;
  late final Future<void> _initialized;

  Future<void> _initialize() async {
    final stored = await _readFromStorage(_defaults);
    if (AppOptions.checkDisablePreferences()) {
      return;
    }
    AppOptions.setAll(
      <String, Object?>{
        ...stored.browserPrefs,
        ...stored.prefs,
      },
      prefs: true,
    );
  }

  Future<void> _writeToStorage(Map<String, Object?> preferences) async {
    final persistence = _persistence;
    if (persistence == null) {
      throw UnsupportedError('Not implemented: _writeToStorage');
    }
    await persistence.write(preferences);
  }

  Future<PreferenceReadResult> _readFromStorage(
    Map<String, Object?> defaults,
  ) async {
    final persistence = _persistence;
    if (persistence == null) {
      throw UnsupportedError('Not implemented: _readFromStorage');
    }
    return persistence.read(defaults);
  }

  /// Restores all preference options and persists the full default map.
  Future<void> reset() async {
    await _initialized;
    AppOptions.setAll(_defaults, prefs: true);
    await _writeToStorage(_defaults);
  }

  /// Updates a preference when its name and type are valid.
  ///
  /// Invalid or non-preference options are ignored by [AppOptions], matching
  /// upstream, but the normalized full preferences object is still written.
  Future<void> set(String name, Object? value) async {
    await _initialized;
    AppOptions.setAll(<String, Object?>{name: value}, prefs: true);
    await _writeToStorage(
      AppOptions.getAll(kind: OptionKind.preference),
    );
  }

  Future<Object?> get(String name) async {
    await _initialized;
    return AppOptions.get(name);
  }

  Map<String, Object?> get defaults => _defaults;

  Future<void> get initializedPromise => _initialized;
}

/// Preferences used by the generic web viewer.
final class GenericPreferences extends BasePreferences {
  GenericPreferences({ViewerStorage? storage, String? storageKey})
      : super(
          persistence: JsonPreferencePersistence(
            storage: storage,
            storageKey: storageKey ?? 'pdfjs.preferences',
          ),
        );
}
