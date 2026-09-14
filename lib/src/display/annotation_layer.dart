// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../shared/util.dart';
import 'annotation_storage.dart';
import 'display_utils.dart';

/// Navigation hooks used by link annotations.
abstract interface class AnnotationLinkService {
  void navigateTo(dynamic destination);
  void executeNamedAction(String action);
}

class AnnotationLayerParameters {
  final List<Map<String, dynamic>> annotations;
  final bool renderForms;
  final String imageResourcesPath;

  const AnnotationLayerParameters({
    required this.annotations,
    this.renderForms = true,
    this.imageResourcesPath = '',
  });
}

class AnnotationElementParameters {
  final Map<String, dynamic> data;
  final AnnotationLayer parent;
  final bool renderForms;
  final String imageResourcesPath;

  const AnnotationElementParameters({
    required this.data,
    required this.parent,
    required this.renderForms,
    required this.imageResourcesPath,
  });
}

class AnnotationElementFactory {
  static AnnotationElement create(AnnotationElementParameters parameters) {
    final data = parameters.data;
    return switch (_integer(data['annotationType'])) {
      AnnotationType.link => LinkAnnotationElement(parameters),
      AnnotationType.text => TextAnnotationElement(parameters),
      AnnotationType.widget => _createWidget(parameters),
      AnnotationType.popup => PopupAnnotationElement(parameters),
      AnnotationType.freetext => FreeTextAnnotationElement(parameters),
      AnnotationType.line => LineAnnotationElement(parameters),
      AnnotationType.square => SquareAnnotationElement(parameters),
      AnnotationType.circle => CircleAnnotationElement(parameters),
      AnnotationType.polyline => PolylineAnnotationElement(parameters),
      AnnotationType.polygon => PolygonAnnotationElement(parameters),
      AnnotationType.ink => InkAnnotationElement(parameters),
      AnnotationType.highlight => HighlightAnnotationElement(parameters),
      AnnotationType.underline => UnderlineAnnotationElement(parameters),
      AnnotationType.squiggly => SquigglyAnnotationElement(parameters),
      AnnotationType.strikeout => StrikeOutAnnotationElement(parameters),
      AnnotationType.stamp => StampAnnotationElement(parameters),
      AnnotationType.fileattachment =>
        FileAttachmentAnnotationElement(parameters),
      _ => AnnotationElement(parameters),
    };
  }

  static AnnotationElement _createWidget(
    AnnotationElementParameters parameters,
  ) {
    final data = parameters.data;
    final fieldType = data['fieldType']?.toString();
    if (fieldType == 'Tx' ||
        data.containsKey('multiLine') ||
        data.containsKey('maxLen')) {
      return TextWidgetAnnotationElement(parameters);
    }
    if (fieldType == 'Ch' || data.containsKey('options')) {
      return ChoiceWidgetAnnotationElement(parameters);
    }
    if (fieldType == 'Btn' ||
        data['checkBox'] == true ||
        data['radioButton'] == true ||
        data['pushButton'] == true) {
      if (data['pushButton'] == true) {
        return PushButtonWidgetAnnotationElement(parameters);
      }
      return ButtonWidgetAnnotationElement(parameters);
    }
    return WidgetAnnotationElement(parameters);
  }
}

int _integer(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;
double _number(dynamic value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;
List<num> _numbers(dynamic value) =>
    value is List ? value.whereType<num>().toList() : const [];
String _text(dynamic value) {
  if (value is Map && value['str'] != null) return value['str'].toString();
  return value?.toString() ?? '';
}

String _cssNumber(num value) =>
    value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

class AnnotationElement {
  final AnnotationElementParameters parameters;
  late final Map<String, dynamic> data = parameters.data;
  late final web.HTMLElement container = _createContainer();
  web.Element? contentElement;
  bool get isRenderable => false;

  AnnotationElement(this.parameters);

  AnnotationLayer get parent => parameters.parent;
  AnnotationStorage get annotationStorage => parent.annotationStorage;

  web.HTMLElement _createContainer() {
    final section = web.document.createElement('section') as web.HTMLElement;
    section.className = 'annotation';
    section.setAttribute('data-annotation-id', data['id']?.toString() ?? '');
    section.style.position = 'absolute';
    section.style.zIndex = '${parent.nextZIndex()}';
    if (data['hidden'] == true) section.style.visibility = 'hidden';
    if (data['alternativeText'] != null) {
      section.title = data['alternativeText'].toString();
    }
    _position(section);
    _border(section);
    return section;
  }

  void _position(web.HTMLElement element) {
    final rect = _numbers(data['rect']);
    if (rect.length != 4) return;
    final dims = parent.viewport.rawDims;
    final left = 100 * (rect[0] - dims.pageX) / dims.pageWidth;
    final top =
        100 * (dims.pageY + dims.pageHeight - rect[3]) / dims.pageHeight;
    final width = 100 * (rect[2] - rect[0]) / dims.pageWidth;
    final height = 100 * (rect[3] - rect[1]) / dims.pageHeight;
    element.style
      ..left = '${_cssNumber(left)}%'
      ..top = '${_cssNumber(top)}%'
      ..width = '${_cssNumber(width)}%'
      ..height = '${_cssNumber(height)}%';
  }

  void _border(web.HTMLElement element) {
    final border = data['borderStyle'];
    if (border is! Map) return;
    final width = _number(border['width']);
    if (width <= 0) return;
    final color = _numbers(data['color']);
    element.style.borderWidth = '${_cssNumber(width)}px';
    element.style.borderStyle = switch (_integer(border['style'], 1)) {
      AnnotationBorderStyleType.dashed => 'dashed',
      AnnotationBorderStyleType.underline => 'none none solid none',
      _ => 'solid',
    };
    if (color.length >= 3) {
      element.style.borderColor =
          'rgb(${_integer(color[0])}, ${_integer(color[1])}, ${_integer(color[2])})';
    }
  }

  web.HTMLElement render() => container;

  void update(PageViewport viewport) => _position(container);
}

class LinkAnnotationElement extends AnnotationElement {
  LinkAnnotationElement(super.parameters);
  @override
  bool get isRenderable =>
      data['url'] != null ||
      data['destination'] != null ||
      data['action'] != null;

  @override
  web.HTMLElement render() {
    container.classList.add('linkAnnotation');
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    final url = data['url']?.toString();
    if (url != null && url.isNotEmpty) {
      anchor.href = url;
      anchor.target = '_blank';
      anchor.rel = 'noopener noreferrer nofollow';
    } else {
      anchor.href = '#';
      anchor.addEventListener(
        'click',
        ((web.Event event) {
          event.preventDefault();
          if (data['destination'] != null) {
            parent.linkService?.navigateTo(data['destination']);
          } else if (data['action'] != null) {
            parent.linkService?.executeNamedAction(data['action'].toString());
          }
        }).toJS,
      );
    }
    anchor.setAttribute(
        'aria-label', data['alternativeText']?.toString() ?? 'PDF link');
    contentElement = anchor;
    container.append(anchor);
    return container;
  }
}

class TextAnnotationElement extends AnnotationElement {
  TextAnnotationElement(super.parameters);
  @override
  bool get isRenderable => true;

  @override
  web.HTMLElement render() {
    container.classList.add('textAnnotation');
    final button =
        web.document.createElement('button') as web.HTMLButtonElement;
    button.type = 'button';
    button.className = 'annotationIcon';
    final name = data['name']?.toString() ?? 'Note';
    button.setAttribute('aria-label', name);
    button.title = name;
    final popup = _createPopup(data);
    button.addEventListener(
      'click',
      ((web.Event event) {
        event.preventDefault();
        if (popup.hasAttribute('hidden')) {
          popup.removeAttribute('hidden');
        } else {
          popup.setAttribute('hidden', '');
        }
      }).toJS,
    );
    contentElement = button;
    container
      ..append(button)
      ..append(popup);
    if (data['open'] == true) popup.removeAttribute('hidden');
    return container;
  }
}

web.HTMLDivElement _createPopup(Map<String, dynamic> data) {
  final popup = web.document.createElement('div') as web.HTMLDivElement;
  popup.className = 'popupWrapper';
  popup.setAttribute('hidden', '');
  popup.setAttribute('role', 'dialog');
  final title = web.document.createElement('h1') as web.HTMLHeadingElement;
  title.textContent = _text(data['title'] ?? data['titleObj']);
  final contents = web.document.createElement('p') as web.HTMLParagraphElement;
  contents.textContent = _text(data['contents'] ?? data['contentsObj']);
  popup
    ..append(title)
    ..append(contents);
  return popup;
}

class PopupAnnotationElement extends AnnotationElement {
  PopupAnnotationElement(super.parameters);
  @override
  bool get isRenderable =>
      _text(data['contents'] ?? data['contentsObj']).isNotEmpty;

  @override
  web.HTMLElement render() {
    container.classList.add('popupAnnotation');
    final popup = _createPopup(data)..removeAttribute('hidden');
    contentElement = popup;
    container.append(popup);
    return container;
  }
}

class WidgetAnnotationElement extends AnnotationElement {
  WidgetAnnotationElement(super.parameters);
  @override
  bool get isRenderable => parameters.renderForms;

  dynamic get storedValue => annotationStorage.getValue(
        data['id'].toString(),
        {'value': data['fieldValue'] ?? ''},
      );

  void store(dynamic value) {
    annotationStorage.setValue(data['id'].toString(), {'value': value});
  }

  T configure<T extends web.HTMLElement>(T control) {
    control.classList.add('widgetAnnotation');
    control.title = data['alternativeText']?.toString() ?? '';
    final fieldName = data['fieldName']?.toString() ?? '';
    if (fieldName.isNotEmpty) control.setAttribute('name', fieldName);
    if (data['readOnly'] == true) control.setAttribute('disabled', 'disabled');
    if (data['required'] == true) control.setAttribute('required', 'required');
    contentElement = control;
    container
      ..classList.add('widgetAnnotation')
      ..append(control);
    return control;
  }
}

class TextWidgetAnnotationElement extends WidgetAnnotationElement {
  TextWidgetAnnotationElement(super.parameters);

  @override
  web.HTMLElement render() {
    final value =
        storedValue is Map ? storedValue['value'] : data['fieldValue'];
    if (data['multiLine'] == true) {
      final input = configure(
        web.document.createElement('textarea') as web.HTMLTextAreaElement,
      );
      input.value = value?.toString() ?? '';
      input.addEventListener(
        'input',
        ((web.Event event) => store(input.value)).toJS,
      );
      return container;
    }
    final input = configure(
      web.document.createElement('input') as web.HTMLInputElement,
    );
    input.type = data['password'] == true ? 'password' : 'text';
    input.value = value?.toString() ?? '';
    final maxLen = _integer(data['maxLen']);
    if (maxLen > 0) input.maxLength = maxLen;
    input.addEventListener(
      'input',
      ((web.Event event) => store(input.value)).toJS,
    );
    return container;
  }
}

class ButtonWidgetAnnotationElement extends WidgetAnnotationElement {
  ButtonWidgetAnnotationElement(super.parameters);

  @override
  web.HTMLElement render() {
    final input = configure(
      web.document.createElement('input') as web.HTMLInputElement,
    );
    input.type = data['radioButton'] == true ? 'radio' : 'checkbox';
    final value =
        storedValue is Map ? storedValue['value'] : data['fieldValue'];
    final exportValue = data['exportValue']?.toString() ?? 'Yes';
    input.value = exportValue;
    input.checked = value == true || value?.toString() == exportValue;
    input.addEventListener(
      'change',
      ((web.Event event) {
        store(input.checked ? exportValue : 'Off');
      }).toJS,
    );
    return container;
  }
}

class PushButtonWidgetAnnotationElement extends LinkAnnotationElement {
  PushButtonWidgetAnnotationElement(super.parameters);
  @override
  bool get isRenderable => true;

  @override
  web.HTMLElement render() {
    container.classList.add('buttonWidgetAnnotation');
    final button =
        web.document.createElement('button') as web.HTMLButtonElement;
    button.type = 'button';
    button.textContent = data['alternativeText']?.toString() ??
        data['fieldValue']?.toString() ??
        '';
    button.addEventListener(
      'click',
      ((web.Event event) {
        if (data['destination'] != null) {
          parent.linkService?.navigateTo(data['destination']);
        } else if (data['action'] != null) {
          parent.linkService?.executeNamedAction(data['action'].toString());
        }
      }).toJS,
    );
    contentElement = button;
    container.append(button);
    return container;
  }
}

class ChoiceWidgetAnnotationElement extends WidgetAnnotationElement {
  ChoiceWidgetAnnotationElement(super.parameters);

  @override
  web.HTMLElement render() {
    final select = configure(
      web.document.createElement('select') as web.HTMLSelectElement,
    );
    select.multiple = data['multiSelect'] == true;
    final current =
        storedValue is Map ? storedValue['value'] : data['fieldValue'];
    final values =
        current is List ? current.map((e) => '$e').toSet() : {'$current'};
    final options = data['options'];
    if (options is List) {
      for (final raw in options) {
        final optionData =
            raw is Map ? raw : {'exportValue': raw, 'displayValue': raw};
        final option =
            web.document.createElement('option') as web.HTMLOptionElement;
        option.value = optionData['exportValue']?.toString() ?? '';
        option.textContent =
            optionData['displayValue']?.toString() ?? option.value;
        option.selected = values.contains(option.value);
        select.append(option);
      }
    }
    select.addEventListener(
      'change',
      ((web.Event event) {
        final selected = <String>[];
        for (var i = 0; i < select.options.length; i++) {
          final option = select.options.item(i);
          if (option is web.HTMLOptionElement && option.selected) {
            selected.add(option.value);
          }
        }
        store(select.multiple ? selected : (selected.firstOrNull ?? ''));
      }).toJS,
    );
    return container;
  }
}

abstract class SvgMarkupAnnotationElement extends AnnotationElement {
  SvgMarkupAnnotationElement(super.parameters);
  @override
  bool get isRenderable => true;

  String get elementClass;
  void draw(web.SVGSVGElement svg, double width, double height);

  @override
  web.HTMLElement render() {
    container.classList.add(elementClass);
    final rect = _numbers(data['rect']);
    final width = rect.length == 4 ? math.max(1, rect[2] - rect[0]) : 1;
    final height = rect.length == 4 ? math.max(1, rect[3] - rect[1]) : 1;
    final svg =
        web.document.createElementNS(SVG_NS, 'svg') as web.SVGSVGElement;
    svg
      ..setAttribute('width', '100%')
      ..setAttribute('height', '100%')
      ..setAttribute('viewBox', '0 0 $width $height')
      ..setAttribute('preserveAspectRatio', 'none');
    draw(svg, width.toDouble(), height.toDouble());
    contentElement = svg;
    container.append(svg);
    final contents = _text(data['contents'] ?? data['contentsObj']);
    if (contents.isNotEmpty) container.append(_createPopup(data));
    return container;
  }

  web.SVGElement shape(String name) =>
      web.document.createElementNS(SVG_NS, name) as web.SVGElement;
  String get stroke {
    final color = _numbers(data['color']);
    return color.length >= 3
        ? 'rgb(${_integer(color[0])},${_integer(color[1])},${_integer(color[2])})'
        : 'rgb(255,255,0)';
  }

  double get strokeWidth =>
      math.max(1, _number((data['borderStyle'] as Map?)?['width'], 1));
}

class FreeTextAnnotationElement extends SvgMarkupAnnotationElement {
  FreeTextAnnotationElement(super.parameters);
  @override
  String get elementClass => 'freeTextAnnotation';
  @override
  void draw(web.SVGSVGElement svg, double width, double height) {
    final foreign =
        web.document.createElementNS(SVG_NS, 'text') as web.SVGElement;
    foreign
      ..setAttribute('x', '2')
      ..setAttribute('y', '${math.max(12, height / 2)}')
      ..setAttribute('fill', stroke)
      ..textContent = _text(data['contents'] ?? data['contentsObj']);
    svg.append(foreign);
  }
}

class LineAnnotationElement extends SvgMarkupAnnotationElement {
  LineAnnotationElement(super.parameters);
  @override
  String get elementClass => 'lineAnnotation';
  @override
  void draw(web.SVGSVGElement svg, double width, double height) {
    final coordinates = _numbers(data['lineCoordinates']);
    final rect = _numbers(data['rect']);
    final line = shape('line');
    final x1 = coordinates.length == 4 ? coordinates[0] - rect[0] : 0;
    final y1 = coordinates.length == 4 ? rect[3] - coordinates[1] : height;
    final x2 = coordinates.length == 4 ? coordinates[2] - rect[0] : width;
    final y2 = coordinates.length == 4 ? rect[3] - coordinates[3] : 0;
    line
      ..setAttribute('x1', '$x1')
      ..setAttribute('y1', '$y1')
      ..setAttribute('x2', '$x2')
      ..setAttribute('y2', '$y2')
      ..setAttribute('stroke', stroke)
      ..setAttribute('stroke-width', '$strokeWidth');
    svg.append(line);
  }
}

class SquareAnnotationElement extends SvgMarkupAnnotationElement {
  SquareAnnotationElement(super.parameters);
  @override
  String get elementClass => 'squareAnnotation';
  @override
  void draw(web.SVGSVGElement svg, double width, double height) {
    final rectangle = shape('rect');
    final inset = strokeWidth / 2;
    rectangle
      ..setAttribute('x', '$inset')
      ..setAttribute('y', '$inset')
      ..setAttribute('width', '${math.max(0, width - strokeWidth)}')
      ..setAttribute('height', '${math.max(0, height - strokeWidth)}')
      ..setAttribute('fill', 'none')
      ..setAttribute('stroke', stroke)
      ..setAttribute('stroke-width', '$strokeWidth');
    svg.append(rectangle);
  }
}

class CircleAnnotationElement extends SvgMarkupAnnotationElement {
  CircleAnnotationElement(super.parameters);
  @override
  String get elementClass => 'circleAnnotation';
  @override
  void draw(web.SVGSVGElement svg, double width, double height) {
    final ellipse = shape('ellipse');
    ellipse
      ..setAttribute('cx', '${width / 2}')
      ..setAttribute('cy', '${height / 2}')
      ..setAttribute('rx', '${math.max(0, (width - strokeWidth) / 2)}')
      ..setAttribute('ry', '${math.max(0, (height - strokeWidth) / 2)}')
      ..setAttribute('fill', 'none')
      ..setAttribute('stroke', stroke)
      ..setAttribute('stroke-width', '$strokeWidth');
    svg.append(ellipse);
  }
}

class PolylineAnnotationElement extends SvgMarkupAnnotationElement {
  PolylineAnnotationElement(super.parameters);
  @override
  String get elementClass => 'polylineAnnotation';
  String get nodeName => 'polyline';
  @override
  void draw(web.SVGSVGElement svg, double width, double height) {
    final vertices = data['vertices'];
    final rect = _numbers(data['rect']);
    final points = <String>[];
    if (vertices is List && rect.length == 4) {
      for (final vertex in vertices) {
        if (vertex is Map) {
          points.add(
              '${_number(vertex['x']) - rect[0]},${rect[3] - _number(vertex['y'])}');
        } else {
          try {
            final dynamic point = vertex;
            points.add(
                '${_number(point.x) - rect[0]},${rect[3] - _number(point.y)}');
          } catch (_) {}
        }
      }
    }
    final polyline = shape(nodeName);
    polyline
      ..setAttribute('points', points.join(' '))
      ..setAttribute('fill', nodeName == 'polygon' ? 'transparent' : 'none')
      ..setAttribute('stroke', stroke)
      ..setAttribute('stroke-width', '$strokeWidth');
    svg.append(polyline);
  }
}

class PolygonAnnotationElement extends PolylineAnnotationElement {
  PolygonAnnotationElement(super.parameters);
  @override
  String get elementClass => 'polygonAnnotation';
  @override
  String get nodeName => 'polygon';
}

class InkAnnotationElement extends SvgMarkupAnnotationElement {
  InkAnnotationElement(super.parameters);
  @override
  String get elementClass => 'inkAnnotation';
  @override
  void draw(web.SVGSVGElement svg, double width, double height) {
    final lists = data['inkLists'];
    final rect = _numbers(data['rect']);
    if (lists is! List || rect.length != 4) return;
    for (final rawLine in lists) {
      if (rawLine is! List) continue;
      final points = <String>[];
      for (final point in rawLine) {
        if (point is Map) {
          points.add(
              '${_number(point['x']) - rect[0]},${rect[3] - _number(point['y'])}');
        }
      }
      final polyline = shape('polyline');
      polyline
        ..setAttribute('points', points.join(' '))
        ..setAttribute('fill', 'none')
        ..setAttribute('stroke', stroke)
        ..setAttribute('stroke-linecap', 'round')
        ..setAttribute('stroke-linejoin', 'round')
        ..setAttribute('stroke-width', '$strokeWidth');
      svg.append(polyline);
    }
  }
}

class HighlightAnnotationElement extends AnnotationElement {
  HighlightAnnotationElement(super.parameters);
  @override
  bool get isRenderable => true;
  @override
  web.HTMLElement render() {
    container.classList.add('highlightAnnotation');
    container.style.backgroundColor =
        'rgba(255, 255, 0, ${_number(data['opacity'], .4)})';
    contentElement = container;
    return container;
  }
}

class UnderlineAnnotationElement extends HighlightAnnotationElement {
  UnderlineAnnotationElement(super.parameters);
  @override
  web.HTMLElement render() {
    super.render();
    container
      ..className = 'annotation underlineAnnotation'
      ..style.backgroundColor = 'transparent'
      ..style.borderBottom = '2px solid rgb(255, 255, 0)';
    return container;
  }
}

class StrikeOutAnnotationElement extends UnderlineAnnotationElement {
  StrikeOutAnnotationElement(super.parameters);
  @override
  web.HTMLElement render() {
    super.render();
    container
      ..className = 'annotation strikeOutAnnotation'
      ..style.borderBottom = 'none'
      ..style.setProperty('text-decoration', 'line-through');
    final line = web.document.createElement('span') as web.HTMLSpanElement;
    line.style
      ..position = 'absolute'
      ..left = '0'
      ..right = '0'
      ..top = '50%'
      ..borderTop = '2px solid rgb(255, 255, 0)';
    container.append(line);
    return container;
  }
}

class SquigglyAnnotationElement extends UnderlineAnnotationElement {
  SquigglyAnnotationElement(super.parameters);
  @override
  web.HTMLElement render() {
    super.render();
    container.className = 'annotation squigglyAnnotation';
    container.style
      ..borderBottom = 'none'
      ..setProperty('text-decoration', 'underline wavy rgb(255, 255, 0)');
    return container;
  }
}

class StampAnnotationElement extends AnnotationElement {
  StampAnnotationElement(super.parameters);
  @override
  bool get isRenderable => true;
  @override
  web.HTMLElement render() {
    container.classList.add('stampAnnotation');
    container.setAttribute('aria-label', 'Stamp annotation');
    contentElement = container;
    return container;
  }
}

class FileAttachmentAnnotationElement extends AnnotationElement {
  FileAttachmentAnnotationElement(super.parameters);
  @override
  bool get isRenderable => true;
  @override
  web.HTMLElement render() {
    container.classList.add('fileAttachmentAnnotation');
    final button =
        web.document.createElement('button') as web.HTMLButtonElement;
    button.type = 'button';
    button.textContent = data['fileName']?.toString() ?? 'Attachment';
    button.title = button.textContent ?? '';
    contentElement = button;
    container.append(button);
    return container;
  }
}

/// DOM overlay for page annotations.
class AnnotationLayer {
  final web.HTMLDivElement div;
  final AnnotationStorage annotationStorage;
  final AnnotationLinkService? linkService;
  PageViewport viewport;
  final List<AnnotationElement> _elements = [];
  int _zIndex = 0;

  AnnotationLayer({
    required this.div,
    required this.viewport,
    AnnotationStorage? annotationStorage,
    this.linkService,
  }) : annotationStorage = annotationStorage ?? AnnotationStorage();

  List<AnnotationElement> get elements => List.unmodifiable(_elements);
  int nextZIndex() => _zIndex += 2;

  Future<void> render(AnnotationLayerParameters parameters) async {
    _setLayerDimensions();
    _elements.clear();
    div.textContent = '';
    final fragment = web.document.createDocumentFragment();
    for (final data in parameters.annotations) {
      if (data['noHTML'] == true) continue;
      final rect = _numbers(data['rect']);
      if (_integer(data['annotationType']) != AnnotationType.popup &&
          (rect.length != 4 || rect[0] == rect[2] || rect[1] == rect[3])) {
        continue;
      }
      final element = AnnotationElementFactory.create(
        AnnotationElementParameters(
          data: data,
          parent: this,
          renderForms: parameters.renderForms,
          imageResourcesPath: parameters.imageResourcesPath,
        ),
      );
      if (!element.isRenderable) continue;
      final rendered = element.render();
      element.contentElement?.id = 'pdfjs_internal_id_${data['id']}';
      _elements.add(element);
      fragment.append(rendered);
    }
    div.append(fragment);
  }

  void update({required PageViewport viewport}) {
    this.viewport = viewport;
    _setLayerDimensions();
    for (final element in _elements) {
      element.update(viewport);
    }
    div.removeAttribute('hidden');
  }

  void _setLayerDimensions() {
    div.style
      ..width = '${_cssNumber(viewport.width)}px'
      ..height = '${_cssNumber(viewport.height)}px'
      ..position = 'absolute';
    div.setAttribute('data-main-rotation', '${viewport.rotation}');
  }
}
