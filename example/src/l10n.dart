// Copyright 2023 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

/// One localization message requested from a backend.
class L10nRequest {
  final String id;
  final Map<String, dynamic>? args;

  const L10nRequest(this.id, {this.args});
}

/// One formatted localization message.
class L10nMessage {
  final String? value;

  const L10nMessage(this.value);
}

/// Adapter implemented by Fluent DOM or another localization engine.
abstract interface class LocalizationBackend {
  Future<List<L10nMessage>> formatMessages(List<L10nRequest> requests);

  void connectRoot(Object element);

  Future<void> translateRoots();

  Future<void> translateElements(List<Object> elements);

  void disconnectRoot(Object element);

  void pauseObserving();

  void resumeObserving();
}

/// Language and DOM-localization facade used throughout the viewer.
///
/// Language codes are normalized to lowercase, matching PDF.js. An explicit
/// [isRtl] value overrides the direction inferred from the language.
class L10n {
  static const Map<String, String> _partialLanguageCodes = {
    'en': 'en-us',
    'es': 'es-es',
    'fy': 'fy-nl',
    'ga': 'ga-ie',
    'gu': 'gu-in',
    'hi': 'hi-in',
    'hy': 'hy-am',
    'nb': 'nb-no',
    'ne': 'ne-np',
    'nn': 'nn-no',
    'pa': 'pa-in',
    'pt': 'pt-pt',
    'sv': 'sv-se',
    'zh': 'zh-cn',
  };

  static const Set<String> _rtlLanguages = {'ar', 'he', 'fa', 'ps', 'ur'};

  final String _lang;
  final String _direction;
  final Set<Object> _elements = Set.identity();
  LocalizationBackend? _backend;

  L10n({String? lang, bool? isRtl, LocalizationBackend? backend})
      : _lang = fixupLanguageCode(lang),
        _direction =
            (isRtl ?? isRtlLanguage(fixupLanguageCode(lang))) ? 'rtl' : 'ltr',
        _backend = backend;

  String getLanguage() => _lang;

  String getDirection() => _direction;

  void setL10n(LocalizationBackend backend) {
    _backend = backend;
  }

  /// Gets one translated string, falling back when the backend has no value.
  Future<String?> get(
    String id, {
    Map<String, dynamic>? args,
    String? fallback,
  }) async {
    final backend = _requireBackend();
    final messages = await backend.formatMessages([
      L10nRequest(id, args: args),
    ]);
    if (messages.isEmpty) return fallback;
    final value = messages.first.value;
    return value == null || value.isEmpty ? fallback : value;
  }

  /// Gets several translated strings in the same order as [ids].
  Future<List<String?>> getAll(List<String> ids) async {
    final backend = _requireBackend();
    final messages = await backend.formatMessages(
      [for (final id in ids) L10nRequest(id)],
    );
    return [for (final message in messages) message.value];
  }

  /// Connects [element] as a localization root and translates all roots.
  Future<void> translate(Object element) async {
    final backend = _requireBackend();
    _elements.add(element);
    try {
      backend.connectRoot(element);
      await backend.translateRoots();
    } catch (_) {
      // The element may already be under another connected root.
    }
  }

  /// Translates [element] once without observing it for future changes.
  Future<void> translateOnce(Object element) async {
    try {
      await _requireBackend().translateElements([element]);
    } catch (_) {
      // PDF.js deliberately treats translation errors as non-fatal.
    }
  }

  Future<void> destroy() async {
    final backend = _requireBackend();
    for (final element in _elements) {
      backend.disconnectRoot(element);
    }
    _elements.clear();
    backend.pauseObserving();
  }

  void pause() => _requireBackend().pauseObserving();

  void resume() => _requireBackend().resumeObserving();

  LocalizationBackend _requireBackend() {
    final backend = _backend;
    if (backend == null) {
      throw StateError('No localization backend has been configured.');
    }
    return backend;
  }

  static String fixupLanguageCode(String? languageCode) {
    final normalized = languageCode?.toLowerCase() ?? '';
    final language = normalized.isEmpty ? 'en-us' : normalized;
    return _partialLanguageCodes[language] ?? language;
  }

  static bool isRtlLanguage(String language) {
    final separator = language.indexOf('-');
    final shortCode =
        separator < 0 ? language : language.substring(0, separator);
    return _rtlLanguages.contains(shortCode);
  }
}

/// The browser-specific GenericL10n implementation is ported separately.
typedef GenericL10n = L10n;
