// Copyright 2020 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;
import 'dart:typed_data';

import '../shared/util.dart';
import 'base_stream.dart';
import 'colorspace.dart';
import 'colorspace_utils.dart';
import 'core_utils.dart';
import 'evaluator_preprocessor.dart';
import 'function.dart';
import 'primitives.dart';
import 'stream.dart';

class DefaultAppearanceResult {
  DefaultAppearanceResult({
    this.fontSize = 0.0,
    this.fontName = '',
    Uint8List? fontColor,
  }) : fontColor = fontColor ?? Uint8List(3);

  double fontSize;
  String fontName;
  Uint8List fontColor;
}

class DefaultAppearanceEvaluator extends EvaluatorPreprocessor {
  DefaultAppearanceEvaluator(String str) : super(StringStream(str));

  DefaultAppearanceResult parse() {
    final operation = EvaluatorOperation();
    final result = DefaultAppearanceResult();

    try {
      while (true) {
        operation.args.clear();

        if (!read(operation)) {
          break;
        }
        if (savedStatesDepth != 0) {
          continue;
        }
        final fn = operation.fn;
        final args = operation.args;

        switch (fn) {
          case OPS.setFont:
            if (args.isNotEmpty) {
              final fontName = args[0];
              if (fontName is Name) {
                result.fontName = fontName.name;
              }
            }
            if (args.length > 1) {
              final fontSize = args[1];
              if (fontSize is num && fontSize > 0) {
                result.fontSize = fontSize.toDouble();
              }
            }
            break;
          case OPS.setFillRGBColor:
            ColorSpaceUtils.rgb.getRgbItem(args.cast<num>(), 0, result.fontColor, 0);
            break;
          case OPS.setFillGray:
            ColorSpaceUtils.gray.getRgbItem(args.cast<num>(), 0, result.fontColor, 0);
            break;
          case OPS.setFillCMYKColor:
            ColorSpaceUtils.cmyk.getRgbItem(args.cast<num>(), 0, result.fontColor, 0);
            break;
        }
      }
    } catch (reason) {
      warn('parseDefaultAppearance - ignoring errors: "$reason".');
    }

    return result;
  }
}

DefaultAppearanceResult parseDefaultAppearance(String str) {
  return DefaultAppearanceEvaluator(str).parse();
}

class AppearanceStreamResult {
  AppearanceStreamResult({
    this.scaleFactor = 1.0,
    this.fontSize = 0.0,
    this.fontName = '',
    Uint8List? fontColor,
    ColorSpace? fillColorSpace,
  })  : fontColor = fontColor ?? Uint8List(3),
        fillColorSpace = fillColorSpace ?? ColorSpaceUtils.gray;

  double scaleFactor;
  double fontSize;
  String fontName;
  Uint8List fontColor;
  ColorSpace fillColorSpace;
}

class AppearanceStreamEvaluator extends EvaluatorPreprocessor {
  AppearanceStreamEvaluator(
    this.stream,
    dynamic xref,
    this.globalColorSpaceCache,
  ) : super(stream, xref) {
    this.xref = xref;
    final dict = stream.dict;
    resources = dict?.get('Resources');
  }

  final BaseStream stream;
  dynamic xref;
  final GlobalColorSpaceCache globalColorSpaceCache;
  dynamic resources;

  final LocalColorSpaceCache _localColorSpaceCache = LocalColorSpaceCache();
  late final PDFFunctionFactory _pdfFunctionFactory =
      PDFFunctionFactory(xref: xref);

  AppearanceStreamResult parse() {
    final operation = EvaluatorOperation();
    var result = AppearanceStreamResult();
    var breakLoop = false;
    final stack = <AppearanceStreamResult>[];

    try {
      while (true) {
        operation.args.clear();

        if (breakLoop || !read(operation)) {
          break;
        }
        final fn = operation.fn;
        final args = operation.args;

        switch (fn) {
          case OPS.save:
            stack.add(AppearanceStreamResult(
              scaleFactor: result.scaleFactor,
              fontSize: result.fontSize,
              fontName: result.fontName,
              fontColor: Uint8List.fromList(result.fontColor),
              fillColorSpace: result.fillColorSpace,
            ));
            break;
          case OPS.restore:
            result = stack.isNotEmpty ? stack.removeLast() : result;
            break;
          case OPS.setTextMatrix:
            final a = (args[0] as num).toDouble();
            final b = (args[1] as num).toDouble();
            result.scaleFactor *= math.sqrt(a * a + b * b);
            break;
          case OPS.setFont:
            if (args.isNotEmpty) {
              final fontName = args[0];
              if (fontName is Name) {
                result.fontName = fontName.name;
              }
            }
            if (args.length > 1) {
              final fontSize = args[1];
              if (fontSize is num && fontSize > 0) {
                result.fontSize = fontSize.toDouble() * result.scaleFactor;
              }
            }
            break;
          case OPS.setFillColorSpace:
            result.fillColorSpace = ColorSpaceUtils.parse(
              cs: args[0],
              xref: xref,
              resources: resources is Dict ? resources as Dict : null,
              pdfFunctionFactory: _pdfFunctionFactory,
              globalColorSpaceCache: globalColorSpaceCache,
              localColorSpaceCache: _localColorSpaceCache,
            );
            break;
          case OPS.setFillColor:
            result.fillColorSpace.getRgbItem(args.cast<num>(), 0, result.fontColor, 0);
            break;
          case OPS.setFillRGBColor:
            ColorSpaceUtils.rgb.getRgbItem(args.cast<num>(), 0, result.fontColor, 0);
            break;
          case OPS.setFillGray:
            ColorSpaceUtils.gray.getRgbItem(args.cast<num>(), 0, result.fontColor, 0);
            break;
          case OPS.setFillCMYKColor:
            ColorSpaceUtils.cmyk.getRgbItem(args.cast<num>(), 0, result.fontColor, 0);
            break;
          case OPS.showText:
          case OPS.showSpacedText:
          case OPS.nextLineShowText:
          case OPS.nextLineSetSpacingShowText:
            breakLoop = true;
            break;
        }
      }
    } catch (reason) {
      warn('parseAppearanceStream - ignoring errors: "$reason".');
    }
    stream.reset();

    return result;
  }
}

AppearanceStreamResult parseAppearanceStream(
  BaseStream stream,
  dynamic xref,
  GlobalColorSpaceCache globalColorSpaceCache,
) {
  return AppearanceStreamEvaluator(stream, xref, globalColorSpaceCache).parse();
}

String getPdfColor(List<num> color, bool isFill) {
  if (color.length >= 3 && color[0] == color[1] && color[1] == color[2]) {
    final gray = color[0] / 255;
    return '${numberToString(gray)} ${isFill ? "g" : "G"}';
  }
  final comps = color.map((c) => numberToString(c / 255)).join(' ');
  return '$comps ${isFill ? "rg" : "RG"}';
}

String createDefaultAppearance({
  required num fontSize,
  required String fontName,
  required List<num> fontColor,
}) {
  return '/${escapePDFName(fontName)} $fontSize Tf ${getPdfColor(fontColor, true)}';
}

class FakeUnicodeFont {
  FakeUnicodeFont(this.xref, this.fontFamily)
      : fontName = Name.get('InvalidPDFjsFont_${fontFamily}_${_fontNameId++}');

  static int _fontNameId = 1;
  static Ref? _fontDescriptorRef;

  final dynamic xref;
  final String fontFamily;
  final Name fontName;

  Map<int, int>? widths;
  int firstChar = 1000000;
  int lastChar = -1;

  Ref get fontDescriptorRef {
    if (_fontDescriptorRef == null) {
      final fontDescriptor = Dict(xref);
      fontDescriptor.setIfName('Type', 'FontDescriptor');
      fontDescriptor.set('FontName', fontName);
      fontDescriptor.set('FontFamily', 'MyriadPro Regular');
      fontDescriptor.set('FontBBox', [0, 0, 0, 0]);
      fontDescriptor.setIfName('FontStretch', 'Normal');
      fontDescriptor.set('FontWeight', 400);
      fontDescriptor.set('ItalicAngle', 0);

      _fontDescriptorRef = xref?.getNewPersistentRef(fontDescriptor);
    }
    return _fontDescriptorRef!;
  }

  Ref get descendantFontRef {
    final descendantFont = Dict(xref);
    descendantFont.set('BaseFont', fontName);
    descendantFont.setIfName('Type', 'Font');
    descendantFont.setIfName('Subtype', 'CIDFontType0');
    descendantFont.setIfName('CIDToGIDMap', 'Identity');
    descendantFont.set('FirstChar', firstChar);
    descendantFont.set('LastChar', lastChar);
    descendantFont.set('FontDescriptor', fontDescriptorRef);
    descendantFont.set('DW', 1000);

    final sortedChars = (widths?.entries.toList() ?? <MapEntry<int, int>>[])
      ..sort((a, b) => a.key.compareTo(b.key));

    final wList = <dynamic>[];
    int? currentChar;
    List<int>? currentWidths;
    for (final entry in sortedChars) {
      final char = entry.key;
      final width = entry.value;
      if (currentChar == null) {
        currentChar = char;
        currentWidths = [width];
        continue;
      }
      if (char == currentChar + currentWidths!.length) {
        currentWidths.add(width);
      } else {
        wList.add(currentChar);
        wList.add(currentWidths);
        currentChar = char;
        currentWidths = [width];
      }
    }
    if (currentChar != null && currentWidths != null) {
      wList.add(currentChar);
      wList.add(currentWidths);
    }

    descendantFont.set('W', wList);

    final cidSystemInfo = Dict(xref);
    cidSystemInfo.set('Ordering', 'Identity');
    cidSystemInfo.set('Registry', 'Adobe');
    cidSystemInfo.set('Supplement', 0);
    descendantFont.set('CIDSystemInfo', cidSystemInfo);

    return xref?.getNewPersistentRef(descendantFont);
  }

  Ref get baseFontRef {
    final baseFont = Dict(xref);
    baseFont.set('BaseFont', fontName);
    baseFont.setIfName('Type', 'Font');
    baseFont.setIfName('Subtype', 'Type0');
    baseFont.setIfName('Encoding', 'Identity-H');
    baseFont.set('DescendantFonts', [descendantFontRef]);
    baseFont.setIfName('ToUnicode', 'Identity-H');

    return xref?.getNewPersistentRef(baseFont);
  }

  Dict get resources {
    final res = Dict(xref);
    final fontDict = Dict(xref);
    fontDict.set(fontName.name, baseFontRef);
    res.set('Font', fontDict);
    return res;
  }

  int _measureCharWidth(int charCode) {
    // Estimativa padrão baseada em proporções tipográficas para quando
    // não há canvas disponível
    if (charCode == 0x20) return 250;
    if (charCode >= 0x41 && charCode <= 0x5a) return 700; // Maiúsculas
    if (charCode >= 0x61 && charCode <= 0x7a) return 500; // Minúsculas
    if (charCode >= 0x30 && charCode <= 0x39) return 550; // Dígitos
    return 600;
  }

  Dict createFontResources(String text) {
    widths = <int, int>{};
    for (final line in text.split(RegExp(r'\r\n?|\n'))) {
      for (var i = 0; i < line.length; i++) {
        final code = line.codeUnitAt(i);
        if (widths!.containsKey(code)) continue;
        final w = _measureCharWidth(code);
        widths![code] = w;
        firstChar = math.min(code, firstChar);
        lastChar = math.max(code, lastChar);
      }
    }
    return resources;
  }
}
