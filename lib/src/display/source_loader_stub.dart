// Copyright 2026. Apache License 2.0.

import 'dart:typed_data';

Future<Uint8List> loadPdfUrl(
  Uri url, {
  void Function(Map<String, int> progress)? onProgress,
}) {
  throw UnsupportedError(
    'URL loading is only built in on the web. Provide urlLoader on this '
    'platform.',
  );
}
