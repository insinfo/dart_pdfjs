@TestOn('browser')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/base_tree_viewer.dart';
import '../../example/src/event_utils.dart';
import '../../example/src/l10n.dart';
import '../../example/src/pdf_attachment_viewer.dart';

void main() {
  late web.HTMLDivElement container;
  late EventBus eventBus;
  late _DownloadManager downloadManager;
  late PDFAttachmentViewer viewer;

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body!.appendChild(container);
    eventBus = EventBus();
    downloadManager = _DownloadManager();
    viewer = PDFAttachmentViewer(
      container: container,
      eventBus: eventBus,
      l10n: L10n(backend: _Backend()),
      downloadManager: downloadManager,
      emptyDispatchDelay: const Duration(milliseconds: 20),
    );
  });

  tearDown(() => container.remove());

  test('renders attachments and dispatches the exact count', () async {
    final events = <Object?>[];
    eventBus.on('attachmentsloaded', events.add);

    viewer.render(attachments: <String, dynamic>{
      'first': <String, dynamic>{
        'filename': 'first.txt',
        'description': 'First file',
        'content': <int>[1, 2],
      },
      'second': <String, dynamic>{
        'filename': 'second.bin',
        'content': <int>[3],
      },
    });
    await Future<void>.delayed(Duration.zero);

    expect(container.querySelectorAll('ul > li').length, 2);
    final links = container.querySelectorAll('a');
    expect(links.item(0)!.textContent, 'first.txt');
    expect((links.item(0)! as web.HTMLAnchorElement).title, 'First file');
    expect((events.single as Map)['attachmentsCount'], 2);
  });

  test('click opens the selected embedded file', () {
    final content = <int>[8, 9];
    viewer.render(attachments: <String, dynamic>{
      'download': <String, dynamic>{
        'filename': 'archive.zip',
        'content': content,
      },
    });

    container.querySelector('a')!.dispatchEvent(
          web.MouseEvent('click', web.MouseEventInit(cancelable: true)),
        );

    expect(downloadManager.filename, 'archive.zip');
    expect(downloadManager.content, same(content));
  });

  test('empty event waits for initial annotation layer', () async {
    final events = <Object?>[];
    eventBus.on('attachmentsloaded', events.add);
    viewer.render(attachments: null);
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);

    eventBus.dispatch('annotationlayerrendered');
    await Future<void>.delayed(Duration.zero);
    expect((events.single as Map)['attachmentsCount'], 0);
  });

  test('empty event eventually fires after timeout', () async {
    final event = Completer<Object?>();
    eventBus.on('attachmentsloaded', event.complete);
    viewer.render(attachments: null);

    final payload = await event.future.timeout(const Duration(seconds: 1));
    expect((payload as Map)['attachmentsCount'], 0);
  });

  test('annotation attachment is appended after initial rendering', () async {
    final counts = <int>[];
    eventBus.on('attachmentsloaded', (event) {
      counts.add((event as Map)['attachmentsCount'] as int);
    });
    viewer.render(attachments: <String, dynamic>{
      'regular': <String, dynamic>{
        'filename': 'regular.txt',
        'content': 1,
      },
    });
    eventBus.dispatch('fileattachmentannotation', <String, dynamic>{
      'filename': 'annotation.txt',
      'description': 'From a page',
      'content': 2,
    });
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.querySelectorAll('li').length, 2);
    expect(container.textContent, contains('annotation.txt'));
    expect(counts, <int>[1, 2]);
  });

  test('supports nested attachment payload from annotation events', () async {
    viewer.render(attachments: <String, dynamic>{});
    eventBus.dispatch('fileattachmentannotation', <String, dynamic>{
      'attachment': <String, dynamic>{
        'filename': 'nested.pdf',
        'content': 7,
      },
    });
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.textContent, contains('nested.pdf'));
  });

  test('duplicate annotation filenames are ignored', () async {
    viewer.render(attachments: <String, dynamic>{
      'same': <String, dynamic>{'filename': 'same.txt', 'content': 1},
    });
    eventBus.dispatch('fileattachmentannotation', <String, dynamic>{
      'filename': 'same.txt',
      'content': 99,
    });
    await Future<void>.delayed(Duration.zero);

    expect(container.querySelectorAll('li').length, 1);
  });

  test('annotation from a previous document cannot mutate a reset viewer',
      () async {
    viewer.reset();
    eventBus.dispatch('fileattachmentannotation', <String, dynamic>{
      'filename': 'old.txt',
      'content': 1,
    });
    viewer.reset();
    viewer.render(attachments: <String, dynamic>{
      'new': <String, dynamic>{'filename': 'new.txt', 'content': 2},
    });
    await Future<void>.delayed(Duration.zero);

    expect(container.textContent, contains('new.txt'));
    expect(container.textContent, isNot(contains('old.txt')));
  });

  test('sanitizes attachment labels', () {
    viewer.render(attachments: <String, dynamic>{
      'bad': <String, dynamic>{'filename': 'a\x00b\x02c', 'content': 1},
    });
    expect(container.querySelector('a')!.textContent, 'ab c');
  });
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
