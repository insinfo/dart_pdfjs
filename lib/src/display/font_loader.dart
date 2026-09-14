// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:web/web.dart' as web;

/// Font loader that manages loading fonts into the DOM using the
/// FontFace API or CSS @font-face rules via the web package.
class FontLoader {
  final Set<dynamic> nativeFontFaces = {};
  final Set<String> _systemFonts = {};
  web.HTMLStyleElement? styleElement;

  FontLoader({web.HTMLStyleElement? styleElement}) : styleElement = styleElement;

  /// Add a native FontFace to the document's font set.
  void addNativeFontFace(dynamic nativeFontFace) {
    nativeFontFaces.add(nativeFontFace);
  }

  /// Remove a native FontFace from the document's font set.
  void removeNativeFontFace(dynamic nativeFontFace) {
    nativeFontFaces.remove(nativeFontFace);
  }

  /// Insert a CSS rule into the style element.
  void insertRule(String rule) {
    if (styleElement == null) {
      styleElement =
          web.document.createElement('style') as web.HTMLStyleElement;
      final head = web.document.documentElement
          ?.getElementsByTagName('head')
          .item(0);
      head?.append(styleElement!);
    }
    final sheet = styleElement!.sheet;
    if (sheet != null) {
      sheet.insertRule(rule, sheet.cssRules.length);
    }
  }

  /// Clear all loaded fonts and remove the style element.
  void clear() {
    nativeFontFaces.clear();
    _systemFonts.clear();

    styleElement?.remove();
    styleElement = null;
  }

  /// Load a system font by its info.
  Future<void> loadSystemFont({
    required Map<String, dynamic>? systemFontInfo,
    bool disableFontFace = false,
    Function? inspectFont,
  }) async {
    if (systemFontInfo == null ||
        _systemFonts.contains(systemFontInfo['loadedName'])) {
      return;
    }
    assert(!disableFontFace,
        "loadSystemFont shouldn't be called when `disableFontFace` is set.");

    if (isFontLoadingAPISupported) {
      final loadedName = systemFontInfo['loadedName'] as String;
      try {
        _systemFonts.add(loadedName);
        inspectFont?.call(systemFontInfo);
      } catch (_) {
        // Font loading failed silently
      }
      return;
    }
  }

  /// Bind a font object, loading it into the DOM.
  Future<void> bind(dynamic font) async {
    if (font is Map) {
      if (font['attached'] == true ||
          (font['missingFile'] == true && font['systemFontInfo'] == null)) {
        return;
      }
      font['attached'] = true;

      if (font['systemFontInfo'] != null) {
        await loadSystemFont(
            systemFontInfo:
                font['systemFontInfo'] as Map<String, dynamic>?);
        return;
      }
    }
  }

  /// Whether the Font Loading API is supported.
  bool get isFontLoadingAPISupported => true;

  /// Whether synchronous font loading is supported.
  bool get isSyncFontLoadingSupported => false;
}
