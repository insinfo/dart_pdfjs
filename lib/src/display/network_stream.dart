// Copyright 2026 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'display_utils.dart';
import 'fetch_stream.dart';
import 'network.dart';

/// Get the appropriate network stream class for the given URL.
/// In Dart web context, always returns PDFFetchStream.
Type getNetworkStream(dynamic url) {
  if (isValidFetchUrl(url)) {
    return PDFFetchStream;
  }
  return PDFNetworkStream;
}
