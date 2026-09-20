import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';

import '../../example/src/app_options.dart';
import '../../example/src/preferences.dart';
import '../../example/src/viewer_storage.dart';

void main() {
  setUp(AppOptions.reset);

  test('initialization applies browser preferences before regular ones',
      () async {
    final persistence = _RecordingPersistence(
      const PreferenceReadResult(
        browserPrefs: <String, Object?>{
          'supportsPrinting': false,
          'disableRange': false,
        },
        prefs: <String, Object?>{'disableRange': true},
      ),
    );
    final preferences = BasePreferences(persistence: persistence);
    await preferences.initializedPromise;
    expect(AppOptions.get('supportsPrinting'), isFalse);
    expect(AppOptions.get('disableRange'), isTrue);
  });

  test('defaults equal immutable preference defaults', () async {
    final preferences = BasePreferences(
      persistence: _RecordingPersistence(const PreferenceReadResult()),
    );
    await preferences.initializedPromise;
    expect(
      preferences.defaults,
      AppOptions.getAll(kind: OptionKind.preference, defaultOnly: true),
    );
    expect(
      () => preferences.defaults['disableRange'] = true,
      throwsUnsupportedError,
    );
  });

  test('disablePreferences prevents stored values from applying', () async {
    AppOptions.set('disablePreferences', true);
    final preferences = BasePreferences(
      persistence: _RecordingPersistence(
        const PreferenceReadResult(
          prefs: <String, Object?>{'disableRange': true},
        ),
      ),
    );
    await preferences.initializedPromise;
    expect(AppOptions.get('disableRange'), isFalse);
  });

  test('get waits for asynchronous initialization', () async {
    final completer = Completer<PreferenceReadResult>();
    final persistence = _DelayedPersistence(completer.future);
    final preferences = BasePreferences(persistence: persistence);
    var completed = false;
    final result = preferences.get('defaultZoomValue').then((value) {
      completed = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    completer.complete(
      const PreferenceReadResult(
        prefs: <String, Object?>{'defaultZoomValue': 'page-fit'},
      ),
    );
    expect(await result, 'page-fit');
  });

  test('set writes complete normalized preference map', () async {
    final persistence = _RecordingPersistence(const PreferenceReadResult());
    final preferences = BasePreferences(persistence: persistence);
    await preferences.set('defaultZoomValue', 'page-width');
    expect(AppOptions.get('defaultZoomValue'), 'page-width');
    expect(persistence.writes, hasLength(1));
    expect(persistence.writes.single['defaultZoomValue'], 'page-width');
    expect(persistence.writes.single, contains('disableRange'));
    expect(persistence.writes.single, isNot(contains('workerSrc')));
  });

  test('invalid set retains default and writes normalized values', () async {
    final persistence = _RecordingPersistence(const PreferenceReadResult());
    final preferences = BasePreferences(persistence: persistence);
    await preferences.set('disableRange', 'yes');
    expect(AppOptions.get('disableRange'), isFalse);
    expect(persistence.writes.single['disableRange'], isFalse);
  });

  test('reset restores and writes all defaults', () async {
    final persistence = _RecordingPersistence(
      const PreferenceReadResult(
        prefs: <String, Object?>{
          'disableRange': true,
          'defaultZoomValue': '150%',
        },
      ),
    );
    final preferences = BasePreferences(persistence: persistence);
    await preferences.initializedPromise;
    await preferences.reset();
    expect(AppOptions.get('disableRange'), isFalse);
    expect(AppOptions.get('defaultZoomValue'), '');
    expect(persistence.writes.single, preferences.defaults);
  });

  test('JSON persistence reads and writes generic viewer format', () async {
    final storage = MemoryViewerStorage(<String, String>{
      'custom.preferences': jsonEncode(<String, Object?>{
        'disableRange': true,
        'defaultZoomValue': 'page-fit',
      }),
    });
    final persistence = JsonPreferencePersistence(
      storage: storage,
      storageKey: 'custom.preferences',
    );
    final result = await persistence.read(const <String, Object?>{});
    expect(result.prefs['disableRange'], isTrue);
    expect(result.prefs['defaultZoomValue'], 'page-fit');
    await persistence.write(<String, Object?>{'enableXfa': false});
    expect(
      jsonDecode(storage.values['custom.preferences']!),
      <String, Object?>{'enableXfa': false},
    );
  });

  test('JSON persistence treats absent and non-object data as empty', () async {
    final storage = MemoryViewerStorage();
    final persistence = JsonPreferencePersistence(storage: storage);
    expect((await persistence.read(const {})).prefs, isEmpty);
    storage.values['pdfjs.preferences'] = '[1, 2]';
    expect((await persistence.read(const {})).prefs, isEmpty);
  });

  test('storage errors propagate from initialization', () async {
    final preferences = BasePreferences(persistence: _FailingPersistence());
    await expectLater(preferences.initializedPromise, throwsStateError);
  });
}

final class _RecordingPersistence implements PreferencePersistence {
  _RecordingPersistence(this.result);

  final PreferenceReadResult result;
  final List<Map<String, Object?>> writes = <Map<String, Object?>>[];

  @override
  Future<PreferenceReadResult> read(Map<String, Object?> defaults) async =>
      result;

  @override
  Future<void> write(Map<String, Object?> preferences) async {
    writes.add(Map<String, Object?>.of(preferences));
  }
}

final class _DelayedPersistence implements PreferencePersistence {
  _DelayedPersistence(this.result);

  final Future<PreferenceReadResult> result;

  @override
  Future<PreferenceReadResult> read(Map<String, Object?> defaults) => result;

  @override
  Future<void> write(Map<String, Object?> preferences) async {}
}

final class _FailingPersistence implements PreferencePersistence {
  @override
  Future<PreferenceReadResult> read(Map<String, Object?> defaults) async {
    throw StateError('storage unavailable');
  }

  @override
  Future<void> write(Map<String, Object?> preferences) async {}
}
