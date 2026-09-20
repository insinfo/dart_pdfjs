// Copyright 2026
// SPDX-License-Identifier: Apache-2.0

import 'viewer_storage_stub.dart'
    if (dart.library.js_interop) 'viewer_storage_web.dart' as implementation;

/// Minimal asynchronous key/value storage used by viewer persistence classes.
///
/// Keeping this boundary independent from the DOM makes preferences and view
/// history usable in command-line tests while the web implementation still
/// delegates to the browser's Storage API.
abstract interface class ViewerStorage {
  Future<String?> getItem(String key);

  Future<void> setItem(String key, String value);

  Future<void> removeItem(String key);
}

ViewerStorage createLocalViewerStorage() =>
    implementation.createLocalViewerStorage();

ViewerStorage createSessionViewerStorage() =>
    implementation.createSessionViewerStorage();

/// In-memory implementation useful for embedders and deterministic tests.
final class MemoryViewerStorage implements ViewerStorage {
  MemoryViewerStorage([Map<String, String>? initialValues])
      : values = <String, String>{...?initialValues};

  final Map<String, String> values;

  @override
  Future<String?> getItem(String key) async => values[key];

  @override
  Future<void> setItem(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem(String key) async {
    values.remove(key);
  }
}
