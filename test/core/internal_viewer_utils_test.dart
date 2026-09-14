// Copyright 2026 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'package:pdfjs/src/core/internal_viewer_utils.dart';
import 'package:pdfjs/src/core/postscript/lexer.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/stream.dart';
import 'package:test/test.dart';

class _FakeXRef {
  dynamic fetchIfRef(dynamic ref) => ref;
}

void main() {
  group('PostScript Type 4 Lexer', () {
    List<int> tokenIds(String src) {
      final lexer = PsLexer(src);
      final ids = <int>[];
      Token tok;
      while ((tok = lexer.next()).id != TOKEN.eof) {
        ids.add(tok.id);
      }
      return ids;
    }

    test('tokenizes numbers', () {
      final lexer = PsLexer('3 -1.5 +0.5 .25 1.5e3');
      final values = <num>[];
      Token tok;
      while ((tok = lexer.next()).id != TOKEN.eof) {
        values.add(tok.value as num);
      }
      expect(values, [3, -1.5, 0.5, 0.25, 1500]);
    });

    test('tokenizes braces', () {
      expect(tokenIds('{ }'), [TOKEN.lbrace, TOKEN.rbrace]);
    });

    test('tokenizes operator keywords', () {
      const ops = 'abs add and atan bitshift ceiling copy cos cvi cvr div dup eq exch '
          'exp false floor ge gt idiv if ifelse index le ln log lt mod mul ne '
          'neg not or pop roll round sin sqrt sub true truncate xor';
      final ids = tokenIds(ops);
      for (final id in ids) {
        expect(id, greaterThan(TOKEN.rbrace));
        expect(id, lessThan(TOKEN.eof));
      }
    });

    test('skips % comments', () {
      expect(tokenIds('{ % comment\nadd }'), [
        TOKEN.lbrace,
        TOKEN.add,
        TOKEN.rbrace,
      ]);
    });

    test('skips whitespace', () {
      expect(tokenIds('  \t\n\r\fadd'), [TOKEN.add]);
    });

    test('operator tokens carry their name as value', () {
      final lexer = PsLexer('mul');
      final tok = lexer.next();
      expect(tok.id, equals(TOKEN.mul));
      expect(tok.value, equals('mul'));
    });
  });

  group('InternalViewerUtils', () {
    test('tokenToJSObject converts primitives', () {
      expect(
        InternalViewerUtils.tokenToJSObject(Cmd.get('BT')),
        {'type': 'cmd', 'value': 'BT'},
      );
      expect(
        InternalViewerUtils.tokenToJSObject(Name.get('F1')),
        {'type': 'name', 'value': 'F1'},
      );
      expect(
        InternalViewerUtils.tokenToJSObject(Ref.get(12, 0)),
        {'type': 'ref', 'num': 12, 'gen': 0},
      );
      expect(
        InternalViewerUtils.tokenToJSObject(42.5),
        {'type': 'number', 'value': 42.5},
      );
      expect(
        InternalViewerUtils.tokenToJSObject('hello'),
        {'type': 'string', 'value': 'hello'},
      );
      expect(
        InternalViewerUtils.tokenToJSObject(true),
        {'type': 'boolean', 'value': true},
      );
      expect(
        InternalViewerUtils.tokenToJSObject(null),
        {'type': 'null'},
      );
      expect(
        InternalViewerUtils.tokenToJSObject([1, 2]),
        {
          'type': 'array',
          'value': [
            {'type': 'number', 'value': 1},
            {'type': 'number', 'value': 2},
          ],
        },
      );

      final dict = Dict(null);
      dict.set('Key', Name.get('Val'));
      expect(
        InternalViewerUtils.tokenToJSObject(dict),
        {
          'type': 'dict',
          'value': {
            'Key': {'type': 'name', 'value': 'Val'},
          },
        },
      );
    });

    test('groupIntoInstructions groups args with operations', () {
      final tokens = <Map<String, dynamic>>[
        {'type': 'number', 'value': 100},
        {'type': 'number', 'value': 200},
        {'type': 'cmd', 'value': 'm'}, // moveTo takes 2 args
        {'type': 'cmd', 'value': 'h'}, // closePath takes 0 args
      ];

      final grouped = InternalViewerUtils.groupIntoInstructions(tokens);
      final instructions = grouped['instructions'] as List;
      final cmdNames = grouped['cmdNames'] as Map;

      expect(cmdNames['m'], equals('moveTo'));
      expect(cmdNames['h'], equals('closePath'));
      expect(instructions.length, equals(2));
      expect(instructions[0]['cmd'], equals('m'));
      expect(instructions[0]['args'].length, equals(2));
      expect(instructions[1]['cmd'], equals('h'));
      expect(instructions[1]['args'].length, equals(0));
    });

    test('tokenizePSSource formats indented blocks', () {
      const ps = '{\n  dup 0 eq\n  { pop 1 }\n  if\n}';
      final lines = InternalViewerUtils.tokenizePSSource(ps);
      expect(lines.isNotEmpty, isTrue);
      expect(lines[0]['tokens'][0]['type'], equals('brace'));
      expect(lines[0]['tokens'][0]['value'], equals('{'));
    });

    test('tokenizeStream and getContentTokens parses streams', () {
      final data = Uint8List.fromList('10 20 m S'.codeUnits);
      final stream = Stream(data);
      final xref = _FakeXRef();

      final tokens = InternalViewerUtils.tokenizeStream(stream, xref);
      expect(tokens.length, equals(4)); // 10, 20, m, S

      final res = InternalViewerUtils.getContentTokens(stream, xref);
      expect(res['contentStream'], isTrue);
      expect((res['instructions'] as List).length, equals(2));
    });
  });
}
