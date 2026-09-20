// Copyright 2026
// SPDX-License-Identifier: Apache-2.0

import 'package:web/web.dart' as web;

import 'viewer_storage.dart';

ViewerStorage createLocalViewerStorage() =>
    _WebViewerStorage(web.window.localStorage);

ViewerStorage createSessionViewerStorage() =>
    _WebViewerStorage(web.window.sessionStorage);

final class _WebViewerStorage implements ViewerStorage {
  const _WebViewerStorage(this._storage);

  final web.Storage _storage;

  @override
  Future<String?> getItem(String key) async => _storage.getItem(key);

  @override
  Future<void> setItem(String key, String value) async {
    _storage.setItem(key, value);
  }

  @override
  Future<void> removeItem(String key) async {
    _storage.removeItem(key);
  }
}
