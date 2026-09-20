@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/base_tree_viewer.dart';
import '../../example/src/event_utils.dart';
import '../../example/src/l10n.dart';

void main() {
  late web.HTMLDivElement container;
  late _LocalizationBackend backend;
  late _TestTreeViewer viewer;

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body!.appendChild(container);
    backend = _LocalizationBackend();
    viewer = _TestTreeViewer(
      container: container,
      eventBus: EventBus(),
      l10n: L10n(backend: backend),
    );
  });

  tearDown(() => container.remove());

  test('normalizes control characters and empty labels', () {
    expect(viewer.normalizeTextContent('A\x00B\x01C'), 'AB C');
    expect(viewer.normalizeTextContent(''), '\u2013');
    expect(viewer.normalizeTextContent(null), '\u2013');
  });

  test('toggle buttons honor initial state and toggle a complete subtree', () {
    final parent = web.document.createElement('div') as web.HTMLDivElement;
    final child = web.document.createElement('div') as web.HTMLDivElement;
    viewer.addToggleButton(parent, hidden: true);
    viewer.addToggleButton(child);
    parent.appendChild(child);
    container.appendChild(parent);

    expect(
      parent.firstElementChild!.classList.contains('treeItemsHidden'),
      isTrue,
    );
    viewer.toggleTreeItem(parent, show: true);
    expect(
      parent.querySelectorAll('.treeItemsHidden').length,
      0,
    );
    expect(backend.pauses, 1);
    expect(backend.resumes, 1);

    viewer.toggleTreeItem(parent);
    expect(parent.querySelectorAll('.treeItemsHidden').length, 2);
  });

  test('finishRendering inserts content and dispatches count', () {
    final fragment = web.document.createDocumentFragment();
    final item = web.document.createElement('div') as web.HTMLDivElement;
    item.className = 'treeItem';
    fragment.appendChild(item);

    viewer.finishRendering(fragment, 7);

    expect(container.children.length, 1);
    expect(viewer.lastCount, 7);
    expect(backend.pauses, 1);
    expect(backend.resumes, 1);
  });

  test('delegated click toggles only expansion controls', () {
    final fragment = web.document.createDocumentFragment();
    final item = web.document.createElement('div') as web.HTMLDivElement;
    item.className = 'treeItem';
    viewer.addToggleButton(item);
    final label = web.document.createElement('a') as web.HTMLAnchorElement;
    item.appendChild(label);
    fragment.appendChild(item);
    viewer.finishRendering(fragment, 1, hasAnyNesting: true);

    final toggler = item.firstElementChild!;
    expect(container.classList.contains('withNesting'), isTrue);
    toggler.dispatchEvent(web.MouseEvent(
        'click',
        web.MouseEventInit(
          bubbles: true,
          cancelable: true,
        )));
    expect(toggler.classList.contains('treeItemsHidden'), isTrue);

    label.dispatchEvent(web.MouseEvent(
        'click',
        web.MouseEventInit(
          bubbles: true,
          cancelable: true,
        )));
    expect(toggler.classList.contains('treeItemsHidden'), isTrue);
  });

  test('shift-click applies the clicked state to descendants', () {
    final fragment = web.document.createDocumentFragment();
    final parent = web.document.createElement('div') as web.HTMLDivElement;
    parent.className = 'treeItem';
    viewer.addToggleButton(parent, hidden: true);
    final child = web.document.createElement('div') as web.HTMLDivElement;
    viewer.addToggleButton(child, hidden: true);
    parent.appendChild(child);
    fragment.appendChild(parent);
    viewer.finishRendering(fragment, 2, hasAnyNesting: true);

    parent.firstElementChild!.dispatchEvent(
      web.MouseEvent(
          'click',
          web.MouseEventInit(
            bubbles: true,
            cancelable: true,
            shiftKey: true,
          )),
    );
    expect(parent.querySelectorAll('.treeItemsHidden').length, 0);
  });

  test('selection moves and reset clears DOM and nesting state', () {
    final one = web.document.createElement('div') as web.HTMLDivElement;
    final two = web.document.createElement('div') as web.HTMLDivElement;
    container
      ..appendChild(one)
      ..appendChild(two);
    container.classList.add('withNesting');

    viewer.updateCurrentTreeItem(one);
    expect(one.classList.contains(treeItemSelectedClass), isTrue);
    viewer.updateCurrentTreeItem(two);
    expect(one.classList.contains(treeItemSelectedClass), isFalse);
    expect(two.classList.contains(treeItemSelectedClass), isTrue);

    viewer.reset();
    expect(container.children.length, 0);
    expect(container.classList.contains('withNesting'), isFalse);
    expect(viewer.currentTreeItem, isNull);
  });

  test('scroll selection expands every treeItem ancestor', () {
    final outer = web.document.createElement('div') as web.HTMLDivElement;
    outer.className = 'treeItem';
    viewer.addToggleButton(outer, hidden: true);
    final items = web.document.createElement('div') as web.HTMLDivElement;
    final inner = web.document.createElement('div') as web.HTMLDivElement;
    inner.className = 'treeItem';
    viewer.addToggleButton(inner, hidden: true);
    items.appendChild(inner);
    outer.appendChild(items);
    container.appendChild(outer);

    viewer.scrollToCurrentTreeItem(inner);

    expect(
        outer.firstElementChild!.classList.contains('treeItemsHidden'), false);
    expect(inner.classList.contains(treeItemSelectedClass), true);
  });
}

class _TestTreeViewer extends BaseTreeViewer {
  _TestTreeViewer({
    required super.container,
    required super.eventBus,
    required super.l10n,
  });

  int? lastCount;

  @override
  void bindLink(web.HTMLAnchorElement element, Map<String, dynamic> item) {}

  @override
  void dispatchLoadedEvent(int count) => lastCount = count;
}

class _LocalizationBackend implements LocalizationBackend {
  int pauses = 0;
  int resumes = 0;

  @override
  void pauseObserving() => pauses++;

  @override
  void resumeObserving() => resumes++;

  @override
  void connectRoot(Object element) {}

  @override
  void disconnectRoot(Object element) {}

  @override
  Future<List<L10nMessage>> formatMessages(List<L10nRequest> requests) async =>
      <L10nMessage>[];

  @override
  Future<void> translateElements(List<Object> elements) async {}

  @override
  Future<void> translateRoots() async {}
}
