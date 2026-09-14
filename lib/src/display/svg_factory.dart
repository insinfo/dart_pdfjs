// Copyright 2015 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:web/web.dart' as web;

import 'display_utils.dart' show SVG_NS;

/// Base class for SVG element factories.
/// Subclasses must implement [createSVGElement].
abstract class BaseSVGFactory {
  /// Create an SVG element with the given [width] and [height].
  /// If [skipDimensions] is true, width/height attributes are omitted.
  web.SVGElement create(num width, num height,
      {bool skipDimensions = false}) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Invalid SVG dimensions');
    }
    final svg = createSVGElement('svg:svg');
    svg.setAttribute('version', '1.1');

    if (!skipDimensions) {
      svg.setAttribute('width', '${width}px');
      svg.setAttribute('height', '${height}px');
    }

    svg.setAttribute('preserveAspectRatio', 'none');
    svg.setAttribute('viewBox', '0 0 $width $height');

    return svg;
  }

  /// Create an SVG element of the given [type].
  web.SVGElement createElement(String type) {
    return createSVGElement(type);
  }

  /// Abstract method to create an SVG element.
  web.SVGElement createSVGElement(String type);
}

/// DOM-based SVG factory that creates SVG elements using the web package.
class DOMSVGFactory extends BaseSVGFactory {
  @override
  web.SVGElement createSVGElement(String type) {
    return web.document.createElementNS(SVG_NS, type) as web.SVGElement;
  }
}
