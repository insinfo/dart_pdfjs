import 'dart:async';

import 'package:test/test.dart';

import '../../example/src/event_utils.dart';
import '../../example/src/pdf_text_extractor.dart';

void main() {
  late EventBus eventBus;
  late _Viewer viewer;
  late _Reporter reporter;
  late _FakeTimerFactory timers;
  late PdfTextExtractor extractor;

  setUp(() {
    eventBus = EventBus();
    viewer = _Viewer('document text');
    reporter = _Reporter();
    timers = _FakeTimerFactory();
    extractor = PdfTextExtractor(
      reporter,
      viewer,
      eventBus,
      timerFactory: timers.call,
    );
  });

  tearDown(() => extractor.dispose());

  test('waits for pagesinit before extracting text', () async {
    var completed = false;
    final extraction = extractor.extractTextContent(7).then((_) {
      completed = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    eventBus.dispatch('pagesinit');
    await extraction;
    expect(reporter.reports, [(text: 'document text', requestId: 7)]);
  });

  test('shares and temporarily caches extraction', () async {
    eventBus.dispatch('pagesinit');
    await Future.wait([
      extractor.extractTextContent(1),
      extractor.extractTextContent(2),
    ]);
    expect(viewer.calls, 1);
    expect(timers.created, 1);

    await extractor.extractTextContent(3);
    expect(viewer.calls, 1);
    timers.fireLatest();
    await extractor.extractTextContent(4);
    expect(viewer.calls, 2);
  });

  test('pagesdestroy clears cache and waits for replacement viewer', () async {
    eventBus.dispatch('pagesinit');
    await extractor.extractTextContent(1);
    eventBus.dispatch('pagesdestroy');

    final replacement = _Viewer('replacement');
    eventBus.dispatch('pagesinit', replacement);
    await extractor.extractTextContent(2);
    expect(reporter.reports.last.text, 'replacement');
  });

  test('forwards requests from an external stream', () async {
    await extractor.dispose();
    final requests = StreamController<TextContentRequest>();
    extractor = PdfTextExtractor(
      reporter,
      viewer,
      eventBus,
      requests: requests.stream,
      timerFactory: timers.call,
    );
    eventBus.dispatch('pagesinit');
    requests.add(const TextContentRequest(42));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(reporter.reports.last.requestId, 42);
    await requests.close();
  });

  test('dispose rejects subsequent explicit requests', () async {
    await extractor.dispose();
    await expectLater(extractor.extractTextContent(1), throwsStateError);
  });
}

class _Viewer implements TextProvidingViewer {
  final String text;
  var calls = 0;

  _Viewer(this.text);

  @override
  Future<String> getAllText() async {
    calls++;
    return text;
  }
}

class _Reporter implements TextReportingService {
  final List<({String text, int requestId})> reports = [];

  @override
  void reportText({required String text, required int requestId}) {
    reports.add((text: text, requestId: requestId));
  }
}

class _FakeTimerFactory {
  final List<_FakeTimer> timers = [];

  int get created => timers.length;

  Timer call(Duration duration, void Function() callback) {
    final timer = _FakeTimer(callback);
    timers.add(timer);
    return timer;
  }

  void fireLatest() => timers.last.fire();
}

class _FakeTimer implements Timer {
  final void Function() callback;
  var _active = true;

  _FakeTimer(this.callback);

  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;

  @override
  void cancel() => _active = false;
}
