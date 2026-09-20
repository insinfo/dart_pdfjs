@TestOn('browser')
library;

import 'package:pdfjs/src/display/optional_content_config.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/event_utils.dart';
import '../../example/src/l10n.dart';
import '../../example/src/pdf_layer_viewer.dart';

void main() {
  late web.HTMLDivElement container;
  late EventBus eventBus;
  late PDFLayerViewer viewer;
  late _Document document;
  late List<int> loaded;
  late List<Future<OptionalContentConfig>> updates;

  OptionalContentConfig config({bool firstVisible = true}) =>
      OptionalContentConfig({
        'groups': [
          {'id': 'one', 'name': 'Layer One'},
          {'id': 'two', 'name': 'Layer\u0000 Two'},
          {'id': 'three', 'name': 'Layer Three'},
        ],
        'order': [
          'one',
          {
            'name': 'Nested',
            'order': ['two']
          },
          {
            'name': null,
            'order': ['three']
          },
        ],
        if (!firstVisible) 'off': ['one'],
      });

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body!.append(container);
    eventBus = EventBus();
    viewer = PDFLayerViewer(
      container: container,
      eventBus: eventBus,
      l10n: L10n(backend: _Backend()),
    );
    document = _Document(config());
    loaded = [];
    updates = [];
    eventBus.on('layersloaded',
        (data) => loaded.add((data as Map)['layersCount'] as int));
    eventBus.on('optionalcontentconfig', (data) {
      updates.add((data as Map)['promise'] as Future<OptionalContentConfig>);
    });
  });

  tearDown(() => container.remove());

  test('renders flat and nested groups and dispatches count', () {
    viewer.render(
        optionalContentConfig: document.config, pdfDocument: document);
    expect(loaded, [3]);
    expect(container.querySelectorAll('.treeItem').length, 5);
    expect(container.querySelectorAll('input[type=checkbox]').length, 3);
    expect(container.classList.contains('withNesting'), isTrue);
    expect(container.textContent, contains('Layer  Two'));
    expect(container.querySelector('[data-l10n-id="pdfjs-additional-layers"]'),
        isNotNull);
  });

  test('checkbox updates visibility and emits configuration', () async {
    viewer.render(
        optionalContentConfig: document.config, pdfDocument: document);
    final input = container.querySelector('input') as web.HTMLInputElement;
    input.click();
    expect(document.config.getGroup('one')!.visible, isFalse);
    expect(updates, hasLength(1));
    expect(await updates.single, same(document.config));
  });

  test('anchor click toggles its checkbox', () {
    viewer.render(
        optionalContentConfig: document.config, pdfDocument: document);
    final anchor = container.querySelector('a') as web.HTMLAnchorElement;
    final input = anchor.querySelector('input') as web.HTMLInputElement;
    expect(input.checked, isTrue);
    anchor.click();
    expect(input.checked, isFalse);
  });

  test('changed configuration synchronizes cached controls', () async {
    viewer.render(
        optionalContentConfig: document.config, pdfDocument: document);
    final changed = config(firstVisible: false);
    eventBus.dispatch('optionalcontentconfigchanged', {
      'promise': Future<OptionalContentConfig>.value(changed),
    });
    await Future<void>.delayed(Duration.zero);
    final input = container.querySelector('input') as web.HTMLInputElement;
    expect(input.checked, isFalse);
  });

  test('resetlayers fetches fresh config and rerenders', () async {
    viewer.render(
        optionalContentConfig: document.config, pdfDocument: document);
    document.config = config(firstVisible: false);
    eventBus.dispatch('resetlayers');
    await Future<void>.delayed(Duration.zero);
    expect(document.calls, 1);
    expect(updates, hasLength(1));
    expect((container.querySelector('input') as web.HTMLInputElement).checked,
        isFalse);
    expect(loaded, [3, 3]);
  });

  test('empty config dispatches zero and toggle event is safe', () {
    viewer.render(
      optionalContentConfig: OptionalContentConfig(null),
      pdfDocument: document,
    );
    expect(loaded, [0]);
    eventBus.dispatch('togglelayerstree');
  });

  test('togglelayerstree expands and collapses nested entries', () {
    viewer.render(
        optionalContentConfig: document.config, pdfDocument: document);
    eventBus.dispatch('togglelayerstree');
    expect(
        container.querySelectorAll('.treeItemsHidden').length, greaterThan(0));
    eventBus.dispatch('togglelayerstree');
    expect(container.querySelectorAll('.treeItemsHidden').length, 0);
  });
}

final class _Document implements LayerViewerDocument {
  _Document(this.config);
  OptionalContentConfig config;
  int calls = 0;
  @override
  Future<OptionalContentConfig> getOptionalContentConfig(
      {String intent = 'display'}) async {
    calls++;
    expect(intent, 'display');
    return config;
  }
}

final class _Backend implements LocalizationBackend {
  @override
  Future<List<L10nMessage>> formatMessages(List<L10nRequest> requests) async =>
      requests.map((request) => L10nMessage(request.id)).toList();
  @override
  void connectRoot(Object element) {}
  @override
  void disconnectRoot(Object element) {}
  @override
  void pauseObserving() {}
  @override
  void resumeObserving() {}
  @override
  Future<void> translateElements(List<Object> elements) async {}
  @override
  Future<void> translateRoots() async {}
}
