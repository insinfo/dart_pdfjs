// Copyright 2021 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'calibri_factors.dart';
import 'font_metrics.dart';
import 'fonts_utils.dart';
import 'helvetica_factors.dart';
import 'liberationsans_widths.dart';
import 'myriadpro_factors.dart';
import 'primitives.dart';
import 'segoeui_factors.dart';

class XfaFontInfo {
  final String name;
  final List<double>? factors;
  final List<int> baseWidths;
  final List<int> baseMapping;
  final FontMetrics? metrics;

  const XfaFontInfo({
    required this.name,
    this.factors,
    required this.baseWidths,
    required this.baseMapping,
    this.metrics,
  });
}

Map<String, XfaFontInfo>? _xfaFontMap;

Map<String, XfaFontInfo> getXFAFontMap() {
  if (_xfaFontMap != null) return _xfaFontMap!;

  final t = <String, XfaFontInfo>{};

  final myriadReg = XfaFontInfo(
    name: 'LiberationSans-Regular',
    factors: MyriadProRegularFactors,
    baseWidths: LiberationSansRegularWidths,
    baseMapping: LiberationSansRegularMapping,
    metrics: MyriadProRegularMetrics,
  );
  t['MyriadPro-Regular'] = myriadReg;
  t['PdfJS-Fallback-Regular'] = myriadReg;

  final myriadBold = XfaFontInfo(
    name: 'LiberationSans-Bold',
    factors: MyriadProBoldFactors,
    baseWidths: LiberationSansBoldWidths,
    baseMapping: LiberationSansBoldMapping,
    metrics: MyriadProBoldMetrics,
  );
  t['MyriadPro-Bold'] = myriadBold;
  t['PdfJS-Fallback-Bold'] = myriadBold;

  final myriadItalic = XfaFontInfo(
    name: 'LiberationSans-Italic',
    factors: MyriadProItalicFactors,
    baseWidths: LiberationSansItalicWidths,
    baseMapping: LiberationSansItalicMapping,
    metrics: MyriadProItalicMetrics,
  );
  t['MyriadPro-It'] = myriadItalic;
  t['MyriadPro-Italic'] = myriadItalic;
  t['PdfJS-Fallback-Italic'] = myriadItalic;

  final myriadBoldIt = XfaFontInfo(
    name: 'LiberationSans-BoldItalic',
    factors: MyriadProBoldItalicFactors,
    baseWidths: LiberationSansBoldItalicWidths,
    baseMapping: LiberationSansBoldItalicMapping,
    metrics: MyriadProBoldItalicMetrics,
  );
  t['MyriadPro-BoldIt'] = myriadBoldIt;
  t['MyriadPro-BoldItalic'] = myriadBoldIt;
  t['PdfJS-Fallback-BoldItalic'] = myriadBoldIt;

  final arialReg = XfaFontInfo(
    name: 'LiberationSans-Regular',
    baseWidths: LiberationSansRegularWidths,
    baseMapping: LiberationSansRegularMapping,
  );
  t['ArialMT'] = arialReg;
  t['Arial'] = arialReg;
  t['Arial-Regular'] = arialReg;

  final arialBold = XfaFontInfo(
    name: 'LiberationSans-Bold',
    baseWidths: LiberationSansBoldWidths,
    baseMapping: LiberationSansBoldMapping,
  );
  t['Arial-BoldMT'] = arialBold;
  t['Arial-Bold'] = arialBold;

  final arialItalic = XfaFontInfo(
    name: 'LiberationSans-Italic',
    baseWidths: LiberationSansItalicWidths,
    baseMapping: LiberationSansItalicMapping,
  );
  t['Arial-ItalicMT'] = arialItalic;
  t['Arial-Italic'] = arialItalic;

  final arialBoldIt = XfaFontInfo(
    name: 'LiberationSans-BoldItalic',
    baseWidths: LiberationSansBoldItalicWidths,
    baseMapping: LiberationSansBoldItalicMapping,
  );
  t['Arial-BoldItalicMT'] = arialBoldIt;
  t['Arial-BoldItalic'] = arialBoldIt;

  t['Calibri-Regular'] = XfaFontInfo(
    name: 'LiberationSans-Regular',
    factors: CalibriRegularFactors,
    baseWidths: LiberationSansRegularWidths,
    baseMapping: LiberationSansRegularMapping,
    metrics: CalibriRegularMetrics,
  );

  t['Calibri-Bold'] = XfaFontInfo(
    name: 'LiberationSans-Bold',
    factors: CalibriBoldFactors,
    baseWidths: LiberationSansBoldWidths,
    baseMapping: LiberationSansBoldMapping,
    metrics: CalibriBoldMetrics,
  );

  t['Calibri-Italic'] = XfaFontInfo(
    name: 'LiberationSans-Italic',
    factors: CalibriItalicFactors,
    baseWidths: LiberationSansItalicWidths,
    baseMapping: LiberationSansItalicMapping,
    metrics: CalibriItalicMetrics,
  );

  t['Calibri-BoldItalic'] = XfaFontInfo(
    name: 'LiberationSans-BoldItalic',
    factors: CalibriBoldItalicFactors,
    baseWidths: LiberationSansBoldItalicWidths,
    baseMapping: LiberationSansBoldItalicMapping,
    metrics: CalibriBoldItalicMetrics,
  );

  t['Segoeui-Regular'] = XfaFontInfo(
    name: 'LiberationSans-Regular',
    factors: SegoeuiRegularFactors,
    baseWidths: LiberationSansRegularWidths,
    baseMapping: LiberationSansRegularMapping,
    metrics: SegoeuiRegularMetrics,
  );

  t['Segoeui-Bold'] = XfaFontInfo(
    name: 'LiberationSans-Bold',
    factors: SegoeuiBoldFactors,
    baseWidths: LiberationSansBoldWidths,
    baseMapping: LiberationSansBoldMapping,
    metrics: SegoeuiBoldMetrics,
  );

  t['Segoeui-Italic'] = XfaFontInfo(
    name: 'LiberationSans-Italic',
    factors: SegoeuiItalicFactors,
    baseWidths: LiberationSansItalicWidths,
    baseMapping: LiberationSansItalicMapping,
    metrics: SegoeuiItalicMetrics,
  );

  t['Segoeui-BoldItalic'] = XfaFontInfo(
    name: 'LiberationSans-BoldItalic',
    factors: SegoeuiBoldItalicFactors,
    baseWidths: LiberationSansBoldItalicWidths,
    baseMapping: LiberationSansBoldItalicMapping,
    metrics: SegoeuiBoldItalicMetrics,
  );

  final helveticaReg = XfaFontInfo(
    name: 'LiberationSans-Regular',
    factors: HelveticaRegularFactors,
    baseWidths: LiberationSansRegularWidths,
    baseMapping: LiberationSansRegularMapping,
    metrics: HelveticaRegularMetrics,
  );
  t['Helvetica-Regular'] = helveticaReg;
  t['Helvetica'] = helveticaReg;

  t['Helvetica-Bold'] = XfaFontInfo(
    name: 'LiberationSans-Bold',
    factors: HelveticaBoldFactors,
    baseWidths: LiberationSansBoldWidths,
    baseMapping: LiberationSansBoldMapping,
    metrics: HelveticaBoldMetrics,
  );

  t['Helvetica-Italic'] = XfaFontInfo(
    name: 'LiberationSans-Italic',
    factors: HelveticaItalicFactors,
    baseWidths: LiberationSansItalicWidths,
    baseMapping: LiberationSansItalicMapping,
    metrics: HelveticaItalicMetrics,
  );

  t['Helvetica-BoldItalic'] = XfaFontInfo(
    name: 'LiberationSans-BoldItalic',
    factors: HelveticaBoldItalicFactors,
    baseWidths: LiberationSansBoldItalicWidths,
    baseMapping: LiberationSansBoldItalicMapping,
    metrics: HelveticaBoldItalicMetrics,
  );

  _xfaFontMap = t;
  return t;
}

XfaFontInfo? getXfaFontName(String name) {
  final fontName = normalizeFontName(name);
  final fontMap = getXFAFontMap();
  return fontMap[fontName];
}

List<dynamic>? getXfaFontWidths(String name) {
  final info = getXfaFontName(name);
  if (info == null) {
    return null;
  }

  final baseWidths = info.baseWidths;
  final baseMapping = info.baseMapping;
  final factors = info.factors;

  final rescaledBaseWidths = factors == null
      ? baseWidths.map((w) => w.toDouble()).toList()
      : List<double>.generate(
          baseWidths.length, (i) => baseWidths[i] * factors[i]);

  int currentCode = -2;
  List<double> currentArray = [];

  // Widths array for composite font is:
  // CharCode1 [10, 20, 30] ...
  // which means:
  //   - CharCode1 has a width equal to 10
  //   - CharCode1+1 has a width equal to 20
  //   - CharCode1+2 has a width equal to 30
  //
  // The baseMapping array contains a map for glyph index to unicode.
  // So from baseMapping we'll get sorted unicodes and their positions
  // (i.e. glyph indices) and then we put widths in an array for
  // consecutive unicodes.
  final newWidths = <dynamic>[];

  final pairs = <(int unicode, int glyphIndex)>[];
  for (int index = 0; index < baseMapping.length; index++) {
    pairs.add((baseMapping[index], index));
  }
  pairs.sort((a, b) => a.$1.compareTo(b.$1));

  for (final pair in pairs) {
    final unicode = pair.$1;
    final glyphIndex = pair.$2;

    if (unicode == -1) {
      continue;
    }

    if (unicode == currentCode + 1) {
      currentArray.add(rescaledBaseWidths[glyphIndex]);
      currentCode += 1;
    } else {
      currentCode = unicode;
      currentArray = [rescaledBaseWidths[glyphIndex]];
      newWidths.add(unicode);
      newWidths.add(currentArray);
    }
  }

  return newWidths;
}

Dict getXfaFontDict(String name) {
  final widths = getXfaFontWidths(name);
  final dict = Dict();
  dict.set('BaseFont', Name.get(name));
  dict.set('Type', Name.get('Font'));
  dict.set('Subtype', Name.get('CIDFontType2'));
  dict.set('Encoding', Name.get('Identity-H'));
  dict.set('CIDToGIDMap', Name.get('Identity'));
  dict.set('W', widths);
  if (widths != null && widths.isNotEmpty) {
    dict.set('FirstChar', widths[0]);
    final lastCode = widths[widths.length - 2] as int;
    final lastArr = widths[widths.length - 1] as List;
    dict.set('LastChar', lastCode + lastArr.length - 1);
  }
  final descriptor = Dict();
  dict.set('FontDescriptor', descriptor);
  final systemInfo = Dict();
  systemInfo.set('Ordering', 'Identity');
  systemInfo.set('Registry', 'Adobe');
  systemInfo.set('Supplement', 0);
  dict.set('CIDSystemInfo', systemInfo);

  return dict;
}
