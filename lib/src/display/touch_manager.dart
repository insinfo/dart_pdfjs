// Copyright 2024 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:web/web.dart' as web;

/// Manages touch events for pinch-to-zoom and related gestures.
class TouchManager {
  final web.Element container;
  bool _isPinching = false;
  final Function? isPinchingStopped;
  final Function? isPinchingDisabled;
  final Function? onPinchStart;
  final Function? onPinching;
  final Function? onPinchEnd;
  Map<String, double>? _touchInfo;
  bool _disposed = false;

  /// The minimum touch distance to start pinching, in CSS pixels.
  double get minTouchDistanceToPinch {
    return 35 / web.window.devicePixelRatio;
  }

  TouchManager({
    required this.container,
    this.isPinchingDisabled,
    this.isPinchingStopped,
    this.onPinchStart,
    this.onPinching,
    this.onPinchEnd,
  });

  void dispose() {
    _disposed = true;
    _touchInfo = null;
  }
}
