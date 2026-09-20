@TestOn('browser')
library;

import 'dart:async';

import 'package:pdfjs/pdfjs.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/annotation_layer_builder.dart';
import '../../example/src/draw_layer_builder.dart';
import '../../example/src/layer_page_adapter.dart';
import '../../example/src/pdf_link_service.dart';
import '../../example/src/struct_tree_layer_builder.dart';
import '../../example/src/text_layer_builder.dart';
import '../../example/src/xfa_layer_builder.dart';

final class FakeLayerPage implements LayerPage {
  List<Map<String, dynamic>> annotations = [];
  Map<String, dynamic> text = {
    'items': <dynamic>[],
    'styles': <String, dynamic>{}
  };
  Map<String, dynamic>? structure;
  Map<String, dynamic>? xfa;
  Completer<Map<String, dynamic>?>? pendingXfa;

  @override
  Future<List<Map<String, dynamic>>> getAnnotations(
          {String intent = 'display'}) async =>
      annotations;

  @override
  Future<Map<String, dynamic>?> getStructTree() async => structure;

  @override
  Future<Map<String, dynamic>> getTextContent({
    bool includeMarkedContent = true,
    bool disableNormalization = true,
  }) async =>
      text;

  @override
  Future<Map<String, dynamic>?> getXfa() =>
      pendingXfa?.future ?? Future.value(xfa);
}

final class RecordingHighlighter implements TextHighlighterController {
  int enabled = 0;
  int disabled = 0;
  List<String> strings = [];

  @override
  void disable() => disabled++;
  @override
  void enable() => enabled++;
  @override
  void setTextMapping(List<web.Node> textDivs, List<String> textContentItems) {
    strings = List.of(textContentItems);
  }
}

PageViewport viewport([double scale = 1]) => PageViewport(
      viewBox: const [0, 0, 200, 100],
      scale: scale,
      rotation: 0,
    );

void main() {
  group('DrawLayerBuilder', () {
    test('creates only for display and cancel destroys it', () async {
      final builder = DrawLayerBuilder();
      await builder.render(intent: 'print');
      expect(builder.getDrawLayer(), isNull);
      await builder.render();
      expect(builder.getDrawLayer(), isNotNull);
      final parent = web.document.createElement('div');
      builder.setParent(parent);
      builder.cancel();
      expect(builder.cancelled, isTrue);
      expect(builder.getDrawLayer(), isNull);
      await builder.render();
      expect(builder.getDrawLayer(), isNull);
    });
  });

  group('TextLayerBuilder', () {
    test('renders, updates mappings, hides, shows and cancels', () async {
      final page = FakeLayerPage()
        ..text = {
          'styles': {
            'f1': {'fontFamily': 'sans-serif', 'ascent': .8},
          },
          'items': [
            {
              'str': 'Hello',
              'dir': 'ltr',
              'fontName': 'f1',
              'transform': [1, 0, 0, 10, 10, 20],
              'width': 30,
              'height': 10,
            }
          ],
        };
      final highlighter = RecordingHighlighter();
      web.HTMLDivElement? appended;
      final builder = TextLayerBuilder(
        pdfPage: page,
        highlighter: highlighter,
        onAppend: (value) => appended = value,
      );
      await builder.render(viewport: viewport());
      expect(builder.renderingDone, isTrue);
      expect(builder.textContentItemsStr, ['Hello']);
      expect(highlighter.strings, ['Hello']);
      expect(appended, same(builder.div));
      expect(builder.div.querySelector('.endOfContent'), isNotNull);
      builder.hide();
      expect(builder.div.hasAttribute('hidden'), isTrue);
      builder.show();
      expect(builder.div.hasAttribute('hidden'), isFalse);
      builder.cancel();
      expect(highlighter.disabled, greaterThan(0));
    });

    test('second render updates existing layer', () async {
      final builder = TextLayerBuilder(pdfPage: FakeLayerPage());
      await builder.render(viewport: viewport());
      await builder.render(viewport: viewport(2));
      expect(builder.renderingDone, isTrue);
    });
  });

  group('StructTreeLayerBuilder', () {
    test('maps roles, headings and annotation alt attributes', () async {
      final page = FakeLayerPage()
        ..structure = {
          'role': 'Document',
          'children': [
            {
              'role': 'H2',
              'children': [
                {'type': 'content', 'id': 'heading'},
              ],
            },
            {
              'role': 'Figure',
              'alt': 'Chart\u0000 title',
              'bbox': [10, 10, 30, 40],
              'children': [
                {'type': 'annotation', 'id': 'annot-1'},
              ],
            },
          ],
        };
      final builder = StructTreeLayerBuilder(page, viewport().rawDims);
      final tree = await builder.render();
      expect(tree?.classList.contains('structTree'), isTrue);
      expect(
          tree?.querySelector('[role="heading"]')?.getAttribute('aria-level'),
          '2');
      expect(await builder.getAriaAttributes('annot-1'),
          {'aria-label': 'Chart title'});
      builder.hide();
      expect((tree as web.HTMLElement).hasAttribute('hidden'), isTrue);
      builder.show();
      expect(tree.hasAttribute('hidden'), isFalse);
    });

    test('moves figure alternatives and steals MathML text', () async {
      final host = web.document.createElement('div');
      web.document.body?.append(host);
      addTearDown(() => host.remove());
      final marked = web.document.createElement('span')..id = 'mc1';
      marked.textContent = 'x';
      host.append(marked);
      final page = FakeLayerPage()
        ..structure = {
          'role': 'math',
          'children': [
            {'type': 'content', 'id': 'mc1'},
          ],
        };
      final builder = StructTreeLayerBuilder(page, viewport().rawDims);
      final tree = await builder.render();
      builder.updateTextLayer();
      expect(tree?.textContent, 'x');
      expect(marked.getAttribute('aria-hidden'), 'true');
    });
  });

  group('AnnotationLayerBuilder', () {
    test('renders annotations, refreshes and suppresses overlapping links',
        () async {
      final page = FakeLayerPage()
        ..annotations = [
          {
            'id': 'existing',
            'annotationType': 2,
            'url': 'https://example.com',
            'rect': [0, 0, 50, 50],
          }
        ];
      final builder = AnnotationLayerBuilder(
        pdfPage: page,
        linkService: PDFLinkService(),
      );
      await builder.render(viewport: viewport());
      expect(builder.div?.className, 'annotationLayer');
      expect(builder.div?.children.length, 1);
      await builder.injectLinkAnnotations([
        {
          'id': 'duplicate',
          'annotationType': 2,
          'url': 'https://duplicate.example',
          'rect': [0, 0, 40, 40],
        },
        {
          'id': 'new',
          'annotationType': 2,
          'url': 'https://new.example',
          'rect': [60, 0, 90, 30],
        },
      ]);
      expect(builder.div?.children.length, 2);
      builder.hide();
      expect(builder.div?.hasAttribute('hidden'), isTrue);
      builder.cancel();
      expect(builder.cancelled, isTrue);
    });

    test('requires rendering before inferred links', () async {
      final builder = AnnotationLayerBuilder(
        pdfPage: FakeLayerPage(),
        linkService: PDFLinkService(),
      );
      expect(() => builder.injectLinkAnnotations([]), throwsStateError);
    });
  });

  group('XfaLayerBuilder', () {
    Map<String, dynamic> xfa() => {
          'name': 'div',
          'attributes': {
            'class': ['root'],
          },
          'children': [
            {'name': '#text', 'value': 'Name:'},
            {
              'name': 'input',
              'attributes': {'type': 'text', 'dataId': 'name'},
              'children': <dynamic>[],
            },
          ],
        };

    test('renders fields and synchronizes annotation storage', () async {
      final page = FakeLayerPage()..xfa = xfa();
      final storage = AnnotationStorage()..setValue('name', {'value': 'Ada'});
      final builder = XfaLayerBuilder(
        pdfPage: page,
        linkService: PDFLinkService(),
        annotationStorage: storage,
      );
      final result = await builder.render(viewport: viewport());
      expect(result.textNodes.single.data, 'Name:');
      final input = builder.div?.querySelector('input') as web.HTMLInputElement;
      expect(input.value, 'Ada');
      builder.hide();
      expect(builder.div?.hasAttribute('hidden'), isTrue);
      await builder.render(viewport: viewport(2));
      expect(builder.div?.hasAttribute('hidden'), isFalse);
    });

    test('cancel during load prevents DOM creation', () async {
      final pending = Completer<Map<String, dynamic>?>();
      final page = FakeLayerPage()..pendingXfa = pending;
      final builder = XfaLayerBuilder(
        pdfPage: page,
        linkService: PDFLinkService(),
      );
      final rendering = builder.render(viewport: viewport());
      builder.cancel();
      pending.complete(xfa());
      expect((await rendering).textNodes, isEmpty);
      expect(builder.div, isNull);
    });

    test('print uses supplied XFA without loading the page', () async {
      final builder = XfaLayerBuilder(
        pdfPage: FakeLayerPage(),
        linkService: PDFLinkService(),
        xfaHtml: xfa(),
      );
      final result =
          await builder.render(viewport: viewport(), intent: 'print');
      expect(result.textNodes, isNotEmpty);
      expect(builder.div?.className, 'xfaLayer xfaFont');
    });
  });
}
