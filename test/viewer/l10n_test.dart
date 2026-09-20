import 'package:test/test.dart';

import '../../example/src/l10n.dart';

void main() {
  group('language and direction', () {
    test('normalizes complete and partial language codes', () {
      expect(L10n(lang: 'PT').getLanguage(), 'pt-pt');
      expect(L10n(lang: 'PT-BR').getLanguage(), 'pt-br');
      expect(L10n(lang: '').getLanguage(), 'en-us');
      expect(L10n().getLanguage(), 'en-us');
    });

    test('infers RTL direction and accepts an override', () {
      expect(L10n(lang: 'ar-EG').getDirection(), 'rtl');
      expect(L10n(lang: 'he').getDirection(), 'rtl');
      expect(L10n(lang: 'en').getDirection(), 'ltr');
      expect(L10n(lang: 'ar', isRtl: false).getDirection(), 'ltr');
    });
  });

  group('backend', () {
    test('formats one or several messages and applies fallback', () async {
      final backend = _FakeBackend({
        'hello': 'Olá',
        'empty': '',
      });
      final l10n = L10n(lang: 'pt-BR', backend: backend);

      expect(await l10n.get('hello'), 'Olá');
      expect(await l10n.get('missing', fallback: 'Ausente'), 'Ausente');
      expect(await l10n.get('empty', fallback: 'Vazio'), 'Vazio');
      expect(await l10n.getAll(['hello', 'missing']), ['Olá', null]);
    });

    test('connects roots, translates once, pauses and resumes', () async {
      final backend = _FakeBackend(const {});
      final l10n = L10n(backend: backend);
      final root = Object();
      final child = Object();

      await l10n.translate(root);
      await l10n.translateOnce(child);
      l10n.pause();
      l10n.resume();

      expect(backend.connected, [root]);
      expect(backend.translatedElements.single, [child]);
      expect(backend.translateRootsCount, 1);
      expect(backend.pauseCount, 1);
      expect(backend.resumeCount, 1);

      await l10n.destroy();
      expect(backend.disconnected, [root]);
      expect(backend.pauseCount, 2);
    });

    test('translation failures remain non-fatal', () async {
      final backend = _FakeBackend(const {})
        ..throwOnConnect = true
        ..throwOnElements = true;
      final l10n = L10n(backend: backend);

      await expectLater(l10n.translate(Object()), completes);
      await expectLater(l10n.translateOnce(Object()), completes);
    });

    test('requires a configured backend for backend operations', () async {
      final l10n = L10n();
      await expectLater(l10n.get('x'), throwsStateError);
      expect(l10n.pause, throwsStateError);
    });
  });
}

class _FakeBackend implements LocalizationBackend {
  final Map<String, String> values;
  final List<Object> connected = [];
  final List<Object> disconnected = [];
  final List<List<Object>> translatedElements = [];
  var translateRootsCount = 0;
  var pauseCount = 0;
  var resumeCount = 0;
  var throwOnConnect = false;
  var throwOnElements = false;

  _FakeBackend(this.values);

  @override
  void connectRoot(Object element) {
    if (throwOnConnect) throw StateError('already connected');
    connected.add(element);
  }

  @override
  void disconnectRoot(Object element) => disconnected.add(element);

  @override
  Future<List<L10nMessage>> formatMessages(List<L10nRequest> requests) async {
    return [for (final request in requests) L10nMessage(values[request.id])];
  }

  @override
  void pauseObserving() => pauseCount++;

  @override
  void resumeObserving() => resumeCount++;

  @override
  Future<void> translateElements(List<Object> elements) async {
    if (throwOnElements) throw StateError('translation failed');
    translatedElements.add(elements);
  }

  @override
  Future<void> translateRoots() async => translateRootsCount++;
}
