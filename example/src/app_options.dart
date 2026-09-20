// Copyright 2018 Mozilla Foundation
// SPDX-License-Identifier: Apache-2.0

import 'app_options_environment_stub.dart'
    if (dart.library.js_interop) 'app_options_environment_web.dart'
    as environment_reader;

/// Bit masks used to select groups of viewer options.
abstract final class OptionKind {
  static const int browser = 0x01;
  static const int viewer = 0x02;
  static const int api = 0x04;
  static const int worker = 0x08;
  static const int eventDispatch = 0x10;
  static const int preference = 0x80;
}

abstract final class OptionType {
  static const int boolean = 0x01;
  static const int number = 0x02;
  static const int object = 0x04;
  static const int string = 0x08;
  static const int undefined = 0x10;
}

typedef AppOptionEventListener = void Function(
  String eventName,
  Map<String, Object?> detail,
);

typedef AppOptionWarningListener = void Function(String message);

final class AppOptionDefinition {
  const AppOptionDefinition(this.value, this.kind, [this.type]);

  final Object? value;
  final int kind;
  final int? type;
}

/// Runtime data that differs between browser engines and test environments.
final class AppOptionsEnvironment {
  const AppOptionsEnvironment({
    this.language = 'en-US',
    this.documentUrl = '',
    this.userAgent = '',
    this.platform = '',
    this.maxTouchPoints = 0,
    this.isGeckoView = false,
  });

  final String language;
  final String documentUrl;
  final String userAgent;
  final String platform;
  final int maxTouchPoints;
  final bool isGeckoView;

  factory AppOptionsEnvironment.browser() {
    final values = environment_reader.readAppOptionsEnvironment();
    return AppOptionsEnvironment(
      language: values['language'] as String? ?? 'en-US',
      documentUrl: values['documentUrl'] as String? ?? '',
      userAgent: values['userAgent'] as String? ?? '',
      platform: values['platform'] as String? ?? '',
      maxTouchPoints: values['maxTouchPoints'] as int? ?? 0,
      isGeckoView: values['isGeckoView'] as bool? ?? false,
    );
  }

  bool get isAndroid => userAgent.contains('Android');

  bool get isIOS =>
      RegExp(r'\b(iPad|iPhone|iPod)(?=;)').hasMatch(userAgent) ||
      (platform == 'MacIntel' && maxTouchPoints > 1);
}

/// Central registry for PDF.js viewer, API and worker options.
abstract final class AppOptions {
  static AppOptionEventListener? eventDispatcher;
  static AppOptionWarningListener? warningListener;
  static bool _hasInvokedSet = false;
  static AppOptionsEnvironment _environment = AppOptionsEnvironment.browser();
  static late Map<String, AppOptionDefinition> _defaults =
      _createDefaults(_environment);
  static late Map<String, Object?> _options = _defaultValues(_defaults);

  static Map<String, AppOptionDefinition> _createDefaults(
    AppOptionsEnvironment environment,
  ) {
    const b = OptionKind.browser;
    const v = OptionKind.viewer;
    const a = OptionKind.api;
    const w = OptionKind.worker;
    const e = OptionKind.eventDispatch;
    const p = OptionKind.preference;
    final documentUrl = environment.documentUrl.split('#').first;

    final definitions = <String, AppOptionDefinition>{
      'allowedGlobalEvents': const AppOptionDefinition(null, b),
      'canvasMaxAreaInBytes': const AppOptionDefinition(-1, b + a),
      'isInAutomation': const AppOptionDefinition(false, b),
      'localeProperties': AppOptionDefinition(
        <String, String>{'lang': environment.language},
        b,
      ),
      'maxCanvasDim': const AppOptionDefinition(32767, b + v),
      'nimbusDataStr': const AppOptionDefinition('', b),
      'supportsCaretBrowsingMode': const AppOptionDefinition(false, b),
      'supportsDocumentFonts': const AppOptionDefinition(true, b),
      'supportsIntegratedFind': const AppOptionDefinition(false, b),
      'supportsMouseWheelZoomCtrlKey': const AppOptionDefinition(true, b),
      'supportsMouseWheelZoomMetaKey': const AppOptionDefinition(true, b),
      'supportsPinchToZoom': const AppOptionDefinition(true, b),
      'supportsPrinting': const AppOptionDefinition(true, b),
      'toolbarDensity': const AppOptionDefinition(0, b + e),
      'altTextLearnMoreUrl': const AppOptionDefinition('', v + p),
      'annotationEditorMode': const AppOptionDefinition(0, v + p),
      'annotationMode': const AppOptionDefinition(2, v + p),
      'capCanvasAreaFactor': const AppOptionDefinition(200, v + p),
      'commentLearnMoreUrl': const AppOptionDefinition(
        'https://support.mozilla.org/%LOCALE%/kb/view-pdf-files-firefox-or-choose-another-viewer#w_add-a-comment-to-a-pdf',
        v + p,
      ),
      'cursorToolOnLoad': const AppOptionDefinition(0, v + p),
      'debuggerSrc': const AppOptionDefinition('./debugger.mjs', v),
      'defaultZoomDelay': const AppOptionDefinition(400, v + p),
      'defaultZoomValue': const AppOptionDefinition('', v + p),
      'disableHistory': const AppOptionDefinition(false, v),
      'disablePageLabels': const AppOptionDefinition(false, v + p),
      'enableAltText': const AppOptionDefinition(false, v + p),
      'enableAltTextModelDownload': const AppOptionDefinition(true, v + p + e),
      'enableAutoLinking': const AppOptionDefinition(true, v + p),
      'enableComment': const AppOptionDefinition(true, v + p),
      'enableDetailCanvas': const AppOptionDefinition(true, v),
      'enableGuessAltText': const AppOptionDefinition(true, v + p + e),
      'enableHighlightFloatingButton': const AppOptionDefinition(true, v + p),
      'enableMerge': const AppOptionDefinition(true, v + p),
      'enableNewAltTextWhenAddingImage': const AppOptionDefinition(true, v + p),
      'enableNewBadge': const AppOptionDefinition(true, v + p),
      'enableOptimizedPartialRendering':
          const AppOptionDefinition(false, v + p),
      'enablePermissions': const AppOptionDefinition(false, v + p),
      'enablePrintAutoRotate': const AppOptionDefinition(true, v + p),
      'enableScripting': const AppOptionDefinition(true, v + p),
      'enableSignatureEditor': const AppOptionDefinition(true, v + p),
      'enableSplitMerge': const AppOptionDefinition(true, v + p),
      'enableUpdatedAddImage': const AppOptionDefinition(false, v + p),
      'externalLinkRel': const AppOptionDefinition(
        'noopener noreferrer nofollow',
        v,
      ),
      'externalLinkTarget': const AppOptionDefinition(0, v + p),
      'highlightEditorColors': const AppOptionDefinition(
        'yellow=#FFFF98,green=#53FFBC,blue=#80EBFF,pink=#FFCBE6,red=#FF4F5F,'
        'yellow_HCM=#FFFFCC,green_HCM=#53FFBC,blue_HCM=#80EBFF,pink_HCM=#F6B8FF,red_HCM=#C50043',
        v + p,
      ),
      'historyUpdateUrl': const AppOptionDefinition(false, v + p),
      'ignoreDestinationZoom': const AppOptionDefinition(false, v + p),
      'imageResourcesPath': const AppOptionDefinition('./images/', v),
      'imagesRightClickMinSize': const AppOptionDefinition(-1, v + p),
      'maxCanvasPixels': const AppOptionDefinition(33554432, v),
      'minDurationToUpdateCanvas': const AppOptionDefinition(500, v),
      'forcePageColors': const AppOptionDefinition(false, v + p),
      'pageColorsBackground': const AppOptionDefinition('Canvas', v + p),
      'pageColorsForeground': const AppOptionDefinition('CanvasText', v + p),
      'pdfBugEnabled': const AppOptionDefinition(true, v + p),
      'printResolution': const AppOptionDefinition(150, v),
      'sidebarViewOnLoad': const AppOptionDefinition(-1, v + p),
      'scrollModeOnLoad': const AppOptionDefinition(-1, v + p),
      'spreadModeOnLoad': const AppOptionDefinition(-1, v + p),
      'textLayerMode': const AppOptionDefinition(1, v + p),
      'viewerCssTheme': const AppOptionDefinition(0, v + p),
      'viewOnLoad': const AppOptionDefinition(0, v + p),
      'cMapPacked': const AppOptionDefinition(true, a),
      'cMapUrl': const AppOptionDefinition('../external/bcmaps/', a),
      'disableAutoFetch': const AppOptionDefinition(false, a + p),
      'disableFontFace': const AppOptionDefinition(false, a + p),
      'disableRange': const AppOptionDefinition(false, a + p),
      'disableStream': const AppOptionDefinition(false, a + p),
      'docBaseUrl': AppOptionDefinition(documentUrl, a),
      'enableHWA': const AppOptionDefinition(true, a + p),
      'enableWebGPU': const AppOptionDefinition(true, a + p),
      'enableXfa': const AppOptionDefinition(true, a + p),
      'fontExtraProperties': const AppOptionDefinition(false, a),
      'iccUrl': const AppOptionDefinition('../external/iccs/', a),
      'isOffscreenCanvasSupported': const AppOptionDefinition(true, a),
      'maxImageSize': const AppOptionDefinition(-1, a),
      'pdfBug': const AppOptionDefinition(false, a),
      'standardFontDataUrl': const AppOptionDefinition(
        '../external/standard_fonts/',
        a,
      ),
      'useSystemFonts': AppOptionDefinition(
        environment.isGeckoView ? false : null,
        a,
        OptionType.boolean + OptionType.undefined,
      ),
      'verbosity': const AppOptionDefinition(1, a),
      'wasmUrl': const AppOptionDefinition('../web/wasm/', a),
      'workerPort': const AppOptionDefinition(null, w, OptionType.object),
      'workerSrc': const AppOptionDefinition('../src/pdf.worker.js', w),
      'defaultUrl': const AppOptionDefinition(
        'compressed.tracemonkey-pldi-09.pdf',
        v,
      ),
      'sandboxBundleSrc': const AppOptionDefinition(
        '../build/dev-sandbox/pdf.sandbox.mjs',
        v,
      ),
      'enableFakeMLManager': const AppOptionDefinition(true, v),
      'disablePreferences': const AppOptionDefinition(false, v),
    };
    return Map<String, AppOptionDefinition>.unmodifiable(definitions);
  }

  static Map<String, Object?> _defaultValues(
    Map<String, AppOptionDefinition> definitions,
  ) {
    final values = <String, Object?>{
      for (final entry in definitions.entries) entry.key: entry.value.value,
    };
    if (_environment.isIOS || _environment.isAndroid) {
      values['maxCanvasPixels'] = 5242880;
    }
    if (_environment.isAndroid) {
      values['useSystemFonts'] = false;
    }
    return values;
  }

  static Object? get(String name) => _options[name];

  static Map<String, Object?> getAll({int? kind, bool defaultOnly = false}) {
    final result = <String, Object?>{};
    for (final entry in _defaults.entries) {
      if (kind != null && kind != 0 && (kind & entry.value.kind) == 0) {
        continue;
      }
      result[entry.key] = defaultOnly ? entry.value.value : _options[entry.key];
    }
    return result;
  }

  static void set(String name, Object? value) {
    setAll(<String, Object?>{name: value});
  }

  static void setAll(Map<String, Object?> options, {bool prefs = false}) {
    _hasInvokedSet = true;
    final events = <String, Object?>{};
    for (final entry in options.entries) {
      final definition = _defaults[entry.key];
      if (definition == null || !_isValidType(entry.value, definition)) {
        continue;
      }
      if (prefs &&
          (definition.kind & (OptionKind.browser | OptionKind.preference)) ==
              0) {
        continue;
      }
      _options[entry.key] = entry.value;
      if (eventDispatcher != null &&
          (definition.kind & OptionKind.eventDispatch) != 0) {
        events[entry.key] = entry.value;
      }
    }
    for (final entry in events.entries) {
      eventDispatcher!(entry.key.toLowerCase(), <String, Object?>{
        'source': AppOptions,
        'value': entry.value,
      });
    }
  }

  static bool _isValidType(Object? value, AppOptionDefinition definition) {
    if (value == null) {
      return definition.value == null ||
          ((definition.type ?? 0) &
                  (OptionType.object | OptionType.undefined)) !=
              0;
    }
    if (definition.value != null) {
      if (definition.value is bool) return value is bool;
      if (definition.value is int) return value is int;
      if (definition.value is num) return value is num;
      if (definition.value is String) return value is String;
      if (definition.value is Map) return value is Map;
      return value.runtimeType == definition.value.runtimeType;
    }
    // In JavaScript `typeof null === "object"`; a null default therefore
    // accepts object values even without an explicit type mask.
    final type = definition.type ?? OptionType.object;
    return (value is bool && (type & OptionType.boolean) != 0) ||
        (value is num && (type & OptionType.number) != 0) ||
        (value is String && (type & OptionType.string) != 0) ||
        (value is! bool &&
            value is! num &&
            value is! String &&
            (type & OptionType.object) != 0);
  }

  /// Whether stored preferences must be ignored.
  static bool checkDisablePreferences() {
    if (get('disablePreferences') == true) {
      return true;
    }
    if (_hasInvokedSet) {
      warningListener?.call(
        'The Preferences may override manually set AppOptions; '
        'please use the "disablePreferences"-option to prevent that.',
      );
    }
    return false;
  }

  static bool get hasInvokedSet => _hasInvokedSet;

  static Map<String, AppOptionDefinition> get definitions => _defaults;

  /// Rebuilds all defaults for an environment and clears user overrides.
  /// Intended for viewer bootstrap and isolated tests.
  static void reset({
    AppOptionsEnvironment? environment,
  }) {
    _environment = environment ?? AppOptionsEnvironment.browser();
    _defaults = _createDefaults(_environment);
    _options = _defaultValues(_defaults);
    _hasInvokedSet = false;
    eventDispatcher = null;
    warningListener = null;
  }
}
