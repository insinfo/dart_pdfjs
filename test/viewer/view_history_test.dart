import 'dart:convert';

import 'package:test/test.dart';

import '../../example/src/view_history.dart';
import '../../example/src/viewer_storage.dart';

void main() {
  test('creates an empty database and fingerprint branch', () async {
    final storage = MemoryViewerStorage();
    final history = ViewHistory('document-a', storage: storage);
    await history.initializedPromise;
    expect(history.database['files'], hasLength(1));
    expect(history.file, <String, Object?>{'fingerprint': 'document-a'});
  });

  test('reuses an existing fingerprint branch', () async {
    final storage = MemoryViewerStorage(<String, String>{
      'pdfjs.history': jsonEncode(<String, Object?>{
        'files': <Object?>[
          <String, Object?>{'fingerprint': 'a', 'page': 3},
          <String, Object?>{'fingerprint': 'b', 'page': 8},
        ],
      }),
    });
    final history = ViewHistory('b', storage: storage);
    expect(await history.get('page', 1), 8);
    expect(history.database['files'], hasLength(2));
  });

  test('evicts oldest branches before adding a new one', () async {
    final storage = MemoryViewerStorage(<String, String>{
      'pdfjs.history': jsonEncode(<String, Object?>{
        'files': <Object?>[
          <String, Object?>{'fingerprint': 'a'},
          <String, Object?>{'fingerprint': 'b'},
          <String, Object?>{'fingerprint': 'c'},
        ],
      }),
    });
    final history = ViewHistory('d', cacheSize: 3, storage: storage);
    await history.initializedPromise;
    final files = history.database['files']! as List;
    expect(files, hasLength(3));
    expect(
      files.map((Object? file) => (file! as Map)['fingerprint']),
      <String>['b', 'c', 'd'],
    );
  });

  test('eviction can remove an old occurrence of current fingerprint',
      () async {
    final storage = MemoryViewerStorage(<String, String>{
      'pdfjs.history': jsonEncode(<String, Object?>{
        'files': <Object?>[
          <String, Object?>{'fingerprint': 'a', 'page': 99},
          <String, Object?>{'fingerprint': 'b'},
        ],
      }),
    });
    final history = ViewHistory('a', cacheSize: 2, storage: storage);
    expect(await history.get('page', 1), 1);
  });

  test('set persists one property', () async {
    final storage = MemoryViewerStorage();
    final history = ViewHistory('a', storage: storage);
    await history.set('page', 4);
    final decoded = jsonDecode(storage.values['pdfjs.history']!) as Map;
    expect((decoded['files'] as List).single['page'], 4);
  });

  test('setMultiple persists every property in one write', () async {
    final storage = _CountingStorage();
    final history = ViewHistory('a', storage: storage);
    await history.setMultiple(<String, Object?>{
      'page': 5,
      'zoom': 'page-width',
      'rotation': 90,
      'scrollLeft': 12.5,
    });
    expect(storage.writeCount, 1);
    expect(await history.get('page'), 5);
    expect(await history.get('zoom'), 'page-width');
    expect(await history.get('rotation'), 90);
    expect(await history.get('scrollLeft'), 12.5);
  });

  test('get distinguishes absent keys from stored null', () async {
    final history = ViewHistory('a', storage: MemoryViewerStorage());
    await history.set('nullable', null);
    expect(await history.get('nullable', 'fallback'), isNull);
    expect(await history.get('missing', 'fallback'), 'fallback');
  });

  test('getMultiple combines stored values and supplied defaults', () async {
    final history = ViewHistory('a', storage: MemoryViewerStorage());
    await history.setMultiple(<String, Object?>{
      'page': 7,
      'zoom': null,
    });
    expect(
      await history.getMultiple(<String, Object?>{
        'page': 1,
        'zoom': 'auto',
        'rotation': 0,
      }),
      <String, Object?>{
        'page': 7,
        'zoom': null,
        'rotation': 0,
      },
    );
  });

  test('repairs a database whose files property is not an array', () async {
    final storage = MemoryViewerStorage(<String, String>{
      'pdfjs.history': '{"files":"invalid","version":2}',
    });
    final history = ViewHistory('a', storage: storage);
    await history.initializedPromise;
    expect(history.database['version'], 2);
    expect(history.database['files'], hasLength(1));
  });

  test('skips invalid array entries', () async {
    final storage = MemoryViewerStorage(<String, String>{
      'pdfjs.history': '{"files":[null,4,"bad",{"fingerprint":"a"}]}',
    });
    final history = ViewHistory('a', storage: storage);
    await history.initializedPromise;
    expect(history.database['files'], hasLength(1));
  });

  test('supports a custom key without touching the default key', () async {
    final storage = MemoryViewerStorage();
    final history = ViewHistory(
      'a',
      storage: storage,
      storageKey: 'private.history',
    );
    await history.set('page', 2);
    expect(storage.values, contains('private.history'));
    expect(storage.values, isNot(contains('pdfjs.history')));
  });

  test('rejects non-positive cache sizes', () {
    expect(() => ViewHistory('a', cacheSize: 0), throwsArgumentError);
    expect(() => ViewHistory('a', cacheSize: -1), throwsArgumentError);
  });

  test('malformed JSON fails initialization', () async {
    final history = ViewHistory(
      'a',
      storage: MemoryViewerStorage(<String, String>{
        'pdfjs.history': '{broken',
      }),
    );
    await expectLater(history.initializedPromise, throwsFormatException);
  });
}

final class _CountingStorage implements ViewerStorage {
  String? value;
  int writeCount = 0;

  @override
  Future<String?> getItem(String key) async => value;

  @override
  Future<void> removeItem(String key) async {
    value = null;
  }

  @override
  Future<void> setItem(String key, String value) async {
    this.value = value;
    writeCount++;
  }
}
