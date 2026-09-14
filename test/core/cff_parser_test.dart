// Copyright 2017 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'package:pdfjs/src/core/cff_parser.dart';
import 'package:test/test.dart';

Uint8List _hex(String source) {
  final bytes = <int>[];
  for (var i = 0; i < source.length; i += 2) {
    bytes.add(int.parse(source.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

CFFParser _parser([List<int> bytes = const []]) =>
    CFFParser(Uint8List.fromList(bytes), <String, dynamic>{}, true);

CFFPrivateDict _privateDict({num defaultWidth = 0, num nominalWidth = 0}) {
  final dict = CFFPrivateDict(CFFStrings());
  dict.setByName('defaultWidthX', defaultWidth);
  dict.setByName('nominalWidthX', nominalWidth);
  return dict;
}

void main() {
  group('CFFParser full font', () {
    late CFFParser parser;
    late CFF cff;
    late Map<String, dynamic> properties;

    setUp(() {
      // Example font from the Compact Font Format specification.
      const exampleFont = '0100040100010101134142434445462b'
          '54696d65732d526f6d616e000101011f'
          'f81b00f81c02f81d03f819041c6f000d'
          'fb3cfb6efa7cfa1605e911b8f1120003'
          '01010813183030312e30303754696d65'
          '7320526f6d616e54696d657300000002'
          '010102030e0e7d99f92a99fb7695f773'
          '8b06f79a93fc7c8c077d99f85695f75e'
          '9908fb6e8cf87393f7108b09a70adf0b'
          'f78e14';
      properties = <String, dynamic>{};
      parser = CFFParser(_hex(exampleFont), properties, true);
      cff = parser.parse();
    });

    test('parses header', () {
      expect(cff.header!.major, 1);
      expect(cff.header!.minor, 0);
      expect(cff.header!.hdrSize, 4);
      expect(cff.header!.offSize, 1);
    });

    test('parses name index', () {
      expect(cff.names, ['ABCDEF+Times-Roman']);
    });

    test('parses string index', () {
      expect(cff.strings.count, 3);
      expect(cff.strings.get(0), '.notdef');
      expect(cff.strings.get(391), '001.007');
      expect(cff.strings.get(392), 'Times Roman');
      expect(cff.strings.get(393), 'Times');
    });

    test('parses top dictionary', () {
      final dict = cff.topDict!;
      expect(dict.getByName('version'), 391);
      expect(dict.getByName('FullName'), 392);
      expect(dict.getByName('FamilyName'), 393);
      expect(dict.getByName('Weight'), 389);
      expect(dict.getByName('UniqueID'), 28416);
      expect(dict.getByName('FontBBox'), [-168, -218, 1000, 898]);
      expect(dict.getByName('CharStrings'), 94);
      expect(dict.getByName('Private'), [45, 102]);
    });

    test('copies font metrics to properties', () {
      expect(properties['fontMatrix'], [0.001, 0, 0, 0.001, 0, 0]);
      expect(properties['ascent'], 898);
      expect(properties['descent'], -218);
      expect(properties['ascentScaled'], isTrue);
    });

    test('parses charstrings, widths, charset and encoding', () {
      expect(cff.charStringCount, 2);
      expect(cff.charStrings!.count, 2);
      expect(cff.charStrings!.get(0), [14]);
      expect(cff.widths, hasLength(2));
      expect(cff.charset!.predefined, isTrue);
      expect(cff.charset!.charset.first, '.notdef');
      expect(cff.encoding!.predefined, isTrue);
      expect(cff.isCIDFont, isFalse);
    });

    test('refuses invalid dictionary values', () {
      final dict = cff.topDict!;
      final defaultValue = dict.getByName('UnderlinePosition');
      dict.setByKey(3075, [double.nan]);
      expect(dict.getByName('UnderlinePosition'), defaultValue);
    });

    test('compiler round-trips parsed font', () {
      final compiled = CFFCompiler(cff).compile();
      final reparsed = CFFParser(compiled, <String, dynamic>{}, true).parse();
      expect(reparsed.names, cff.names);
      expect(reparsed.charStrings!.count, cff.charStrings!.count);
      expect(reparsed.topDict!.getByName('FullName'), 392);
      expect(reparsed.charset!.charset.take(2), cff.charset!.charset.take(2));
    });
  });

  group('CFF header', () {
    test('finds a shifted header', () {
      final parser = _parser([99, 88, 1, 0, 4, 1]);
      final result = parser.parseHeader();
      expect(result.obj.major, 1);
      expect(result.obj.minor, 0);
      expect(result.endPos, 4);
      expect(parser.bytes, [1, 0, 4, 1]);
    });

    test('rejects an empty input', () {
      expect(() => _parser().parseHeader(), throwsFormatException);
    });

    test('rejects input without a version-one marker', () {
      expect(
        () => _parser([2, 0, 4, 1]).parseHeader(),
        throwsFormatException,
      );
    });

    test('rejects a truncated header', () {
      expect(() => _parser([1, 0, 4]).parseHeader(), throwsFormatException);
    });

    test('rejects an undersized header', () {
      expect(() => _parser([1, 0, 3, 1]).parseHeader(), throwsFormatException);
    });

    test('rejects a header beyond the input', () {
      expect(() => _parser([1, 0, 8, 1]).parseHeader(), throwsFormatException);
    });

    test('rejects invalid offset sizes', () {
      expect(() => _parser([1, 0, 4, 0]).parseHeader(), throwsFormatException);
      expect(() => _parser([1, 0, 4, 5]).parseHeader(), throwsFormatException);
    });
  });

  group('CFF INDEX', () {
    test('parses an empty index', () {
      final result = _parser([0, 0]).parseIndex(0);
      expect(result.obj.count, 0);
      expect(result.obj.length, 0);
      expect(result.endPos, 2);
    });

    test('parses a one-byte offset index', () {
      final result = _parser([
        0,
        2,
        1,
        1,
        3,
        6,
        65,
        66,
        67,
        68,
        69,
      ]).parseIndex(0);
      expect(result.obj.count, 2);
      expect(result.obj.get(0), [65, 66]);
      expect(result.obj.get(1), [67, 68, 69]);
      expect(result.endPos, 11);
    });

    test('parses a two-byte offset index', () {
      final data = <int>[
        0,
        1,
        2,
        0,
        1,
        1,
        2,
        ...List<int>.generate(257, (i) => i & 255),
      ];
      final result = _parser(data).parseIndex(0);
      expect(result.obj.count, 1);
      expect(result.obj.get(0), hasLength(257));
      expect(result.obj.get(0).first, 0);
      expect(result.obj.get(0).last, 0);
    });

    test('can parse an index at a nonzero position', () {
      final result = _parser([99, 98, 0, 1, 1, 1, 2, 42]).parseIndex(2);
      expect(result.obj.get(0), [42]);
      expect(result.endPos, 8);
    });

    test('rejects a truncated count', () {
      expect(() => _parser([0]).parseIndex(0), throwsFormatException);
    });

    test('rejects a missing offset size', () {
      expect(() => _parser([0, 1]).parseIndex(0), throwsFormatException);
    });

    test('rejects invalid offset sizes', () {
      expect(() => _parser([0, 1, 0]).parseIndex(0), throwsFormatException);
      expect(() => _parser([0, 1, 5]).parseIndex(0), throwsFormatException);
    });

    test('rejects a first offset other than one', () {
      expect(
        () => _parser([0, 1, 1, 0, 1]).parseIndex(0),
        throwsFormatException,
      );
    });

    test('rejects descending offsets', () {
      expect(
        () => _parser([0, 1, 1, 1, 0]).parseIndex(0),
        throwsFormatException,
      );
    });

    test('rejects data offsets past input', () {
      expect(
        () => _parser([0, 1, 1, 1, 20, 42]).parseIndex(0),
        throwsFormatException,
      );
    });

    test('parses names and custom strings', () {
      final index = CFFIndex()
        ..add('One'.codeUnits)
        ..add('Two'.codeUnits);
      final parser = _parser();
      expect(parser.parseNameIndex(index), ['One', 'Two']);
      final strings = parser.parseStringIndex(index);
      expect(strings.count, 2);
      expect(strings.get(391), 'One');
      expect(strings.get(392), 'Two');
    });
  });

  group('CFF DICT', () {
    test('parses compact positive and negative integers', () {
      final entries = _parser().parseDict(Uint8List.fromList([
        139,
        239,
        39,
        0,
      ]));
      expect(entries.single[0], 0);
      expect(entries.single[1], [0, 100, -100]);
    });

    test('parses two-byte positive and negative integers', () {
      final entries = _parser().parseDict(Uint8List.fromList([
        250,
        124,
        254,
        124,
        1,
      ]));
      expect(entries.single[1], [1000, -1000]);
    });

    test('parses signed 16-bit integers', () {
      final entries = _parser().parseDict(Uint8List.fromList([
        28,
        0x27,
        0x10,
        28,
        0xd8,
        0xf0,
        2,
      ]));
      expect(entries.single[1], [10000, -10000]);
    });

    test('parses signed 32-bit integers', () {
      final entries = _parser().parseDict(Uint8List.fromList([
        29,
        0,
        1,
        0x86,
        0xa0,
        29,
        0xff,
        0xfe,
        0x79,
        0x60,
        3,
      ]));
      expect(entries.single[1], [100000, -100000]);
    });

    test('parses real numbers', () {
      final entries = _parser().parseDict(Uint8List.fromList([
        30,
        0xe2,
        0xa2,
        0x5f,
        4,
      ]));
      expect(entries.single[1].single, -2.25);
    });

    test('parses escaped operators', () {
      final entries = _parser().parseDict(Uint8List.fromList([
        140,
        12,
        3,
      ]));
      expect(entries.single[0], 3075);
      expect(entries.single[1], [1]);
    });

    test('separates operands between operators', () {
      final entries = _parser().parseDict(Uint8List.fromList([
        140,
        0,
        141,
        142,
        5,
      ]));
      expect(entries, [
        [
          0,
          [1]
        ],
        [
          5,
          [2, 3]
        ],
      ]);
    });

    test('marks reserved operands as invalid', () {
      final entries = _parser().parseDict(Uint8List.fromList([31, 0]));
      expect((entries.single[1].single as double).isNaN, isTrue);
    });

    test('rejects truncated integer operands', () {
      expect(
        () => _parser().parseDict(Uint8List.fromList([28, 0])),
        throwsFormatException,
      );
      expect(
        () => _parser().parseDict(Uint8List.fromList([29, 0, 0])),
        throwsFormatException,
      );
    });
  });

  group('CFF charset', () {
    test('parses all predefined charsets', () {
      final parser = _parser();
      expect(
          parser.parseCharsets(0, 2, CFFStrings(), false).predefined, isTrue);
      expect(parser.parseCharsets(1, 2, CFFStrings(), false).format, 1);
      expect(parser.parseCharsets(2, 2, CFFStrings(), false).format, 2);
    });

    test('parses format zero names and CIDs', () {
      final parser = _parser([0, 0, 0, 0, 0, 2]);
      expect(
        parser.parseCharsets(3, 2, CFFStrings(), false).charset,
        ['.notdef', 'exclam'],
      );
      expect(
        parser.parseCharsets(3, 2, CFFStrings(), true).charset,
        [0, 2],
      );
    });

    test('parses format one names and CIDs', () {
      final parser = _parser([0, 0, 0, 1, 0, 8, 1]);
      expect(
        parser.parseCharsets(3, 3, CFFStrings(), false).charset,
        ['.notdef', 'quoteright', 'parenleft'],
      );
      expect(
        parser.parseCharsets(3, 3, CFFStrings(), true).charset,
        [0, 8, 9],
      );
    });

    test('parses format two names and CIDs', () {
      final parser = _parser([0, 0, 0, 2, 0, 8, 0, 1]);
      expect(
        parser.parseCharsets(3, 3, CFFStrings(), false).charset,
        ['.notdef', 'quoteright', 'parenleft'],
      );
      expect(
        parser.parseCharsets(3, 3, CFFStrings(), true).charset,
        [0, 8, 9],
      );
    });

    test('retains raw custom charset bytes', () {
      final parser = _parser([0, 0, 0, 0, 0, 2]);
      final charset = parser.parseCharsets(3, 2, CFFStrings(), false);
      expect(charset.predefined, isFalse);
      expect(charset.raw, [0, 0, 2]);
    });

    test('rejects unknown and truncated formats', () {
      expect(
        () => _parser([0, 0, 0, 3]).parseCharsets(3, 2, CFFStrings(), false),
        throwsFormatException,
      );
      expect(
        () => _parser([0, 0, 0, 0, 0]).parseCharsets(3, 2, CFFStrings(), false),
        throwsFormatException,
      );
    });

    test('rejects a range larger than glyph count', () {
      expect(
        () => _parser([0, 0, 0, 1, 0, 8, 9])
            .parseCharsets(3, 2, CFFStrings(), false),
        throwsFormatException,
      );
    });
  });

  group('CFF encoding', () {
    test('parses format zero', () {
      final encoding =
          _parser([0, 0, 0, 1, 8]).parseEncoding(2, CFFStrings(), const []);
      expect(encoding.encoding, {8: 1});
      expect(encoding.predefined, isFalse);
      expect(encoding.format, 0);
    });

    test('parses format one', () {
      final encoding =
          _parser([0, 0, 1, 1, 7, 1]).parseEncoding(2, CFFStrings(), const []);
      expect(encoding.encoding, {7: 1, 8: 2});
      expect(encoding.format, 1);
    });

    test('maps predefined standard encoding', () {
      final encoding = _parser().parseEncoding(
        0,
        CFFStrings(),
        ['.notdef', 'space', 'A'],
      );
      expect(encoding.predefined, isTrue);
      expect(encoding.encoding[32], 1);
      expect(encoding.encoding[65], 2);
    });

    test('maps predefined expert encoding', () {
      final encoding = _parser().parseEncoding(
        1,
        CFFStrings(),
        ['.notdef', 'exclamsmall'],
      );
      expect(encoding.predefined, isTrue);
      expect(encoding.encoding[33], 1);
    });

    test('parses supplements and clears supplement bit', () {
      final data = [0, 0, 0x80, 1, 8, 1, 9, 0, 2];
      final parser = _parser(data);
      final encoding = parser.parseEncoding(
        2,
        CFFStrings(),
        ['.notdef', 'space', 'exclam'],
      );
      expect(encoding.encoding[8], 1);
      expect(encoding.encoding[9], 2);
      expect(parser.bytes[2], 0);
    });

    test('rejects unknown and truncated formats', () {
      expect(
        () => _parser([0, 0, 2]).parseEncoding(2, CFFStrings(), const []),
        throwsFormatException,
      );
      expect(
        () => _parser([0, 0, 0, 2, 8]).parseEncoding(2, CFFStrings(), const []),
        throwsFormatException,
      );
    });

    test('rejects overflowing ranges', () {
      expect(
        () => _parser([0, 0, 1, 1, 255, 1])
            .parseEncoding(2, CFFStrings(), const []),
        throwsFormatException,
      );
    });
  });

  group('CFF FDSelect', () {
    test('parses format zero', () {
      final result = _parser([0, 0, 1]).parseFDSelect(0, 2);
      expect(result.format, 0);
      expect(result.fdSelect, [0, 1]);
      expect(result.getFDIndex(0), 0);
      expect(result.getFDIndex(1), 1);
      expect(result.getFDIndex(2), -1);
    });

    test('parses format three', () {
      final result = _parser([
        3,
        0,
        2,
        0,
        0,
        9,
        0,
        2,
        10,
        0,
        4,
      ]).parseFDSelect(0, 4);
      expect(result.format, 3);
      expect(result.fdSelect, [9, 9, 10, 10]);
    });

    test('recovers first range that does not start at zero', () {
      final result = _parser([
        3,
        0,
        2,
        0,
        1,
        9,
        0,
        2,
        10,
        0,
        4,
      ]).parseFDSelect(0, 4);
      expect(result.fdSelect, [9, 9, 10, 10]);
    });

    test('rejects unknown format', () {
      expect(() => _parser([2]).parseFDSelect(0, 1), throwsFormatException);
    });

    test('rejects empty format-three ranges', () {
      expect(
        () => _parser([3, 0, 0]).parseFDSelect(0, 1),
        throwsFormatException,
      );
    });

    test('rejects sentinel beyond glyph count', () {
      expect(
        () => _parser([3, 0, 1, 0, 0, 4, 0, 3]).parseFDSelect(0, 2),
        throwsFormatException,
      );
    });

    test('rejects a glyph count mismatch', () {
      expect(() => _parser([0, 1]).parseFDSelect(0, 2), throwsFormatException);
    });
  });

  group('CFF charstrings', () {
    test('preserves a cntrmask with mask bytes', () {
      final bytes = <int>[
        ...List<int>.filled(16, 149),
        1,
        ...List<int>.filled(16, 149),
        3,
        20,
        22,
        22,
        14,
      ];
      final index = CFFIndex()..add(bytes);
      final result = _parser().parseCharStrings(
        charStrings: index,
        privateDict: _privateDict(),
      );
      expect(result.charStrings.get(0), hasLength(38));
      expect(result.charStrings.get(0).last, 14);
    });

    test('extracts seac operands when enabled', () {
      final index = CFFIndex()..add([237, 247, 22, 247, 72, 204, 247, 86, 14]);
      final result = _parser().parseCharStrings(
        charStrings: index,
        privateDict: _privateDict(),
      );
      expect(result.charStrings.get(0), [14]);
      expect(result.seacs.single, [130, 180, 65, 194]);
    });

    test('keeps seac operands when analysis is disabled', () {
      final parser = CFFParser(Uint8List(0), <String, dynamic>{}, false);
      final index = CFFIndex()..add([237, 247, 22, 247, 72, 204, 247, 86, 14]);
      final result = parser.parseCharStrings(
        charStrings: index,
        privateDict: _privateDict(),
      );
      expect(result.charStrings.get(0), hasLength(9));
      expect(result.seacs, isEmpty);
    });

    test('keeps a normal endchar', () {
      final index = CFFIndex()..add([14]);
      final result = _parser().parseCharStrings(
        charStrings: index,
        privateDict: _privateDict(),
      );
      expect(result.charStrings.get(0), [14]);
      expect(result.seacs, isEmpty);
    });

    test('calculates default width', () {
      final index = CFFIndex()..add([14]);
      final result = _parser().parseCharStrings(
        charStrings: index,
        privateDict: _privateDict(defaultWidth: 500),
      );
      expect(result.widths, [500]);
    });

    test('calculates nominal plus explicit width', () {
      final index = CFFIndex()..add([189, 149, 22, 14]);
      final result = _parser().parseCharStrings(
        charStrings: index,
        privateDict: _privateDict(nominalWidth: 400),
      );
      expect(result.widths, [450]);
    });

    test('sanitizes an invalid command', () {
      final index = CFFIndex()..add([2]);
      final result = _parser().parseCharStrings(
        charStrings: index,
        privateDict: _privateDict(),
      );
      expect(result.charStrings.get(0), [14]);
    });

    test('sanitizes a command with too few operands', () {
      final index = CFFIndex()..add([139, 5]);
      final result = _parser().parseCharStrings(
        charStrings: index,
        privateDict: _privateDict(),
      );
      expect(result.charStrings.get(0), [14]);
    });

    test('accepts short and fixed point numbers', () {
      final index = CFFIndex()
        ..add([28, 0, 1, 28, 0, 2, 5, 255, 0, 1, 0, 0, 22, 14]);
      final result = _parser().parseCharStrings(
        charStrings: index,
        privateDict: _privateDict(),
      );
      expect(result.charStrings.get(0).last, 14);
    });

    test('converts deprecated dotsection to hmoveto sequence', () {
      final index = CFFIndex()..add([12, 0, 14]);
      _parser().parseCharStrings(
        charStrings: index,
        privateDict: _privateDict(),
      );
      expect(index.get(0).take(2), [139, 22]);
    });

    test('repairs a trailing zero operator', () {
      final index = CFFIndex()..add([0]);
      _parser().parseCharStrings(
        charStrings: index,
        privateDict: _privateDict(),
      );
      expect(index.get(0), [14]);
    });

    test('supports local subroutine calls', () {
      final subrs = CFFIndex();
      for (var i = 0; i < 107; i++) subrs.add([11]);
      final index = CFFIndex()..add([32, 10, 14]);
      final result = _parser().parseCharStrings(
        charStrings: index,
        localSubrIndex: subrs,
        privateDict: _privateDict(),
      );
      expect(result.charStrings.get(0).last, 14);
    });

    test('sanitizes out-of-range subroutine calls', () {
      final index = CFFIndex()..add([139, 10, 14]);
      final result = _parser().parseCharStrings(
        charStrings: index,
        localSubrIndex: CFFIndex(),
        privateDict: _privateDict(),
      );
      expect(result.charStrings.get(0), [14]);
    });
  });

  group('CFF compiler/parser interoperability', () {
    test('integer examples round-trip through DICT parser', () {
      final compiler = CFFCompiler(CFF());
      for (final value in [
        0,
        100,
        -100,
        1000,
        -1000,
        10000,
        -10000,
        100000,
        -100000,
      ]) {
        final data = [...compiler.encodeInteger(value), 0];
        final parsed = _parser().parseDict(Uint8List.fromList(data));
        expect(parsed.single[1], [value]);
      }
    });

    test('float examples round-trip through DICT parser', () {
      final compiler = CFFCompiler(CFF());
      for (final value in [-2.25, 0.5, 12.75, 5e-11]) {
        final data = [...compiler.encodeFloat(value), 0];
        final parsed = _parser().parseDict(Uint8List.fromList(data));
        expect(parsed.single[1].single,
            closeTo(value, value.abs() * 1e-10 + 1e-15));
      }
    });

    test('name index sanitization is readable by parser', () {
      final compiler = CFFCompiler(CFF());
      final compiled = compiler.compileNameIndex(['[a', 'Good Name']);
      final parser = CFFParser(compiled, <String, dynamic>{}, true);
      final result = parser.parseIndex(0);
      expect(parser.parseNameIndex(result.obj), ['_a', 'Good_Name']);
    });

    test('long names are limited to 127 bytes', () {
      final compiler = CFFCompiler(CFF());
      final compiled = compiler.compileNameIndex(['_' * 129]);
      final parser = CFFParser(compiled, <String, dynamic>{}, true);
      final result = parser.parseIndex(0);
      expect(parser.parseNameIndex(result.obj).single, hasLength(127));
    });

    test('format-zero FDSelect compiler output parses', () {
      final compiler = CFFCompiler(CFF());
      final bytes = compiler.compileFDSelect(CFFFDSelect(0, [3, 2, 1]));
      final parsed =
          CFFParser(bytes, <String, dynamic>{}, true).parseFDSelect(0, 3);
      expect(parsed.fdSelect, [3, 2, 1]);
    });

    test('format-three FDSelect compiler output parses', () {
      final compiler = CFFCompiler(CFF());
      final bytes = compiler.compileFDSelect(CFFFDSelect(3, [0, 0, 1, 1]));
      final parsed =
          CFFParser(bytes, <String, dynamic>{}, true).parseFDSelect(0, 4);
      expect(parsed.fdSelect, [0, 0, 1, 1]);
    });

    test('single-range FDSelect compiler output parses', () {
      final compiler = CFFCompiler(CFF());
      final bytes = compiler.compileFDSelect(CFFFDSelect(3, [4, 4]));
      final parsed =
          CFFParser(bytes, <String, dynamic>{}, true).parseFDSelect(0, 2);
      expect(parsed.fdSelect, [4, 4]);
    });

    test('non-CID charset compiler output parses', () {
      final strings = CFFStrings();
      final charset = CFFCharset(false, 0, ['space', 'exclam']);
      final bytes = CFFCompiler(CFF()).compileCharset(
        charset,
        3,
        strings,
        false,
      );
      final padding = Uint8List(bytes.length + 3)..setAll(3, bytes);
      final parsed = CFFParser(padding, <String, dynamic>{}, true)
          .parseCharsets(3, 3, strings, false);
      expect(parsed.charset, ['.notdef', 'space', 'exclam']);
    });

    test('CID charset compiler output parses', () {
      final strings = CFFStrings();
      final bytes = CFFCompiler(CFF()).compileCharset(
        CFFCharset(false, 0, const []),
        7,
        strings,
        true,
      );
      final padding = Uint8List(bytes.length + 3)..setAll(3, bytes);
      final parsed = CFFParser(padding, <String, dynamic>{}, true)
          .parseCharsets(3, 7, strings, true);
      expect(parsed.charset, [0, 1, 2, 3, 4, 5, 6]);
    });
  });
}
