// Copyright 2020 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

const viewerType = 'PDF.js';
const viewerVariation = 'Full';
const viewerVersion = 21.00720099;
const formsVersion = 21.00720099;

const userActivationCallbackId = 0;
const userActivationMaxTimeValidity = 5000;

Map<String, String> serializeError(Object error, [StackTrace? stackTrace]) {
  final trace = stackTrace ?? (error is Error ? error.stackTrace : null);
  return {'command': 'error', 'value': '$error\n$trace'};
}

List<T> makeArr<T>([Object? _]) => <T>[];

Map<K, V> makeMap<K, V>([Object? _]) => <K, V>{};
