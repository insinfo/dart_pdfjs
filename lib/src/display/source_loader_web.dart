// Copyright 2026. Apache License 2.0.

import 'dart:typed_data';

import 'fetch_stream.dart';

Future<Uint8List> loadPdfUrl(
  Uri url, {
  void Function(Map<String, int> progress)? onProgress,
}) async {
  final stream = PDFFetchStream({'url': url});
  final reader = stream.getFullReader();
  reader.onProgress = (loaded, total) {
    onProgress?.call({'loaded': loaded, 'total': total});
  };
  final result = await reader.read();
  final value = result['value'];
  if (value is ByteBuffer) return value.asUint8List();
  if (value is Uint8List) return value;
  throw StateError('The URL loader returned no PDF data.');
}
