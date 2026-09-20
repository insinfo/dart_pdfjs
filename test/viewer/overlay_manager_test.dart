@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/overlay_manager.dart';

void main() {
  late OverlayManager manager;
  late web.HTMLDialogElement first;
  late web.HTMLDialogElement second;

  setUp(() {
    manager = OverlayManager();
    first = web.document.createElement('dialog') as web.HTMLDialogElement;
    second = web.document.createElement('dialog') as web.HTMLDialogElement;
    web.document.body!
      ..append(first)
      ..append(second);
  });

  tearDown(() async {
    if (first.open) first.close();
    if (second.open) second.close();
    first.remove();
    second.remove();
    await manager.dispose();
  });

  test('registers, opens and closes a dialog', () async {
    await manager.register(first);
    expect(manager.active, isNull);

    await manager.open(first);
    expect(manager.active, same(first));
    expect(first.open, isTrue);

    await manager.close(first);
    expect(manager.active, isNull);
    expect(first.open, isFalse);
  });

  test('rejects duplicate and unknown dialogs', () async {
    await manager.register(first);

    await expectLater(manager.register(first), throwsStateError);
    await expectLater(manager.open(second), throwsStateError);
    await expectLater(manager.close(second), throwsStateError);
  });

  test('does not replace an overlay without permission', () async {
    await manager.register(first);
    await manager.register(second);
    await manager.open(first);

    await expectLater(manager.open(first), throwsStateError);
    await expectLater(manager.open(second), throwsStateError);
    expect(manager.active, same(first));
  });

  test('a force-close overlay replaces the active dialog', () async {
    await manager.register(first);
    await manager.register(second, canForceClose: true);
    await manager.open(first);

    await manager.open(second);
    expect(first.open, isFalse);
    expect(second.open, isTrue);
    expect(manager.active, same(second));
  });

  test('closeIfActive ignores inactive dialogs', () async {
    await manager.register(first);
    await manager.register(second);
    await manager.open(first);

    await manager.closeIfActive(second);
    expect(manager.active, same(first));
    await manager.closeIfActive(first);
    expect(manager.active, isNull);
  });

  test('cancel event clears the active overlay', () async {
    await manager.register(first);
    await manager.open(first);

    first.dispatchEvent(web.Event('cancel'));
    await Future<void>.delayed(Duration.zero);
    expect(manager.active, isNull);
  });
}
