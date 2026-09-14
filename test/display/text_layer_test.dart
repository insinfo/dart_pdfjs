// Copyright 2026. Apache License 2.0.

@TestOn('browser')

import 'package:pdfjs/src/display/display_utils.dart';
import 'package:pdfjs/src/display/text_layer.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

PageViewport _viewport({double scale = 1, int rotation = 0}) => PageViewport(
      viewBox: [0, 0, 200, 100],
      scale: scale,
      rotation: rotation,
    );

Map<String, dynamic> _content() => {
      'lang': 'en',
      'styles': {
        'f1': {
          'fontFamily': 'serif',
          'ascent': 0.75,
          'vertical': false,
        },
      },
      'items': [
        {
          'str': 'Chapter A',
          'dir': 'ltr',
          'width': 100,
          'height': 20,
          'transform': [20, 0, 0, 20, 40, 80],
          'fontName': 'f1',
          'hasEOL': true,
        },
        {
          'str': '',
          'dir': 'ltr',
          'width': 0,
          'height': 20,
          'transform': [20, 0, 0, 20, 40, 60],
          'fontName': 'f1',
          'hasEOL': false,
        },
      ],
    };

void main() {
  group('TextLayer', () {
    test('renders text items, styles and line breaks', () async {
      final container = web.document.createElement('div') as web.HTMLDivElement;
      final layer = TextLayer(
        textContentSource: _content(),
        container: container,
        viewport: _viewport(),
      );

      await layer.render();

      expect(layer.textContentItemsStr, ['Chapter A', '']);
      expect(layer.textDivs, hasLength(2));
      expect(container.querySelectorAll('span').length, 1);
      expect(container.querySelectorAll('br').length, 1);
      expect(layer.textDivs.first.textContent, 'Chapter A');
      expect(layer.textDivs.first.style.fontFamily, 'serif');
      expect(layer.textDivs.first.getAttribute('role'), 'presentation');
    });

    test('creates nested marked-content containers', () async {
      final container = web.document.createElement('div') as web.HTMLDivElement;
      final content = _content();
      content['items'] = [
        {'type': 'beginMarkedContentProps', 'id': 'mc1', 'tag': 'Artifact'},
        (content['items'] as List).first,
        {'type': 'endMarkedContent'},
      ];
      final layer = TextLayer(
        textContentSource: content,
        container: container,
        viewport: _viewport(),
      );

      await layer.render();

      final marked = container.querySelector('.markedContent')!;
      expect(marked.id, 'mc1');
      expect(marked.getAttribute('aria-hidden'), 'true');
      expect(marked.querySelector('span')!.textContent, 'Chapter A');
    });

    test('updates scale and rotation and invokes the callback', () async {
      final container = web.document.createElement('div') as web.HTMLDivElement;
      final layer = TextLayer(
        textContentSource: _content(),
        container: container,
        viewport: _viewport(),
      );
      await layer.render();
      var calls = 0;

      layer.update(
        viewport: _viewport(scale: 2, rotation: 90),
        onBefore: () => calls++,
      );

      expect(calls, 2);
      expect(container.getAttribute('data-main-rotation'), '90');
      expect(
          layer.textDivs.first.style.getPropertyValue('--scale-x'), isNotEmpty);
    });

    test('prevents duplicate rendering', () async {
      final layer = TextLayer(
        textContentSource: _content(),
        container: web.document.createElement('div') as web.HTMLDivElement,
        viewport: _viewport(),
      );
      await layer.render();

      await expectLater(layer.render(), throwsStateError);
    });

    test('cancel prevents pending content from being rendered', () async {
      final container = web.document.createElement('div') as web.HTMLDivElement;
      final layer = TextLayer(
        textContentSource: _content(),
        container: container,
        viewport: _viewport(),
      );

      layer.cancel();
      await layer.render();

      expect(container.childElementCount, 0);
    });
  });
}
