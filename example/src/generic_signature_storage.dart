// Copyright 2025 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'event_utils.dart';
import 'viewer_storage.dart';

const signatureStorageKey = 'pdfjs.signature';

typedef UuidFactory = String Function();

/// Persistent storage for reusable signatures in the generic viewer.
class SignatureStorage {
  static const int maximumSignatures = 5;

  final EventBus? _eventBus;
  final ViewerStorage _storage;
  final UuidFactory _uuidFactory;
  StreamSubscription<String?>? _storageSubscription;
  Map<String, dynamic>? _signatures;

  SignatureStorage({
    EventBus? eventBus,
    ViewerStorage? storage,
    Stream<String?>? storageChanges,
    UuidFactory uuidFactory = _createUuid,
  })  : _eventBus = eventBus,
        _storage = storage ?? createLocalViewerStorage(),
        _uuidFactory = uuidFactory {
    _storageSubscription = storageChanges?.listen(_handleStorageChange);
  }

  Future<Map<String, dynamic>> getAll() async {
    final cached = _signatures;
    if (cached != null) return cached;

    final signatures = <String, dynamic>{};
    final serialized = await _storage.getItem(signatureStorageKey);
    if (serialized != null && serialized.isNotEmpty) {
      final decoded = jsonDecode(serialized);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          if (entry.key is String) {
            signatures[entry.key as String] = entry.value;
          }
        }
      }
    }
    return _signatures = signatures;
  }

  Future<bool> isFull() async => await size() >= maximumSignatures;

  Future<int> size() async => (await getAll()).length;

  Future<String?> create(dynamic data) async {
    final signatures = await getAll();
    if (signatures.length >= maximumSignatures) return null;

    var uuid = _uuidFactory();
    while (signatures.containsKey(uuid)) {
      uuid = _uuidFactory();
    }
    signatures[uuid] = data;
    await _save();
    return uuid;
  }

  Future<bool> delete(String uuid) async {
    final signatures = await getAll();
    if (!signatures.containsKey(uuid)) return false;
    signatures.remove(uuid);
    await _save();
    return true;
  }

  Future<void> dispose() async {
    await _storageSubscription?.cancel();
    _storageSubscription = null;
  }

  Future<void> _save() async {
    await _storage.setItem(signatureStorageKey, jsonEncode(_signatures));
  }

  void _handleStorageChange(String? key) {
    if (key != signatureStorageKey) return;
    _signatures = null;
    _eventBus?.dispatch('storedsignatureschanged', {'source': this});
  }
}

String _createUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String pair(int index) => bytes[index].toRadixString(16).padLeft(2, '0');
  String range(int start, int end) =>
      [for (var i = start; i < end; i++) pair(i)].join();
  return '${range(0, 4)}-${range(4, 6)}-${range(6, 8)}-'
      '${range(8, 10)}-${range(10, 16)}';
}
