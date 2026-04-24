// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026.
// Licensed under the Apache License, Version 2.0.

import 'dart:math' as math;

/// Clamps [v] to the range [min]..[max].
double mathClamp(double v, double min, double max) {
  return math.min(math.max(v, min), max);
}

/// Integer version of clamp.
int mathClampInt(int v, int min, int max) {
  return math.min(math.max(v, min), max);
}
