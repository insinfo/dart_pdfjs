import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';

import '../../example/src/event_utils.dart';
import '../../example/src/generic_signature_storage.dart';
import '../../example/src/viewer_storage.dart';

void main() {
  late MemoryViewerStorage storage;
  late EventBus eventBus;
  late StreamController<String?> changes;
  late _UuidSequence uuids;
  late SignatureStorage signatures;

  setUp(() {
    storage = MemoryViewerStorage();
    eventBus = EventBus();
    changes = StreamController<String?>();
    uuids = _UuidSequence();
    signatures = SignatureStorage(
      storage: storage,
      eventBus: eventBus,
      storageChanges: changes.stream,
      uuidFactory: uuids.next,
    );
  });

  tearDown(() async {
    await signatures.dispose();
    await changes.close();
  });

  test('starts empty and returns a stable cached map', () async {
    final first = await signatures.getAll();
    final second = await signatures.getAll();
    expect(first, isEmpty);
    expect(second, same(first));
    expect(await signatures.size(), 0);
    expect(await signatures.isFull(), isFalse);
  });

  test('loads serialized signature data', () async {
    storage.values[signatureStorageKey] = jsonEncode({
      'one': {'type': 'drawn', 'data': 'abc'},
      'two': 'image',
    });
    expect(await signatures.getAll(), {
      'one': {'type': 'drawn', 'data': 'abc'},
      'two': 'image',
    });
  });

  test('ignores a serialized value that is not an object', () async {
    storage.values[signatureStorageKey] = jsonEncode(['not', 'an', 'object']);
    expect(await signatures.getAll(), isEmpty);
  });

  test('creates and persists a signature', () async {
    final id = await signatures.create({'path': 'M0 0'});
    expect(id, 'uuid-1');
    expect(await signatures.size(), 1);
    expect(jsonDecode(storage.values[signatureStorageKey]!), {
      'uuid-1': {'path': 'M0 0'},
    });
  });

  test('avoids a colliding generated identifier', () async {
    uuids.values
      ..clear()
      ..addAll(['duplicate', 'duplicate', 'unique']);
    storage.values[signatureStorageKey] = jsonEncode({'duplicate': 1});
    expect(await signatures.create(2), 'unique');
  });

  test('limits storage to five signatures', () async {
    for (var i = 0; i < SignatureStorage.maximumSignatures; i++) {
      expect(await signatures.create('signature-$i'), isNotNull);
    }
    expect(await signatures.isFull(), isTrue);
    expect(await signatures.create('too-many'), isNull);
    expect(await signatures.size(), SignatureStorage.maximumSignatures);
  });

  test('deletes an existing signature and persists the change', () async {
    final id = await signatures.create('signature');
    expect(await signatures.delete(id!), isTrue);
    expect(await signatures.delete(id), isFalse);
    expect(jsonDecode(storage.values[signatureStorageKey]!), isEmpty);
  });

  test('storage changes invalidate cache and notify the viewer', () async {
    final notifications = <Object?>[];
    eventBus.on('storedsignatureschanged', notifications.add);
    await signatures.getAll();
    storage.values[signatureStorageKey] = jsonEncode({'external': true});

    changes.add(signatureStorageKey);
    await Future<void>.delayed(Duration.zero);
    expect(notifications, hasLength(1));
    expect(await signatures.getAll(), {'external': true});
  });

  test('unrelated storage changes leave the cache intact', () async {
    final cached = await signatures.getAll();
    storage.values[signatureStorageKey] = jsonEncode({'external': true});
    changes.add('another.key');
    await Future<void>.delayed(Duration.zero);
    expect(await signatures.getAll(), same(cached));
  });
}

class _UuidSequence {
  final List<String> values = [];
  var counter = 0;

  String next() {
    if (values.isNotEmpty) return values.removeAt(0);
    return 'uuid-${++counter}';
  }
}
