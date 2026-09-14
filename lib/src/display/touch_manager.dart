// Copyright 2024 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

/// Immutable representation of the browser touch data used by pinch gestures.
///
/// Keeping this value independent from [web.Touch] makes the gesture state
/// machine deterministic and directly testable.
class TouchPoint {
  final int identifier;
  final double screenX;
  final double screenY;

  const TouchPoint(this.identifier, this.screenX, this.screenY);
}

/// Describes one accepted pinch movement.
class PinchUpdate {
  final List<double> origin;
  final double previousDistance;
  final double distance;

  const PinchUpdate({
    required this.origin,
    required this.previousDistance,
    required this.distance,
  });
}

typedef PinchPredicate = bool Function();
typedef PinchCallback = void Function();
typedef PinchingCallback = void Function(
  List<double> origin,
  double previousDistance,
  double distance,
);

/// Manages browser touch events for pinch-to-zoom gestures.
///
/// This follows PDF.js' touch manager semantics: a two-finger gesture is
/// captured immediately, but zoom updates only begin after the fingers move
/// farther than [minTouchDistanceToPinch].
class TouchManager {
  final web.Element container;
  final PinchPredicate? isPinchingStopped;
  final PinchPredicate? isPinchingDisabled;
  final PinchCallback? onPinchStart;
  final PinchingCallback? onPinching;
  final PinchCallback? onPinchEnd;

  late final JSFunction _touchStartListener;
  late final JSFunction _touchMoveListener;
  late final JSFunction _touchEndListener;

  bool _isPinching = false;
  bool _tracking = false;
  bool _moveListenersAttached = false;
  bool _disposed = false;
  List<TouchPoint>? _touchInfo;

  TouchManager({
    required this.container,
    this.isPinchingDisabled,
    this.isPinchingStopped,
    this.onPinchStart,
    this.onPinching,
    this.onPinchEnd,
  }) {
    _touchStartListener = ((web.Event event) {
      final touchEvent = event as web.TouchEvent;
      final points = _readTouches(touchEvent.touches);
      if (handleTouchStart(points)) {
        _stopEvent(touchEvent);
        _attachMoveListeners();
      }
    }).toJS;
    _touchMoveListener = ((web.Event event) {
      final touchEvent = event as web.TouchEvent;
      final shouldConsume = _touchInfo != null && touchEvent.touches.length == 2;
      handleTouchMove(_readTouches(touchEvent.touches));
      if (shouldConsume) {
        _stopEvent(touchEvent);
      }
    }).toJS;
    _touchEndListener = ((web.Event event) {
      final touchEvent = event as web.TouchEvent;
      final hadTouchInfo = _touchInfo != null;
      final ended = handleTouchEnd(touchEvent.touches.length);
      if (ended) {
        _detachMoveListeners();
        if (hadTouchInfo) {
          _stopEvent(touchEvent);
        }
      }
    }).toJS;

    container.addEventListener('touchstart', _touchStartListener);
  }

  /// The minimum distance change needed to recognize a pinch, in CSS pixels.
  ///
  /// This is calculated on every access because the device pixel ratio can
  /// change when the browser window moves between screens.
  double get minTouchDistanceToPinch => 35 / web.window.devicePixelRatio;

  bool get isPinching => _isPinching;
  bool get isDisposed => _disposed;

  /// Starts or refreshes gesture tracking. Returns whether the browser event
  /// must be consumed.
  bool handleTouchStart(List<TouchPoint> touches) {
    if (_disposed || (isPinchingDisabled?.call() ?? false)) {
      return false;
    }
    if (touches.length < 2) {
      return false;
    }

    if (!_tracking) {
      _tracking = true;
      onPinchStart?.call();
    }

    if (touches.length != 2 || (isPinchingStopped?.call() ?? false)) {
      _touchInfo = null;
      return true;
    }
    _touchInfo = _orderedTouches(touches);
    return true;
  }

  /// Advances the gesture and returns a zoom update once pinching is active.
  ///
  /// The first movement beyond the threshold only activates pinching, exactly
  /// like PDF.js, which prevents the initial zoom step from being too large.
  PinchUpdate? handleTouchMove(List<TouchPoint> touches) {
    final previous = _touchInfo;
    if (_disposed || previous == null || touches.length != 2) {
      return null;
    }

    final current = _orderedTouches(touches);
    final previousDistance = _distance(previous[0], previous[1]);
    final distance = _distance(current[0], current[1]);
    if (!_isPinching &&
        (previousDistance - distance).abs() <= minTouchDistanceToPinch) {
      return null;
    }

    _touchInfo = current;
    if (!_isPinching) {
      _isPinching = true;
      return null;
    }

    final update = PinchUpdate(
      origin: [
        (current[0].screenX + current[1].screenX) / 2,
        (current[0].screenY + current[1].screenY) / 2,
      ],
      previousDistance: previousDistance,
      distance: distance,
    );
    onPinching?.call(
      update.origin,
      update.previousDistance,
      update.distance,
    );
    return update;
  }

  /// Ends tracking after fewer than two touches remain.
  bool handleTouchEnd(int remainingTouches) {
    if (_disposed || remainingTouches >= 2) {
      return false;
    }
    if (_tracking) {
      _tracking = false;
      onPinchEnd?.call();
    }
    _touchInfo = null;
    _isPinching = false;
    return true;
  }

  void _attachMoveListeners() {
    if (_moveListenersAttached || _disposed) {
      return;
    }
    _moveListenersAttached = true;
    container
      ..addEventListener('touchmove', _touchMoveListener)
      ..addEventListener('touchend', _touchEndListener)
      ..addEventListener('touchcancel', _touchEndListener);
  }

  void _detachMoveListeners() {
    if (!_moveListenersAttached) {
      return;
    }
    _moveListenersAttached = false;
    container
      ..removeEventListener('touchmove', _touchMoveListener)
      ..removeEventListener('touchend', _touchEndListener)
      ..removeEventListener('touchcancel', _touchEndListener);
  }

  static List<TouchPoint> _readTouches(web.TouchList touches) {
    return [
      for (var i = 0; i < touches.length; i++)
        if (touches.item(i) case final touch?)
          TouchPoint(
            touch.identifier,
            touch.screenX.toDouble(),
            touch.screenY.toDouble(),
          ),
    ];
  }

  static List<TouchPoint> _orderedTouches(List<TouchPoint> touches) {
    final first = touches[0];
    final second = touches[1];
    return first.identifier <= second.identifier
        ? [first, second]
        : [second, first];
  }

  static double _distance(TouchPoint first, TouchPoint second) {
    final distance = math.sqrt(
      math.pow(second.screenX - first.screenX, 2) +
          math.pow(second.screenY - first.screenY, 2),
    );
    return distance == 0 ? 1 : distance;
  }

  static void _stopEvent(web.Event event) {
    event
      ..preventDefault()
      ..stopPropagation();
  }

  /// Removes every DOM listener owned by this manager.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    container.removeEventListener('touchstart', _touchStartListener);
    _detachMoveListeners();
    _tracking = false;
    _isPinching = false;
    _touchInfo = null;
  }

  /// PDF.js-compatible lifecycle alias.
  void destroy() => dispose();
}
