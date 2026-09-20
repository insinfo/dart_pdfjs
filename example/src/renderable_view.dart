// Copyright 2018 Mozilla Foundation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Ported from pdf.js/web/renderable_view.js.

import 'dart:async';

/// Lifecycle states shared by page and thumbnail views.
///
/// The order and integer values intentionally match the upstream PDF.js
/// constants.  Persisting the numeric value is discouraged; [RenderingState]
/// should be used directly by Dart clients.
enum RenderingState {
  initial(0),
  running(1),
  paused(2),
  finished(3);

  const RenderingState(this.value);

  final int value;

  static RenderingState fromValue(int value) => switch (value) {
        0 => initial,
        1 => running,
        2 => paused,
        3 => finished,
        _ =>
          throw ArgumentError.value(value, 'value', 'Unknown rendering state'),
      };
}

/// A renderable item managed by [PDFRenderingQueue].
///
/// This is an abstract contract rather than an instantiable base, matching the
/// runtime guard in the JavaScript implementation while making violations a
/// compile-time error in Dart.
abstract class RenderableView {
  /// Stable, unique identifier used by the rendering queue.
  String get renderingId;

  RenderingState get renderingState;

  set renderingState(RenderingState state);

  /// Continuation installed when an in-progress render is paused.
  void Function()? get resume;

  set resume(void Function()? callback);

  /// Starts drawing and completes when drawing has settled.
  Future<void> draw();
}
