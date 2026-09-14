// Copyright 2015 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../shared/util.dart';
import 'display_utils.dart';
import 'text_layer_images.dart';

const int maxTextDivsToRender = 100000;

class _TextDivProperties {
  double angle = 0;
  double canvasWidth = 0;
  bool hasText;
  bool hasEOL;
  double fontSize = 0;

  _TextDivProperties({required this.hasText, required this.hasEOL});
}

/// Builds the selectable DOM text overlay for a PDF page.
class TextLayer {
  final Map<String, dynamic> textContentSource;
  final TextLayerImages? images;
  final web.HTMLElement rootContainer;
  web.HTMLElement _container;
  PageViewport _viewport;
  final List<web.HTMLElement> _textDivs = [];
  final List<String> _textContentItemsStr = [];
  final Map<String, dynamic> _styleCache = {};
  final Map<web.HTMLElement, _TextDivProperties> _properties = {};
  bool _cancelled = false;
  bool _rendered = false;
  bool _disableProcessItems = false;

  TextLayer({
    required this.textContentSource,
    required web.HTMLElement container,
    required PageViewport viewport,
    this.images,
  })  : rootContainer = container,
        _container = container,
        _viewport = viewport {
    _setDimensions(container, viewport);
  }

  List<web.HTMLElement> get textDivs => List.unmodifiable(_textDivs);
  List<String> get textContentItemsStr =>
      List.unmodifiable(_textContentItemsStr);
  double get pageWidth => _viewport.rawDims.pageWidth;
  double get pageHeight => _viewport.rawDims.pageHeight;

  Future<void> render() async {
    if (_rendered) {
      throw StateError('TextLayer.render can only be called once.');
    }
    _rendered = true;
    if (_cancelled) return;
    if (images != null) {
      _container.append(images!.render());
    }
    final styles = textContentSource['styles'];
    if (styles is Map) {
      for (final entry in styles.entries) {
        _styleCache[entry.key.toString()] = entry.value;
      }
    }
    final items = textContentSource['items'];
    if (items is List) {
      _processItems(items);
    }
  }

  void cancel() {
    _cancelled = true;
  }

  void update({required PageViewport viewport, void Function()? onBefore}) {
    if (viewport.rotation != _viewport.rotation) {
      onBefore?.call();
      _setDimensions(rootContainer, viewport);
    }
    if (viewport.scale != _viewport.scale) {
      onBefore?.call();
      _viewport = viewport;
      for (final div in _textDivs) {
        _layout(div, _properties[div]!);
      }
    } else {
      _viewport = viewport;
    }
  }

  void _processItems(List<dynamic> items) {
    if (_disableProcessItems || _cancelled) return;
    for (final rawItem in items) {
      if (_textDivs.length > maxTextDivsToRender) {
        warn('Ignoring additional textDivs for performance reasons.');
        _disableProcessItems = true;
        return;
      }
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      if (!item.containsKey('str')) {
        _processMarker(item);
        continue;
      }
      final text = item['str']?.toString() ?? '';
      _textContentItemsStr.add(text);
      _appendText(item, text);
    }
  }

  void _processMarker(Map<String, dynamic> item) {
    switch (item['type']) {
      case 'beginMarkedContentProps':
      case 'beginMarkedContent':
        final parent = _container;
        final span = web.document.createElement('span') as web.HTMLSpanElement;
        span.classList.add('markedContent');
        if (item['id'] != null) span.id = item['id'].toString();
        if (item['tag'] == 'Artifact') span.setAttribute('aria-hidden', 'true');
        parent.append(span);
        _container = span;
        break;
      case 'endMarkedContent':
        final parent = _container.parentElement;
        if (parent is web.HTMLElement) _container = parent;
        break;
    }
  }

  void _appendText(Map<String, dynamic> geom, String text) {
    final div = web.document.createElement('span') as web.HTMLSpanElement;
    final properties = _TextDivProperties(
      hasText: text.isNotEmpty,
      hasEOL: geom['hasEOL'] == true,
    );
    _textDivs.add(div);

    final transform = (geom['transform'] as List)
        .map((value) => (value as num).toDouble())
        .toList();
    final dims = _viewport.rawDims;
    final pageTransform = <double>[
      1,
      0,
      0,
      -1,
      -dims.pageX,
      dims.pageY + dims.pageHeight,
    ];
    final tx = Util.transform(pageTransform, transform);
    final style = _styleCache[geom['fontName']] is Map
        ? _styleCache[geom['fontName']] as Map
        : const {};
    var angle = math.atan2(tx[1], tx[0]);
    if (style['vertical'] == true) angle += math.pi / 2;
    final fontFamily = style['fontFamily']?.toString() ?? 'sans-serif';
    final fontHeight = math.sqrt(tx[2] * tx[2] + tx[3] * tx[3]);
    final ascent = style['ascent'] is num
        ? (style['ascent'] as num).toDouble()
        : style['descent'] is num
            ? 1 + (style['descent'] as num).toDouble()
            : 0.8;
    final fontAscent = fontHeight * ascent;
    final left = angle == 0 ? tx[4] : tx[4] + fontAscent * math.sin(angle);
    final top =
        angle == 0 ? tx[5] - fontAscent : tx[5] - fontAscent * math.cos(angle);

    div.style.left = '${(100 * left / dims.pageWidth).toStringAsFixed(2)}%';
    div.style.top = '${(100 * top / dims.pageHeight).toStringAsFixed(2)}%';
    div.style
        .setProperty('--font-height', '${fontHeight.toStringAsFixed(2)}px');
    div.style.fontFamily = fontFamily;
    div.setAttribute('role', 'presentation');
    div.textContent = text;
    div.dir = geom['dir']?.toString() ?? 'ltr';
    properties.fontSize = fontHeight;
    if (angle != 0) properties.angle = angle * 180 / math.pi;
    if (text.length > 1) {
      properties.canvasWidth =
          ((style['vertical'] == true ? geom['height'] : geom['width']) as num?)
                  ?.toDouble() ??
              0;
    }
    _properties[div] = properties;
    _layout(div, properties);
    if (properties.hasText) _container.append(div);
    if (properties.hasEOL) {
      final br = web.document.createElement('br');
      br.setAttribute('role', 'presentation');
      _container.append(br);
    }
  }

  void _layout(web.HTMLElement div, _TextDivProperties properties) {
    if (properties.canvasWidth != 0 && properties.hasText) {
      final canvas =
          web.document.createElement('canvas') as web.HTMLCanvasElement;
      final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
      if (context != null) {
        context.font =
            '${properties.fontSize * _viewport.scale}px ${div.style.fontFamily}';
        final width = context.measureText(div.textContent ?? '').width;
        if (width > 0) {
          div.style.setProperty(
            '--scale-x',
            '${properties.canvasWidth * _viewport.scale / width}',
          );
        }
      }
    }
    if (properties.angle != 0) {
      div.style.setProperty('--rotate', '${properties.angle}deg');
    }
  }

  static void cleanup() {}

  static void _setDimensions(web.HTMLElement container, PageViewport viewport) {
    final dims = viewport.rawDims;
    container.style.width =
        'calc(var(--total-scale-factor) * ${dims.pageWidth}px)';
    container.style.height =
        'calc(var(--total-scale-factor) * ${dims.pageHeight}px)';
    container.setAttribute('data-main-rotation', '${viewport.rotation}');
  }
}
