// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'package:pdfjs/src/core/evaluator.dart';
import 'package:pdfjs/src/core/font_translation.dart';
import 'package:pdfjs/src/core/operator_list.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/stream.dart';
import 'package:pdfjs/src/core/xref.dart';
import 'package:pdfjs/src/shared/util.dart';
import 'package:test/test.dart';

Dict dict(Map<String, dynamic> values) {
  final value = Dict();
  for (final entry in values.entries) {
    value.set(entry.key, entry.value);
  }
  return value;
}

Dict simpleFont({
  String subtype = 'Type1',
  String baseFont = 'Helvetica',
  dynamic encoding,
  dynamic toUnicode,
  int firstChar = 32,
  int lastChar = 90,
  List<num>? widths,
  Dict? descriptor,
}) {
  return dict(<String, dynamic>{
    'Type': Name.get('Font'),
    'Subtype': Name.get(subtype),
    'BaseFont': Name.get(baseFont),
    'FirstChar': firstChar,
    'LastChar': lastChar,
    'Widths':
        widths ?? List<num>.generate(lastChar - firstChar + 1, (index) => 500),
    if (encoding != null) 'Encoding': encoding,
    if (toUnicode != null) 'ToUnicode': toUnicode,
    if (descriptor != null) 'FontDescriptor': descriptor,
  });
}

Future<OperatorList> evaluateFont(String content, Dict font,
    {dynamic handler}) async {
  final resources = dict(<String, dynamic>{
    'Font': dict(<String, dynamic>{'F1': font}),
  });
  final evaluator = PartialEvaluator(
    xref: XRef(StringStream(''), null),
    pageIndex: 4,
    handler: handler,
  );
  final result = OperatorList(RenderingIntentFlag.opList);
  await evaluator.getOperatorList(
    contentStream: StringStream(content),
    executionContext: null,
    operatorList: result,
    resources: resources,
  );
  return result;
}

List<dynamic> textArguments(OperatorList list, int operation) {
  final index = list.fnArray.indexOf(operation);
  expect(index, isNonNegative);
  return list.argsArray[index];
}

class RecordingHandler {
  final calls = <List<dynamic>>[];

  void send(String action, List<dynamic> data) {
    calls.add(<dynamic>[action, data]);
  }
}

void main() {
  group('parseToUnicodeCMap', () {
    test('parses bfchar entries', () {
      final map = parseToUnicodeCMap(Uint8List.fromList('''
        2 beginbfchar
        <01> <0041>
        <02> <20AC>
        endbfchar
      '''
          .codeUnits));
      expect(map.get(1), 'A');
      expect(map.get(2), '€');
      expect(map.length, 2);
    });

    test('parses surrogate pairs encoded as UTF-16BE', () {
      final map = parseToUnicodeCMap(Uint8List.fromList('''
        1 beginbfchar
        <20> <D83DDE00>
        endbfchar
      '''
          .codeUnits));
      expect(map.get(0x20), '😀');
    });

    test('parses a sequential bfrange', () {
      final map = parseToUnicodeCMap(Uint8List.fromList('''
        1 beginbfrange
        <10> <13> <0061>
        endbfrange
      '''
          .codeUnits));
      expect(map.get(0x10), 'a');
      expect(map.get(0x11), 'b');
      expect(map.get(0x12), 'c');
      expect(map.get(0x13), 'd');
    });

    test('parses an explicit bfrange array', () {
      final map = parseToUnicodeCMap(Uint8List.fromList('''
        1 beginbfrange
        <20> <22> [ <0066> <0069> <006A> ]
        endbfrange
      '''
          .codeUnits));
      expect(map.get(0x20), 'f');
      expect(map.get(0x21), 'i');
      expect(map.get(0x22), 'j');
    });

    test('ignores comments and unrelated CMap declarations', () {
      final map = parseToUnicodeCMap(Uint8List.fromList('''
        /CIDInit /ProcSet findresource begin
        12 dict begin begincmap
        /CMapName /Adobe-Identity-UCS def
        1 beginbfchar <41> <005A> endbfchar
        endcmap end end
      '''
          .codeUnits));
      expect(map.get(0x41), 'Z');
    });

    test('returns an empty map for malformed hex operands', () {
      final map = parseToUnicodeCMap(Uint8List.fromList(
        '1 beginbfchar <XX> <0041> endbfchar'.codeUnits,
      ));
      expect(map.length, 0);
    });
  });

  group('FontTranslator simple fonts', () {
    test('uses standard encoding and explicit widths', () {
      final translated = FontTranslator().translate(
        simpleFont(
          firstChar: 65,
          lastChar: 67,
          widths: const <num>[600, 610, 620],
        ),
        'g_font_1',
      );
      final glyphs = translated.glyphs('ABC');
      expect(glyphs.map((g) => g['unicode']), <String>['A', 'B', 'C']);
      expect(glyphs.map((g) => g['width']), <num>[600, 610, 620]);
      expect(translated.loadedName, 'g_font_1');
      expect(translated.font.name, 'Helvetica');
    });

    test('applies Encoding Differences to glyph Unicode', () {
      final encoding = dict(<String, dynamic>{
        'BaseEncoding': Name.get('WinAnsiEncoding'),
        'Differences': <dynamic>[
          65,
          Name.get('Euro'),
          Name.get('Agrave'),
        ],
      });
      final translated = FontTranslator().translate(
        simpleFont(
          encoding: encoding,
          firstChar: 65,
          lastChar: 66,
          widths: const <num>[700, 710],
        ),
        'g_font_2',
      );
      final glyphs = translated.glyphs('AB');
      expect(glyphs[0]['unicode'], '€');
      expect(glyphs[1]['unicode'], 'À');
      expect(translated.properties['differences'], <int, String>{
        65: 'Euro',
        66: 'Agrave',
      });
    });

    test('lets an included ToUnicode map override the encoding', () {
      final cmap = StringStream('''
        2 beginbfchar
        <41> <03A9>
        <42> <03B2>
        endbfchar
      ''');
      final translated = FontTranslator().translate(
        simpleFont(
          toUnicode: cmap,
          firstChar: 65,
          lastChar: 66,
          widths: const <num>[550, 560],
        ),
        'g_font_3',
      );
      final glyphs = translated.glyphs('AB');
      expect(glyphs[0]['unicode'], 'Ω');
      expect(glyphs[1]['unicode'], 'β');
      expect(translated.properties['hasIncludedToUnicodeMap'], isTrue);
    });

    test('copies descriptor metrics and missing width', () {
      final descriptor = dict(<String, dynamic>{
        'Flags': 33,
        'FontBBox': <dynamic>[-10, -200, 900, 800],
        'Ascent': 750,
        'Descent': -250,
        'CapHeight': 700,
        'ItalicAngle': -12,
        'MissingWidth': 333,
      });
      final translated = FontTranslator().translate(
        simpleFont(
          firstChar: 65,
          lastChar: 65,
          widths: const <num>[],
          descriptor: descriptor,
        ),
        'g_font_4',
      );
      expect(translated.font.defaultWidth, 333);
      expect(translated.font.ascent, 0.75);
      expect(translated.font.descent, -0.25);
      expect(translated.font.bbox, <double>[-10, -200, 900, 800]);
      expect(translated.font.isMonospace, isTrue);
    });

    test('removes the six-letter subset prefix from the family', () {
      final translated = FontTranslator().translate(
        simpleFont(baseFont: 'ABCDEF+Times-Roman'),
        'g_font_5',
      );
      expect(translated.font.name, 'Times-Roman');
      expect(translated.font.isSerifFont, isTrue);
    });

    test('selects Symbol and Dingbats defaults from the base font', () {
      final symbol = FontTranslator().translate(
        simpleFont(baseFont: 'Symbol', firstChar: 65, lastChar: 65),
        'symbol',
      );
      final dingbats = FontTranslator().translate(
        simpleFont(baseFont: 'ZapfDingbats', firstChar: 33, lastChar: 33),
        'dingbats',
      );
      expect(symbol.properties['baseEncodingName'], 'SymbolSetEncoding');
      expect(
        dingbats.properties['baseEncodingName'],
        'ZapfDingbatsEncoding',
      );
    });

    test('exports data consumable by a common-object font cache', () {
      final translated = FontTranslator().translate(
        simpleFont(),
        'g_export',
      );
      final data = translated.exportData();
      expect(data['loadedName'], 'g_export');
      expect(data['name'], 'Helvetica');
      expect(data['fontFamily'], isNotEmpty);
      expect(data['missingFile'], isTrue);
      expect(data['data'], isA<Map<String, dynamic>>());
    });
  });

  group('FontTranslator composite fonts', () {
    test('reads DW and both W array forms', () {
      final descendant = dict(<String, dynamic>{
        'Subtype': Name.get('CIDFontType2'),
        'DW': 900,
        'W': <dynamic>[
          1,
          <dynamic>[500, 510, 520],
          10,
          12,
          700,
        ],
      });
      final font = dict(<String, dynamic>{
        'Subtype': Name.get('Type0'),
        'BaseFont': Name.get('CIDFont'),
        'Encoding': Name.get('Identity-H'),
        'DescendantFonts': <dynamic>[descendant],
      });
      final translated = FontTranslator().translate(font, 'cid');
      expect(translated.font.composite, isTrue);
      expect(translated.font.defaultWidth, 900);
      expect(translated.font.widths[1], 500);
      expect(translated.font.widths[3], 520);
      expect(translated.font.widths[10], 700);
      expect(translated.font.widths[12], 700);
    });

    test('detects vertical identity encodings', () {
      final descendant = dict(<String, dynamic>{
        'Subtype': Name.get('CIDFontType2'),
      });
      final font = dict(<String, dynamic>{
        'Subtype': Name.get('Type0'),
        'BaseFont': Name.get('VerticalCID'),
        'Encoding': Name.get('Identity-V'),
        'DescendantFonts': <dynamic>[descendant],
      });
      final translated = FontTranslator().translate(font, 'cid_v');
      expect(translated.font.vertical, isTrue);
      expect(translated.font.cidEncoding, 'Identity-V');
    });
  });

  group('PartialEvaluator font integration', () {
    test('turns Tj strings into display glyph records', () async {
      final result = await evaluateFont(
        'BT /F1 12 Tf (ABC) Tj ET',
        simpleFont(
          firstChar: 65,
          lastChar: 67,
          widths: const <num>[600, 610, 620],
        ),
      );
      final args = textArguments(result, OPS.showText);
      final glyphs = args.single as List<dynamic>;
      expect(glyphs, hasLength(3));
      expect(glyphs[0]['unicode'], 'A');
      expect(glyphs[1]['width'], 610);
      expect(glyphs[2]['originalCharCode'], 67);
    });

    test('preserves numeric positioning adjustments in TJ', () async {
      final result = await evaluateFont(
        'BT /F1 10 Tf [(A) -120 (V)] TJ ET',
        simpleFont(
          firstChar: 65,
          lastChar: 86,
          widths: List<num>.filled(22, 500),
        ),
      );
      final glyphs =
          textArguments(result, OPS.showSpacedText).single as List<dynamic>;
      expect(glyphs, hasLength(3));
      expect(glyphs[0]['unicode'], 'A');
      expect(glyphs[1], -120);
      expect(glyphs[2]['unicode'], 'V');
    });

    test('translates quote and double-quote text operators', () async {
      final result = await evaluateFont(
        "BT /F1 10 Tf (A) ' 2 3 (B) \" ET",
        simpleFont(
          firstChar: 65,
          lastChar: 66,
          widths: const <num>[500, 600],
        ),
      );
      final quote =
          textArguments(result, OPS.nextLineShowText).single as List<dynamic>;
      final doubleQuote =
          textArguments(result, OPS.nextLineSetSpacingShowText)[2]
              as List<dynamic>;
      expect(quote.single['unicode'], 'A');
      expect(doubleQuote.single['unicode'], 'B');
    });

    test('publishes translated metadata through the handler', () async {
      final handler = RecordingHandler();
      final result = await evaluateFont(
        'BT /F1 8 Tf (A) Tj ET',
        simpleFont(firstChar: 65, lastChar: 65),
        handler: handler,
      );
      expect(result.dependencies, hasLength(1));
      expect(handler.calls, hasLength(1));
      expect(handler.calls.single[0], 'commonobj');
      final payload = handler.calls.single[1] as List<dynamic>;
      expect(payload[0], startsWith('g_p4_f'));
      expect(payload[1], 'Font');
      expect(payload[2]['name'], 'Helvetica');
    });

    test('reuses font translation and dependency for repeated Tf', () async {
      final handler = RecordingHandler();
      final result = await evaluateFont(
        'BT /F1 8 Tf (A) Tj /F1 16 Tf (B) Tj ET',
        simpleFont(
          firstChar: 65,
          lastChar: 66,
          widths: const <num>[500, 600],
        ),
        handler: handler,
      );
      expect(result.dependencies, hasLength(1));
      expect(handler.calls, hasLength(2));
      final ids =
          handler.calls.map((call) => (call[1] as List<dynamic>)[0]).toSet();
      expect(ids, hasLength(1));
      final texts = <List<dynamic>>[];
      for (var i = 0; i < result.fnArray.length; i++) {
        if (result.fnArray[i] == OPS.showText) {
          texts.add(result.argsArray[i].single as List<dynamic>);
        }
      }
      expect(texts[0].single['unicode'], 'A');
      expect(texts[1].single['unicode'], 'B');
    });

    test('keeps raw text when a font resource is missing', () async {
      final resources = dict(<String, dynamic>{'Font': Dict()});
      final evaluator = PartialEvaluator(
        xref: XRef(StringStream(''), null),
        pageIndex: 0,
      );
      final result = OperatorList(RenderingIntentFlag.opList);
      await evaluator.getOperatorList(
        contentStream: StringStream('BT /Missing 12 Tf (raw) Tj ET'),
        executionContext: null,
        operatorList: result,
        resources: resources,
      );
      expect(textArguments(result, OPS.showText), <dynamic>['raw']);
    });
  });
}
