@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/event_utils.dart';
import '../../example/src/l10n.dart';
import '../../example/src/ui_utils.dart';
import '../../example/src/views_manager.dart';

void main() {
  late web.HTMLDivElement host;
  late ViewsManagerElements elements;
  late EventBus eventBus;
  late ViewsManager manager;
  late List<int> changes;
  late int toggles;
  late int thumbnailUpdates;

  web.HTMLButtonElement button() =>
      web.document.createElement('button') as web.HTMLButtonElement;
  web.HTMLElement div() => web.document.createElement('div') as web.HTMLElement;

  setUp(() {
    host = web.document.createElement('div') as web.HTMLDivElement;
    final outer = web.document.createElement('div') as web.HTMLDivElement;
    final sidebar = div()
      ..style.setProperty('--sidebar-width', '240')
      ..style.width = '240px';
    final resizer = div();
    final toggle = button();
    elements = ViewsManagerElements(
      outerContainer: outer,
      sidebarContainer: sidebar,
      toggleButton: toggle,
      resizer: resizer,
      thumbnailButton: button(),
      outlineButton: button(),
      attachmentsButton: button(),
      layersButton: button(),
      thumbnailsView: div(),
      outlinesView: div(),
      attachmentsView: div(),
      layersView: div(),
      addFileButton: button(),
      currentOutlineButton: button(),
      selectorButton: button(),
      selectorOptions: div(),
      headerLabel: div(),
      status: div(),
    );
    host.append(outer);
    outer
      ..append(sidebar)
      ..append(toggle);
    sidebar
      ..append(resizer)
      ..append(elements.thumbnailButton)
      ..append(elements.outlineButton)
      ..append(elements.attachmentsButton)
      ..append(elements.layersButton)
      ..append(elements.thumbnailsView)
      ..append(elements.outlinesView)
      ..append(elements.attachmentsView)
      ..append(elements.layersView)
      ..append(elements.addFileButton)
      ..append(elements.currentOutlineButton)
      ..append(elements.selectorButton)
      ..append(elements.selectorOptions)
      ..append(elements.headerLabel)
      ..append(elements.status);
    web.document.body!.append(host);
    eventBus = EventBus();
    changes = [];
    toggles = 0;
    thumbnailUpdates = 0;
    eventBus.on('sidebarviewchanged', (data) {
      changes.add((data as Map)['view'] as int);
    });
    manager = ViewsManager(
      elements: elements,
      eventBus: eventBus,
      l10n: L10n(backend: _Backend()),
      enableMerge: true,
      enableSplitMerge: true,
    )
      ..onToggled = () {
        toggles++;
      }
      ..onUpdateThumbnails = () {
        thumbnailUpdates++;
      };
  });

  tearDown(() {
    manager.destroy();
    host.remove();
  });

  test('starts closed on thumbnails and opens through toggle', () async {
    expect(manager.visibleView, SidebarView.none);
    expect(manager.active, SidebarView.thumbs);
    elements.toggleButton.click();
    await Future<void>.delayed(Duration.zero);
    expect(manager.isOpen, isTrue);
    expect(manager.visibleView, SidebarView.thumbs);
    expect(elements.toggleButton.getAttribute('aria-expanded'), 'true');
    expect(
        elements.outerContainer.classList.contains('viewsManagerOpen'), isTrue);
    expect(thumbnailUpdates, 1);
    expect(toggles, 1);
    expect(changes.last, SidebarView.thumbs);
  });

  test('switches buttons, views, header, and contextual controls', () {
    manager.open();
    manager.switchView(SidebarView.outline);
    expect(manager.active, SidebarView.outline);
    expect(elements.outlineButton.classList.contains('selected'), isTrue);
    expect(elements.outlinesView.classList.contains('hidden'), isFalse);
    expect(elements.thumbnailsView.classList.contains('hidden'), isTrue);
    expect(elements.headerLabel.getAttribute('data-l10n-id'),
        'pdfjs-views-manager-outlines-title1');
    expect(elements.currentOutlineButton.hasAttribute('hidden'), isFalse);
    expect(elements.addFileButton.hasAttribute('hidden'), isTrue);
    expect(elements.status.hasAttribute('hidden'), isTrue);
  });

  test('disabled or invalid views are ignored', () {
    elements.outlineButton.disabled = true;
    manager.switchView(SidebarView.outline);
    manager.switchView(99);
    expect(manager.active, SidebarView.thumbs);
  });

  test('setInitialView opens once and dispatches one final state', () {
    manager.setInitialView(SidebarView.layers);
    expect(manager.isOpen, isTrue);
    expect(manager.active, SidebarView.layers);
    final count = changes.length;
    manager.setInitialView(SidebarView.outline);
    expect(changes.length, count);
    expect(manager.active, SidebarView.layers);
  });

  test('initial none dispatches closed state without opening', () {
    manager.setInitialView();
    expect(manager.isOpen, isFalse);
    expect(changes, [SidebarView.none]);
  });

  test('loaded events enable, disable, notify and fallback', () async {
    eventBus.dispatch('outlineloaded', {
      'outlineCount': 2,
      'currentOutlineItemPromise': Future<bool>.value(true),
    });
    await Future<void>.delayed(Duration.zero);
    expect(elements.outlineButton.disabled, isFalse);
    expect(elements.toggleButton.classList.contains('pdfSidebarNotification'),
        isTrue);

    manager.setInitialView(SidebarView.outline);
    await Future<void>.delayed(Duration.zero);
    expect(elements.currentOutlineButton.disabled, isFalse);
    eventBus.dispatch('outlineloaded', {
      'outlineCount': 0,
      'currentOutlineItemPromise': Future<bool>.value(false),
    });
    expect(manager.active, SidebarView.thumbs);
    expect(elements.outlineButton.disabled, isTrue);
  });

  test('attachment and layer loading disable empty views', () {
    eventBus.dispatch('attachmentsloaded', {'attachmentsCount': 0});
    eventBus.dispatch('layersloaded', {'layersCount': 0});
    expect(elements.attachmentsButton.disabled, isTrue);
    expect(elements.layersButton.disabled, isTrue);
  });

  test('header double click and current outline button dispatch actions', () {
    final events = <String>[];
    eventBus.on('toggleoutlinetree', (_) => events.add('outline'));
    eventBus.on('resetlayers', (_) => events.add('layers'));
    eventBus.on('currentoutlineitem', (_) => events.add('current'));
    manager.switchView(SidebarView.outline);
    elements.headerLabel.dispatchEvent(web.MouseEvent('dblclick'));
    elements.currentOutlineButton.click();
    manager.switchView(SidebarView.layers);
    elements.headerLabel.dispatchEvent(web.MouseEvent('dblclick'));
    expect(events, ['outline', 'current', 'layers']);
  });

  test('presentation exit refreshes visible thumbnails', () {
    manager.open();
    thumbnailUpdates = 0;
    eventBus.dispatch('presentationmodechanged', {
      'state': PresentationModeState.fullscreen,
    });
    expect(thumbnailUpdates, 0);
    eventBus.dispatch('presentationmodechanged', {
      'state': PresentationModeState.normal,
    });
    expect(thumbnailUpdates, 1);
  });

  test('close and reset restore lifecycle state', () {
    manager.open();
    manager.switchView(SidebarView.layers);
    manager.close();
    expect(manager.visibleView, SidebarView.none);
    expect(elements.outerContainer.classList.contains('viewsManagerOpen'),
        isFalse);
    manager.reset();
    expect(manager.active, SidebarView.thumbs);
    expect(manager.isInitialViewSet, isFalse);
    expect(elements.currentOutlineButton.disabled, isTrue);
    expect(elements.toggleButton.getAttribute('data-l10n-id'),
        'pdfjs-toggle-views-manager-button1');
  });
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
