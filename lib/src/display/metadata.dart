// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

class Metadata {
  final Map<String, dynamic> _map;
  final String? _data;

  Metadata({Map<String, dynamic>? parsedData, String? rawData})
      : _map = parsedData ?? const {},
        _data = rawData;

  String? getRaw() => _data;

  dynamic get(String name) => _map[name];

  bool has(String name) => _map.containsKey(name);

  Iterable<MapEntry<String, dynamic>> get entries => _map.entries;
}
