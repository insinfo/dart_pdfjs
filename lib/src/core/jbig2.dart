// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import '../shared/util.dart';
import 'arithmetic_decoder.dart';
import 'ccitt.dart';
import 'core_utils.dart';

class Jbig2Error extends BaseException {
  Jbig2Error(String msg) : super(msg, 'Jbig2Error');
}

// Utility data structures
class ContextCache {
  final Map<String, Uint8List> _cache = {};

  Uint8List getContexts(String id) {
    return _cache.putIfAbsent(id, () => Uint8List(1 << 16));
  }
}

class DecodingContext {
  final Uint8List data;
  final int start;
  final int end;
  ArithmeticDecoder? _decoder;
  ContextCache? _contextCache;

  DecodingContext(this.data, this.start, this.end);

  ArithmeticDecoder get decoder {
    _decoder ??= ArithmeticDecoder(data, start, end);
    return _decoder!;
  }

  ContextCache get contextCache {
    _contextCache ??= ContextCache();
    return _contextCache!;
  }
}

int? decodeInteger(
  ContextCache contextCache,
  String procedure,
  ArithmeticDecoder decoder,
) {
  final contexts = contextCache.getContexts(procedure);
  var prev = 1;

  int readBits(int length) {
    var value = 0;
    for (var i = 0; i < length; i++) {
      final bit = decoder.readBit(contexts, prev);
      prev = prev < 256 ? (prev << 1) | bit : (((prev << 1) | bit) & 511) | 256;
      value = (value << 1) | bit;
    }
    return value & 0xffffffff;
  }

  final sign = readBits(1);
  final value = readBits(1) != 0
      ? (readBits(1) != 0
          ? (readBits(1) != 0
              ? (readBits(1) != 0
                  ? (readBits(1) != 0
                      ? readBits(32) + 4436
                      : readBits(12) + 340)
                  : readBits(8) + 84)
              : readBits(6) + 20)
          : readBits(4) + 4)
      : readBits(2);

  int? signedValue;
  if (sign == 0) {
    signedValue = value;
  } else if (value > 0) {
    signedValue = -value;
  }
  if (signedValue != null &&
      signedValue >= MIN_INT_32 &&
      signedValue <= MAX_INT_32) {
    return signedValue;
  }
  return null;
}

int decodeIAID(
    ContextCache contextCache, ArithmeticDecoder decoder, int codeLength) {
  final contexts = contextCache.getContexts('IAID');
  var prev = 1;
  for (var i = 0; i < codeLength; i++) {
    final bit = decoder.readBit(contexts, prev);
    prev = (prev << 1) | bit;
  }
  if (codeLength < 31) {
    return prev & ((1 << codeLength) - 1);
  }
  return prev & 0x7fffffff;
}

int _requireInteger(
  int? value,
  String procedure, {
  bool allowOob = false,
}) {
  if (value == null) {
    if (allowOob) {
      throw Jbig2Error('unexpected OOB in $procedure');
    }
    throw Jbig2Error('invalid arithmetic integer in $procedure');
  }
  return value;
}

// dart format off
// @formatter:off
const List<String?> segmentTypes = [
  "SymbolDictionary",
  null,
  null,
  null,
  "IntermediateTextRegion",
  null,
  "ImmediateTextRegion",
  "ImmediateLosslessTextRegion",
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  "PatternDictionary",
  null,
  null,
  null,
  "IntermediateHalftoneRegion",
  null,
  "ImmediateHalftoneRegion",
  "ImmediateLosslessHalftoneRegion",
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  "IntermediateGenericRegion",
  null,
  "ImmediateGenericRegion",
  "ImmediateLosslessGenericRegion",
  "IntermediateGenericRefinementRegion",
  null,
  "ImmediateGenericRefinementRegion",
  "ImmediateLosslessGenericRefinementRegion",
  null,
  null,
  null,
  null,
  "PageInformation",
  "EndOfPage",
  "EndOfStripe",
  "EndOfFile",
  "Profiles",
  "Tables",
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  null,
  "Extension",
];

class _TemplatePoint {
  final int x;
  final int y;
  const _TemplatePoint(this.x, this.y);
}

const List<List<_TemplatePoint>> codingTemplates = [
  [
    _TemplatePoint(-1, -2),
    _TemplatePoint(0, -2),
    _TemplatePoint(1, -2),
    _TemplatePoint(-2, -1),
    _TemplatePoint(-1, -1),
    _TemplatePoint(0, -1),
    _TemplatePoint(1, -1),
    _TemplatePoint(2, -1),
    _TemplatePoint(-4, 0),
    _TemplatePoint(-3, 0),
    _TemplatePoint(-2, 0),
    _TemplatePoint(-1, 0),
  ],
  [
    _TemplatePoint(-1, -2),
    _TemplatePoint(0, -2),
    _TemplatePoint(1, -2),
    _TemplatePoint(2, -2),
    _TemplatePoint(-2, -1),
    _TemplatePoint(-1, -1),
    _TemplatePoint(0, -1),
    _TemplatePoint(1, -1),
    _TemplatePoint(2, -1),
    _TemplatePoint(-3, 0),
    _TemplatePoint(-2, 0),
    _TemplatePoint(-1, 0),
  ],
  [
    _TemplatePoint(-1, -2),
    _TemplatePoint(0, -2),
    _TemplatePoint(1, -2),
    _TemplatePoint(-2, -1),
    _TemplatePoint(-1, -1),
    _TemplatePoint(0, -1),
    _TemplatePoint(1, -1),
    _TemplatePoint(-2, 0),
    _TemplatePoint(-1, 0),
  ],
  [
    _TemplatePoint(-3, -1),
    _TemplatePoint(-2, -1),
    _TemplatePoint(-1, -1),
    _TemplatePoint(0, -1),
    _TemplatePoint(1, -1),
    _TemplatePoint(-4, 0),
    _TemplatePoint(-3, 0),
    _TemplatePoint(-2, 0),
    _TemplatePoint(-1, 0),
  ],
];

class _RefinementTemplate {
  final List<_TemplatePoint> coding;
  final List<_TemplatePoint> reference;
  const _RefinementTemplate(this.coding, this.reference);
}

const List<_RefinementTemplate> refinementTemplates = [
  _RefinementTemplate(
    [
      _TemplatePoint(0, -1),
      _TemplatePoint(1, -1),
      _TemplatePoint(-1, 0),
    ],
    [
      _TemplatePoint(0, -1),
      _TemplatePoint(1, -1),
      _TemplatePoint(-1, 0),
      _TemplatePoint(0, 0),
      _TemplatePoint(1, 0),
      _TemplatePoint(-1, 1),
      _TemplatePoint(0, 1),
      _TemplatePoint(1, 1),
    ],
  ),
  _RefinementTemplate(
    [
      _TemplatePoint(-1, -1),
      _TemplatePoint(0, -1),
      _TemplatePoint(1, -1),
      _TemplatePoint(-1, 0),
    ],
    [
      _TemplatePoint(0, -1),
      _TemplatePoint(-1, 0),
      _TemplatePoint(0, 0),
      _TemplatePoint(1, 0),
      _TemplatePoint(0, 1),
      _TemplatePoint(1, 1),
    ],
  ),
];

// See 6.2.5.7 Decoding the bitmap.
const List<int> reusedContexts = [
  0x9b25, // 10011 0110010 0101
  0x0795, // 0011 110010 101
  0x00e5, // 001 11001 01
  0x0195, // 011001 0101
];

const List<int> refinementReusedContexts = [
  0x0020, // '000' + '0' (coding) + '00010000' + '0' (reference)
  0x0008, // '0000' + '001000'
];
// @formatter:on
// dart format on

List<Uint8List> _decodeBitmapTemplate0(
  int width,
  int height,
  DecodingContext decodingContext,
) {
  final decoder = decodingContext.decoder;
  final contexts = decodingContext.contextCache.getContexts('GB');
  final bitmap = <Uint8List>[];
  const oldPixelMask = 0x7bf7;

  for (var i = 0; i < height; i++) {
    final row = Uint8List(width);
    bitmap.add(row);
    final row1 = i < 1 ? row : bitmap[i - 1];
    final row2 = i < 2 ? row : bitmap[i - 2];

    var contextLabel = (width > 0 ? row2[0] << 13 : 0) |
        (width > 1 ? row2[1] << 12 : 0) |
        (width > 2 ? row2[2] << 11 : 0) |
        (width > 0 ? row1[0] << 7 : 0) |
        (width > 1 ? row1[1] << 6 : 0) |
        (width > 2 ? row1[2] << 5 : 0) |
        (width > 3 ? row1[3] << 4 : 0);

    for (var j = 0; j < width; j++) {
      final pixel = decoder.readBit(contexts, contextLabel);
      row[j] = pixel;
      contextLabel = ((contextLabel & oldPixelMask) << 1) |
          (j + 3 < width ? row2[j + 3] << 11 : 0) |
          (j + 4 < width ? row1[j + 4] << 4 : 0) |
          pixel;
    }
  }
  return bitmap;
}

List<Uint8List> decodeBitmap(
  bool mmr,
  int width,
  int height,
  int templateIndex,
  bool prediction,
  dynamic skip,
  dynamic at,
  DecodingContext decodingContext,
) {
  if (mmr) {
    final input = Reader(
        decodingContext.data, decodingContext.start, decodingContext.end);
    return decodeMMRBitmap(input, width, height, false);
  }

  final atList = at is List ? at.cast<_TemplatePoint>() : <_TemplatePoint>[];
  if (templateIndex == 0 &&
      skip == null &&
      !prediction &&
      atList.length == 4 &&
      atList[0].x == 3 &&
      atList[0].y == -1 &&
      atList[1].x == -3 &&
      atList[1].y == -1 &&
      atList[2].x == 2 &&
      atList[2].y == -2 &&
      atList[3].x == -2 &&
      atList[3].y == -2) {
    return _decodeBitmapTemplate0(width, height, decodingContext);
  }

  final useSkip = skip != null;
  final template = <_TemplatePoint>[
    ...codingTemplates[templateIndex],
    ...atList,
  ]..sort((a, b) => a.y == b.y ? a.x - b.x : a.y - b.y);

  final templateLength = template.length;
  final templateX = Int8List(templateLength);
  final templateY = Int8List(templateLength);
  final changingTemplateEntries = <int>[];
  var reuseMask = 0;
  var minX = 0;
  var maxX = 0;
  var minY = 0;

  for (var k = 0; k < templateLength; k++) {
    templateX[k] = template[k].x;
    templateY[k] = template[k].y;
    if (template[k].x < minX) minX = template[k].x;
    if (template[k].x > maxX) maxX = template[k].x;
    if (template[k].y < minY) minY = template[k].y;
    if (k < templateLength - 1 &&
        template[k].y == template[k + 1].y &&
        template[k].x == template[k + 1].x - 1) {
      reuseMask |= 1 << (templateLength - 1 - k);
    } else {
      changingTemplateEntries.add(k);
    }
  }

  final changingTemplateX = Int8List(changingTemplateEntries.length);
  final changingTemplateY = Int8List(changingTemplateEntries.length);
  final changingTemplateBit = Uint16List(changingTemplateEntries.length);
  for (var c = 0; c < changingTemplateEntries.length; c++) {
    final k = changingTemplateEntries[c];
    changingTemplateX[c] = template[k].x;
    changingTemplateY[c] = template[k].y;
    changingTemplateBit[c] = 1 << (templateLength - 1 - k);
  }

  final safeLeft = -minX;
  final safeTop = -minY;
  final safeRight = width - maxX;
  final pseudoPixelContext = reusedContexts[templateIndex];
  var row = Uint8List(width);
  final bitmap = <Uint8List>[];
  final decoder = decodingContext.decoder;
  final contexts = decodingContext.contextCache.getContexts('GB');
  var ltp = 0;
  var contextLabel = 0;

  for (var i = 0; i < height; i++) {
    if (prediction) {
      final sltp = decoder.readBit(contexts, pseudoPixelContext);
      ltp ^= sltp;
      if (ltp != 0) {
        bitmap.add(row);
        continue;
      }
    }
    row = Uint8List.fromList(row);
    bitmap.add(row);
    for (var j = 0; j < width; j++) {
      if (useSkip && skip[i][j] != 0) {
        row[j] = 0;
        continue;
      }
      if (j >= safeLeft && j < safeRight && i >= safeTop) {
        contextLabel = (contextLabel << 1) & reuseMask;
        for (var k = 0; k < changingTemplateEntries.length; k++) {
          final i0 = i + changingTemplateY[k];
          final j0 = j + changingTemplateX[k];
          var bit = bitmap[i0][j0];
          if (bit != 0) {
            bit = changingTemplateBit[k];
            contextLabel |= bit;
          }
        }
      } else {
        contextLabel = 0;
        var shift = templateLength - 1;
        for (var k = 0; k < templateLength; k++, shift--) {
          final j0 = j + templateX[k];
          if (j0 >= 0 && j0 < width) {
            final i0 = i + templateY[k];
            if (i0 >= 0) {
              final bit = bitmap[i0][j0];
              if (bit != 0) {
                contextLabel |= bit << shift;
              }
            }
          }
        }
      }
      row[j] = decoder.readBit(contexts, contextLabel);
    }
  }
  return bitmap;
}

// 6.3.2 Generic Refinement Region Decoding Procedure
List<Uint8List> decodeRefinement(
    int width,
    int height,
    int templateIndex,
    List<Uint8List> referenceBitmap,
    int offsetX,
    int offsetY,
    bool prediction,
    dynamic at,
    DecodingContext decodingContext) {
  final atList = at is List ? at.cast<_TemplatePoint>() : <_TemplatePoint>[];

  final codingTemplate =
      List<_TemplatePoint>.from(refinementTemplates[templateIndex].coding);
  if (templateIndex == 0) {
    codingTemplate.add(atList[0]);
  }
  final codingTemplateLength = codingTemplate.length;
  final codingTemplateX = Int32List(codingTemplateLength);
  final codingTemplateY = Int32List(codingTemplateLength);
  for (var k = 0; k < codingTemplateLength; k++) {
    codingTemplateX[k] = codingTemplate[k].x;
    codingTemplateY[k] = codingTemplate[k].y;
  }

  final referenceTemplate =
      List<_TemplatePoint>.from(refinementTemplates[templateIndex].reference);
  if (templateIndex == 0) {
    referenceTemplate.add(atList[1]);
  }
  final referenceTemplateLength = referenceTemplate.length;
  final referenceTemplateX = Int32List(referenceTemplateLength);
  final referenceTemplateY = Int32List(referenceTemplateLength);
  for (var k = 0; k < referenceTemplateLength; k++) {
    referenceTemplateX[k] = referenceTemplate[k].x;
    referenceTemplateY[k] = referenceTemplate[k].y;
  }

  final referenceWidth =
      referenceBitmap.isEmpty ? 0 : referenceBitmap[0].length;
  final referenceHeight = referenceBitmap.length;
  final pseudoPixelContext = refinementReusedContexts[templateIndex];
  final bitmap = <Uint8List>[];

  final decoder = decodingContext.decoder;
  final contexts = decodingContext.contextCache.getContexts('GR');

  var ltp = 0;
  for (var i = 0; i < height; i++) {
    if (prediction) {
      final sltp = decoder.readBit(contexts, pseudoPixelContext);
      ltp ^= sltp;
      if (ltp != 0) {
        throw Jbig2Error('prediction is not supported');
      }
    }

    final row = Uint8List(width);
    bitmap.add(row);
    for (var j = 0; j < width; j++) {
      var contextLabel = 0;
      for (var k = 0; k < codingTemplateLength; k++) {
        final i0 = i + codingTemplateY[k];
        final j0 = j + codingTemplateX[k];
        if (i0 < 0 || j0 < 0 || j0 >= width) {
          contextLabel <<= 1;
        } else {
          contextLabel = (contextLabel << 1) | bitmap[i0][j0];
        }
      }

      for (var k = 0; k < referenceTemplateLength; k++) {
        final i0 = i + referenceTemplateY[k] - offsetY;
        final j0 = j + referenceTemplateX[k] - offsetX;
        if (i0 < 0 || i0 >= referenceHeight || j0 < 0 || j0 >= referenceWidth) {
          contextLabel <<= 1;
        } else {
          contextLabel = (contextLabel << 1) | referenceBitmap[i0][j0];
        }
      }

      row[j] = decoder.readBit(contexts, contextLabel);
    }
  }

  return bitmap;
}

// 6.5.5 Decoding the symbol dictionary
List<dynamic> decodeSymbolDictionary(
    bool huffman,
    bool refinement,
    List<dynamic> symbols,
    int numberOfNewSymbols,
    int numberOfExportedSymbols,
    dynamic huffmanTables,
    int templateIndex,
    dynamic at,
    int refinementTemplateIndex,
    dynamic refinementAt,
    DecodingContext decodingContext,
    dynamic huffmanInput) {
  if (huffman && refinement) {
    throw Jbig2Error('symbol refinement with Huffman is not supported');
  }
  if (symbols.isEmpty &&
      numberOfNewSymbols == 0 &&
      numberOfExportedSymbols == 0) {
    return <List<Uint8List>>[];
  }

  final newSymbols = <List<Uint8List>>[];
  var currentHeight = 0;
  var symbolCodeLength = log2(symbols.length + numberOfNewSymbols);

  final decoder = decodingContext.decoder;
  final contextCache = decodingContext.contextCache;
  dynamic tableB1;
  final symbolWidths = <int>[];
  if (huffman) {
    tableB1 = getStandardTable(1);
    if (symbolCodeLength < 1) {
      symbolCodeLength = 1;
    }
  }

  while (newSymbols.length < numberOfNewSymbols) {
    final deltaHeight = huffman
        ? huffmanTables.tableDeltaHeight.decode(huffmanInput) as int
        : _requireInteger(
            decodeInteger(contextCache, 'IADH', decoder),
            'IADH',
          );
    currentHeight += deltaHeight;
    var currentWidth = 0;
    var totalWidth = 0;
    final firstSymbol = huffman ? symbolWidths.length : 0;
    while (true) {
      final int? deltaWidth = huffman
          ? huffmanTables.tableDeltaWidth.decode(huffmanInput) as int?
          : decodeInteger(contextCache, 'IADW', decoder);
      if (deltaWidth == null) {
        break;
      }
      currentWidth += deltaWidth;
      totalWidth += currentWidth;

      List<Uint8List> bitmap;
      if (refinement) {
        final numberOfInstances = _requireInteger(
          decodeInteger(contextCache, 'IAAI', decoder),
          'IAAI',
        );
        if (numberOfInstances > 1) {
          bitmap = decodeTextRegion(
            huffman,
            refinement,
            currentWidth,
            currentHeight,
            0,
            numberOfInstances,
            1,
            <dynamic>[...symbols, ...newSymbols],
            symbolCodeLength,
            0,
            0,
            1,
            0,
            huffmanTables,
            refinementTemplateIndex,
            refinementAt,
            decodingContext,
            0,
            huffmanInput,
          );
        } else {
          final symbolId = decodeIAID(contextCache, decoder, symbolCodeLength);
          final rdx = _requireInteger(
            decodeInteger(contextCache, 'IARDX', decoder),
            'IARDX',
          );
          final rdy = _requireInteger(
            decodeInteger(contextCache, 'IARDY', decoder),
            'IARDY',
          );
          final symbol = symbolId < symbols.length
              ? symbols[symbolId] as List<Uint8List>
              : newSymbols[symbolId - symbols.length];
          bitmap = decodeRefinement(
            currentWidth,
            currentHeight,
            refinementTemplateIndex,
            symbol,
            rdx,
            rdy,
            false,
            refinementAt,
            decodingContext,
          );
        }
        newSymbols.add(bitmap);
      } else if (huffman) {
        symbolWidths.add(currentWidth);
      } else {
        bitmap = decodeBitmap(
          false,
          currentWidth,
          currentHeight,
          templateIndex,
          false,
          null,
          at,
          decodingContext,
        );
        newSymbols.add(bitmap);
      }
    }

    if (huffman && !refinement) {
      final bitmapSize = huffmanTables.tableBitmapSize.decode(huffmanInput);
      huffmanInput.byteAlign();
      List<Uint8List> collectiveBitmap;
      if (bitmapSize == 0) {
        collectiveBitmap =
            readUncompressedBitmap(huffmanInput, totalWidth, currentHeight);
      } else {
        final originalEnd = huffmanInput.end;
        final bitmapEnd = huffmanInput.position + bitmapSize as int;
        huffmanInput.end = bitmapEnd;
        collectiveBitmap =
            decodeMMRBitmap(huffmanInput, totalWidth, currentHeight, false);
        huffmanInput.end = originalEnd;
        huffmanInput.position = bitmapEnd;
      }

      final numberOfSymbolsDecoded = symbolWidths.length;
      if (firstSymbol == numberOfSymbolsDecoded - 1) {
        newSymbols.add(collectiveBitmap);
      } else {
        var xMin = 0;
        for (var i = firstSymbol; i < numberOfSymbolsDecoded; i++) {
          final bitmapWidth = symbolWidths[i];
          final xMax = xMin + bitmapWidth;
          final symbolBitmap = <Uint8List>[];
          for (var y = 0; y < currentHeight; y++) {
            symbolBitmap.add(Uint8List.sublistView(
              collectiveBitmap[y],
              xMin,
              xMax,
            ));
          }
          newSymbols.add(symbolBitmap);
          xMin = xMax;
        }
      }
    }
  }

  final exportedSymbols = <List<Uint8List>>[];
  final flags = <bool>[];
  var currentFlag = false;
  final totalSymbolsLength = symbols.length + numberOfNewSymbols;
  while (flags.length < totalSymbolsLength) {
    var runLength = huffman
        ? tableB1.decode(huffmanInput) as int
        : _requireInteger(
            decodeInteger(contextCache, 'IAEX', decoder),
            'IAEX',
          );
    while (runLength-- > 0) {
      flags.add(currentFlag);
    }
    currentFlag = !currentFlag;
  }

  var i = 0;
  for (; i < symbols.length; i++) {
    if (flags[i]) {
      exportedSymbols.add(symbols[i] as List<Uint8List>);
    }
  }
  for (var j = 0; j < numberOfNewSymbols; i++, j++) {
    if (flags[i]) {
      exportedSymbols.add(newSymbols[j]);
    }
  }
  return exportedSymbols;
}

// 6.4 Decoding the text region
List<Uint8List> decodeTextRegion(
    bool huffman,
    bool refinement,
    int width,
    int height,
    int defaultPixelValue,
    int numberOfSymbolInstances,
    int stripSize,
    List<dynamic> inputSymbols,
    int symbolCodeLength,
    int transposed,
    int dsOffset,
    int referenceCorner,
    int combinationOperator,
    dynamic huffmanTables,
    int refinementTemplateIndex,
    dynamic refinementAt,
    DecodingContext decodingContext,
    int logStripSize,
    dynamic huffmanInput) {
  if (huffman && refinement) {
    throw Jbig2Error('refinement with Huffman is not supported');
  }

  final bitmap = <Uint8List>[];
  for (var i = 0; i < height; i++) {
    final row = Uint8List(width);
    if (defaultPixelValue != 0) {
      row.fillRange(0, row.length, defaultPixelValue);
    }
    bitmap.add(row);
  }

  final decoder = decodingContext.decoder;
  final contextCache = decodingContext.contextCache;

  var stripT = huffman
      ? -(huffmanTables.tableDeltaT.decode(huffmanInput) as int)
      : -_requireInteger(
          decodeInteger(contextCache, 'IADT', decoder),
          'IADT',
        );
  var firstS = 0;
  var i = 0;
  while (i < numberOfSymbolInstances) {
    final deltaT = huffman
        ? huffmanTables.tableDeltaT.decode(huffmanInput) as int
        : _requireInteger(
            decodeInteger(contextCache, 'IADT', decoder),
            'IADT',
          );
    stripT += deltaT;

    final deltaFirstS = huffman
        ? huffmanTables.tableFirstS.decode(huffmanInput) as int
        : _requireInteger(
            decodeInteger(contextCache, 'IAFS', decoder),
            'IAFS',
          );
    firstS += deltaFirstS;
    var currentS = firstS;

    while (true) {
      var currentT = 0;
      if (stripSize > 1) {
        currentT = huffman
            ? huffmanInput.readBits(logStripSize) as int
            : _requireInteger(
                decodeInteger(contextCache, 'IAIT', decoder),
                'IAIT',
              );
      }
      final t = stripSize * stripT + currentT;
      final symbolId = huffman
          ? huffmanTables.symbolIDTable.decode(huffmanInput) as int
          : decodeIAID(contextCache, decoder, symbolCodeLength);
      final applyRefinement = refinement &&
          (huffman
              ? huffmanInput.readBit() != 0
              : _requireInteger(
                    decodeInteger(contextCache, 'IARI', decoder),
                    'IARI',
                  ) !=
                  0);

      var symbolBitmap = inputSymbols[symbolId] as List<Uint8List>;
      var symbolWidth = symbolBitmap[0].length;
      var symbolHeight = symbolBitmap.length;
      if (applyRefinement) {
        final rdw = _requireInteger(
          decodeInteger(contextCache, 'IARDW', decoder),
          'IARDW',
        );
        final rdh = _requireInteger(
          decodeInteger(contextCache, 'IARDH', decoder),
          'IARDH',
        );
        final rdx = _requireInteger(
          decodeInteger(contextCache, 'IARDX', decoder),
          'IARDX',
        );
        final rdy = _requireInteger(
          decodeInteger(contextCache, 'IARDY', decoder),
          'IARDY',
        );
        symbolWidth += rdw;
        symbolHeight += rdh;
        symbolBitmap = decodeRefinement(
          symbolWidth,
          symbolHeight,
          refinementTemplateIndex,
          symbolBitmap,
          (rdw >> 1) + rdx,
          (rdh >> 1) + rdy,
          false,
          refinementAt,
          decodingContext,
        );
      }

      var increment = 0;
      if (transposed == 0) {
        if (referenceCorner > 1) {
          currentS += symbolWidth - 1;
        } else {
          increment = symbolWidth - 1;
        }
      } else if ((referenceCorner & 1) == 0) {
        currentS += symbolHeight - 1;
      } else {
        increment = symbolHeight - 1;
      }

      final offsetT = t - ((referenceCorner & 1) != 0 ? 0 : symbolHeight - 1);
      final offsetS =
          currentS - ((referenceCorner & 2) != 0 ? symbolWidth - 1 : 0);

      if (transposed != 0) {
        for (var s2 = 0; s2 < symbolHeight; s2++) {
          final targetY = offsetS + s2;
          if (targetY < 0 || targetY >= height) {
            continue;
          }
          final row = bitmap[targetY];
          final symbolRow = symbolBitmap[s2];
          for (var t2 = 0; t2 < symbolWidth; t2++) {
            final targetX = offsetT + t2;
            if (targetX < 0 || targetX >= width) {
              continue;
            }
            switch (combinationOperator) {
              case 0:
                row[targetX] |= symbolRow[t2];
                break;
              case 2:
                row[targetX] ^= symbolRow[t2];
                break;
              default:
                throw Jbig2Error(
                  'operator $combinationOperator is not supported',
                );
            }
          }
        }
      } else {
        for (var t2 = 0; t2 < symbolHeight; t2++) {
          final targetY = offsetT + t2;
          if (targetY < 0 || targetY >= height) {
            continue;
          }
          final row = bitmap[targetY];
          final symbolRow = symbolBitmap[t2];
          for (var s2 = 0; s2 < symbolWidth; s2++) {
            final targetX = offsetS + s2;
            if (targetX < 0 || targetX >= width) {
              continue;
            }
            switch (combinationOperator) {
              case 0:
                row[targetX] |= symbolRow[s2];
                break;
              case 2:
                row[targetX] ^= symbolRow[s2];
                break;
              default:
                throw Jbig2Error(
                  'operator $combinationOperator is not supported',
                );
            }
          }
        }
      }

      i++;
      final deltaS = huffman
          ? huffmanTables.tableDeltaS.decode(huffmanInput) as int?
          : decodeInteger(contextCache, 'IADS', decoder);
      if (deltaS == null) {
        break;
      }
      currentS += increment + deltaS + dsOffset;
    }
  }
  return bitmap;
}

List<List<Uint8List>> decodePatternDictionary(
  bool mmr,
  int patternWidth,
  int patternHeight,
  int maxPatternIndex,
  int template,
  DecodingContext decodingContext,
) {
  final at = <_TemplatePoint>[];
  if (!mmr) {
    at.add(_TemplatePoint(-patternWidth, 0));
    if (template == 0) {
      at.addAll(const [
        _TemplatePoint(-3, -1),
        _TemplatePoint(2, -2),
        _TemplatePoint(-2, -2),
      ]);
    }
  }

  final collectiveWidth = (maxPatternIndex + 1) * patternWidth;
  if (collectiveWidth == 0 || patternHeight == 0) {
    return List<List<Uint8List>>.generate(
      maxPatternIndex + 1,
      (_) => <Uint8List>[],
    );
  }
  final collectiveBitmap = decodeBitmap(
    mmr,
    collectiveWidth,
    patternHeight,
    template,
    false,
    null,
    at,
    decodingContext,
  );

  final patterns = <List<Uint8List>>[];
  for (var i = 0; i <= maxPatternIndex; i++) {
    final patternBitmap = <Uint8List>[];
    final xMin = patternWidth * i;
    final xMax = xMin + patternWidth;
    for (var y = 0; y < patternHeight; y++) {
      patternBitmap.add(Uint8List.sublistView(
        collectiveBitmap[y],
        xMin,
        xMax,
      ));
    }
    patterns.add(patternBitmap);
  }
  return patterns;
}

List<Uint8List> decodeHalftoneRegion(
  bool mmr,
  List<List<Uint8List>> patterns,
  int template,
  int regionWidth,
  int regionHeight,
  int defaultPixelValue,
  bool enableSkip,
  int combinationOperator,
  int gridWidth,
  int gridHeight,
  int gridOffsetX,
  int gridOffsetY,
  int gridVectorX,
  int gridVectorY,
  DecodingContext decodingContext,
) {
  if (enableSkip) {
    throw Jbig2Error('skip is not supported');
  }
  if (combinationOperator != 0) {
    throw Jbig2Error(
      'operator "$combinationOperator" is not supported in halftone region',
    );
  }

  final regionBitmap = <Uint8List>[];
  for (var i = 0; i < regionHeight; i++) {
    final row = Uint8List(regionWidth);
    if (defaultPixelValue != 0) {
      row.fillRange(0, row.length, defaultPixelValue);
    }
    regionBitmap.add(row);
  }

  if (patterns.isEmpty) {
    return regionBitmap;
  }

  final pattern0 = patterns[0];
  if (pattern0.isEmpty) {
    return regionBitmap;
  }

  final numberOfPatterns = patterns.length;
  final patternWidth = pattern0[0].length;
  final patternHeight = pattern0.length;
  final bitsPerValue = log2(numberOfPatterns);
  final at = <_TemplatePoint>[];
  if (!mmr) {
    at.add(_TemplatePoint(template <= 1 ? 3 : 2, -1));
    if (template == 0) {
      at.addAll(const [
        _TemplatePoint(-3, -1),
        _TemplatePoint(2, -2),
        _TemplatePoint(-2, -2),
      ]);
    }
  }

  final grayScaleBitPlanes = List<List<Uint8List>?>.filled(bitsPerValue, null);
  Reader? mmrInput;
  if (mmr) {
    mmrInput = Reader(
      decodingContext.data,
      decodingContext.start,
      decodingContext.end,
    );
  }

  for (var i = bitsPerValue - 1; i >= 0; i--) {
    grayScaleBitPlanes[i] = mmr
        ? decodeMMRBitmap(mmrInput, gridWidth, gridHeight, true)
        : decodeBitmap(
            false,
            gridWidth,
            gridHeight,
            template,
            false,
            null,
            at,
            decodingContext,
          );
  }

  for (var mg = 0; mg < gridHeight; mg++) {
    for (var ng = 0; ng < gridWidth; ng++) {
      var bit = 0;
      var patternIndex = 0;
      for (var j = bitsPerValue - 1; j >= 0; j--) {
        bit ^= grayScaleBitPlanes[j]![mg][ng];
        patternIndex |= bit << j;
      }
      if (patternIndex >= patterns.length) {
        continue;
      }
      final patternBitmap = patterns[patternIndex];
      final x = (gridOffsetX + mg * gridVectorY + ng * gridVectorX) >> 8;
      final y = (gridOffsetY + mg * gridVectorX - ng * gridVectorY) >> 8;

      for (var i = 0; i < patternHeight; i++) {
        final regionY = y + i;
        if (regionY < 0 || regionY >= regionHeight) {
          continue;
        }
        final regionRow = regionBitmap[regionY];
        final patternRow = patternBitmap[i];
        for (var j = 0; j < patternWidth; j++) {
          final regionX = x + j;
          if (regionX >= 0 && regionX < regionWidth) {
            regionRow[regionX] |= patternRow[j];
          }
        }
      }
    }
  }
  return regionBitmap;
}

class SegmentHeader {
  SegmentHeader({
    required this.number,
    required this.type,
    required this.typeName,
    required this.deferredNonRetain,
    required this.retainBits,
    required this.referredTo,
    required this.pageAssociation,
    required this.length,
    required this.headerEnd,
  });

  final int number;
  final int type;
  final String typeName;
  final bool deferredNonRetain;
  final List<int> retainBits;
  final List<int> referredTo;
  final int pageAssociation;
  int length;
  int headerEnd;
}

class Segment {
  Segment({
    required this.header,
    required this.data,
    this.start = 0,
    this.end = 0,
  });

  final SegmentHeader header;
  final Uint8List data;
  int start;
  int end;
}

class RegionSegmentInformation {
  const RegionSegmentInformation({
    required this.width,
    required this.height,
    required this.x,
    required this.y,
    required this.combinationOperator,
  });

  final int width;
  final int height;
  final int x;
  final int y;
  final int combinationOperator;
}

class PageInformation {
  PageInformation({
    required this.width,
    this.height,
    required this.resolutionX,
    required this.resolutionY,
    required this.lossless,
    required this.refinement,
    required this.defaultPixelValue,
    required this.combinationOperator,
    required this.requiresBuffer,
    required this.combinationOperatorOverride,
  });

  final int width;
  final int? height;
  final int resolutionX;
  final int resolutionY;
  final bool lossless;
  final bool refinement;
  final int defaultPixelValue;
  final int combinationOperator;
  final bool requiresBuffer;
  final bool combinationOperatorOverride;
}

class _GenericRegion {
  _GenericRegion({
    required this.info,
    required this.mmr,
    required this.template,
    required this.prediction,
    this.at,
  });

  final RegionSegmentInformation info;
  final bool mmr;
  final int template;
  final bool prediction;
  final List<_TemplatePoint>? at;
}

class _SymbolDictionary {
  _SymbolDictionary({
    required this.huffman,
    required this.refinement,
    required this.huffmanDHSelector,
    required this.huffmanDWSelector,
    required this.bitmapSizeSelector,
    required this.aggregationInstancesSelector,
    required this.bitmapCodingContextUsed,
    required this.bitmapCodingContextRetained,
    required this.template,
    required this.refinementTemplate,
    this.at,
    this.refinementAt,
    required this.numberOfExportedSymbols,
    required this.numberOfNewSymbols,
  });

  final bool huffman;
  final bool refinement;
  final int huffmanDHSelector;
  final int huffmanDWSelector;
  final bool bitmapSizeSelector;
  final bool aggregationInstancesSelector;
  final bool bitmapCodingContextUsed;
  final bool bitmapCodingContextRetained;
  final int template;
  final int refinementTemplate;
  final List<_TemplatePoint>? at;
  final List<_TemplatePoint>? refinementAt;
  final int numberOfExportedSymbols;
  final int numberOfNewSymbols;
}

class _TextRegion {
  _TextRegion({
    required this.info,
    required this.huffman,
    required this.refinement,
    required this.logStripSize,
    required this.stripSize,
    required this.referenceCorner,
    required this.transposed,
    required this.combinationOperator,
    required this.defaultPixelValue,
    required this.dsOffset,
    required this.refinementTemplate,
    this.huffmanFS = 0,
    this.huffmanDS = 0,
    this.huffmanDT = 0,
    this.huffmanRefinementDW = 0,
    this.huffmanRefinementDH = 0,
    this.huffmanRefinementDX = 0,
    this.huffmanRefinementDY = 0,
    this.huffmanRefinementSizeSelector = false,
    this.refinementAt,
    required this.numberOfSymbolInstances,
  });

  final RegionSegmentInformation info;
  final bool huffman;
  final bool refinement;
  final int logStripSize;
  final int stripSize;
  final int referenceCorner;
  final int transposed;
  final int combinationOperator;
  final int defaultPixelValue;
  final int dsOffset;
  final int refinementTemplate;
  final int huffmanFS;
  final int huffmanDS;
  final int huffmanDT;
  final int huffmanRefinementDW;
  final int huffmanRefinementDH;
  final int huffmanRefinementDX;
  final int huffmanRefinementDY;
  final bool huffmanRefinementSizeSelector;
  final List<_TemplatePoint>? refinementAt;
  final int numberOfSymbolInstances;
}

class _PatternDictionary {
  const _PatternDictionary({
    required this.mmr,
    required this.template,
    required this.patternWidth,
    required this.patternHeight,
    required this.maxPatternIndex,
  });

  final bool mmr;
  final int template;
  final int patternWidth;
  final int patternHeight;
  final int maxPatternIndex;
}

class _HalftoneRegion {
  const _HalftoneRegion({
    required this.info,
    required this.mmr,
    required this.template,
    required this.enableSkip,
    required this.combinationOperator,
    required this.defaultPixelValue,
    required this.gridWidth,
    required this.gridHeight,
    required this.gridOffsetX,
    required this.gridOffsetY,
    required this.gridVectorX,
    required this.gridVectorY,
  });

  final RegionSegmentInformation info;
  final bool mmr;
  final int template;
  final bool enableSkip;
  final int combinationOperator;
  final int defaultPixelValue;
  final int gridWidth;
  final int gridHeight;
  final int gridOffsetX;
  final int gridOffsetY;
  final int gridVectorX;
  final int gridVectorY;
}

int _uint16(Uint8List data, int offset) {
  return (data[offset] << 8) | data[offset + 1];
}

int _uint32(Uint8List data, int offset) {
  return ((data[offset] << 24) |
          (data[offset + 1] << 16) |
          (data[offset + 2] << 8) |
          data[offset + 3]) &
      0xffffffff;
}

int _int8(Uint8List data, int offset) {
  final value = data[offset];
  return value >= 0x80 ? value - 0x100 : value;
}

const int regionSegmentInformationFieldLength = 17;

RegionSegmentInformation readRegionSegmentInformation(
  Uint8List data,
  int start,
) {
  return RegionSegmentInformation(
    width: _uint32(data, start),
    height: _uint32(data, start + 4),
    x: _uint32(data, start + 8),
    y: _uint32(data, start + 12),
    combinationOperator: data[start + 16] & 7,
  );
}

SegmentHeader readSegmentHeader(Uint8List data, int start) {
  final number = _uint32(data, start);
  final flags = data[start + 4];
  final segmentType = flags & 0x3f;
  final typeName = segmentTypes[segmentType];
  if (typeName == null) {
    throw Jbig2Error('invalid segment type: $segmentType');
  }

  final pageAssociationFieldSize = (flags & 0x40) != 0;
  final referredFlags = data[start + 5];
  var referredToCount = (referredFlags >> 5) & 7;
  final retainBits = <int>[referredFlags & 31];
  var position = start + 6;
  if (referredToCount == 7) {
    referredToCount = _uint32(data, position - 1) & 0x1fffffff;
    position += 3;
    var bytes = (referredToCount + 8) >> 3;
    retainBits[0] = data[position++];
    while (--bytes > 0) {
      retainBits.add(data[position++]);
    }
  } else if (referredToCount == 5 || referredToCount == 6) {
    throw Jbig2Error('invalid referred-to flags');
  }

  var referredToSegmentNumberSize = 4;
  if (number <= 256) {
    referredToSegmentNumberSize = 1;
  } else if (number <= 65536) {
    referredToSegmentNumberSize = 2;
  }
  final referredTo = <int>[];
  for (var i = 0; i < referredToCount; i++) {
    int referredNumber;
    if (referredToSegmentNumberSize == 1) {
      referredNumber = data[position];
    } else if (referredToSegmentNumberSize == 2) {
      referredNumber = _uint16(data, position);
    } else {
      referredNumber = _uint32(data, position);
    }
    referredTo.add(referredNumber);
    position += referredToSegmentNumberSize;
  }

  final pageAssociation =
      pageAssociationFieldSize ? _uint32(data, position) : data[position];
  position += pageAssociationFieldSize ? 4 : 1;

  var length = _uint32(data, position);
  position += 4;

  if (length == 0xffffffff) {
    if (segmentType == 38) {
      final genericRegionInfo = readRegionSegmentInformation(data, position);
      final genericRegionSegmentFlags =
          data[position + regionSegmentInformationFieldLength];
      final genericRegionMmr = (genericRegionSegmentFlags & 1) != 0;
      final searchPattern = Uint8List(6);
      if (!genericRegionMmr) {
        searchPattern[0] = 0xff;
        searchPattern[1] = 0xac;
      }
      searchPattern[2] = (genericRegionInfo.height >> 24) & 0xff;
      searchPattern[3] = (genericRegionInfo.height >> 16) & 0xff;
      searchPattern[4] = (genericRegionInfo.height >> 8) & 0xff;
      searchPattern[5] = genericRegionInfo.height & 0xff;
      for (var i = position; i < data.length; i++) {
        var j = 0;
        while (j < searchPattern.length &&
            i + j < data.length &&
            searchPattern[j] == data[i + j]) {
          j++;
        }
        if (j == searchPattern.length) {
          length = i + searchPattern.length - position;
          break;
        }
      }
      if (length == 0xffffffff) {
        throw Jbig2Error('segment end was not found');
      }
    } else {
      throw Jbig2Error('invalid unknown segment length');
    }
  }

  return SegmentHeader(
    number: number,
    type: segmentType,
    typeName: typeName,
    deferredNonRetain: (flags & 0x80) != 0,
    retainBits: retainBits,
    referredTo: referredTo,
    pageAssociation: pageAssociation,
    length: length,
    headerEnd: position,
  );
}

List<Segment> readSegments(
  Map<String, dynamic> header,
  Uint8List data,
  int start,
  int end,
) {
  final segments = <Segment>[];
  var position = start;
  while (position < end) {
    final segmentHeader = readSegmentHeader(data, position);
    position = segmentHeader.headerEnd;
    final segment = Segment(header: segmentHeader, data: data);
    if (header['randomAccess'] != true) {
      segment.start = position;
      position += segmentHeader.length;
      segment.end = position;
    }
    segments.add(segment);
    if (segmentHeader.type == 51) {
      break;
    }
  }
  if (header['randomAccess'] == true) {
    for (final segment in segments) {
      segment.start = position;
      position += segment.header.length;
      segment.end = position;
    }
  }
  return segments;
}

void processSegment(Segment segment, SimpleSegmentVisitor visitor) {
  final header = segment.header;
  final data = segment.data;
  var position = segment.start;

  switch (header.type) {
    case 0:
      final dictionaryFlags = _uint16(data, position);
      position += 2;
      final huffman = (dictionaryFlags & 1) != 0;
      final refinement = (dictionaryFlags & 2) != 0;
      final template = (dictionaryFlags >> 10) & 3;
      final refinementTemplate = (dictionaryFlags >> 12) & 1;
      List<_TemplatePoint>? at;
      if (!huffman) {
        final atLength = template == 0 ? 4 : 1;
        at = <_TemplatePoint>[];
        for (var i = 0; i < atLength; i++) {
          at.add(
              _TemplatePoint(_int8(data, position), _int8(data, position + 1)));
          position += 2;
        }
      }
      List<_TemplatePoint>? refinementAt;
      if (refinement && refinementTemplate == 0) {
        refinementAt = <_TemplatePoint>[];
        for (var i = 0; i < 2; i++) {
          refinementAt.add(
              _TemplatePoint(_int8(data, position), _int8(data, position + 1)));
          position += 2;
        }
      }
      final numberOfExportedSymbols = _uint32(data, position);
      position += 4;
      final numberOfNewSymbols = _uint32(data, position);
      position += 4;
      visitor.onSymbolDictionary(
        _SymbolDictionary(
          huffman: huffman,
          refinement: refinement,
          huffmanDHSelector: (dictionaryFlags >> 2) & 3,
          huffmanDWSelector: (dictionaryFlags >> 4) & 3,
          bitmapSizeSelector: (dictionaryFlags & 0x40) != 0,
          aggregationInstancesSelector: (dictionaryFlags & 0x80) != 0,
          bitmapCodingContextUsed: (dictionaryFlags & 0x100) != 0,
          bitmapCodingContextRetained: (dictionaryFlags & 0x200) != 0,
          template: template,
          refinementTemplate: refinementTemplate,
          at: at,
          refinementAt: refinementAt,
          numberOfExportedSymbols: numberOfExportedSymbols,
          numberOfNewSymbols: numberOfNewSymbols,
        ),
        header.number,
        header.referredTo,
        data,
        position,
        segment.end,
      );
      break;
    case 6:
    case 7:
      final info = readRegionSegmentInformation(data, position);
      position += regionSegmentInformationFieldLength;
      final textRegionSegmentFlags = _uint16(data, position);
      position += 2;
      final refinement = (textRegionSegmentFlags & 2) != 0;
      final refinementTemplate = (textRegionSegmentFlags >> 15) & 1;
      var huffmanFS = 0;
      var huffmanDS = 0;
      var huffmanDT = 0;
      var huffmanRefinementDW = 0;
      var huffmanRefinementDH = 0;
      var huffmanRefinementDX = 0;
      var huffmanRefinementDY = 0;
      var huffmanRefinementSizeSelector = false;
      final huffman = (textRegionSegmentFlags & 1) != 0;
      if (huffman) {
        final textRegionHuffmanFlags = _uint16(data, position);
        position += 2;
        huffmanFS = textRegionHuffmanFlags & 3;
        huffmanDS = (textRegionHuffmanFlags >> 2) & 3;
        huffmanDT = (textRegionHuffmanFlags >> 4) & 3;
        huffmanRefinementDW = (textRegionHuffmanFlags >> 6) & 3;
        huffmanRefinementDH = (textRegionHuffmanFlags >> 8) & 3;
        huffmanRefinementDX = (textRegionHuffmanFlags >> 10) & 3;
        huffmanRefinementDY = (textRegionHuffmanFlags >> 12) & 3;
        huffmanRefinementSizeSelector = (textRegionHuffmanFlags & 0x4000) != 0;
      }
      List<_TemplatePoint>? refinementAt;
      if (refinement && refinementTemplate == 0) {
        refinementAt = <_TemplatePoint>[];
        for (var i = 0; i < 2; i++) {
          refinementAt.add(
              _TemplatePoint(_int8(data, position), _int8(data, position + 1)));
          position += 2;
        }
      }
      final dsOffsetRaw = (textRegionSegmentFlags >> 10) & 31;
      final dsOffset = dsOffsetRaw >= 16 ? dsOffsetRaw - 32 : dsOffsetRaw;
      final numberOfSymbolInstances = _uint32(data, position);
      position += 4;
      visitor.onImmediateTextRegion(
        _TextRegion(
          info: info,
          huffman: huffman,
          refinement: refinement,
          logStripSize: (textRegionSegmentFlags >> 2) & 3,
          stripSize: 1 << ((textRegionSegmentFlags >> 2) & 3),
          referenceCorner: (textRegionSegmentFlags >> 4) & 3,
          transposed: (textRegionSegmentFlags & 0x40) != 0 ? 1 : 0,
          combinationOperator: (textRegionSegmentFlags >> 7) & 3,
          defaultPixelValue: (textRegionSegmentFlags >> 9) & 1,
          dsOffset: dsOffset,
          refinementTemplate: refinementTemplate,
          huffmanFS: huffmanFS,
          huffmanDS: huffmanDS,
          huffmanDT: huffmanDT,
          huffmanRefinementDW: huffmanRefinementDW,
          huffmanRefinementDH: huffmanRefinementDH,
          huffmanRefinementDX: huffmanRefinementDX,
          huffmanRefinementDY: huffmanRefinementDY,
          huffmanRefinementSizeSelector: huffmanRefinementSizeSelector,
          refinementAt: refinementAt,
          numberOfSymbolInstances: numberOfSymbolInstances,
        ),
        header.referredTo,
        data,
        position,
        segment.end,
      );
      break;
    case 16:
      final patternDictionaryFlags = data[position++];
      final patternDictionary = _PatternDictionary(
        mmr: (patternDictionaryFlags & 1) != 0,
        template: (patternDictionaryFlags >> 1) & 3,
        patternWidth: data[position++],
        patternHeight: data[position++],
        maxPatternIndex: _uint32(data, position),
      );
      position += 4;
      visitor.onPatternDictionary(
        patternDictionary,
        header.number,
        data,
        position,
        segment.end,
      );
      break;
    case 22:
    case 23:
      final info = readRegionSegmentInformation(data, position);
      position += regionSegmentInformationFieldLength;
      final halftoneRegionFlags = data[position++];
      final halftoneRegion = _HalftoneRegion(
        info: info,
        mmr: (halftoneRegionFlags & 1) != 0,
        template: (halftoneRegionFlags >> 1) & 3,
        enableSkip: (halftoneRegionFlags & 8) != 0,
        combinationOperator: (halftoneRegionFlags >> 4) & 7,
        defaultPixelValue: (halftoneRegionFlags >> 7) & 1,
        gridWidth: _uint32(data, position),
        gridHeight: _uint32(data, position + 4),
        gridOffsetX: _uint32(data, position + 8),
        gridOffsetY: _uint32(data, position + 12),
        gridVectorX: _uint16(data, position + 16),
        gridVectorY: _uint16(data, position + 18),
      );
      position += 20;
      visitor.onImmediateHalftoneRegion(
        halftoneRegion,
        header.referredTo,
        data,
        position,
        segment.end,
      );
      break;
    case 38:
    case 39:
      final info = readRegionSegmentInformation(data, position);
      position += regionSegmentInformationFieldLength;
      final flags = data[position++];
      final mmr = (flags & 1) != 0;
      final template = (flags >> 1) & 3;
      final prediction = (flags & 8) != 0;
      List<_TemplatePoint>? at;
      if (!mmr) {
        final atLength = template == 0 ? 4 : 1;
        at = <_TemplatePoint>[];
        for (var i = 0; i < atLength; i++) {
          at.add(
              _TemplatePoint(_int8(data, position), _int8(data, position + 1)));
          position += 2;
        }
      }
      visitor.onImmediateGenericRegion(
        _GenericRegion(
          info: info,
          mmr: mmr,
          template: template,
          prediction: prediction,
          at: at,
        ),
        data,
        position,
        segment.end,
      );
      break;
    case 48:
      final height = _uint32(data, position + 4);
      final pageSegmentFlags = data[position + 16];
      visitor.onPageInformation(
        PageInformation(
          width: _uint32(data, position),
          height: height == 0xffffffff ? null : height,
          resolutionX: _uint32(data, position + 8),
          resolutionY: _uint32(data, position + 12),
          lossless: (pageSegmentFlags & 1) != 0,
          refinement: (pageSegmentFlags & 2) != 0,
          defaultPixelValue: (pageSegmentFlags >> 2) & 1,
          combinationOperator: (pageSegmentFlags >> 3) & 3,
          requiresBuffer: (pageSegmentFlags & 32) != 0,
          combinationOperatorOverride: (pageSegmentFlags & 64) != 0,
        ),
      );
      break;
    case 49:
    case 50:
    case 51:
      break;
    case 53:
      visitor.onTables(header.number, data, position, segment.end);
      break;
    case 62:
      break;
    default:
      throw Jbig2Error(
        'segment type ${header.typeName}(${header.type}) is not implemented',
      );
  }
}

void processSegments(List<Segment> segments, SimpleSegmentVisitor visitor) {
  for (final segment in segments) {
    processSegment(segment, visitor);
  }
}

class Reader implements CCITTFaxDecoderSource {
  Reader(this.data, this.start, this.end)
      : position = start,
        shift = -1;

  final Uint8List data;
  final int start;
  final int end;
  int position;
  int shift;
  int currentByte = 0;

  int readBit() {
    if (shift < 0) {
      if (position >= end) {
        throw Jbig2Error('end of data while reading bit');
      }
      currentByte = data[position++];
      shift = 7;
    }
    final bit = (currentByte >> shift) & 1;
    shift--;
    return bit;
  }

  int readBits(int numBits) {
    var result = 0;
    for (var i = numBits - 1; i >= 0; i--) {
      result |= readBit() << i;
    }
    return result;
  }

  void byteAlign() {
    shift = -1;
  }

  int next() {
    if (position >= end) {
      return -1;
    }
    return data[position++];
  }
}

class HuffmanLine {
  HuffmanLine(List<dynamic> lineData)
      : isOOB = lineData.length == 2,
        rangeLow = lineData.length == 2 ? 0 : lineData[0] as int,
        prefixLength =
            lineData.length == 2 ? lineData[0] as int : lineData[1] as int,
        rangeLength = lineData.length == 2 ? 0 : lineData[2] as int,
        prefixCode =
            lineData.length == 2 ? lineData[1] as int : lineData[3] as int,
        isLowerRange = lineData.length > 4 && lineData[4] == 'lower';

  final bool isOOB;
  final int rangeLow;
  final int prefixLength;
  final int rangeLength;
  int prefixCode;
  final bool isLowerRange;
}

class HuffmanTreeNode {
  HuffmanTreeNode([HuffmanLine? line])
      : isLeaf = line != null,
        rangeLength = line?.rangeLength ?? 0,
        rangeLow = line?.rangeLow ?? 0,
        isLowerRange = line?.isLowerRange ?? false,
        isOOB = line?.isOOB ?? false;

  final List<HuffmanTreeNode?> children =
      List<HuffmanTreeNode?>.filled(2, null);
  final bool isLeaf;
  final int rangeLength;
  final int rangeLow;
  final bool isLowerRange;
  final bool isOOB;

  void buildTree(HuffmanLine line, int shift) {
    final bit = (line.prefixCode >> shift) & 1;
    if (shift <= 0) {
      children[bit] = HuffmanTreeNode(line);
      return;
    }
    final node = children[bit] ??= HuffmanTreeNode();
    node.buildTree(line, shift - 1);
  }

  int? decodeNode(Reader reader) {
    if (isLeaf) {
      if (isOOB) {
        return null;
      }
      final htOffset = reader.readBits(rangeLength);
      return rangeLow + (isLowerRange ? -htOffset : htOffset);
    }
    final node = children[reader.readBit()];
    if (node == null) {
      throw Jbig2Error('invalid Huffman data');
    }
    return node.decodeNode(reader);
  }
}

class HuffmanTable {
  HuffmanTable(List<HuffmanLine> lines, bool prefixCodesDone) {
    if (!prefixCodesDone) {
      assignPrefixCodes(lines);
    }
    rootNode = HuffmanTreeNode();
    for (final line in lines) {
      if (line.prefixLength > 0) {
        rootNode.buildTree(line, line.prefixLength - 1);
      }
    }
  }

  late final HuffmanTreeNode rootNode;

  int? decode(Reader reader) {
    return rootNode.decodeNode(reader);
  }

  void assignPrefixCodes(List<HuffmanLine> lines) {
    var prefixLengthMax = 0;
    for (final line in lines) {
      if (line.prefixLength > prefixLengthMax) {
        prefixLengthMax = line.prefixLength;
      }
    }

    final histogram = Uint32List(prefixLengthMax + 1);
    for (final line in lines) {
      histogram[line.prefixLength]++;
    }
    histogram[0] = 0;

    var currentLength = 1;
    var firstCode = 0;
    while (currentLength <= prefixLengthMax) {
      firstCode = (firstCode + histogram[currentLength - 1]) << 1;
      var currentCode = firstCode;
      for (final line in lines) {
        if (line.prefixLength == currentLength) {
          line.prefixCode = currentCode;
          currentCode++;
        }
      }
      currentLength++;
    }
  }
}

final Map<int, HuffmanTable> _standardTablesCache = {};

List<List<dynamic>> _standardTableLines(int number) {
  switch (number) {
    case 1:
      return [
        [0, 1, 4, 0x0],
        [16, 2, 8, 0x2],
        [272, 3, 16, 0x6],
        [65808, 3, 32, 0x7],
      ];
    case 2:
      return [
        [0, 1, 0, 0x0],
        [1, 2, 0, 0x2],
        [2, 3, 0, 0x6],
        [3, 4, 3, 0xe],
        [11, 5, 6, 0x1e],
        [75, 6, 32, 0x3e],
        [6, 0x3f],
      ];
    case 3:
      return [
        [-256, 8, 8, 0xfe],
        [0, 1, 0, 0x0],
        [1, 2, 0, 0x2],
        [2, 3, 0, 0x6],
        [3, 4, 3, 0xe],
        [11, 5, 6, 0x1e],
        [-257, 8, 32, 0xff, 'lower'],
        [75, 7, 32, 0x7e],
        [6, 0x3e],
      ];
    case 4:
      return [
        [1, 1, 0, 0x0],
        [2, 2, 0, 0x2],
        [3, 3, 0, 0x6],
        [4, 4, 3, 0xe],
        [12, 5, 6, 0x1e],
        [76, 5, 32, 0x1f],
      ];
    case 5:
      return [
        [-255, 7, 8, 0x7e],
        [1, 1, 0, 0x0],
        [2, 2, 0, 0x2],
        [3, 3, 0, 0x6],
        [4, 4, 3, 0xe],
        [12, 5, 6, 0x1e],
        [-256, 7, 32, 0x7f, 'lower'],
        [76, 6, 32, 0x3e],
      ];
    case 6:
      return [
        [-2048, 5, 10, 0x1c],
        [-1024, 4, 9, 0x8],
        [-512, 4, 8, 0x9],
        [-256, 4, 7, 0xa],
        [-128, 5, 6, 0x1d],
        [-64, 5, 5, 0x1e],
        [-32, 4, 5, 0xb],
        [0, 2, 7, 0x0],
        [128, 3, 7, 0x2],
        [256, 3, 8, 0x3],
        [512, 4, 9, 0xc],
        [1024, 4, 10, 0xd],
        [-2049, 6, 32, 0x3e, 'lower'],
        [2048, 6, 32, 0x3f],
      ];
    case 7:
      return [
        [-1024, 4, 9, 0x8],
        [-512, 3, 8, 0x0],
        [-256, 4, 7, 0x9],
        [-128, 5, 6, 0x1a],
        [-64, 5, 5, 0x1b],
        [-32, 4, 5, 0xa],
        [0, 4, 5, 0xb],
        [32, 5, 5, 0x1c],
        [64, 5, 6, 0x1d],
        [128, 4, 7, 0xc],
        [256, 3, 8, 0x1],
        [512, 3, 9, 0x2],
        [1024, 3, 10, 0x3],
        [-1025, 5, 32, 0x1e, 'lower'],
        [2048, 5, 32, 0x1f],
      ];
    case 8:
      return [
        [-15, 8, 3, 0xfc],
        [-7, 9, 1, 0x1fc],
        [-5, 8, 1, 0xfd],
        [-3, 9, 0, 0x1fd],
        [-2, 7, 0, 0x7c],
        [-1, 4, 0, 0xa],
        [0, 2, 1, 0x0],
        [2, 5, 0, 0x1a],
        [3, 6, 0, 0x3a],
        [4, 3, 4, 0x4],
        [20, 6, 1, 0x3b],
        [22, 4, 4, 0xb],
        [38, 4, 5, 0xc],
        [70, 5, 6, 0x1b],
        [134, 5, 7, 0x1c],
        [262, 6, 7, 0x3c],
        [390, 7, 8, 0x7d],
        [646, 6, 10, 0x3d],
        [-16, 9, 32, 0x1fe, 'lower'],
        [1670, 9, 32, 0x1ff],
        [2, 0x1],
      ];
    case 9:
      return [
        [-31, 8, 4, 0xfc],
        [-15, 9, 2, 0x1fc],
        [-11, 8, 2, 0xfd],
        [-7, 9, 1, 0x1fd],
        [-5, 7, 1, 0x7c],
        [-3, 4, 1, 0xa],
        [-1, 3, 1, 0x2],
        [1, 3, 1, 0x3],
        [3, 5, 1, 0x1a],
        [5, 6, 1, 0x3a],
        [7, 3, 5, 0x4],
        [39, 6, 2, 0x3b],
        [43, 4, 5, 0xb],
        [75, 4, 6, 0xc],
        [139, 5, 7, 0x1b],
        [267, 5, 8, 0x1c],
        [523, 6, 8, 0x3c],
        [779, 7, 9, 0x7d],
        [1291, 6, 11, 0x3d],
        [-32, 9, 32, 0x1fe, 'lower'],
        [3339, 9, 32, 0x1ff],
        [2, 0x0],
      ];
    case 10:
      return [
        [-21, 7, 4, 0x7a],
        [-5, 8, 0, 0xfc],
        [-4, 7, 0, 0x7b],
        [-3, 5, 0, 0x18],
        [-2, 2, 2, 0x0],
        [2, 5, 0, 0x19],
        [3, 6, 0, 0x36],
        [4, 7, 0, 0x7c],
        [5, 8, 0, 0xfd],
        [6, 2, 6, 0x1],
        [70, 5, 5, 0x1a],
        [102, 6, 5, 0x37],
        [134, 6, 6, 0x38],
        [198, 6, 7, 0x39],
        [326, 6, 8, 0x3a],
        [582, 6, 9, 0x3b],
        [1094, 6, 10, 0x3c],
        [2118, 7, 11, 0x7d],
        [-22, 8, 32, 0xfe, 'lower'],
        [4166, 8, 32, 0xff],
        [2, 0x2],
      ];
    case 11:
      return [
        [1, 1, 0, 0x0],
        [2, 2, 1, 0x2],
        [4, 4, 0, 0xc],
        [5, 4, 1, 0xd],
        [7, 5, 1, 0x1c],
        [9, 5, 2, 0x1d],
        [13, 6, 2, 0x3c],
        [17, 7, 2, 0x7a],
        [21, 7, 3, 0x7b],
        [29, 7, 4, 0x7c],
        [45, 7, 5, 0x7d],
        [77, 7, 6, 0x7e],
        [141, 7, 32, 0x7f],
      ];
    case 12:
      return [
        [1, 1, 0, 0x0],
        [2, 2, 0, 0x2],
        [3, 3, 1, 0x6],
        [5, 5, 0, 0x1c],
        [6, 5, 1, 0x1d],
        [8, 6, 1, 0x3c],
        [10, 7, 0, 0x7a],
        [11, 7, 1, 0x7b],
        [13, 7, 2, 0x7c],
        [17, 7, 3, 0x7d],
        [25, 7, 4, 0x7e],
        [41, 8, 5, 0xfe],
        [73, 8, 32, 0xff],
      ];
    case 13:
      return [
        [1, 1, 0, 0x0],
        [2, 3, 0, 0x4],
        [3, 4, 0, 0xc],
        [4, 5, 0, 0x1c],
        [5, 4, 1, 0xd],
        [7, 3, 3, 0x5],
        [15, 6, 1, 0x3a],
        [17, 6, 2, 0x3b],
        [21, 6, 3, 0x3c],
        [29, 6, 4, 0x3d],
        [45, 6, 5, 0x3e],
        [77, 7, 6, 0x7e],
        [141, 7, 32, 0x7f],
      ];
    case 14:
      return [
        [-2, 3, 0, 0x4],
        [-1, 3, 0, 0x5],
        [0, 1, 0, 0x0],
        [1, 3, 0, 0x6],
        [2, 3, 0, 0x7],
      ];
    case 15:
      return [
        [-24, 7, 4, 0x7c],
        [-8, 6, 2, 0x3c],
        [-4, 5, 1, 0x1c],
        [-2, 4, 0, 0xc],
        [-1, 3, 0, 0x4],
        [0, 1, 0, 0x0],
        [1, 3, 0, 0x5],
        [2, 4, 0, 0xd],
        [3, 5, 1, 0x1d],
        [5, 6, 2, 0x3d],
        [9, 7, 4, 0x7d],
        [-25, 7, 32, 0x7e, 'lower'],
        [25, 7, 32, 0x7f],
      ];
    default:
      throw Jbig2Error('standard table B.$number does not exist');
  }
}

HuffmanTable getStandardTable(int number) {
  final cached = _standardTablesCache[number];
  if (cached != null) {
    return cached;
  }
  final lines = _standardTableLines(number).map(HuffmanLine.new).toList();
  final table = HuffmanTable(lines, true);
  _standardTablesCache[number] = table;
  return table;
}

HuffmanTable decodeTablesSegment(Uint8List data, int start, int end) {
  final flags = data[start];
  final lowestValue = _uint32(data, start + 1);
  final highestValue = _uint32(data, start + 5);
  final reader = Reader(data, start + 9, end);

  final prefixSizeBits = ((flags >> 1) & 7) + 1;
  final rangeSizeBits = ((flags >> 4) & 7) + 1;
  final lines = <HuffmanLine>[];
  var currentRangeLow = lowestValue;

  do {
    final prefixLength = reader.readBits(prefixSizeBits);
    final rangeLength = reader.readBits(rangeSizeBits);
    lines.add(HuffmanLine([currentRangeLow, prefixLength, rangeLength, 0]));
    currentRangeLow += 1 << rangeLength;
  } while (currentRangeLow < highestValue);

  var prefixLength = reader.readBits(prefixSizeBits);
  lines.add(HuffmanLine([lowestValue - 1, prefixLength, 32, 0, 'lower']));

  prefixLength = reader.readBits(prefixSizeBits);
  lines.add(HuffmanLine([highestValue, prefixLength, 32, 0]));

  if ((flags & 1) != 0) {
    prefixLength = reader.readBits(prefixSizeBits);
    lines.add(HuffmanLine([prefixLength, 0]));
  }

  return HuffmanTable(lines, false);
}

HuffmanTable getCustomHuffmanTable(
  int index,
  List<int> referredTo,
  Map<int, HuffmanTable> customTables,
) {
  var currentIndex = 0;
  for (final segmentNumber in referredTo) {
    final table = customTables[segmentNumber];
    if (table != null) {
      if (index == currentIndex) {
        return table;
      }
      currentIndex++;
    }
  }
  throw Jbig2Error("can't find custom Huffman table");
}

class TextRegionHuffmanTables {
  const TextRegionHuffmanTables({
    required this.symbolIDTable,
    required this.tableFirstS,
    required this.tableDeltaS,
    required this.tableDeltaT,
  });

  final HuffmanTable symbolIDTable;
  final HuffmanTable tableFirstS;
  final HuffmanTable tableDeltaS;
  final HuffmanTable tableDeltaT;
}

class SymbolDictionaryHuffmanTables {
  const SymbolDictionaryHuffmanTables({
    required this.tableDeltaHeight,
    required this.tableDeltaWidth,
    required this.tableBitmapSize,
    required this.tableAggregateInstances,
  });

  final HuffmanTable tableDeltaHeight;
  final HuffmanTable tableDeltaWidth;
  final HuffmanTable tableBitmapSize;
  final HuffmanTable tableAggregateInstances;
}

dynamic getTextRegionHuffmanTables(dynamic textRegion, dynamic referredTo,
    dynamic customTables, int numberOfSymbols, Reader reader) {
  final codes = <HuffmanLine>[];
  for (var i = 0; i <= 34; i++) {
    final codeLength = reader.readBits(4);
    codes.add(HuffmanLine([i, codeLength, 0, 0]));
  }
  final runCodesTable = HuffmanTable(codes, false);

  codes.clear();
  for (var i = 0; i < numberOfSymbols;) {
    final codeLength = _requireInteger(
      runCodesTable.decode(reader),
      'symbol ID Huffman table',
    );
    if (codeLength >= 32) {
      int repeatedLength;
      int numberOfRepeats;
      switch (codeLength) {
        case 32:
          if (i == 0) {
            throw Jbig2Error('no previous value in symbol ID table');
          }
          numberOfRepeats = reader.readBits(2) + 3;
          repeatedLength = codes[i - 1].prefixLength;
          break;
        case 33:
          numberOfRepeats = reader.readBits(3) + 3;
          repeatedLength = 0;
          break;
        case 34:
          numberOfRepeats = reader.readBits(7) + 11;
          repeatedLength = 0;
          break;
        default:
          throw Jbig2Error('invalid code length in symbol ID table');
      }
      for (var j = 0; j < numberOfRepeats && i < numberOfSymbols; j++, i++) {
        codes.add(HuffmanLine([i, repeatedLength, 0, 0]));
      }
    } else {
      codes.add(HuffmanLine([i, codeLength, 0, 0]));
      i++;
    }
  }
  reader.byteAlign();
  final symbolIDTable = HuffmanTable(codes, false);

  final referredSegments = (referredTo as List).cast<int>();
  final tables = (customTables as Map).cast<int, HuffmanTable>();
  var customIndex = 0;

  late final HuffmanTable tableFirstS;
  switch (textRegion.huffmanFS) {
    case 0:
    case 1:
      tableFirstS = getStandardTable(textRegion.huffmanFS + 6);
      break;
    case 3:
      tableFirstS =
          getCustomHuffmanTable(customIndex++, referredSegments, tables);
      break;
    default:
      throw Jbig2Error('invalid Huffman FS selector');
  }

  late final HuffmanTable tableDeltaS;
  switch (textRegion.huffmanDS) {
    case 0:
    case 1:
    case 2:
      tableDeltaS = getStandardTable(textRegion.huffmanDS + 8);
      break;
    case 3:
      tableDeltaS =
          getCustomHuffmanTable(customIndex++, referredSegments, tables);
      break;
    default:
      throw Jbig2Error('invalid Huffman DS selector');
  }

  late final HuffmanTable tableDeltaT;
  switch (textRegion.huffmanDT) {
    case 0:
    case 1:
    case 2:
      tableDeltaT = getStandardTable(textRegion.huffmanDT + 11);
      break;
    case 3:
      tableDeltaT =
          getCustomHuffmanTable(customIndex++, referredSegments, tables);
      break;
    default:
      throw Jbig2Error('invalid Huffman DT selector');
  }

  if (textRegion.refinement == true) {
    throw Jbig2Error('refinement with Huffman is not supported');
  }

  return TextRegionHuffmanTables(
    symbolIDTable: symbolIDTable,
    tableFirstS: tableFirstS,
    tableDeltaS: tableDeltaS,
    tableDeltaT: tableDeltaT,
  );
}

dynamic getSymbolDictionaryHuffmanTables(
    dynamic dictionary, dynamic referredTo, dynamic customTables) {
  final referredSegments = (referredTo as List).cast<int>();
  final tables = (customTables as Map).cast<int, HuffmanTable>();
  var customIndex = 0;

  late final HuffmanTable tableDeltaHeight;
  switch (dictionary.huffmanDHSelector) {
    case 0:
    case 1:
      tableDeltaHeight = getStandardTable(dictionary.huffmanDHSelector + 4);
      break;
    case 3:
      tableDeltaHeight =
          getCustomHuffmanTable(customIndex++, referredSegments, tables);
      break;
    default:
      throw Jbig2Error('invalid Huffman DH selector');
  }

  late final HuffmanTable tableDeltaWidth;
  switch (dictionary.huffmanDWSelector) {
    case 0:
    case 1:
      tableDeltaWidth = getStandardTable(dictionary.huffmanDWSelector + 2);
      break;
    case 3:
      tableDeltaWidth =
          getCustomHuffmanTable(customIndex++, referredSegments, tables);
      break;
    default:
      throw Jbig2Error('invalid Huffman DW selector');
  }

  final HuffmanTable tableBitmapSize;
  if (dictionary.bitmapSizeSelector == true) {
    tableBitmapSize =
        getCustomHuffmanTable(customIndex++, referredSegments, tables);
  } else {
    tableBitmapSize = getStandardTable(1);
  }

  final HuffmanTable tableAggregateInstances;
  if (dictionary.aggregationInstancesSelector == true) {
    tableAggregateInstances =
        getCustomHuffmanTable(customIndex, referredSegments, tables);
  } else {
    tableAggregateInstances = getStandardTable(1);
  }

  return SymbolDictionaryHuffmanTables(
    tableDeltaHeight: tableDeltaHeight,
    tableDeltaWidth: tableDeltaWidth,
    tableBitmapSize: tableBitmapSize,
    tableAggregateInstances: tableAggregateInstances,
  );
}

List<Uint8List> readUncompressedBitmap(Reader reader, int width, int height) {
  final bitmap = <Uint8List>[];
  for (var y = 0; y < height; y++) {
    final row = Uint8List(width);
    bitmap.add(row);
    for (var x = 0; x < width; x++) {
      row[x] = reader.readBit();
    }
    reader.byteAlign();
  }
  return bitmap;
}

List<Uint8List> decodeMMRBitmap(
    dynamic input, int width, int height, bool endOfBlock) {
  if (input is! CCITTFaxDecoderSource) {
    throw Jbig2Error('invalid MMR input source');
  }
  final decoder = CCITTFaxDecoder(
    input,
    CCITTFaxDecoderOptions(
      k: -1,
      columns: width,
      rows: height,
      blackIs1: true,
      endOfBlock: endOfBlock,
    ),
  );
  final bitmap = <Uint8List>[];
  var eof = false;

  for (var y = 0; y < height; y++) {
    final row = Uint8List(width);
    bitmap.add(row);
    var shift = -1;
    var currentByte = 0;
    for (var x = 0; x < width; x++) {
      if (shift < 0) {
        currentByte = decoder.readNextChar();
        if (currentByte == -1) {
          currentByte = 0;
          eof = true;
        }
        shift = 7;
      }
      row[x] = (currentByte >> shift) & 1;
      shift--;
    }
  }

  if (endOfBlock && !eof) {
    const lookForEofLimit = 5;
    for (var i = 0; i < lookForEofLimit; i++) {
      if (decoder.readNextChar() == -1) {
        break;
      }
    }
  }

  return bitmap;
}

Uint8List parseJbig2Chunks(List<Map<String, dynamic>> chunks) {
  final visitor = SimpleSegmentVisitor();
  for (final chunk in chunks) {
    final data = chunk['data'] as Uint8List;
    final start = chunk['start'] as int;
    final end = chunk['end'] as int;
    final segments = readSegments(<String, dynamic>{}, data, start, end);
    processSegments(segments, visitor);
  }
  return visitor.buffer;
}

class SimpleSegmentVisitor {
  PageInformation? currentPageInfo;
  final Map<int, HuffmanTable> customTables = {};
  final Map<int, List<dynamic>> symbols = {};
  final Map<int, List<List<Uint8List>>> patterns = {};
  Uint8List buffer = Uint8List(0);

  void onPageInformation(PageInformation info) {
    currentPageInfo = info;
    final height = info.height;
    if (height == null) {
      throw Jbig2Error('page information height is unknown');
    }
    final rowSize = (info.width + 7) >> 3;
    buffer = Uint8List(rowSize * height);
    if (info.defaultPixelValue != 0) {
      buffer.fillRange(0, buffer.length, 0xff);
    }
  }

  void drawBitmap(RegionSegmentInformation regionInfo, List<Uint8List> bitmap) {
    final pageInfo = currentPageInfo;
    if (pageInfo == null) {
      throw Jbig2Error('page information missing before region segment');
    }
    final rowSize = (pageInfo.width + 7) >> 3;
    final combinationOperator = pageInfo.combinationOperatorOverride
        ? regionInfo.combinationOperator
        : pageInfo.combinationOperator;
    final mask0 = 128 >> (regionInfo.x & 7);
    var offset0 = regionInfo.y * rowSize + (regionInfo.x >> 3);

    switch (combinationOperator) {
      case 0:
        for (var i = 0; i < regionInfo.height; i++) {
          var mask = mask0;
          var offset = offset0;
          for (var j = 0; j < regionInfo.width; j++) {
            if (bitmap[i][j] != 0) {
              buffer[offset] |= mask;
            }
            mask >>= 1;
            if (mask == 0) {
              mask = 128;
              offset++;
            }
          }
          offset0 += rowSize;
        }
        break;
      case 2:
        for (var i = 0; i < regionInfo.height; i++) {
          var mask = mask0;
          var offset = offset0;
          for (var j = 0; j < regionInfo.width; j++) {
            if (bitmap[i][j] != 0) {
              buffer[offset] ^= mask;
            }
            mask >>= 1;
            if (mask == 0) {
              mask = 128;
              offset++;
            }
          }
          offset0 += rowSize;
        }
        break;
      default:
        throw Jbig2Error('operator $combinationOperator is not supported');
    }
  }

  void onImmediateGenericRegion(
    _GenericRegion region,
    Uint8List data,
    int start,
    int end,
  ) {
    final decodingContext = DecodingContext(data, start, end);
    final bitmap = decodeBitmap(
      region.mmr,
      region.info.width,
      region.info.height,
      region.template,
      region.prediction,
      null,
      region.at,
      decodingContext,
    );
    drawBitmap(region.info, bitmap);
  }

  void onImmediateLosslessGenericRegion(
    _GenericRegion region,
    Uint8List data,
    int start,
    int end,
  ) {
    onImmediateGenericRegion(region, data, start, end);
  }

  void onTables(int currentSegment, Uint8List data, int start, int end) {
    customTables[currentSegment] = decodeTablesSegment(data, start, end);
  }

  void onSymbolDictionary(
    _SymbolDictionary dictionary,
    int currentSegment,
    List<int> referredSegments,
    Uint8List data,
    int start,
    int end,
  ) {
    dynamic huffmanTables;
    Reader? huffmanInput;
    if (dictionary.huffman) {
      huffmanTables = getSymbolDictionaryHuffmanTables(
        dictionary,
        referredSegments,
        customTables,
      );
      huffmanInput = Reader(data, start, end);
    }

    final inputSymbols = <dynamic>[];
    for (final referredSegment in referredSegments) {
      final referredSymbols = symbols[referredSegment];
      if (referredSymbols != null) {
        inputSymbols.addAll(referredSymbols);
      }
    }

    final decodingContext = DecodingContext(data, start, end);
    symbols[currentSegment] = decodeSymbolDictionary(
      dictionary.huffman,
      dictionary.refinement,
      inputSymbols,
      dictionary.numberOfNewSymbols,
      dictionary.numberOfExportedSymbols,
      huffmanTables,
      dictionary.template,
      dictionary.at,
      dictionary.refinementTemplate,
      dictionary.refinementAt,
      decodingContext,
      huffmanInput,
    );
  }

  void onImmediateTextRegion(
    _TextRegion region,
    List<int> referredSegments,
    Uint8List data,
    int start,
    int end,
  ) {
    final inputSymbols = <dynamic>[];
    for (final referredSegment in referredSegments) {
      final referredSymbols = symbols[referredSegment];
      if (referredSymbols != null) {
        inputSymbols.addAll(referredSymbols);
      }
    }

    dynamic huffmanTables;
    Reader? huffmanInput;
    if (region.huffman) {
      huffmanInput = Reader(data, start, end);
      huffmanTables = getTextRegionHuffmanTables(
        region,
        referredSegments,
        customTables,
        inputSymbols.length,
        huffmanInput,
      );
    }

    final decodingContext = DecodingContext(data, start, end);
    final bitmap = decodeTextRegion(
      region.huffman,
      region.refinement,
      region.info.width,
      region.info.height,
      region.defaultPixelValue,
      region.numberOfSymbolInstances,
      region.stripSize,
      inputSymbols,
      log2(inputSymbols.length),
      region.transposed,
      region.dsOffset,
      region.referenceCorner,
      region.combinationOperator,
      huffmanTables,
      region.refinementTemplate,
      region.refinementAt,
      decodingContext,
      region.logStripSize,
      huffmanInput,
    );
    drawBitmap(region.info, bitmap);
  }

  void onImmediateLosslessTextRegion(
    _TextRegion region,
    List<int> referredSegments,
    Uint8List data,
    int start,
    int end,
  ) {
    onImmediateTextRegion(region, referredSegments, data, start, end);
  }

  void onPatternDictionary(
    _PatternDictionary dictionary,
    int currentSegment,
    Uint8List data,
    int start,
    int end,
  ) {
    final decodingContext = DecodingContext(data, start, end);
    patterns[currentSegment] = decodePatternDictionary(
      dictionary.mmr,
      dictionary.patternWidth,
      dictionary.patternHeight,
      dictionary.maxPatternIndex,
      dictionary.template,
      decodingContext,
    );
  }

  void onImmediateHalftoneRegion(
    _HalftoneRegion region,
    List<int> referredSegments,
    Uint8List data,
    int start,
    int end,
  ) {
    if (referredSegments.isEmpty) {
      throw Jbig2Error('halftone region is missing a pattern dictionary');
    }
    final referredPatterns = patterns[referredSegments[0]];
    if (referredPatterns == null) {
      throw Jbig2Error(
          'pattern dictionary ${referredSegments[0]} was not found');
    }
    final decodingContext = DecodingContext(data, start, end);
    final bitmap = decodeHalftoneRegion(
      region.mmr,
      referredPatterns,
      region.template,
      region.info.width,
      region.info.height,
      region.defaultPixelValue,
      region.enableSkip,
      region.combinationOperator,
      region.gridWidth,
      region.gridHeight,
      region.gridOffsetX,
      region.gridOffsetY,
      region.gridVectorX,
      region.gridVectorY,
      decodingContext,
    );
    drawBitmap(region.info, bitmap);
  }

  void onImmediateLosslessHalftoneRegion(
    _HalftoneRegion region,
    List<int> referredSegments,
    Uint8List data,
    int start,
    int end,
  ) {
    onImmediateHalftoneRegion(region, referredSegments, data, start, end);
  }
}

class Jbig2Image {
  Uint8List parseChunks(List<Map<String, dynamic>> chunks) {
    return parseJbig2Chunks(chunks);
  }
}
