// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'package:pdfjs/src/core/evaluator.dart';
import 'package:pdfjs/src/core/operator_list.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/stream.dart';
import 'package:pdfjs/src/core/xref.dart';
import 'package:pdfjs/src/shared/util.dart';
import 'package:test/test.dart';

class _Task {
  int checks = 0;
  bool terminated = false;

  void ensureNotTerminated() {
    checks++;
    if (terminated) throw StateError('terminated');
  }
}

PartialEvaluator evaluator() {
  final stream = StringStream('');
  return PartialEvaluator(xref: XRef(stream, null), pageIndex: 2);
}

Future<OperatorList> evaluate(
  String source, {
  Dict? resources,
  _Task? task,
}) async {
  final result = OperatorList(RenderingIntentFlag.opList);
  await evaluator().getOperatorList(
    contentStream: StringStream(source),
    executionContext: task,
    operatorList: result,
    resources: resources,
  );
  return result;
}

Dict dictionary(Map<String, dynamic> values) {
  final result = Dict();
  for (final entry in values.entries) {
    result.set(entry.key, entry.value);
  }
  return result;
}

void main() {
  group('normalizeBlendMode', () {
    test('maps normal and compatible to source-over', () {
      expect(normalizeBlendMode(Name.get('Normal')), 'source-over');
      expect(normalizeBlendMode(Name.get('Compatible')), 'source-over');
    });

    test('maps every PDF separable blend mode', () {
      expect(normalizeBlendMode(Name.get('Multiply')), 'multiply');
      expect(normalizeBlendMode(Name.get('Screen')), 'screen');
      expect(normalizeBlendMode(Name.get('Overlay')), 'overlay');
      expect(normalizeBlendMode(Name.get('Darken')), 'darken');
      expect(normalizeBlendMode(Name.get('Lighten')), 'lighten');
      expect(normalizeBlendMode(Name.get('ColorDodge')), 'color-dodge');
      expect(normalizeBlendMode(Name.get('ColorBurn')), 'color-burn');
      expect(normalizeBlendMode(Name.get('HardLight')), 'hard-light');
      expect(normalizeBlendMode(Name.get('SoftLight')), 'soft-light');
      expect(normalizeBlendMode(Name.get('Difference')), 'difference');
      expect(normalizeBlendMode(Name.get('Exclusion')), 'exclusion');
    });

    test('maps every PDF non-separable blend mode', () {
      expect(normalizeBlendMode(Name.get('Hue')), 'hue');
      expect(normalizeBlendMode(Name.get('Saturation')), 'saturation');
      expect(normalizeBlendMode(Name.get('Color')), 'color');
      expect(normalizeBlendMode(Name.get('Luminosity')), 'luminosity');
    });

    test('selects the first supported entry from an array', () {
      expect(
        normalizeBlendMode(<dynamic>[
          Name.get('Unsupported'),
          Name.get('Multiply'),
          Name.get('Screen'),
        ]),
        'multiply',
      );
    });

    test('uses source-over for malformed and unknown values', () {
      expect(normalizeBlendMode(null), 'source-over');
      expect(normalizeBlendMode(42), 'source-over');
      expect(normalizeBlendMode(Name.get('SomethingElse')), 'source-over');
      expect(normalizeBlendMode(<dynamic>[]), 'source-over');
    });
  });

  group('PartialEvaluator.getOperatorList', () {
    test('emits basic graphics operators and their arguments', () async {
      final result = await evaluate(
        'q 2 w 1 J 2 j 10 M [3 4] 1 d '
        '1 0 0 1 20 30 cm 10 20 m 30 40 l 50 60 70 80 90 100 c '
        '5 6 7 8 re S Q',
      );
      expect(
        result.fnArray,
        <int>[
          OPS.save,
          OPS.setLineWidth,
          OPS.setLineCap,
          OPS.setLineJoin,
          OPS.setMiterLimit,
          OPS.setDash,
          OPS.transform,
          OPS.moveTo,
          OPS.lineTo,
          OPS.curveTo,
          OPS.rectangle,
          OPS.stroke,
          OPS.restore,
        ],
      );
      expect(result.argsArray[1], <dynamic>[2]);
      expect(result.argsArray[5], <dynamic>[
        <dynamic>[3, 4],
        1,
      ]);
      expect(result.argsArray[6], <dynamic>[1, 0, 0, 1, 20, 30]);
    });

    test('emits all basic path-painting variants', () async {
      final result = await evaluate(
        'S s f F f* B B* b b* n W W*',
      );
      expect(
        result.fnArray,
        <int>[
          OPS.stroke,
          OPS.closeStroke,
          OPS.fill,
          OPS.fill,
          OPS.eoFill,
          OPS.fillStroke,
          OPS.eoFillStroke,
          OPS.closeFillStroke,
          OPS.closeEOFillStroke,
          OPS.endPath,
          OPS.clip,
          OPS.eoClip,
        ],
      );
    });

    test('emits text positioning and state operators', () async {
      final result = await evaluate(
        'BT 1 Tc 2 Tw 90 Tz 14 TL 2 Tr 3 Ts '
        '10 20 Td 2 3 TD 1 0 0 1 40 50 Tm T* ET',
      );
      expect(
        result.fnArray,
        <int>[
          OPS.beginText,
          OPS.setCharSpacing,
          OPS.setWordSpacing,
          OPS.setHScale,
          OPS.setLeading,
          OPS.setTextRenderingMode,
          OPS.setTextRise,
          OPS.moveText,
          OPS.setLeadingMoveText,
          OPS.setTextMatrix,
          OPS.nextLine,
          OPS.endText,
        ],
      );
    });

    test('preserves literal and spaced text operands', () async {
      final result = await evaluate(
        'BT (hello) Tj [(A) -120 (V)] TJ (line) \' '
        '2 3 (spaced) " ET',
      );
      expect(result.fnArray, contains(OPS.showText));
      expect(result.fnArray, contains(OPS.showSpacedText));
      expect(result.fnArray, contains(OPS.nextLineShowText));
      expect(result.fnArray, contains(OPS.nextLineSetSpacingShowText));
      expect(result.argsArray[result.fnArray.indexOf(OPS.showText)],
          <dynamic>['hello']);
      expect(
        result.argsArray[result.fnArray.indexOf(OPS.showSpacedText)],
        <dynamic>[
          <dynamic>['A', -120, 'V'],
        ],
      );
    });

    test('registers a font dependency and replaces its resource name',
        () async {
      final fonts = dictionary(<String, dynamic>{
        'F1': dictionary(<String, dynamic>{
          'Type': Name.get('Font'),
          'Subtype': Name.get('Type1'),
          'BaseFont': Name.get('Helvetica'),
        }),
      });
      final resources = dictionary(<String, dynamic>{'Font': fonts});
      final result =
          await evaluate('BT /F1 12 Tf (Hello) Tj ET', resources: resources);
      expect(result.fnArray.first, OPS.beginText);
      expect(result.fnArray, contains(OPS.dependency));
      final setFont = result.fnArray.indexOf(OPS.setFont);
      expect(result.argsArray[setFont][0], startsWith('g_p2_f'));
      expect(result.argsArray[setFont][1], 12);
      expect(result.dependencies, hasLength(1));
    });

    test('reuses a dependency for repeated selection of the same font',
        () async {
      final font =
          dictionary(<String, dynamic>{'BaseFont': Name.get('Helvetica')});
      final resources = dictionary(<String, dynamic>{
        'Font': dictionary(<String, dynamic>{'F1': font}),
      });
      final result = await evaluate(
        'BT /F1 10 Tf (a) Tj /F1 20 Tf (b) Tj ET',
        resources: resources,
      );
      final fontOps = <int>[];
      for (var i = 0; i < result.fnArray.length; i++) {
        if (result.fnArray[i] == OPS.setFont) fontOps.add(i);
      }
      expect(fontOps, hasLength(2));
      expect(result.argsArray[fontOps[0]][0], result.argsArray[fontOps[1]][0]);
      expect(
        result.fnArray.where((fn) => fn == OPS.dependency),
        hasLength(1),
      );
    });

    test('translates ExtGState values into renderer entries', () async {
      final gs = dictionary(<String, dynamic>{
        'LW': 2,
        'LC': 1,
        'LJ': 2,
        'ML': 5,
        'D': <dynamic>[
          <dynamic>[3, 2],
          1,
        ],
        'RI': Name.get('RelativeColorimetric'),
        'FL': 0.5,
        'CA': 0.75,
        'ca': 0.25,
        'BM': Name.get('Multiply'),
        'SMask': Name.get('None'),
      });
      final resources = dictionary(<String, dynamic>{
        'ExtGState': dictionary(<String, dynamic>{'GS1': gs}),
      });
      final result = await evaluate('/GS1 gs', resources: resources);
      expect(result.fnArray, <int>[OPS.setGState]);
      final entries = result.argsArray.single.single as List<dynamic>;
      expect(entries.any((e) => e[0] == 'LW' && e[1] == 2), isTrue);
      expect(
        entries.any((e) => e[0] == 'BM' && e[1] == 'multiply'),
        isTrue,
      );
      expect(entries.any((e) => e[0] == 'SMask' && e[1] == false), isTrue);
      expect(entries.any((e) => e[0] == 'ca' && e[1] == 0.25), isTrue);
    });

    test('preserves unresolved graphics-state operations', () async {
      final result = await evaluate('/Missing gs');
      expect(result.fnArray, <int>[OPS.setGState]);
      expect((result.argsArray.single.single as Name).name, 'Missing');
    });

    test('expands a Form XObject between begin and end operations', () async {
      final formDict = dictionary(<String, dynamic>{
        'Subtype': Name.get('Form'),
        'BBox': <dynamic>[0, 0, 100, 200],
        'Matrix': <dynamic>[1, 0, 0, 1, 5, 6],
      });
      final form = StringStream('1 2 m 3 4 l S')..dict = formDict;
      final resources = dictionary(<String, dynamic>{
        'XObject': dictionary(<String, dynamic>{'Fm1': form}),
      });
      final result = await evaluate('/Fm1 Do', resources: resources);
      expect(
        result.fnArray,
        <int>[
          OPS.paintFormXObjectBegin,
          OPS.moveTo,
          OPS.lineTo,
          OPS.stroke,
          OPS.paintFormXObjectEnd,
        ],
      );
      final begin = result.argsArray.first;
      expect(begin[0], isA<Float32List>());
      expect(begin[0], orderedEquals(<double>[1, 0, 0, 1, 5, 6]));
      expect(begin[1], orderedEquals(<double>[0, 0, 100, 200]));
    });

    test('uses parent resources inside a Form without Resources', () async {
      final form = StringStream('BT /F1 9 Tf (form text) Tj ET')
        ..dict = dictionary(<String, dynamic>{
          'Subtype': Name.get('Form'),
          'BBox': <dynamic>[0, 0, 20, 20],
        });
      final resources = dictionary(<String, dynamic>{
        'Font': dictionary(<String, dynamic>{
          'F1': dictionary(<String, dynamic>{
            'BaseFont': Name.get('Courier'),
          }),
        }),
        'XObject': dictionary(<String, dynamic>{'Fm': form}),
      });
      final result = await evaluate('/Fm Do', resources: resources);
      expect(result.fnArray, contains(OPS.setFont));
      expect(result.fnArray, contains(OPS.showText));
    });

    test('uses local Form resources in preference to parent resources',
        () async {
      final localResources = dictionary(<String, dynamic>{
        'Font': dictionary(<String, dynamic>{
          'F1': dictionary(<String, dynamic>{
            'BaseFont': Name.get('Times-Roman'),
          }),
        }),
      });
      final form = StringStream('BT /F1 8 Tf (local) Tj ET')
        ..dict = dictionary(<String, dynamic>{
          'Subtype': Name.get('Form'),
          'Resources': localResources,
          'BBox': <dynamic>[0, 0, 20, 20],
        });
      final resources = dictionary(<String, dynamic>{
        'XObject': dictionary(<String, dynamic>{'Fm': form}),
      });
      final result = await evaluate('/Fm Do', resources: resources);
      expect(result.fnArray, contains(OPS.setFont));
    });

    test('registers image XObjects with width and height', () async {
      final image = StringStream('pixel bytes')
        ..dict = dictionary(<String, dynamic>{
          'Subtype': Name.get('Image'),
          'Width': 17,
          'Height': 9,
        });
      final resources = dictionary(<String, dynamic>{
        'XObject': dictionary(<String, dynamic>{'Im1': image}),
      });
      final result = await evaluate('/Im1 Do', resources: resources);
      expect(result.fnArray, <int>[OPS.dependency, OPS.paintImageXObject]);
      expect(result.argsArray.last[0], startsWith('img_p2_'));
      expect(result.argsArray.last[1], 17);
      expect(result.argsArray.last[2], 9);
    });

    test('preserves unresolved XObject operations', () async {
      final result = await evaluate('/Missing Do');
      expect(result.fnArray, <int>[OPS.paintXObject]);
      expect((result.argsArray.single.single as Name).name, 'Missing');
    });

    test('emits device color operators unchanged', () async {
      final result = await evaluate(
        '0.5 G 0.25 g 1 0 0 RG 0 1 0 rg '
        '0 0.5 1 0 K 1 0 0.25 0 k',
      );
      expect(
        result.fnArray,
        <int>[
          OPS.setStrokeGray,
          OPS.setFillGray,
          OPS.setStrokeRGBColor,
          OPS.setFillRGBColor,
          OPS.setStrokeCMYKColor,
          OPS.setFillCMYKColor,
        ],
      );
      expect(result.argsArray[2], <dynamic>[1, 0, 0]);
      expect(result.argsArray[5], <dynamic>[1, 0, 0.25, 0]);
    });

    test('emits color-space and generic color operators', () async {
      final result = await evaluate(
        '/DeviceRGB CS /DeviceCMYK cs 0.1 0.2 0.3 SC '
        '0.1 0.2 0.3 0.4 scn',
      );
      expect(
        result.fnArray,
        <int>[
          OPS.setStrokeColorSpace,
          OPS.setFillColorSpace,
          OPS.setStrokeColor,
          OPS.setFillColorN,
        ],
      );
    });

    test('emits marked-point and compatibility operators', () async {
      final result = await evaluate('/Point MP /Point << /MCID 3 >> DP BX EX');
      expect(
        result.fnArray,
        <int>[
          OPS.markPoint,
          OPS.markPointProps,
          OPS.beginCompat,
          OPS.endCompat,
        ],
      );
    });

    test('consults the execution context while evaluating', () async {
      final task = _Task();
      await evaluate('q 1 0 0 1 0 0 cm Q', task: task);
      expect(task.checks, 3);
    });

    test('propagates cancellation from the execution context', () async {
      final task = _Task()..terminated = true;
      expect(
        () => evaluate('q Q', task: task),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('PartialEvaluator.getTextContent', () {
    test('extracts a basic text-show operation', () async {
      final result = await evaluator().getTextContent(
        contentStream: StringStream('BT /F1 12 Tf 10 20 Td (Hello) Tj ET'),
      );
      final items = result['items'] as List<dynamic>;
      expect(items, hasLength(1));
      expect(items.single['str'], 'Hello');
      expect(items.single['fontName'], 'F1');
      expect(items.single['width'], 30);
      expect(items.single['height'], 12);
      expect(items.single['transform'][4], 10);
      expect(items.single['transform'][5], 20);
    });

    test('extracts and joins strings in a TJ array', () async {
      final result = await evaluator().getTextContent(
        contentStream: StringStream(
          'BT /F1 10 Tf [(A) -100 (V) 50 (A)] TJ ET',
        ),
      );
      final item = (result['items'] as List<dynamic>).single;
      expect(item['str'], 'AVA');
      expect(item['width'], closeTo(15.5, 0.001));
    });

    test('accounts for character and word spacing', () async {
      final result = await evaluator().getTextContent(
        contentStream: StringStream(
          'BT /F1 10 Tf 2 Tc 3 Tw (A B) Tj ET',
        ),
      );
      final item = (result['items'] as List<dynamic>).single;
      expect(item['width'], 22);
    });

    test('accounts for horizontal scaling', () async {
      final result = await evaluator().getTextContent(
        contentStream: StringStream('BT /F1 10 Tf 50 Tz (abcd) Tj ET'),
      );
      final item = (result['items'] as List<dynamic>).single;
      expect(item['width'], 10);
      expect(item['transform'][0], 5);
    });

    test('moves to the next text line using leading', () async {
      final result = await evaluator().getTextContent(
        contentStream: StringStream(
          'BT /F1 10 Tf 12 TL 20 100 Td (one) Tj T* (two) Tj ET',
        ),
      );
      final items = result['items'] as List<dynamic>;
      expect(items, hasLength(2));
      expect(items[0]['transform'][5], 100);
      expect(items[1]['transform'][5], 88);
    });

    test('handles quote operator as next-line text', () async {
      final result = await evaluator().getTextContent(
        contentStream: StringStream(
          "BT /F1 10 Tf 10 TL 0 50 Td (first) Tj (second) ' ET",
        ),
      );
      final items = result['items'] as List<dynamic>;
      expect(items[1]['str'], 'second');
      expect(items[1]['hasEOL'], isTrue);
      expect(items[1]['transform'][5], 40);
    });

    test('handles double-quote spacing and next-line text', () async {
      final result = await evaluator().getTextContent(
        contentStream: StringStream(
          'BT /F1 10 Tf 10 TL 0 50 Td 4 2 (second) " ET',
        ),
      );
      final item = (result['items'] as List<dynamic>).single;
      expect(item['str'], 'second');
      expect(item['hasEOL'], isTrue);
      expect(item['transform'][5], 40);
    });

    test('applies text rise to the reported transform', () async {
      final result = await evaluator().getTextContent(
        contentStream: StringStream(
          'BT /F1 10 Tf 1 0 0 1 5 6 Tm 3 Ts (up) Tj ET',
        ),
      );
      final item = (result['items'] as List<dynamic>).single;
      expect(item['transform'][4], 5);
      expect(item['transform'][5], 9);
    });

    test('advances the text matrix after each item', () async {
      final result = await evaluator().getTextContent(
        contentStream: StringStream(
          'BT /F1 10 Tf 1 0 0 1 0 0 Tm (ab) Tj (cd) Tj ET',
        ),
      );
      final items = result['items'] as List<dynamic>;
      expect(items[0]['transform'][4], 0);
      expect(items[1]['transform'][4], 10);
    });

    test('creates a style entry from the font dictionary', () async {
      final descriptor = dictionary(<String, dynamic>{
        'Ascent': 750,
        'Descent': -250,
      });
      final font = dictionary(<String, dynamic>{
        'BaseFont': Name.get('MyFont'),
        'FontDescriptor': descriptor,
      });
      final resources = dictionary(<String, dynamic>{
        'Font': dictionary(<String, dynamic>{'F7': font}),
      });
      final result = await evaluator().getTextContent(
        contentStream: StringStream('BT /F7 12 Tf (hello) Tj ET'),
        resources: resources,
      );
      final style = (result['styles'] as Map<String, dynamic>)['F7'];
      expect(style['fontFamily'], 'MyFont');
      expect(style['ascent'], 0.75);
      expect(style['descent'], -0.25);
      expect(style['vertical'], isFalse);
    });

    test('uses sensible style defaults without a descriptor', () async {
      final resources = dictionary(<String, dynamic>{
        'Font': dictionary(<String, dynamic>{
          'F1': dictionary(<String, dynamic>{
            'BaseFont': Name.get('Helvetica'),
          }),
        }),
      });
      final result = await evaluator().getTextContent(
        contentStream: StringStream('BT /F1 12 Tf (hello) Tj ET'),
        resources: resources,
      );
      final style = (result['styles'] as Map<String, dynamic>)['F1'];
      expect(style['fontFamily'], 'Helvetica');
      expect(style['ascent'], 0.8);
      expect(style['descent'], -0.2);
    });

    test('returns empty collections for a graphics-only stream', () async {
      final result = await evaluator().getTextContent(
        contentStream: StringStream('0 0 m 10 10 l S'),
      );
      expect(result['items'], isEmpty);
      expect(result['styles'], isEmpty);
    });

    test('rejects a non-stream content source', () async {
      expect(
        () => evaluator().getTextContent(contentStream: 'not a stream'),
        throwsArgumentError,
      );
    });
  });

  group('PartialEvaluator.hasBlendModes', () {
    test('finds a direct non-normal blend mode', () {
      final resources = dictionary(<String, dynamic>{
        'ExtGState': dictionary(<String, dynamic>{
          'GS': dictionary(<String, dynamic>{'BM': Name.get('Multiply')}),
        }),
      });
      expect(evaluator().hasBlendModes(resources, <dynamic>{}), isTrue);
    });

    test('accepts normal and compatible blend modes', () {
      final resources = dictionary(<String, dynamic>{
        'ExtGState': dictionary(<String, dynamic>{
          'A': dictionary(<String, dynamic>{'BM': Name.get('Normal')}),
          'B': dictionary(<String, dynamic>{'BM': Name.get('Compatible')}),
        }),
      });
      final processed = <dynamic>{};
      expect(evaluator().hasBlendModes(resources, processed), isFalse);
      expect(processed, isNotEmpty);
    });

    test('finds a supported blend mode inside an array', () {
      final resources = dictionary(<String, dynamic>{
        'ExtGState': dictionary(<String, dynamic>{
          'GS': dictionary(<String, dynamic>{
            'BM': <dynamic>[Name.get('Normal'), Name.get('Screen')],
          }),
        }),
      });
      expect(evaluator().hasBlendModes(resources, <dynamic>{}), isTrue);
    });

    test('descends into Form XObject resources', () {
      final nested = dictionary(<String, dynamic>{
        'ExtGState': dictionary(<String, dynamic>{
          'GS': dictionary(<String, dynamic>{'BM': Name.get('Overlay')}),
        }),
      });
      final form = StringStream('')
        ..dict = dictionary(<String, dynamic>{
          'Subtype': Name.get('Form'),
          'Resources': nested,
        });
      final resources = dictionary(<String, dynamic>{
        'XObject': dictionary(<String, dynamic>{'Fm': form}),
      });
      expect(evaluator().hasBlendModes(resources, <dynamic>{}), isTrue);
    });

    test('returns false for missing or malformed resources', () {
      expect(evaluator().hasBlendModes(null, <dynamic>{}), isFalse);
      expect(evaluator().hasBlendModes('bad', <dynamic>{}), isFalse);
      expect(evaluator().hasBlendModes(Dict(), <dynamic>{}), isFalse);
    });
  });
}
