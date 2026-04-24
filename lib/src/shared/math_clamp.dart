// Copyright 2026 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math';

/// Retorna [v] fixado entre [min] e [max].
num mathClamp(num v, num minLimit, num maxLimit) {
  return min(max(v, minLimit), maxLimit);
}
