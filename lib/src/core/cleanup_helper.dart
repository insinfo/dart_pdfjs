// Copyright 2022 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'primitives.dart';
import 'unicode.dart';

void clearGlobalCaches() {
  clearPrimitiveCaches();
  clearUnicodeCaches();
}
