// Copyright 2026 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../shared/util.dart';

String _percentage(double value) {
  return '${(value * 100).toStringAsFixed(2)}%';
}

/// Manages placeholder canvas elements that, when right-clicked on,
/// are populated with the corresponding image extracted from the PDF page.
class TextLayerImages {
  static web.HTMLCanvasElement? _activeImage;

  final List<double> _coordinates;
  final Map<web.HTMLCanvasElement, Map<String, dynamic>> _coordinatesByElement =
      {};
  final web.HTMLCanvasElement Function()? getPageCanvas;
  final double _minSize;
  final double _pageWidth;
  final double _pageHeight;

  TextLayerImages({
    required double minSize,
    required List<double> coordinates,
    required Map<String, dynamic> viewport,
    this.getPageCanvas,
  })  : _minSize = minSize,
        _coordinates = coordinates,
        _pageWidth = (viewport['rawDims'] as Map)['pageWidth'] as double,
        _pageHeight = (viewport['rawDims'] as Map)['pageHeight'] as double;

  /// Render the image placeholders and return a container element.
  web.HTMLDivElement render() {
    final container = web.document.createElement('div') as web.HTMLDivElement;
    container.className = 'textLayerImages';

    for (var i = 0; i < _coordinates.length; i += 6) {
      final coords = _coordinates.sublist(i, i + 6);
      final el = _createImagePlaceholder(coords);
      if (el != null) {
        container.append(el);
      }
    }

    container.addEventListener(
      'contextmenu',
      ((web.Event event) {
        final target = event.target;
        if (target is! web.HTMLCanvasElement) {
          return;
        }
        final coords = _coordinatesByElement[target];
        if (coords == null || identical(_activeImage, target)) {
          return;
        }

        final activeImage = _activeImage;
        if (activeImage != null) {
          activeImage.width = 0;
          activeImage.height = 0;
        }
        _activeImage = target;

        final pageCanvas = getPageCanvas?.call();
        if (pageCanvas == null) {
          return;
        }
        final x1 = coords['x1'] as double;
        final y1 = coords['y1'] as double;
        final width = coords['width'] as double;
        final height = coords['height'] as double;
        final inverseTransform = coords['inverseTransform'] as List<double>;
        final imageX1 = (x1 * pageCanvas.width).ceil();
        final imageY1 = (y1 * pageCanvas.height).ceil();
        final imageX2 = ((x1 + width / _pageWidth) * pageCanvas.width).floor();
        final imageY2 =
            ((y1 + height / _pageHeight) * pageCanvas.height).floor();

        target.width = imageX2 - imageX1;
        target.height = imageY2 - imageY1;
        final context =
            target.getContext('2d') as web.CanvasRenderingContext2D?;
        if (context == null) {
          return;
        }
        context.setTransform(
          inverseTransform[0].toJS,
          inverseTransform[1],
          inverseTransform[2],
          inverseTransform[3],
          inverseTransform[4],
          inverseTransform[5],
        );
        context.translate(-imageX1, -imageY1);
        context.drawImage(pageCanvas, 0, 0);
      }).toJS,
    );

    return container;
  }

  web.HTMLCanvasElement? _createImagePlaceholder(List<double> coords) {
    final x1 = coords[0];
    final y1 = coords[1];
    final x2 = coords[2];
    final y2 = coords[3];
    final x3 = coords[4];
    final y3 = coords[5];

    final width = math.sqrt(math.pow((x3 - x1) * _pageWidth, 2) +
        math.pow((y3 - y1) * _pageHeight, 2));
    final height = math.sqrt(math.pow((x2 - x1) * _pageWidth, 2) +
        math.pow((y2 - y1) * _pageHeight, 2));

    if (width < _minSize || height < _minSize) {
      return null;
    }

    final transform = [
      ((x3 - x1) * _pageWidth) / width,
      ((y3 - y1) * _pageHeight) / width,
      ((x2 - x1) * _pageWidth) / height,
      ((y2 - y1) * _pageHeight) / height,
      0.0,
      0.0,
    ];
    final inverseTransform =
        Util.inverseTransform(transform.map((e) => e.toDouble()).toList());

    final imgElement =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    imgElement.className = 'textLayerImagePlaceholder';
    imgElement.width = 0;
    imgElement.height = 0;
    final style = imgElement.style;
    style.opacity = '0';
    style.position = 'absolute';
    style.left = _percentage(x1);
    style.top = _percentage(y1);
    style.width = _percentage(width / _pageWidth);
    style.height = _percentage(height / _pageHeight);
    style.transformOrigin = '0% 0%';
    style.transform = 'matrix(${transform.join(",")})';

    _coordinatesByElement[imgElement] = {
      'inverseTransform': inverseTransform,
      'width': width,
      'height': height,
      'x1': x1,
      'y1': y1,
    };

    return imgElement;
  }
}
