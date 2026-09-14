// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'package:pdfjs/src/core/cid_font_data.dart';
import 'package:pdfjs/src/core/cmap.dart';
import 'package:pdfjs/src/core/font_translation.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/stream.dart';
import 'package:test/test.dart';

Dict makeDict(Map<String, dynamic> values) {
  final dict = Dict();
  values.forEach(dict.set);
  return dict;
}

Stream bytes(List<int> value) => Stream(Uint8List.fromList(value));

Stream ascii(String value) => bytes(value.codeUnits);

Dict compositeFont({
  dynamic encoding,
  List<dynamic>? widths,
  List<dynamic>? verticalWidths,
  List<dynamic>? defaultVertical,
  dynamic cidToGidMap,
  Dict? systemInfo,
  Stream? toUnicode,
}) {
  final descendant = makeDict(<String, dynamic>{
    'Subtype': Name.get('CIDFontType2'),
    'DW': 900,
    if (widths != null) 'W': widths,
    if (verticalWidths != null) 'W2': verticalWidths,
    if (defaultVertical != null) 'DW2': defaultVertical,
    if (cidToGidMap != null) 'CIDToGIDMap': cidToGidMap,
    if (systemInfo != null) 'CIDSystemInfo': systemInfo,
  });
  return makeDict(<String, dynamic>{
    'Subtype': Name.get('Type0'),
    'BaseFont': Name.get('ExampleCID'),
    'Encoding': encoding ?? Name.get('Identity-H'),
    'DescendantFonts': <dynamic>[descendant],
    if (toUnicode != null) 'ToUnicode': toUnicode,
  });
}

void main() {
  group('CID width extraction', () {
    test('reads consecutive width arrays', () {
      final result = readCidWidths(<dynamic>[
        1,
        <dynamic>[250, 300, 350, 400],
      ]);
      expect(result, <int, num>{1: 250, 2: 300, 3: 350, 4: 400});
    });

    test('reads an inclusive constant-width range', () {
      final result = readCidWidths(<dynamic>[10, 14, 625]);
      expect(result.keys, orderedEquals(<int>[10, 11, 12, 13, 14]));
      expect(result.values, everyElement(625));
    });

    test('combines the two legal W forms', () {
      final result = readCidWidths(<dynamic>[
        1,
        <dynamic>[200, 210],
        8,
        10,
        700,
        20,
        <dynamic>[800],
      ]);
      expect(result, hasLength(6));
      expect(result[1], 200);
      expect(result[2], 210);
      expect(result[8], 700);
      expect(result[10], 700);
      expect(result[20], 800);
    });

    test('ignores nonnumeric widths without losing following CIDs', () {
      final result = readCidWidths(<dynamic>[
        3,
        <dynamic>[500, 'bad', 520],
      ]);
      expect(result[3], 500);
      expect(result.containsKey(4), isFalse);
      expect(result[5], 520);
    });

    test('stops safely on malformed input', () {
      expect(readCidWidths(<dynamic>['bad', 2, 500]), isEmpty);
      expect(readCidWidths(<dynamic>[1]), isEmpty);
      expect(readCidWidths(null), isEmpty);
    });
  });

  group('CID vertical metric extraction', () {
    test('reads consecutive W2 triples', () {
      final result = readCidVerticalMetrics(<dynamic>[
        1,
        <dynamic>[-1000, 250, 880, -900, 260, 870],
      ]);
      expect(result[1], <num>[-1000, 250, 880]);
      expect(result[2], <num>[-900, 260, 870]);
    });

    test('reads an inclusive W2 range', () {
      final result = readCidVerticalMetrics(<dynamic>[
        10,
        12,
        -1000,
        500,
        880,
      ]);
      expect(result.keys, orderedEquals(<int>[10, 11, 12]));
      expect(result[11], <num>[-1000, 500, 880]);
      expect(identical(result[10], result[11]), isFalse);
    });

    test('skips an incomplete triple', () {
      final result = readCidVerticalMetrics(<dynamic>[
        1,
        <dynamic>[-1000, 500],
      ]);
      expect(result, isEmpty);
    });

    test('skips nonnumeric triples', () {
      final result = readCidVerticalMetrics(<dynamic>[
        1,
        <dynamic>[-1000, 'x', 880, -900, 300, 800],
      ]);
      expect(result.containsKey(1), isFalse);
      expect(result[2], <num>[-900, 300, 800]);
    });
  });

  group('CIDToGIDMap', () {
    test('decodes big-endian glyph identifiers', () {
      final result = readCidToGidMap(bytes(<int>[
        0x00,
        0x00,
        0x00,
        0x2a,
        0x12,
        0x34,
        0xff,
        0xfe,
      ]));
      expect(result, <int, int>{0: 0, 1: 42, 2: 0x1234, 3: 0xfffe});
    });

    test('ignores a final truncated identifier', () {
      final result = readCidToGidMap(bytes(<int>[0, 1, 255]));
      expect(result, <int, int>{0: 1});
    });

    test('Identity name needs no explicit map', () {
      expect(readCidToGidMap(Name.get('Identity')), isEmpty);
    });

    test('resets the source stream after reading', () {
      final stream = bytes(<int>[0, 4, 0, 5]);
      stream.getByte();
      readCidToGidMap(stream);
      expect(stream.pos, stream.start);
    });
  });

  group('CIDSystemInfo', () {
    test('extracts registry, ordering and supplement', () {
      final info = readCidSystemInfo(makeDict(<String, dynamic>{
        'Registry': 'Adobe',
        'Ordering': 'Japan1',
        'Supplement': 7,
      }));
      expect(info, <String, dynamic>{
        'registry': 'Adobe',
        'ordering': 'Japan1',
        'supplement': 7,
      });
    });

    test('accepts names and supplies defaults', () {
      final info = readCidSystemInfo(makeDict(<String, dynamic>{
        'Registry': Name.get('Adobe'),
        'Ordering': Name.get('GB1'),
      }));
      expect(info?['registry'], 'Adobe');
      expect(info?['ordering'], 'GB1');
      expect(info?['supplement'], 0);
    });
  });

  group('embedded encoding CMaps', () {
    test('reads CMap name, writing mode and code space', () {
      final cmap = parseEmbeddedCMap(ascii(r'''
        /CMapName /Example-V def
        /WMode 1 def
        1 begincodespacerange
        <0000> <ffff>
        endcodespacerange
      '''));
      expect(cmap.name, 'Example-V');
      expect(cmap.vertical, isTrue);
      expect(cmap.numCodespaceRanges, 1);
      expect(cmap.getCharCodeLength(0xabcd), 2);
    });

    test('reads cidchar mappings', () {
      final cmap = parseEmbeddedCMap(ascii(r'''
        1 begincodespacerange <00> <ff> endcodespacerange
        3 begincidchar
        <20> 4
        <41> 100
        <42> 101
        endcidchar
      '''));
      expect(cmap.lookup(0x20), 4);
      expect(cmap.lookup(0x41), 100);
      expect(cmap.lookup(0x42), 101);
    });

    test('reads inclusive cidrange mappings', () {
      final cmap = parseEmbeddedCMap(ascii(r'''
        1 begincidrange
        <8140> <8143> 500
        endcidrange
      '''));
      expect(cmap.lookup(0x8140), 500);
      expect(cmap.lookup(0x8143), 503);
    });

    test('reads bfchar and bfrange mappings', () {
      final cmap = parseEmbeddedCMap(ascii(r'''
        1 beginbfchar <01> <0041> endbfchar
        1 beginbfrange <02> <04> <0042> endbfrange
      '''));
      expect(cmap.lookup(1), '\x00A');
      expect(cmap.lookup(2), '\x00B');
      expect(cmap.lookup(4), '\x00D');
    });

    test('adds a two-byte fallback code space', () {
      final cmap = parseEmbeddedCMap(ascii(
        '1 begincidchar <1234> 9 endcidchar',
      ));
      expect(cmap.numCodespaceRanges, 1);
      expect(cmap.getCharCodeLength(0x1234), 2);
    });

    test('reads multibyte character boundaries', () {
      final cmap = parseEmbeddedCMap(ascii(r'''
        2 begincodespacerange
        <00> <7f>
        <8100> <81ff>
        endcodespacerange
      '''));
      final one = CharCodeOut();
      cmap.readCharCode('A', 0, one);
      expect(one.charcode, 65);
      expect(one.length, 1);
      final two = CharCodeOut();
      cmap.readCharCode(String.fromCharCodes(<int>[0x81, 0x40]), 0, two);
      expect(two.charcode, 0x8140);
      expect(two.length, 2);
    });
  });

  group('FontTranslator CID integration', () {
    test('attaches an Identity-H CMap and keeps two-byte codes', () {
      final translated = FontTranslator().translate(compositeFont(), 'cid_h');
      expect(translated.font.cMap, isA<IdentityCMap>());
      final glyphs = translated.font.charsToGlyphs(
        String.fromCharCodes(<int>[0x00, 0x41, 0x00, 0x42]),
      );
      expect(glyphs, hasLength(2));
      expect(glyphs[0].originalCharCode, 0x41);
      expect(glyphs[1].originalCharCode, 0x42);
    });

    test('uses CIDs for width lookup through a non-Identity CMap', () {
      final encoding = ascii(r'''
        1 begincodespacerange <00> <ff> endcodespacerange
        1 begincidrange <41> <42> 10 endcidrange
      ''');
      final translated = FontTranslator().translate(
        compositeFont(
          encoding: encoding,
          widths: <dynamic>[
            10,
            <dynamic>[610, 620]
          ],
        ),
        'mapped',
      );
      final glyphs = translated.font.charsToGlyphs('AB');
      expect(glyphs[0].width, 610);
      expect(glyphs[1].width, 620);
    });

    test('applies explicit vertical metrics and defaults', () {
      final translated = FontTranslator().translate(
        compositeFont(
          encoding: Name.get('Identity-V'),
          widths: <dynamic>[
            1,
            <dynamic>[600, 700]
          ],
          defaultVertical: <dynamic>[900, -1100],
          verticalWidths: <dynamic>[
            1,
            <dynamic>[-1200, 300, 850],
          ],
        ),
        'vertical',
      );
      expect(translated.font.vertical, isTrue);
      expect(translated.font.defaultVMetrics, <num>[-1100, 450, 900]);
      expect(translated.font.charToGlyph(1).vmetric, <num>[-1200, 300, 850]);
      expect(translated.font.charToGlyph(2).vmetric, <num>[-1100, 450, 900]);
    });

    test('maps CID to embedded glyph id', () {
      final translated = FontTranslator().translate(
        compositeFont(
          cidToGidMap: bytes(<int>[0, 0, 0, 40, 0, 99]),
          widths: <dynamic>[
            1,
            <dynamic>[500, 600]
          ],
        ),
        'gid',
      );
      final glyph = translated.font.charToGlyph(2);
      expect(glyph.originalCharCode, 2);
      expect(glyph.fontChar.codeUnitAt(0), 99);
      expect(glyph.width, 600);
      expect(glyph.isInFont, isTrue);
    });

    test('preserves explicit .notdef mappings', () {
      final translated = FontTranslator().translate(
        compositeFont(cidToGidMap: bytes(<int>[0, 0])),
        'notdef',
      );
      final glyph = translated.font.charToGlyph(0);
      expect(glyph.fontChar.codeUnitAt(0), 0);
      expect(glyph.isInFont, isFalse);
    });

    test('uses an application supplied predefined CMap', () {
      final predefined = CMap(builtInCMap: true)
        ..name = 'Custom-H'
        ..addCodespaceRange(1, 0, 255)
        ..mapOne(65, 321);
      final translated = FontTranslator(options: <String, dynamic>{
        'builtInCMaps': <String, CMap>{'Custom-H': predefined},
      }).translate(
        compositeFont(
          encoding: Name.get('Custom-H'),
          widths: <dynamic>[
            321,
            <dynamic>[777]
          ],
        ),
        'predefined',
      );
      expect(translated.font.cMap, same(predefined));
      expect(translated.font.charToGlyph(65).width, 777);
    });

    test('falls back to two-byte boundaries for unavailable predefined maps',
        () {
      final translated = FontTranslator().translate(
        compositeFont(encoding: Name.get('UniJIS-UCS2-H')),
        'fallback',
      );
      final glyphs = translated.font.charsToGlyphs(
        String.fromCharCodes(<int>[0x30, 0x42]),
      );
      expect(glyphs, hasLength(1));
      expect(glyphs.single.originalCharCode, 0x3042);
    });

    test('uses ToUnicode independently from CID width mapping', () {
      final translated = FontTranslator().translate(
        compositeFont(
          widths: <dynamic>[
            0x41,
            <dynamic>[600]
          ],
          toUnicode: ascii(r'''
            1 beginbfchar <0041> <03a9> endbfchar
          '''),
        ),
        'unicode',
      );
      final glyph = translated.font.charToGlyph(0x41);
      expect(glyph.unicode, '\u03a9');
      expect(glyph.width, 600);
    });

    test('exports vertical state with translated font data', () {
      final translated = FontTranslator().translate(
        compositeFont(encoding: Name.get('Identity-V')),
        'exported',
      );
      expect(translated.exportData()['vertical'], isTrue);
      expect(translated.properties['cMap'], isA<IdentityCMap>());
      expect(translated.properties['vmetrics'], isA<Map<int, List<num>>>());
    });
  });
}
