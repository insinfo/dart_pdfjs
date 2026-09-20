import 'package:test/test.dart';

import '../../example/src/app_options.dart';

void main() {
  setUp(AppOptions.reset);

  group('OptionKind', () {
    test('uses upstream bit values', () {
      expect(OptionKind.browser, 0x01);
      expect(OptionKind.viewer, 0x02);
      expect(OptionKind.api, 0x04);
      expect(OptionKind.worker, 0x08);
      expect(OptionKind.eventDispatch, 0x10);
      expect(OptionKind.preference, 0x80);
    });

    test('every public kind has options', () {
      for (final kind in <int>[
        OptionKind.browser,
        OptionKind.viewer,
        OptionKind.api,
        OptionKind.worker,
        OptionKind.preference,
      ]) {
        expect(AppOptions.getAll(kind: kind), isNotEmpty);
      }
    });

    test('preference count remains compatible with mozilla-central', () {
      expect(
        AppOptions.getAll(kind: OptionKind.preference).length,
        lessThanOrEqualTo(50),
      );
    });
  });

  group('defaults', () {
    test('contains representative browser, viewer, API and worker values', () {
      expect(AppOptions.get('maxCanvasDim'), 32767);
      expect(AppOptions.get('annotationMode'), 2);
      expect(AppOptions.get('maxCanvasPixels'), 33554432);
      expect(AppOptions.get('cMapPacked'), isTrue);
      expect(AppOptions.get('workerSrc'), '../src/pdf.worker.js');
      expect(
        AppOptions.get('defaultUrl'),
        'compressed.tracemonkey-pldi-09.pdf',
      );
      expect(AppOptions.get('useSystemFonts'), isNull);
    });

    test('defaultOnly ignores current overrides', () {
      AppOptions.set('annotationMode', 9);
      expect(
        AppOptions.getAll(kind: OptionKind.viewer)['annotationMode'],
        9,
      );
      expect(
        AppOptions.getAll(
          kind: OptionKind.viewer,
          defaultOnly: true,
        )['annotationMode'],
        2,
      );
    });

    test('combined mask includes either kind', () {
      final values = AppOptions.getAll(
        kind: OptionKind.worker | OptionKind.browser,
      );
      expect(values, contains('workerSrc'));
      expect(values, contains('supportsPrinting'));
      expect(values, isNot(contains('annotationMode')));
    });

    test('zero or omitted mask returns all options', () {
      expect(AppOptions.getAll(kind: 0), AppOptions.getAll());
      expect(AppOptions.getAll(), hasLength(AppOptions.definitions.length));
    });

    test('uses supplied locale and strips document fragment', () {
      AppOptions.reset(
        environment: const AppOptionsEnvironment(
          language: 'pt-BR',
          documentUrl: 'https://example.test/viewer.html#page=4',
        ),
      );
      expect(AppOptions.get('localeProperties'), {'lang': 'pt-BR'});
      expect(
        AppOptions.get('docBaseUrl'),
        'https://example.test/viewer.html',
      );
    });

    test('limits canvas size and system fonts on Android', () {
      AppOptions.reset(
        environment: const AppOptionsEnvironment(
          userAgent: 'Mozilla/5.0 (Linux; Android 15)',
        ),
      );
      expect(AppOptions.get('maxCanvasPixels'), 5242880);
      expect(AppOptions.get('useSystemFonts'), isFalse);
    });

    test('detects iOS and iPad desktop mode', () {
      AppOptions.reset(
        environment: const AppOptionsEnvironment(
          userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0)',
        ),
      );
      expect(AppOptions.get('maxCanvasPixels'), 5242880);

      AppOptions.reset(
        environment: const AppOptionsEnvironment(
          platform: 'MacIntel',
          maxTouchPoints: 5,
        ),
      );
      expect(AppOptions.get('maxCanvasPixels'), 5242880);
    });
  });

  group('set and setAll', () {
    test('sets known option with matching type', () {
      AppOptions.set('defaultZoomValue', 'page-width');
      expect(AppOptions.get('defaultZoomValue'), 'page-width');
      expect(AppOptions.hasInvokedSet, isTrue);
    });

    test('ignores unknown options', () {
      AppOptions.set('doesNotExist', true);
      expect(AppOptions.get('doesNotExist'), isNull);
      expect(AppOptions.getAll(), isNot(contains('doesNotExist')));
    });

    test('ignores mismatched primitive types', () {
      AppOptions.setAll(<String, Object?>{
        'annotationMode': '2',
        'enableXfa': 1,
        'defaultZoomValue': false,
      });
      expect(AppOptions.get('annotationMode'), 2);
      expect(AppOptions.get('enableXfa'), isTrue);
      expect(AppOptions.get('defaultZoomValue'), '');
    });

    test('accepts nullable flags and object-valued options', () {
      AppOptions.set('useSystemFonts', true);
      expect(AppOptions.get('useSystemFonts'), isTrue);
      AppOptions.set('useSystemFonts', null);
      expect(AppOptions.get('useSystemFonts'), isNull);

      final worker = Object();
      AppOptions.set('workerPort', worker);
      expect(AppOptions.get('workerPort'), same(worker));

      final events = <String, Object?>{'pagerendered': true};
      AppOptions.set('allowedGlobalEvents', events);
      expect(AppOptions.get('allowedGlobalEvents'), same(events));
    });

    test('preference update rejects unrelated API-only options', () {
      AppOptions.setAll(<String, Object?>{
        'verbosity': 5,
        'disableRange': true,
        'supportsPrinting': false,
      }, prefs: true);
      expect(AppOptions.get('verbosity'), 1);
      expect(AppOptions.get('disableRange'), isTrue);
      expect(AppOptions.get('supportsPrinting'), isFalse);
    });

    test('all setAll calls mark the upstream invoked-set flag', () {
      AppOptions.setAll(
        <String, Object?>{'disableRange': true},
        prefs: true,
      );
      expect(AppOptions.hasInvokedSet, isTrue);
    });

    test('checkDisablePreferences warns after an explicit set', () {
      final warnings = <String>[];
      AppOptions.warningListener = warnings.add;
      AppOptions.set('annotationMode', 1);
      expect(AppOptions.checkDisablePreferences(), isFalse);
      expect(warnings.single, contains('may override manually set'));
    });

    test('dispatches lower-case events after all updates', () {
      final events = <MapEntry<String, Map<String, Object?>>>[];
      AppOptions.eventDispatcher = (name, detail) {
        events.add(MapEntry(name, detail));
        expect(AppOptions.get('enableGuessAltText'), isFalse);
        expect(AppOptions.get('toolbarDensity'), 2);
      };
      AppOptions.setAll(<String, Object?>{
        'enableGuessAltText': false,
        'toolbarDensity': 2,
        'annotationMode': 1,
      });
      expect(events.map((event) => event.key), <String>[
        'enableguessalttext',
        'toolbardensity',
      ]);
      expect(events.first.value['source'], AppOptions);
      expect(events.first.value['value'], isFalse);
    });

    test('reset clears overrides, event dispatcher and state flag', () {
      AppOptions.eventDispatcher = (_, __) {};
      AppOptions.set('annotationMode', 7);
      AppOptions.reset();
      expect(AppOptions.get('annotationMode'), 2);
      expect(AppOptions.eventDispatcher, isNull);
      expect(AppOptions.hasInvokedSet, isFalse);
    });
  });

  group('definition invariants', () {
    test('preference defaults are scalar and never browser options', () {
      for (final entry in AppOptions.definitions.entries) {
        final definition = entry.value;
        if ((definition.kind & OptionKind.preference) == 0) continue;
        expect(definition.kind, isNot(OptionKind.preference),
            reason: entry.key);
        expect(
          definition.kind & OptionKind.browser,
          0,
          reason: entry.key,
        );
        expect(
          definition.value is bool ||
              definition.value is int ||
              definition.value is String,
          isTrue,
          reason: entry.key,
        );
      }
    });

    test('browser defaults are defined (null object is allowed)', () {
      for (final entry in AppOptions.definitions.entries) {
        if ((entry.value.kind & OptionKind.browser) == 0) continue;
        if (entry.key == 'allowedGlobalEvents') {
          expect(entry.value.value, isNull);
        } else {
          expect(entry.value.value, isNotNull, reason: entry.key);
        }
      }
    });
  });
}
