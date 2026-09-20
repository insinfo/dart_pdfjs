import 'dart:async';

import 'package:test/test.dart';

import '../../example/src/renderable_view.dart';

final class TestView implements RenderableView {
  TestView(this.renderingId, {this.onDraw});

  @override
  final String renderingId;

  final Future<void> Function()? onDraw;
  int drawCalls = 0;

  @override
  RenderingState renderingState = RenderingState.initial;

  @override
  void Function()? resume;

  @override
  Future<void> draw() async {
    drawCalls++;
    await onDraw?.call();
  }
}

void main() {
  group('RenderingState', () {
    test('keeps the upstream numeric values', () {
      expect(RenderingState.initial.value, 0);
      expect(RenderingState.running.value, 1);
      expect(RenderingState.paused.value, 2);
      expect(RenderingState.finished.value, 3);
    });

    test('round-trips every valid numeric value', () {
      for (final state in RenderingState.values) {
        expect(RenderingState.fromValue(state.value), same(state));
      }
    });

    test('rejects an unknown numeric value', () {
      expect(() => RenderingState.fromValue(-1), throwsArgumentError);
      expect(() => RenderingState.fromValue(4), throwsArgumentError);
    });
  });

  test('RenderableView implementations expose a stable lifecycle contract',
      () async {
    final gate = Completer<void>();
    final view = TestView('page7', onDraw: () => gate.future);

    expect(view.renderingId, 'page7');
    expect(view.renderingState, RenderingState.initial);
    final drawing = view.draw();
    expect(view.drawCalls, 1);
    gate.complete();
    await drawing;
  });
}
