// Copyright 2025 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;

class SingleIntersector {
  SingleIntersector(this.annotation) {
    final dynamic data = annotation.data;
    final dynamic quadPoints =
        data is Map ? data['quadPoints'] : data?.quadPoints;
    if (quadPoints == null) {
      final dynamic rect = data is Map ? data['rect'] : data?.rect;
      if (rect is List) {
        minX = (rect[0] as num).toDouble();
        minY = (rect[1] as num).toDouble();
        maxX = (rect[2] as num).toDouble();
        maxY = (rect[3] as num).toDouble();
      }
      return;
    }

    final qpList = (quadPoints as List).cast<num>();
    for (var i = 0; i < qpList.length; i += 8) {
      minX = math.min(minX, qpList[i].toDouble());
      maxX = math.max(maxX, qpList[i + 2].toDouble());
      minY = math.min(minY, qpList[i + 5].toDouble());
      maxY = math.max(maxY, qpList[i + 1].toDouble());
    }
    if (qpList.length > 8) {
      _quadPoints = qpList;
    }
  }

  final dynamic annotation;
  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = -double.infinity;
  double maxY = -double.infinity;

  List<num>? _quadPoints;
  final List<String> _text = [];
  final List<String> _extraChars = [];
  int _lastIntersectingQuadIndex = -1;
  bool _canTakeExtraChars = false;

  bool _intersects(double x, double y) {
    if (minX >= x || maxX <= x || minY >= y || maxY <= y) {
      return false;
    }

    final quadPoints = _quadPoints;
    if (quadPoints == null) {
      return true;
    }

    if (_lastIntersectingQuadIndex >= 0) {
      final i = _lastIntersectingQuadIndex;
      if (!(quadPoints[i] >= x ||
          quadPoints[i + 2] <= x ||
          quadPoints[i + 5] >= y ||
          quadPoints[i + 1] <= y)) {
        return true;
      }
      _lastIntersectingQuadIndex = -1;
    }

    for (var i = 0; i < quadPoints.length; i += 8) {
      if (!(quadPoints[i] >= x ||
          quadPoints[i + 2] <= x ||
          quadPoints[i + 5] >= y ||
          quadPoints[i + 1] <= y)) {
        _lastIntersectingQuadIndex = i;
        return true;
      }
    }
    return false;
  }

  bool addGlyph(double x, double y, String glyph) {
    if (!_intersects(x, y)) {
      disableExtraChars();
      return false;
    }

    if (_extraChars.isNotEmpty) {
      _text.add(_extraChars.join(''));
      _extraChars.clear();
    }
    _text.add(glyph);
    _canTakeExtraChars = true;

    return true;
  }

  void addExtraChar(String char) {
    if (_canTakeExtraChars) {
      _extraChars.add(char);
    }
  }

  void disableExtraChars() {
    if (!_canTakeExtraChars) {
      return;
    }
    _canTakeExtraChars = false;
    _extraChars.clear();
  }

  void setText() {
    final text = _text.join('');
    final dynamic data = annotation.data;
    if (data is Map) {
      data['overlaidText'] = text;
    } else {
      try {
        data.overlaidText = text;
      } catch (_) {}
    }
  }
}

const int _steps = 64;

class Intersector {
  Intersector(List<dynamic> annotations) {
    var mX = double.infinity;
    var mY = double.infinity;
    var mxX = -double.infinity;
    var mxY = -double.infinity;

    for (final annotation in annotations) {
      final dynamic data = annotation.data;
      final dynamic qp = data is Map ? data['quadPoints'] : data?.quadPoints;
      final dynamic rect = data is Map ? data['rect'] : data?.rect;
      if (qp == null && rect == null) {
        continue;
      }
      final intersector = SingleIntersector(annotation);
      _intersectors.add(intersector);
      mX = math.min(mX, intersector.minX);
      mY = math.min(mY, intersector.minY);
      mxX = math.max(mxX, intersector.maxX);
      mxY = math.max(mxY, intersector.maxY);
    }

    minX = mX;
    minY = mY;
    maxX = mxX;
    maxY = mxY;
    _invXRatio = (_steps - 1) / (maxX - minX == 0 ? 1 : maxX - minX);
    _invYRatio = (_steps - 1) / (maxY - minY == 0 ? 1 : maxY - minY);

    for (final intersector in _intersectors) {
      final iMin = _getGridIndex(intersector.minX, intersector.minY);
      final iMax = _getGridIndex(intersector.maxX, intersector.maxY);
      final w = (iMax - iMin) % _steps;
      final h = ((iMax - iMin) / _steps).floor();
      for (var i = iMin; i <= iMin + h * _steps; i += _steps) {
        for (var j = 0; j <= w; j++) {
          final idx = i + j;
          if (idx >= 0 && idx < _grid.length) {
            _grid[idx].add(intersector);
          }
        }
      }
    }
  }

  final List<SingleIntersector> _intersectors = [];
  final List<List<SingleIntersector>> _grid =
      List.generate(_steps * _steps, (_) => <SingleIntersector>[]);

  late final double minX;
  late final double minY;
  late final double maxX;
  late final double maxY;
  late final double _invXRatio;
  late final double _invYRatio;

  int _getGridIndex(double x, double y) {
    final i = ((x - minX) * _invXRatio).floor().clamp(0, _steps - 1);
    final j = ((y - minY) * _invYRatio).floor().clamp(0, _steps - 1);
    return i + j * _steps;
  }

  void addGlyph(List<num> transform, num width, num height, String glyph) {
    final x = (transform[4] + width / 2).toDouble();
    final y = (transform[5] + height / 2).toDouble();
    if (x < minX || y < minY || x > maxX || y > maxY) {
      return;
    }
    final idx = _getGridIndex(x, y);
    final intersectors = _grid[idx];
    for (final intersector in intersectors) {
      intersector.addGlyph(x, y, glyph);
    }
  }

  void addExtraChar(String char) {
    for (final intersector in _intersectors) {
      intersector.addExtraChar(char);
    }
  }

  void setText() {
    for (final intersector in _intersectors) {
      intersector.setText();
    }
  }
}
