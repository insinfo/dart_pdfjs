@TestOn('browser')
library;

import 'package:pdfjs/src/display/touch_manager.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLDivElement container;
  late TouchManager manager;

  TouchPoint point(int id, num x, num y) =>
      TouchPoint(id, x.toDouble(), y.toDouble());

  setUp(() {
    container = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body!.append(container);
  });

  tearDown(() {
    manager.dispose();
    container.remove();
  });

  test('ignores one finger and starts tracking two fingers', () {
    var starts = 0;
    manager = TouchManager(
      container: container,
      onPinchStart: () => starts++,
    );

    expect(manager.handleTouchStart([point(0, 0, 0)]), isFalse);
    expect(starts, 0);
    expect(
      manager.handleTouchStart([point(0, 0, 0), point(1, 100, 0)]),
      isTrue,
    );
    expect(starts, 1);
    expect(
      manager.handleTouchStart([point(0, 0, 0), point(1, 110, 0)]),
      isTrue,
    );
    expect(starts, 1);
  });

  test('applies the threshold before emitting pinch updates', () {
    final updates = <PinchUpdate>[];
    manager = TouchManager(
      container: container,
      onPinching: (origin, previous, distance) => updates.add(PinchUpdate(
        origin: origin,
        previousDistance: previous,
        distance: distance,
      )),
    );
    manager.handleTouchStart([point(0, 0, 0), point(1, 100, 0)]);

    expect(
      manager.handleTouchMove([point(0, 0, 0), point(1, 110, 0)]),
      isNull,
    );
    expect(manager.isPinching, isFalse);
    expect(
      manager.handleTouchMove([point(0, 0, 0), point(1, 140, 0)]),
      isNull,
    );
    expect(manager.isPinching, isTrue);
    expect(updates, isEmpty);

    final update =
        manager.handleTouchMove([point(0, 10, 10), point(1, 190, 10)]);
    expect(update, isNotNull);
    expect(update!.origin, [100, 10]);
    expect(update.previousDistance, 140);
    expect(update.distance, 180);
    expect(updates.single.origin, [100, 10]);
  });

  test('orders touches by identifier before calculating movement', () {
    manager = TouchManager(container: container);
    manager.handleTouchStart([point(8, 100, 0), point(2, 0, 0)]);

    manager.handleTouchMove([point(8, 150, 0), point(2, 0, 0)]);
    final update =
        manager.handleTouchMove([point(2, 10, 20), point(8, 210, 20)]);

    expect(update, isNotNull);
    expect(update!.origin, [110, 20]);
    expect(update.previousDistance, 150);
    expect(update.distance, 200);
  });

  test('honors disabled and stopped predicates', () {
    var disabled = true;
    var stopped = true;
    manager = TouchManager(
      container: container,
      isPinchingDisabled: () => disabled,
      isPinchingStopped: () => stopped,
    );
    final touches = [point(0, 0, 0), point(1, 100, 0)];

    expect(manager.handleTouchStart(touches), isFalse);
    disabled = false;
    expect(manager.handleTouchStart(touches), isTrue);
    expect(
      manager.handleTouchMove([point(0, 0, 0), point(1, 200, 0)]),
      isNull,
    );
    stopped = false;
    manager.handleTouchStart(touches);
    manager.handleTouchMove([point(0, 0, 0), point(1, 150, 0)]);
    expect(manager.isPinching, isTrue);
  });

  test('ends only when fewer than two touches remain', () {
    var ends = 0;
    manager = TouchManager(
      container: container,
      onPinchEnd: () => ends++,
    );
    manager.handleTouchStart([point(0, 0, 0), point(1, 100, 0)]);
    manager.handleTouchMove([point(0, 0, 0), point(1, 150, 0)]);

    expect(manager.handleTouchEnd(2), isFalse);
    expect(ends, 0);
    expect(manager.isPinching, isTrue);
    expect(manager.handleTouchEnd(1), isTrue);
    expect(ends, 1);
    expect(manager.isPinching, isFalse);
    expect(manager.handleTouchEnd(0), isTrue);
    expect(ends, 1);
  });

  test('dispose is idempotent and rejects subsequent input', () {
    manager = TouchManager(container: container);
    manager.dispose();
    manager.dispose();

    expect(manager.isDisposed, isTrue);
    expect(
      manager.handleTouchStart([point(0, 0, 0), point(1, 100, 0)]),
      isFalse,
    );
    expect(manager.handleTouchEnd(0), isFalse);
  });
}
