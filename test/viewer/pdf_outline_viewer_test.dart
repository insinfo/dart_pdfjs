@TestOn('browser')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/base_tree_viewer.dart';
import '../../example/src/event_utils.dart';
import '../../example/src/l10n.dart';
import '../../example/src/pdf_link_service.dart';
import '../../example/src/pdf_outline_viewer.dart';
import '../../example/src/ui_utils.dart' show SidebarView;

void main() {
  late web.HTMLDivElement container;
  late EventBus eventBus;
  late _DownloadManager downloadManager;
  late _LinkService linkService;
  late _Document document;
  late PDFOutlineViewer viewer;

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body!.appendChild(container);
    eventBus = EventBus();
    downloadManager = _DownloadManager();
    linkService = _LinkService(eventBus);
    document = _Document();
    viewer = PDFOutlineViewer(
      container: container,
      eventBus: eventBus,
      l10n: L10n(backend: _Backend()),
      linkService: linkService,
      downloadManager: downloadManager,
    );
  });

  tearDown(() => container.remove());

  test('renders breadth-first tree, styles and loaded metadata', () async {
    Object? loaded;
    eventBus.on('outlineloaded', (event) => loaded = event);
    viewer.render(
      outline: <dynamic>[
        _item(
          title: 'Chapter 1',
          dest: <dynamic>[0],
          bold: true,
          items: <dynamic>[
            _item(title: 'Section', dest: <dynamic>[1], italic: true),
          ],
        ),
        _item(title: 'Chapter 2', dest: <dynamic>[2]),
      ],
      document: document,
    );

    expect(container.querySelectorAll('.treeItem').length, 3);
    expect(container.classList.contains('withNesting'), isTrue);
    final links = container.querySelectorAll('a');
    expect(links.item(0)!.textContent, 'Chapter 1');
    expect(
      (links.item(0)! as web.HTMLAnchorElement).style.fontWeight,
      'bold',
    );
    final sectionLink = <web.HTMLAnchorElement>[
      for (var index = 0; index < links.length; index++)
        links.item(index)! as web.HTMLAnchorElement,
    ].singleWhere((link) => link.textContent == 'Section');
    expect(sectionLink.style.fontStyle, 'italic');
    expect((loaded as Map)['outlineCount'], 3);
    eventBus.dispatch('pagesloaded', <String, Object?>{'pagesCount': 3});
    final enabled =
        await ((loaded as Map)['currentOutlineItemPromise'] as Future<bool>);
    expect(enabled, isTrue);
  });

  test('pagesloaded resolves current item capability', () async {
    Future<bool>? capability;
    eventBus.on('outlineloaded', (event) {
      capability = (event as Map)['currentOutlineItemPromise'] as Future<bool>;
    });
    viewer.render(
      outline: <dynamic>[
        _item(title: 'One', dest: <dynamic>[0])
      ],
      document: document,
    );
    eventBus.dispatch('pagesloaded', <String, Object?>{'pagesCount': 4});

    expect(await capability, isTrue);
  });

  test('disabled auto-fetch disables current outline synchronization',
      () async {
    document.disableAutoFetchValue = true;
    Future<bool>? capability;
    eventBus.on('outlineloaded', (event) {
      capability = (event as Map)['currentOutlineItemPromise'] as Future<bool>;
    });
    viewer.render(
      outline: <dynamic>[
        _item(title: 'One', dest: <dynamic>[0])
      ],
      document: document,
    );
    expect(await capability, isFalse);
  });

  test('null outline dispatches zero and leaves the container empty', () async {
    Object? loaded;
    eventBus.on('outlineloaded', (event) => loaded = event);
    viewer.render(outline: null, document: document);

    expect(container.children.length, 0);
    expect((loaded as Map)['outlineCount'], 0);
    expect(
      await ((loaded as Map)['currentOutlineItemPromise'] as Future<bool>),
      false,
    );
  });

  test('negative count hides a completely collapsed subtree', () {
    viewer.render(
      outline: <dynamic>[
        _item(
          title: 'Parent',
          count: -2,
          items: <dynamic>[
            _item(title: 'A'),
            _item(title: 'B'),
          ],
        ),
      ],
      document: document,
    );

    expect(
      container
          .querySelector('.treeItemToggler')!
          .classList
          .contains('treeItemsHidden'),
      isTrue,
    );
  });

  test('toggleoutlinetree expands and collapses all nested entries', () {
    viewer.render(
      outline: <dynamic>[
        _item(
          title: 'Parent',
          items: <dynamic>[_item(title: 'Child')],
        ),
      ],
      document: document,
    );
    final toggler = container.querySelector('.treeItemToggler')!;

    eventBus.dispatch('toggleoutlinetree');
    expect(toggler.classList.contains('treeItemsHidden'), isTrue);
    eventBus.dispatch('toggleoutlinetree');
    expect(toggler.classList.contains('treeItemsHidden'), isFalse);
  });

  test('external URL receives safe link attributes', () {
    linkService.externalLinkTarget = LinkTarget.self;
    viewer.render(
      outline: <dynamic>[
        _item(title: 'Website', url: 'https://example.com/a')
          ..['newWindow'] = true,
      ],
      document: document,
    );
    final link = container.querySelector('a') as web.HTMLAnchorElement;

    expect(link.href, contains('https://example.com/a'));
    expect(link.target, '_blank');
    expect(link.rel, contains('noopener'));
  });

  test('named action executes through link service', () {
    viewer.render(
      outline: <dynamic>[_item(title: 'Next', action: 'NextPage')],
      document: document,
    );
    container.querySelector('a')!.dispatchEvent(
          web.MouseEvent('click', web.MouseEventInit(cancelable: true)),
        );
    expect(linkService.namedActions, <String>['NextPage']);
  });

  test('embedded attachment opens through download manager', () {
    final content = <int>[1, 2, 3];
    viewer.render(
      outline: <dynamic>[
        _item(title: 'Embedded')
          ..['attachment'] = <String, dynamic>{
            'filename': 'embedded.pdf',
            'content': content,
          },
      ],
      document: document,
    );
    container.querySelector('a')!.dispatchEvent(
          web.MouseEvent('click', web.MouseEventInit(cancelable: true)),
        );

    expect(downloadManager.filename, 'embedded.pdf');
    expect(downloadManager.content, same(content));
  });

  test('optional content action executes through link service', () async {
    final action = <String, dynamic>{
      'state': <dynamic>['ON', 'layer'],
    };
    viewer.render(
      outline: <dynamic>[
        _item(title: 'Layer')..['setOCGState'] = action,
      ],
      document: document,
    );
    container.querySelector('a')!.dispatchEvent(
          web.MouseEvent('click', web.MouseEventInit(cancelable: true)),
        );
    await Future<void>.delayed(Duration.zero);
    expect(linkService.ocgActions, <Map<String, dynamic>>[action]);
  });

  test('destination click selects its item and starts navigation', () async {
    final destination = <dynamic>[2];
    viewer.render(
      outline: <dynamic>[_item(title: 'Destination', dest: destination)],
      document: document,
    );
    final link = container.querySelector('a')!;
    link.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(cancelable: true)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(link.parentElement!.classList.contains(treeItemSelectedClass), true);
    expect(linkService.destinations.single, same(destination));
  });

  test('current item picks deepest destination on active page', () async {
    final shallow = <dynamic>[0];
    final deep = <dynamic>[
      0,
      <String, dynamic>{'name': 'Fit'}
    ];
    viewer.render(
      outline: <dynamic>[
        _item(
          title: 'Shallow',
          dest: shallow,
          items: <dynamic>[_item(title: 'Deep', dest: deep)],
        ),
      ],
      document: document,
    );
    eventBus.dispatch('pagesloaded', <String, Object?>{'pagesCount': 3});
    eventBus.dispatch('pagechanging', <String, Object?>{'pageNumber': 1});
    eventBus.dispatch(
      'sidebarviewchanged',
      <String, Object?>{'view': SidebarView.outline},
    );
    eventBus.dispatch('currentoutlineitem');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final selected = container.querySelector('.selected');
    expect(selected, isNotNull);
    expect(selected!.textContent, contains('Deep'));
  });

  test('current item falls back to a destination on a previous page', () async {
    viewer.render(
      outline: <dynamic>[
        _item(title: 'Earlier', dest: <dynamic>[0])
      ],
      document: document,
    );
    eventBus.dispatch('pagesloaded', <String, Object?>{'pagesCount': 5});
    eventBus.dispatch('pagechanging', <String, Object?>{'pageNumber': 4});
    eventBus.dispatch(
      'sidebarviewchanged',
      <String, Object?>{'view': SidebarView.outline},
    );
    eventBus.dispatch('currentoutlineitem');
    await Future<void>.delayed(Duration.zero);

    expect(container.querySelector('.selected')!.textContent, 'Earlier');
  });

  test('named destinations are resolved before current item selection',
      () async {
    document.destinations['intro'] = <dynamic>[1];
    viewer.render(
      outline: <dynamic>[_item(title: 'Introduction', dest: 'intro')],
      document: document,
    );
    eventBus.dispatch('pagesloaded', <String, Object?>{'pagesCount': 3});
    eventBus.dispatch('pagechanging', <String, Object?>{'pageNumber': 2});
    eventBus.dispatch(
      'sidebarviewchanged',
      <String, Object?>{'view': SidebarView.outline},
    );
    eventBus.dispatch('currentoutlineitem');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(document.destinationRequests, <String>['intro']);
    expect(container.querySelector('.selected')!.textContent, 'Introduction');
  });

  test('does not select while another sidebar is visible', () async {
    viewer.render(
      outline: <dynamic>[
        _item(title: 'Hidden', dest: <dynamic>[0])
      ],
      document: document,
    );
    eventBus.dispatch('pagesloaded', <String, Object?>{'pagesCount': 2});
    eventBus.dispatch('sidebarviewchanged', <String, Object?>{
      'view': SidebarView.attachments,
    });
    eventBus.dispatch('currentoutlineitem');
    await Future<void>.delayed(Duration.zero);
    expect(container.querySelector('.selected'), isNull);
  });

  test('reset replaces pending capability and removes old rendering', () async {
    Future<bool>? first;
    eventBus.on('outlineloaded', (event) {
      first ??= (event as Map)['currentOutlineItemPromise'] as Future<bool>;
    });
    viewer.render(
      outline: <dynamic>[_item(title: 'Old')],
      document: document,
    );
    viewer.render(
      outline: <dynamic>[_item(title: 'New')],
      document: document,
    );
    expect(await first, false);
    expect(container.textContent, 'New');
  });

  test('sanitizes outline title control characters', () {
    viewer.render(
      outline: <dynamic>[_item(title: 'A\x00B\x03C')],
      document: document,
    );
    expect(container.querySelector('a')!.textContent, 'AB C');
  });
}

Map<String, dynamic> _item({
  required String title,
  Object? dest,
  String? url,
  String? action,
  bool bold = false,
  bool italic = false,
  int? count,
  List<dynamic> items = const <dynamic>[],
}) =>
    <String, dynamic>{
      'title': title,
      'dest': dest,
      'url': url,
      'action': action,
      'bold': bold,
      'italic': italic,
      'count': count,
      'items': items,
    };

class _Document implements OutlineDocument {
  final Map<String, List<dynamic>> destinations = {};
  final List<String> destinationRequests = [];
  bool disableAutoFetchValue = false;

  @override
  bool get disableAutoFetch => disableAutoFetchValue;

  @override
  int get pagesCount => 10;

  @override
  int? cachedPageNumber(Object reference) =>
      reference is _Reference ? reference.pageNumber : null;

  @override
  Future<List<dynamic>?> getDestination(String name) async {
    destinationRequests.add(name);
    return destinations[name];
  }

  @override
  Future<int> getPageIndex(Object reference) async =>
      (reference as _Reference).pageNumber - 1;
}

class _Reference {
  const _Reference(this.pageNumber);
  final int pageNumber;
}

class _LinkService extends PDFLinkService {
  _LinkService(EventBus eventBus) : super(eventBus: eventBus);

  final List<String> namedActions = [];
  final List<Object?> destinations = [];
  final List<Map<String, dynamic>> ocgActions = [];

  @override
  void executeNamedAction(String action) => namedActions.add(action);

  @override
  Future<void> goToDestination(FutureOr<Object?> destination) async {
    destinations.add(await destination);
  }

  @override
  Future<void> executeSetOCGState(Map<String, dynamic> action) async {
    ocgActions.add(action);
  }
}

class _DownloadManager implements ViewerDownloadManager {
  Object? content;
  String? filename;

  @override
  void openOrDownloadData(Object? content, String filename) {
    this.content = content;
    this.filename = filename;
  }
}

class _Backend implements LocalizationBackend {
  @override
  void connectRoot(Object element) {}
  @override
  void disconnectRoot(Object element) {}
  @override
  Future<List<L10nMessage>> formatMessages(List<L10nRequest> requests) async =>
      [];
  @override
  void pauseObserving() {}
  @override
  void resumeObserving() {}
  @override
  Future<void> translateElements(List<Object> elements) async {}
  @override
  Future<void> translateRoots() async {}
}
