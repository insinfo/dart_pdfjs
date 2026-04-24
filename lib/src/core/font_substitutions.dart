// Copyright 2023 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import '../shared/util.dart';
import 'core_utils.dart';
import 'fonts_utils.dart';

class FontStyleInfo {
  const FontStyleInfo({
    required this.style,
    required this.weight,
  });

  final String style;
  final String weight;
}

class FontSubstitution {
  const FontSubstitution({
    this.alias,
    this.local,
    this.path,
    this.fallback,
    this.style,
    this.ultimate,
  });

  final String? alias;
  final List<String>? local;
  final String? path;
  final String? fallback;
  final FontStyleInfo? style;
  final String? ultimate;
}

class GeneratedFont {
  const GeneratedFont({
    this.style,
    this.ultimate,
  });

  final FontStyleInfo? style;
  final String? ultimate;
}

class FontSubstitutionInfo {
  const FontSubstitutionInfo({
    required this.css,
    required this.guessFallback,
    required this.loadedName,
    required this.baseFontName,
    required this.src,
    required this.style,
  });

  final String css;
  final bool guessFallback;
  final String loadedName;
  final String baseFontName;
  final String src;
  final FontStyleInfo style;
}

abstract class FontSubstitutionIdFactory {
  String getDocId();
  String createFontId();
}

const normalFontStyle = FontStyleInfo(style: 'normal', weight: 'normal');
const boldFontStyle = FontStyleInfo(style: 'normal', weight: 'bold');
const italicFontStyle = FontStyleInfo(style: 'italic', weight: 'normal');
const boldItalicFontStyle = FontStyleInfo(style: 'italic', weight: 'bold');
const blackFontStyle = FontStyleInfo(style: 'normal', weight: '900');
const blackItalicFontStyle = FontStyleInfo(style: 'italic', weight: '900');

const Map<String, FontSubstitution> substitutionMap = {
  'Times-Roman': FontSubstitution(
    local: [
      'Times New Roman',
      'Times-Roman',
      'Times',
      'Liberation Serif',
      'Nimbus Roman',
      'Nimbus Roman L',
      'Tinos',
      'Thorndale',
      'TeX Gyre Termes',
      'FreeSerif',
      'Linux Libertine O',
      'Libertinus Serif',
      'PT Astra Serif',
      'DejaVu Serif',
      'Bitstream Vera Serif',
      'Ubuntu',
    ],
    style: normalFontStyle,
    ultimate: 'serif',
  ),
  'Times-Bold': FontSubstitution(
    alias: 'Times-Roman',
    style: boldFontStyle,
    ultimate: 'serif',
  ),
  'Times-Italic': FontSubstitution(
    alias: 'Times-Roman',
    style: italicFontStyle,
    ultimate: 'serif',
  ),
  'Times-BoldItalic': FontSubstitution(
    alias: 'Times-Roman',
    style: boldItalicFontStyle,
    ultimate: 'serif',
  ),
  'Helvetica': FontSubstitution(
    local: [
      'Helvetica',
      'Helvetica Neue',
      'Arial',
      'Arial Nova',
      'Liberation Sans',
      'Arimo',
      'Nimbus Sans',
      'Nimbus Sans L',
      'A030',
      'TeX Gyre Heros',
      'FreeSans',
      'DejaVu Sans',
      'Albany',
      'Bitstream Vera Sans',
      'Arial Unicode MS',
      'Microsoft Sans Serif',
      'Apple Symbols',
      'Cantarell',
    ],
    path: 'LiberationSans-Regular.ttf',
    style: normalFontStyle,
    ultimate: 'sans-serif',
  ),
  'Helvetica-Bold': FontSubstitution(
    alias: 'Helvetica',
    path: 'LiberationSans-Bold.ttf',
    style: boldFontStyle,
    ultimate: 'sans-serif',
  ),
  'Helvetica-Oblique': FontSubstitution(
    alias: 'Helvetica',
    path: 'LiberationSans-Italic.ttf',
    style: italicFontStyle,
    ultimate: 'sans-serif',
  ),
  'Helvetica-BoldOblique': FontSubstitution(
    alias: 'Helvetica',
    path: 'LiberationSans-BoldItalic.ttf',
    style: boldItalicFontStyle,
    ultimate: 'sans-serif',
  ),
  'Courier': FontSubstitution(
    local: [
      'Courier',
      'Courier New',
      'Liberation Mono',
      'Nimbus Mono',
      'Nimbus Mono L',
      'Cousine',
      'Cumberland',
      'TeX Gyre Cursor',
      'FreeMono',
      'Linux Libertine Mono O',
      'Libertinus Mono',
    ],
    style: normalFontStyle,
    ultimate: 'monospace',
  ),
  'Courier-Bold': FontSubstitution(
    alias: 'Courier',
    style: boldFontStyle,
    ultimate: 'monospace',
  ),
  'Courier-Oblique': FontSubstitution(
    alias: 'Courier',
    style: italicFontStyle,
    ultimate: 'monospace',
  ),
  'Courier-BoldOblique': FontSubstitution(
    alias: 'Courier',
    style: boldItalicFontStyle,
    ultimate: 'monospace',
  ),
  'ArialBlack': FontSubstitution(
    local: ['Arial Black'],
    style: blackFontStyle,
    fallback: 'Helvetica-Bold',
  ),
  'ArialBlack-Bold': FontSubstitution(alias: 'ArialBlack'),
  'ArialBlack-Italic': FontSubstitution(
    alias: 'ArialBlack',
    style: blackItalicFontStyle,
    fallback: 'Helvetica-BoldOblique',
  ),
  'ArialBlack-BoldItalic': FontSubstitution(alias: 'ArialBlack-Italic'),
  'ArialNarrow': FontSubstitution(
    local: [
      'Arial Narrow',
      'Liberation Sans Narrow',
      'Helvetica Condensed',
      'Nimbus Sans Narrow',
      'TeX Gyre Heros Cn',
    ],
    style: normalFontStyle,
    fallback: 'Helvetica',
  ),
  'ArialNarrow-Bold': FontSubstitution(
    alias: 'ArialNarrow',
    style: boldFontStyle,
    fallback: 'Helvetica-Bold',
  ),
  'ArialNarrow-Italic': FontSubstitution(
    alias: 'ArialNarrow',
    style: italicFontStyle,
    fallback: 'Helvetica-Oblique',
  ),
  'ArialNarrow-BoldItalic': FontSubstitution(
    alias: 'ArialNarrow',
    style: boldItalicFontStyle,
    fallback: 'Helvetica-BoldOblique',
  ),
  'Calibri': FontSubstitution(
    local: ['Calibri', 'Carlito'],
    style: normalFontStyle,
    fallback: 'Helvetica',
  ),
  'Calibri-Bold': FontSubstitution(
    alias: 'Calibri',
    style: boldFontStyle,
    fallback: 'Helvetica-Bold',
  ),
  'Calibri-Italic': FontSubstitution(
    alias: 'Calibri',
    style: italicFontStyle,
    fallback: 'Helvetica-Oblique',
  ),
  'Calibri-BoldItalic': FontSubstitution(
    alias: 'Calibri',
    style: boldItalicFontStyle,
    fallback: 'Helvetica-BoldOblique',
  ),
  'Wingdings': FontSubstitution(
    local: ['Wingdings', 'URW Dingbats'],
    style: normalFontStyle,
  ),
  'Wingdings-Regular': FontSubstitution(alias: 'Wingdings'),
  'Wingdings-Bold': FontSubstitution(alias: 'Wingdings'),
  '\xCB\xCE\xCC\xE5': FontSubstitution(
    local: ['SimSun', 'SimSun Regular', 'NSimSun'],
    style: normalFontStyle,
    ultimate: 'serif',
  ),
  '\xBA\xDA\xCC\xE5': FontSubstitution(
    local: ['SimHei', 'SimHei Regular'],
    style: normalFontStyle,
    ultimate: 'sans-serif',
  ),
  '\xBF\xAC\xCC\xE5': FontSubstitution(
    local: ['KaiTi', 'SimKai', 'SimKai Regular'],
    style: normalFontStyle,
    ultimate: 'sans-serif',
  ),
  '\xB7\xC2\xCB\xCE': FontSubstitution(
    local: ['FangSong', 'SimFang', 'SimFang Regular'],
    style: normalFontStyle,
    ultimate: 'serif',
  ),
  '\xBF\xAC\xCC\xE5_GB2312': FontSubstitution(alias: '\xBF\xAC\xCC\xE5'),
  '\xB7\xC2\xCB\xCE_GB2312': FontSubstitution(alias: '\xB7\xC2\xCB\xCE'),
  '\xC1\xA5\xCA\xE9': FontSubstitution(
    local: ['SimLi', 'SimLi Regular'],
    style: normalFontStyle,
    ultimate: 'serif',
  ),
  '\xD0\xC2\xCB\xCE': FontSubstitution(alias: '\xCB\xCE\xCC\xE5'),
};

const Map<String, String> fontAliases = {
  'Arial-Black': 'ArialBlack',
};

String getStyleToAppend(FontStyleInfo? style) {
  if (identical(style, boldFontStyle)) {
    return 'Bold';
  }
  if (identical(style, italicFontStyle)) {
    return 'Italic';
  }
  if (identical(style, boldItalicFontStyle)) {
    return 'Bold Italic';
  }
  if (style?.weight == 'bold') {
    return 'Bold';
  }
  if (style?.style == 'italic') {
    return 'Italic';
  }
  return '';
}

String getFamilyName(String str) {
  const keywords = {
    'thin',
    'extralight',
    'ultralight',
    'demilight',
    'semilight',
    'light',
    'book',
    'regular',
    'normal',
    'medium',
    'demibold',
    'semibold',
    'bold',
    'extrabold',
    'ultrabold',
    'black',
    'heavy',
    'extrablack',
    'ultrablack',
    'roman',
    'italic',
    'oblique',
    'ultracondensed',
    'extracondensed',
    'condensed',
    'semicondensed',
    'semiexpanded',
    'expanded',
    'extraexpanded',
    'ultraexpanded',
    'bolditalic',
  };
  return str
      .split(RegExp(r'[- ,+]+'))
      .where((token) => !keywords.contains(token.toLowerCase()))
      .join(' ');
}

GeneratedFont generateFont(
  FontSubstitution substitution,
  List<String> src,
  String? localFontPath, {
  bool useFallback = true,
  bool usePath = true,
  String append = '',
}) {
  FontStyleInfo? resultStyle;
  String? resultUltimate;

  final local = substitution.local;
  if (local != null) {
    final extra = append.isNotEmpty ? ' $append' : '';
    for (final name in local) {
      src.add('local($name$extra)');
    }
  }

  final alias = substitution.alias;
  if (alias != null) {
    final aliasSubstitution = substitutionMap[alias];
    if (aliasSubstitution != null) {
      final aliasAppend =
          append.isNotEmpty ? append : getStyleToAppend(substitution.style);
      final generated = generateFont(
        aliasSubstitution,
        src,
        localFontPath,
        useFallback: useFallback && substitution.fallback == null,
        usePath: usePath && substitution.path == null,
        append: aliasAppend,
      );
      resultStyle = generated.style;
      resultUltimate = generated.ultimate;
    }
  }

  if (substitution.style != null) {
    resultStyle = substitution.style;
  }
  if (substitution.ultimate != null) {
    resultUltimate = substitution.ultimate;
  }

  final fallback = substitution.fallback;
  if (useFallback && fallback != null) {
    final fallbackInfo = substitutionMap[fallback];
    if (fallbackInfo != null) {
      final generated = generateFont(
        fallbackInfo,
        src,
        localFontPath,
        useFallback: useFallback,
        usePath: usePath && substitution.path == null,
        append: append,
      );
      resultUltimate ??= generated.ultimate;
    }
  }

  if (usePath && substitution.path != null && localFontPath != null) {
    src.add('url($localFontPath${substitution.path})');
  }

  return GeneratedFont(style: resultStyle, ultimate: resultUltimate);
}

FontSubstitutionInfo? getFontSubstitution(
  Map<String, FontSubstitutionInfo?> systemFontCache,
  FontSubstitutionIdFactory idFactory,
  String? localFontPath,
  String baseFontName,
  String? standardFontName,
  String type,
) {
  if (baseFontName.startsWith('InvalidPDFjsFont_')) {
    return null;
  }

  if ((type == 'TrueType' || type == 'Type1') &&
      RegExp(r'^[A-Z]{6}\+').hasMatch(baseFontName)) {
    baseFontName = baseFontName.substring(7);
  }

  baseFontName = normalizeFontName(baseFontName);

  final key = baseFontName;
  if (systemFontCache.containsKey(key)) {
    return systemFontCache[key];
  }

  var substitution = substitutionMap[baseFontName];
  if (substitution == null) {
    for (final entry in fontAliases.entries) {
      if (baseFontName.startsWith(entry.key)) {
        baseFontName =
            '${entry.value}${baseFontName.substring(entry.key.length)}';
        substitution = substitutionMap[baseFontName];
        break;
      }
    }
  }

  var mustAddBaseFont = false;
  if (substitution == null) {
    substitution = substitutionMap[standardFontName];
    mustAddBaseFont = true;
  }

  final loadedName = '${idFactory.getDocId()}_s${idFactory.createFontId()}';
  if (substitution == null) {
    if (!validateFontName(baseFontName)) {
      warn('Cannot substitute the font because of its name: $baseFontName');
      systemFontCache[key] = null;
      return null;
    }

    final bold = RegExp('bold', caseSensitive: false).hasMatch(baseFontName);
    final italic =
        RegExp('oblique|italic', caseSensitive: false).hasMatch(baseFontName);
    final style = bold && italic
        ? boldItalicFontStyle
        : bold
            ? boldFontStyle
            : italic
                ? italicFontStyle
                : normalFontStyle;
    final substitutionInfo = FontSubstitutionInfo(
      css: '"${getFamilyName(baseFontName)}",$loadedName',
      guessFallback: true,
      loadedName: loadedName,
      baseFontName: baseFontName,
      src: 'local($baseFontName)',
      style: style,
    );
    systemFontCache[key] = substitutionInfo;
    return substitutionInfo;
  }

  final src = <String>[];
  if (mustAddBaseFont && validateFontName(baseFontName)) {
    src.add('local($baseFontName)');
  }

  final generated = generateFont(substitution, src, localFontPath);
  final guessFallback = generated.ultimate == null;
  final fallback = guessFallback ? '' : ',${generated.ultimate}';

  final substitutionInfo = FontSubstitutionInfo(
    css: '"${getFamilyName(baseFontName)}",$loadedName$fallback',
    guessFallback: guessFallback,
    loadedName: loadedName,
    baseFontName: baseFontName,
    src: src.join(','),
    style: generated.style ?? normalFontStyle,
  );
  systemFontCache[key] = substitutionInfo;

  return substitutionInfo;
}
