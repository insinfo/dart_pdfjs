// Copyright 2023 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:web/web.dart' as web;
import 'dart:js_interop';

import 'svg_factory.dart';

/// Manage the SVGs drawn on top of the page canvas.
/// It's important to have them directly on top of the canvas because we want to
/// be able to use mix-blend-mode for some of them.
class DrawLayer {
  web.Element? _parent;
  final Map<int, web.SVGElement> _mapping = {};
  final Map<int, web.Element> _toUpdate = {};

  static int _nextId = 0;
  static final DOMSVGFactory _svgFactory = DOMSVGFactory();

  void setParent(web.Element parent) {
    if (_parent == null) {
      _parent = parent;
      return;
    }

    if (_parent != parent) {
      if (_mapping.isNotEmpty) {
        for (final root in _mapping.values) {
          root.remove();
          parent.append(root);
        }
      }
      _parent = parent;
    }
  }

  static void _setBox(web.Element element, List<num> box) {
    final x = box[0];
    final y = box[1];
    final width = box[2];
    final height = box[3];
    final style = (element as web.HTMLElement).style;
    style.top = '${100 * y}%';
    style.left = '${100 * x}%';
    style.width = '${100 * width}%';
    style.height = '${100 * height}%';
  }

  web.SVGElement _createSVG() {
    final svg = _svgFactory.create(1, 1, skipDimensions: true);
    _parent!.append(svg);
    svg.setAttribute('aria-hidden', 'true');
    return svg;
  }

  String _createClipPath(web.Element defs, String pathId) {
    final clipPath = _svgFactory.createElement('clipPath');
    defs.append(clipPath);
    final clipPathId = 'clip_$pathId';
    clipPath.setAttribute('id', clipPathId);
    clipPath.setAttribute('clipPathUnits', 'objectBoundingBox');
    final clipPathUse = _svgFactory.createElement('use');
    clipPath.append(clipPathUse);
    clipPathUse.setAttribute('href', '#$pathId');
    clipPathUse.classList.add('clip');
    return clipPathId;
  }

  void _updatePropertiesOnElement(
      web.Element element, Map<String, String?> properties) {
    for (final entry in properties.entries) {
      if (entry.value == null) {
        element.removeAttribute(entry.key);
      } else {
        element.setAttribute(entry.key, entry.value!);
      }
    }
  }

  /// Draw an SVG path with the given properties.
  Map<String, dynamic> draw(Map<String, dynamic>? properties,
      {bool isPathUpdatable = false, bool hasClip = false}) {
    final id = _nextId++;
    final root = _createSVG();

    final defs = _svgFactory.createElement('defs');
    root.append(defs);
    final path = _svgFactory.createElement('path');
    defs.append(path);
    final pathId = 'path_$id';
    path.setAttribute('id', pathId);
    path.setAttribute('vector-effect', 'non-scaling-stroke');

    if (isPathUpdatable) {
      _toUpdate[id] = path;
    }

    final clipPathId = hasClip ? _createClipPath(defs, pathId) : null;

    final use = _svgFactory.createElement('use');
    root.append(use);
    use.setAttribute('href', '#$pathId');
    updateProperties(root, properties);

    _mapping[id] = root;

    return {
      'id': id,
      'clipPathId': 'url(#$clipPathId)',
    };
  }

  /// Draw an outline SVG, optionally removing self-intersections with a mask.
  int drawOutline(
      Map<String, dynamic>? properties, bool mustRemoveSelfIntersections) {
    final id = _nextId++;
    final root = _createSVG();
    final defs = _svgFactory.createElement('defs');
    root.append(defs);
    final path = _svgFactory.createElement('path');
    defs.append(path);
    final pathId = 'path_$id';
    path.setAttribute('id', pathId);
    path.setAttribute('vector-effect', 'non-scaling-stroke');

    String? maskId;
    if (mustRemoveSelfIntersections) {
      final mask = _svgFactory.createElement('mask');
      defs.append(mask);
      maskId = 'mask_$id';
      mask.setAttribute('id', maskId);
      mask.setAttribute('maskUnits', 'objectBoundingBox');
      final rect = _svgFactory.createElement('rect');
      mask.append(rect);
      rect.setAttribute('width', '1');
      rect.setAttribute('height', '1');
      rect.setAttribute('fill', 'white');
      final maskUse = _svgFactory.createElement('use');
      mask.append(maskUse);
      maskUse.setAttribute('href', '#$pathId');
      maskUse.setAttribute('stroke', 'none');
      maskUse.setAttribute('fill', 'black');
      maskUse.setAttribute('fill-rule', 'nonzero');
      maskUse.classList.add('mask');
    }

    final use1 = _svgFactory.createElement('use');
    root.append(use1);
    use1.setAttribute('href', '#$pathId');
    if (maskId != null) {
      use1.setAttribute('mask', 'url(#$maskId)');
    }
    final use2 = use1.cloneNode(false) as web.SVGElement;
    root.append(use2);
    use1.classList.add('mainOutline');
    use2.classList.add('secondaryOutline');

    updateProperties(root, properties);

    _mapping[id] = root;

    return id;
  }

  void finalizeDraw(int id, Map<String, dynamic>? properties) {
    _toUpdate.remove(id);
    updateProperties(id, properties);
  }

  void updateProperties(dynamic elementOrId, Map<String, dynamic>? properties) {
    if (properties == null) {
      return;
    }
    final rootProps = properties['root'] as Map<String, String?>?;
    final bbox = properties['bbox'] as List<num>?;
    final rootClass = properties['rootClass'] as Map<String, bool>?;
    final pathProps = properties['path'] as Map<String, String?>?;

    web.Element? element;
    if (elementOrId is int) {
      element = _mapping[elementOrId];
    } else if (elementOrId is web.Element) {
      element = elementOrId;
    }
    if (element == null) return;

    if (rootProps != null) {
      _updatePropertiesOnElement(element, rootProps);
    }
    if (bbox != null) {
      _setBox(element, bbox);
    }
    if (rootClass != null) {
      for (final entry in rootClass.entries) {
        element.classList.toggle(entry.key, entry.value);
      }
    }
    if (pathProps != null) {
      final defs = element.firstElementChild;
      final pathElement = defs?.firstElementChild;
      if (pathElement != null) {
        _updatePropertiesOnElement(pathElement, pathProps);
      }
    }
  }

  void updateParent(int id, DrawLayer layer) {
    if (identical(layer, this)) {
      return;
    }
    final root = _mapping[id];
    if (root == null) {
      return;
    }
    layer._parent!.append(root);
    _mapping.remove(id);
    layer._mapping[id] = root;
  }

  void remove(int id) {
    _toUpdate.remove(id);
    if (_parent == null) {
      return;
    }
    _mapping[id]?.remove();
    _mapping.remove(id);
  }

  void destroy() {
    _parent = null;
    for (final root in _mapping.values) {
      root.remove();
    }
    _mapping.clear();
    _toUpdate.clear();
  }
}
