// Copyright 2026. Apache License 2.0.

@TestOn('browser')
library;

import 'package:pdfjs/src/display/annotation_layer.dart';
import 'package:pdfjs/src/display/annotation_storage.dart';
import 'package:pdfjs/src/display/display_utils.dart';
import 'package:pdfjs/src/shared/util.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

Map<String, dynamic> _annotation(
  String id,
  int type, {
  List<num> rect = const [10, 20, 110, 70],
  Map<String, dynamic> extra = const {},
}) =>
    {
      'id': id,
      'annotationType': type,
      'rect': rect,
      'color': [20, 40, 60],
      'borderStyle': {'width': 1, 'style': 1},
      ...extra,
    };

PageViewport _viewport([double scale = 1]) => PageViewport(
      viewBox: const [0, 0, 200, 100],
      scale: scale,
      rotation: 0,
    );

class _LinkService implements AnnotationLinkService {
  dynamic destination;
  String? action;

  @override
  void executeNamedAction(String action) => this.action = action;

  @override
  void navigateTo(dynamic destination) => this.destination = destination;
}

void main() {
  group('AnnotationLayer', () {
    late web.HTMLDivElement container;
    late AnnotationStorage storage;

    setUp(() {
      container = web.document.createElement('div') as web.HTMLDivElement;
      storage = AnnotationStorage();
      web.document.body?.append(container);
    });

    tearDown(() => container.remove());

    test('positions and orders renderable annotations', () async {
      final layer = AnnotationLayer(
        div: container,
        viewport: _viewport(),
        annotationStorage: storage,
      );
      await layer.render(AnnotationLayerParameters(annotations: [
        _annotation('stamp', AnnotationType.stamp),
        _annotation('empty', AnnotationType.stamp, rect: [0, 0, 0, 0]),
        _annotation('skip', AnnotationType.stamp, extra: {'noHTML': true}),
      ]));

      expect(layer.elements, hasLength(1));
      final stamp = container.querySelector('[data-annotation-id="stamp"]')!
          as web.HTMLElement;
      expect(stamp.classList.contains('stampAnnotation'), isTrue);
      expect(stamp.style.left, '5%');
      expect(stamp.style.top, '30%');
      expect(stamp.style.width, '50%');
      expect(stamp.style.height, '50%');
      expect(container.style.width, '200px');
      expect(container.style.height, '100px');
    });

    test('renders external and internal links', () async {
      final links = _LinkService();
      final layer = AnnotationLayer(
        div: container,
        viewport: _viewport(),
        annotationStorage: storage,
        linkService: links,
      );
      await layer.render(AnnotationLayerParameters(annotations: [
        _annotation('external', AnnotationType.link, extra: {
          'url': 'https://example.test/file.pdf',
        }),
        _annotation('internal', AnnotationType.link, extra: {
          'destination': 'chapter-2',
        }),
        _annotation('action', AnnotationType.link, extra: {
          'action': 'NextPage',
        }),
      ]));

      final external = container.querySelector(
        '[data-annotation-id="external"] a',
      )! as web.HTMLAnchorElement;
      expect(external.href, contains('https://example.test/file.pdf'));
      expect(external.target, '_blank');
      expect(external.rel, contains('noopener'));

      (container.querySelector('[data-annotation-id="internal"] a')!
              as web.HTMLAnchorElement)
          .click();
      expect(links.destination, 'chapter-2');
      (container.querySelector('[data-annotation-id="action"] a')!
              as web.HTMLAnchorElement)
          .click();
      expect(links.action, 'NextPage');
    });

    test('toggles a text annotation popup', () async {
      final layer = AnnotationLayer(div: container, viewport: _viewport());
      await layer.render(AnnotationLayerParameters(annotations: [
        _annotation('note', AnnotationType.text, extra: {
          'name': 'Comment',
          'title': 'Reviewer',
          'contents': 'Please revise this paragraph.',
        }),
      ]));

      final button = container.querySelector('button') as web.HTMLButtonElement;
      final popup =
          container.querySelector('.popupWrapper')! as web.HTMLElement;
      expect(button.getAttribute('aria-label'), 'Comment');
      expect(popup.hasAttribute('hidden'), isTrue);
      button.click();
      expect(popup.hasAttribute('hidden'), isFalse);
      expect(popup.querySelector('h1')!.textContent, 'Reviewer');
      expect(popup.querySelector('p')!.textContent,
          'Please revise this paragraph.');
      button.click();
      expect(popup.hasAttribute('hidden'), isTrue);
    });

    test('renders standalone popup annotations', () async {
      final layer = AnnotationLayer(div: container, viewport: _viewport());
      await layer.render(AnnotationLayerParameters(annotations: [
        _annotation('popup', AnnotationType.popup, rect: const [], extra: {
          'titleObj': {'str': 'Author'},
          'contentsObj': {'str': 'Popup contents'},
        }),
      ]));

      final popup = container.querySelector('.popupAnnotation .popupWrapper')!;
      expect(popup.hasAttribute('hidden'), isFalse);
      expect(popup.textContent, contains('Author'));
      expect(popup.textContent, contains('Popup contents'));
    });

    test('text widgets synchronize their value with AnnotationStorage',
        () async {
      final layer = AnnotationLayer(
        div: container,
        viewport: _viewport(),
        annotationStorage: storage,
      );
      await layer.render(AnnotationLayerParameters(annotations: [
        _annotation('name', AnnotationType.widget, extra: {
          'fieldType': 'Tx',
          'fieldName': 'customer.name',
          'fieldValue': 'Ada',
          'maxLen': 12,
          'alternativeText': 'Customer name',
        }),
        _annotation('notes', AnnotationType.widget, extra: {
          'fieldType': 'Tx',
          'fieldName': 'notes',
          'fieldValue': 'First line',
          'multiLine': true,
        }),
      ]));

      final input = container.querySelector('input') as web.HTMLInputElement;
      expect(input.value, 'Ada');
      expect(input.maxLength, 12);
      expect(input.getAttribute('name'), 'customer.name');
      input.value = 'Grace';
      input.dispatchEvent(web.Event('input'));
      expect(storage.getRawValue('name'), {'value': 'Grace'});

      final textarea =
          container.querySelector('textarea') as web.HTMLTextAreaElement;
      textarea.value = 'Updated';
      textarea.dispatchEvent(web.Event('input'));
      expect(storage.getRawValue('notes'), {'value': 'Updated'});
    });

    test('renders checkboxes and radio buttons', () async {
      final layer = AnnotationLayer(
        div: container,
        viewport: _viewport(),
        annotationStorage: storage,
      );
      await layer.render(AnnotationLayerParameters(annotations: [
        _annotation('agree', AnnotationType.widget, extra: {
          'fieldType': 'Btn',
          'checkBox': true,
          'fieldValue': 'Off',
          'exportValue': 'Yes',
        }),
        _annotation('choice', AnnotationType.widget, extra: {
          'fieldType': 'Btn',
          'radioButton': true,
          'fieldValue': 'A',
          'exportValue': 'A',
        }),
      ]));

      final checkbox = container.querySelector(
        '[data-annotation-id="agree"] input',
      )! as web.HTMLInputElement;
      expect(checkbox.type, 'checkbox');
      expect(checkbox.checked, isFalse);
      checkbox.click();
      expect(storage.getRawValue('agree'), {'value': 'Yes'});

      final radio = container.querySelector(
        '[data-annotation-id="choice"] input',
      )! as web.HTMLInputElement;
      expect(radio.type, 'radio');
      expect(radio.checked, isTrue);
    });

    test('renders choice widgets and stores selections', () async {
      final layer = AnnotationLayer(
        div: container,
        viewport: _viewport(),
        annotationStorage: storage,
      );
      await layer.render(AnnotationLayerParameters(annotations: [
        _annotation('country', AnnotationType.widget, extra: {
          'fieldType': 'Ch',
          'fieldValue': 'br',
          'options': [
            {'exportValue': 'br', 'displayValue': 'Brazil'},
            {'exportValue': 'pt', 'displayValue': 'Portugal'},
          ],
        }),
      ]));

      final select = container.querySelector('select') as web.HTMLSelectElement;
      expect(select.options.length, 2);
      expect(select.value, 'br');
      select.value = 'pt';
      select.dispatchEvent(web.Event('change'));
      expect(storage.getRawValue('country'), {'value': 'pt'});
    });

    test('renderForms false suppresses widget controls', () async {
      final layer = AnnotationLayer(div: container, viewport: _viewport());
      await layer.render(AnnotationLayerParameters(
        renderForms: false,
        annotations: [
          _annotation('field', AnnotationType.widget, extra: {
            'fieldType': 'Tx',
            'fieldValue': 'hidden',
          }),
        ],
      ));
      expect(container.querySelector('input'), isNull);
      expect(layer.elements, isEmpty);
    });

    test('renders vector markup using SVG', () async {
      final layer = AnnotationLayer(div: container, viewport: _viewport());
      await layer.render(AnnotationLayerParameters(annotations: [
        _annotation('line', AnnotationType.line, extra: {
          'lineCoordinates': [10, 20, 110, 70],
        }),
        _annotation('square', AnnotationType.square),
        _annotation('circle', AnnotationType.circle),
        _annotation('poly', AnnotationType.polyline, extra: {
          'vertices': [
            {'x': 10, 'y': 20},
            {'x': 110, 'y': 70},
          ],
        }),
        _annotation('polygon', AnnotationType.polygon, extra: {
          'vertices': [
            {'x': 10, 'y': 20},
            {'x': 110, 'y': 20},
            {'x': 60, 'y': 70},
          ],
        }),
        _annotation('ink', AnnotationType.ink, extra: {
          'inkLists': [
            [
              {'x': 10, 'y': 20},
              {'x': 60, 'y': 70},
            ],
          ],
        }),
      ]));

      expect(container.querySelectorAll('svg').length, 6);
      expect(container.querySelector('.lineAnnotation line'), isNotNull);
      expect(container.querySelector('.squareAnnotation rect'), isNotNull);
      expect(container.querySelector('.circleAnnotation ellipse'), isNotNull);
      expect(
          container.querySelector('.polylineAnnotation polyline'), isNotNull);
      expect(container.querySelector('.polygonAnnotation polygon'), isNotNull);
      expect(container.querySelector('.inkAnnotation polyline'), isNotNull);
    });

    test('renders text markup variants', () async {
      final layer = AnnotationLayer(div: container, viewport: _viewport());
      await layer.render(AnnotationLayerParameters(annotations: [
        _annotation('highlight', AnnotationType.highlight),
        _annotation('underline', AnnotationType.underline),
        _annotation('squiggly', AnnotationType.squiggly),
        _annotation('strike', AnnotationType.strikeout),
      ]));

      expect(container.querySelector('.highlightAnnotation'), isNotNull);
      expect(container.querySelector('.underlineAnnotation'), isNotNull);
      expect(container.querySelector('.squigglyAnnotation'), isNotNull);
      expect(container.querySelector('.strikeOutAnnotation span'), isNotNull);
    });

    test('updates dimensions when the viewport changes', () async {
      final layer = AnnotationLayer(div: container, viewport: _viewport());
      await layer.render(AnnotationLayerParameters(annotations: [
        _annotation('stamp', AnnotationType.stamp),
      ]));
      layer.update(viewport: _viewport(2));
      expect(container.style.width, '400px');
      expect(container.style.height, '200px');
      expect(container.hasAttribute('hidden'), isFalse);
    });
  });
}
