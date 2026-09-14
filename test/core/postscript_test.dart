// Reference-derived tests for PDF Type 4 PostScript functions.

import 'package:pdfjs/src/core/postscript/ast.dart';
import 'package:pdfjs/src/core/postscript/evaluator.dart';
import 'package:pdfjs/src/core/postscript/lexer.dart';
import 'package:test/test.dart';

List<double> evaluate(
  String body, {
  List<double> input = const [0],
  List<double> domain = const [-1000, 1000],
  List<double> range = const [-100000, 100000],
}) {
  return buildPostScriptFunction(
    source: '{ $body }',
    domain: domain,
    range: range,
  )(input);
}

void main() {
  group('PostScript lexer', () {
    test('tokenizes integers, decimals and exponents', () {
      final lexer = PsLexer('3 -1.5 +0.5 .25 1.5e3');
      final values = <double>[];
      Token token;
      while ((token = lexer.next()).id != TOKEN.eof) {
        values.add(token.value as double);
      }
      expect(values, [3, -1.5, .5, .25, 1500]);
    });

    test('tokenizes braces', () {
      final lexer = PsLexer('{ }');
      expect(lexer.next().id, TOKEN.lbrace);
      expect(lexer.next().id, TOKEN.rbrace);
      expect(lexer.next().id, TOKEN.eof);
    });

    test('skips comments through the line ending', () {
      final lexer = PsLexer('1 % ignored add\r\n 2');
      expect(lexer.next().value, 1);
      expect(lexer.next().value, 2);
      expect(lexer.next().id, TOKEN.eof);
    });

    test('skips every PostScript whitespace character', () {
      final lexer = PsLexer('\u0000\t\n\f\r 42');
      expect(lexer.next().value, 42);
    });

    test('recognizes all supported keywords', () {
      const source = 'abs add and atan bitshift ceiling copy cos cvi cvr div '
          'dup eq exch exp false floor ge gt idiv if ifelse index le ln log '
          'lt mod mul ne neg not or pop roll round sin sqrt sub true truncate xor';
      final lexer = PsLexer(source);
      var count = 0;
      while (lexer.next().id != TOKEN.eof) count++;
      expect(count, 42);
    });

    test('operator tokens retain their spelling', () {
      final token = PsLexer('sqrt').next();
      expect(token.id, TOKEN.sqrt);
      expect(token.value, 'sqrt');
    });

    test('reuses singleton operator tokens', () {
      final lexer = PsLexer('add add');
      expect(identical(lexer.next(), lexer.next()), isTrue);
    });

    test('maps an unknown identifier to zero', () {
      final token = PsLexer('unknown').next();
      expect(token.id, TOKEN.number);
      expect(token.value, 0);
    });

    test('maps non-finite numbers to zero', () {
      expect(PsLexer('1e999').next().value, 0);
    });

    test('maps unexpected characters to zero', () {
      expect(PsLexer('@').next().value, 0);
    });
  });

  group('PostScript parser', () {
    test('parses an empty program', () {
      expect(parsePostScriptFunction('{ }').children, isEmpty);
    });

    test('parses number literals', () {
      final nodes = parsePostScriptFunction('{ 1 -2 .5 }').children;
      expect(nodes, hasLength(3));
      expect(nodes.whereType<PsNumber>().map((n) => n.value), [1, -2, .5]);
    });

    test('parses operators', () {
      final nodes = parsePostScriptFunction('{ add neg }').children;
      expect(nodes.whereType<PsOperator>().map((n) => n.name), ['add', 'neg']);
    });

    test('parses if procedures', () {
      final node = parsePostScriptFunction('{ { 1 } if }').children.single;
      expect(node, isA<PsIf>());
      expect((node as PsIf).body.children.single, isA<PsNumber>());
    });

    test('parses ifelse procedures', () {
      final node =
          parsePostScriptFunction('{ { 1 } { 2 } ifelse }').children.single;
      expect(node, isA<PsIfElse>());
      expect((node as PsIfElse).thenBody.children, hasLength(1));
      expect(node.elseBody.children, hasLength(1));
    });

    test('rejects input without an opening brace', () {
      expect(() => parsePostScriptFunction('1 2 add'), throwsFormatException);
    });

    test('rejects unterminated nested procedures', () {
      expect(() => parsePostScriptFunction('{ { 1'), throwsFormatException);
    });

    test('rejects a free-standing if', () {
      expect(() => parsePostScriptFunction('{ if }'), throwsFormatException);
    });

    test('rejects a procedure without a control operator', () {
      expect(() => parsePostScriptFunction('{ { 1 } add }'),
          throwsFormatException);
    });

    test('rejects two procedures without ifelse', () {
      expect(
        () => parsePostScriptFunction('{ { 1 } { 2 } add }'),
        throwsFormatException,
      );
    });
  });

  group('PostScript arithmetic', () {
    test('adds', () {
      expect(evaluate('2 add', input: [3]), [5]);
    });

    test('subtracts preserving operand order', () {
      expect(evaluate('2 sub', input: [7]), [5]);
    });

    test('multiplies', () {
      expect(evaluate('4 mul', input: [3]), [12]);
    });

    test('divides', () {
      expect(evaluate('4 div', input: [10]), [2.5]);
    });

    test('returns zero when dividing by zero', () {
      expect(evaluate('0 div', input: [10]), [0]);
    });

    test('performs integer division', () {
      expect(evaluate('3 idiv', input: [10]), [3]);
    });

    test('performs remainder', () {
      expect(evaluate('3 mod', input: [10]), [1]);
    });

    test('raises to a power', () {
      expect(evaluate('3 exp', input: [2]), [8]);
    });

    test('negates', () {
      expect(evaluate('neg', input: [12]), [-12]);
    });

    test('calculates absolute value', () {
      expect(evaluate('abs', input: [-12]), [12]);
    });

    test('calculates square root', () {
      expect(evaluate('sqrt', input: [81]), [9]);
    });

    test('calculates natural logarithm', () {
      expect(evaluate('ln', input: [1]).single, closeTo(0, 1e-12));
    });

    test('calculates base-ten logarithm', () {
      expect(evaluate('log', input: [100]).single, closeTo(2, 1e-12));
    });
  });

  group('PostScript rounding and conversion', () {
    test('floors', () {
      expect(evaluate('floor', input: [2.9]), [2]);
    });

    test('ceilings', () {
      expect(evaluate('ceiling', input: [2.1]), [3]);
    });

    test('rounds positive halves upward', () {
      expect(evaluate('round', input: [2.5]), [3]);
    });

    test('rounds negative halves toward zero', () {
      expect(evaluate('round', input: [-2.5]), [-2]);
    });

    test('truncates positive values', () {
      expect(evaluate('truncate', input: [2.9]), [2]);
    });

    test('truncates negative values', () {
      expect(evaluate('truncate', input: [-2.9]), [-2]);
    });

    test('cvi converts to integer', () {
      expect(evaluate('cvi', input: [4.8]), [4]);
    });

    test('cvr retains real values', () {
      expect(evaluate('cvr', input: [4.8]), [4.8]);
    });
  });

  group('PostScript trigonometry', () {
    test('sin uses degrees', () {
      expect(evaluate('sin', input: [90]).single, closeTo(1, 1e-12));
    });

    test('cos uses degrees', () {
      expect(evaluate('cos', input: [180]).single, closeTo(-1, 1e-12));
    });

    test('sin normalizes a complete rotation', () {
      expect(evaluate('sin', input: [360]).single, closeTo(0, 1e-12));
    });

    test('cos normalizes a complete rotation', () {
      expect(evaluate('cos', input: [360]).single, closeTo(1, 1e-12));
    });

    test('atan produces degrees', () {
      expect(evaluate('1 atan', input: [1]).single, closeTo(45, 1e-12));
    });

    test('atan normalizes negative angles', () {
      expect(evaluate('1 atan', input: [-1]).single, closeTo(315, 1e-12));
    });
  });

  group('PostScript comparison and logic', () {
    test('eq compares values', () {
      expect(evaluate('5 eq { 1 } { 0 } ifelse', input: [5]), [1]);
    });

    test('ne compares values', () {
      expect(evaluate('5 ne { 1 } { 0 } ifelse', input: [4]), [1]);
    });

    test('gt compares numbers', () {
      expect(evaluate('3 gt { 1 } { 0 } ifelse', input: [4]), [1]);
    });

    test('ge compares numbers', () {
      expect(evaluate('4 ge { 1 } { 0 } ifelse', input: [4]), [1]);
    });

    test('lt compares numbers', () {
      expect(evaluate('5 lt { 1 } { 0 } ifelse', input: [4]), [1]);
    });

    test('le compares numbers', () {
      expect(evaluate('4 le { 1 } { 0 } ifelse', input: [4]), [1]);
    });

    test('boolean and combines predicates', () {
      expect(
          evaluate('0 gt exch 10 lt and { 1 } { 0 } ifelse',
              input: [5, 5], domain: [-100, 100, -100, 100]),
          [1]);
    });

    test('boolean or combines predicates', () {
      expect(
          evaluate('0 lt exch 10 gt or { 1 } { 0 } ifelse',
              input: [20, 5], domain: [-100, 100, -100, 100]),
          [1]);
    });

    test('boolean xor distinguishes predicates', () {
      expect(
          evaluate('0 gt exch 10 gt xor { 1 } { 0 } ifelse',
              input: [-5, 5], domain: [-100, 100, -100, 100]),
          [1]);
    });

    test('boolean not negates predicates', () {
      expect(evaluate('0 gt not { 1 } { 0 } ifelse', input: [-2]), [1]);
    });

    test('integer and is bitwise', () {
      expect(evaluate('3 and', input: [6]), [2]);
    });

    test('integer or is bitwise', () {
      expect(evaluate('3 or', input: [4]), [7]);
    });

    test('integer xor is bitwise', () {
      expect(evaluate('3 xor', input: [6]), [5]);
    });

    test('integer not is bitwise', () {
      expect(evaluate('not', input: [0]), [-1]);
    });

    test('bitshift shifts left', () {
      expect(evaluate('3 bitshift', input: [2]), [16]);
    });

    test('bitshift shifts right', () {
      expect(evaluate('-2 bitshift', input: [16]), [4]);
    });
  });

  group('PostScript stack operators', () {
    test('dup duplicates the top value', () {
      expect(evaluate('dup mul', input: [7]), [49]);
    });

    test('exch swaps the top values', () {
      expect(evaluate('2 exch sub', input: [7]), [-5]);
    });

    test('pop discards the top value', () {
      expect(evaluate('99 pop', input: [7]), [7]);
    });

    test('copy duplicates a window', () {
      expect(evaluate('2 3 2 copy add add add add', input: [1]), [11]);
    });

    test('index copies an indexed value', () {
      expect(evaluate('2 3 2 index add add add', input: [1]), [7]);
    });

    test('roll rotates a stack window forward', () {
      expect(evaluate('2 3 3 1 roll pop pop', input: [1]), [3]);
    });

    test('roll rotates a stack window backward', () {
      expect(evaluate('2 3 3 -1 roll pop pop', input: [1]), [2]);
    });

    test('throws on stack underflow', () {
      expect(() => evaluate('pop pop', input: [1]), throwsStateError);
    });

    test('throws on an invalid copy count', () {
      expect(() => evaluate('5 copy', input: [1]), throwsRangeError);
    });

    test('throws on an invalid index', () {
      expect(() => evaluate('5 index', input: [1]), throwsRangeError);
    });
  });

  group('PostScript functions', () {
    test('executes the true if branch', () {
      expect(evaluate('dup 0 gt { 10 add } if', input: [2]), [12]);
    });

    test('skips a false if branch', () {
      expect(evaluate('dup 0 gt { 10 add } if', input: [-2]), [-2]);
    });

    test('selects the true ifelse branch', () {
      expect(evaluate('0 gt { 10 } { 20 } ifelse', input: [2]), [10]);
    });

    test('selects the false ifelse branch', () {
      expect(evaluate('0 gt { 10 } { 20 } ifelse', input: [-2]), [20]);
    });

    test('clamps inputs to the domain', () {
      expect(evaluate('', input: [20], domain: [0, 10]), [10]);
    });

    test('clamps outputs to the range', () {
      expect(evaluate('10 mul', input: [20], range: [0, 100]), [100]);
    });

    test('supports several inputs', () {
      expect(evaluate('add', input: [2, 3], domain: [0, 10, 0, 10]), [5]);
    });

    test('supports several outputs', () {
      expect(evaluate('dup 2 mul', range: [-100, 100, -100, 100], input: [3]),
          [3, 6]);
    });

    test('validates input count', () {
      final fn =
          buildPostScriptFunction(source: '{ }', domain: [0, 1], range: [0, 1]);
      expect(() => fn([]), throwsArgumentError);
    });

    test('validates domain pairs', () {
      expect(
        () => buildPostScriptFunction(source: '{}', domain: [0], range: [0, 1]),
        throwsArgumentError,
      );
    });

    test('validates range pairs', () {
      expect(
        () => buildPostScriptFunction(source: '{}', domain: [0, 1], range: [0]),
        throwsArgumentError,
      );
    });

    test('rejects too few outputs', () {
      final fn = buildPostScriptFunction(
          source: '{ pop }', domain: [0, 1], range: [0, 1]);
      expect(() => fn([.5]), throwsStateError);
    });
  });

  group('PSStackToTree', () {
    List<PsNode> tree(String body, {int inputs = 1}) {
      return PSStackToTree(inputs)
          .convert(parsePostScriptFunction('{ $body }'))!;
    }

    test('wraps inputs in argument nodes', () {
      final nodes = tree('', inputs: 2);
      expect(nodes, hasLength(2));
      expect((nodes[0] as PsArgNode).index, 0);
      expect((nodes[1] as PsArgNode).index, 1);
    });

    test('wraps literals in constant nodes', () {
      expect(tree('2').last, isA<PsConstNode>());
    });

    test('creates binary expression nodes', () {
      final node = tree('2 add').single as PsBinaryNode;
      expect(node.operator, TOKEN.add);
      expect(node.left, isA<PsArgNode>());
      expect(node.right, isA<PsConstNode>());
    });

    test('creates unary expression nodes', () {
      final node = tree('neg').single as PsUnaryNode;
      expect(node.operator, TOKEN.neg);
      expect(node.argument, isA<PsArgNode>());
    });

    test('dup shares node identity', () {
      final nodes = tree('dup');
      expect(identical(nodes[0], nodes[1]), isTrue);
    });

    test('exch swaps nodes', () {
      final nodes = tree('exch', inputs: 2);
      expect((nodes[0] as PsArgNode).index, 1);
      expect((nodes[1] as PsArgNode).index, 0);
    });

    test('pop removes a node', () {
      expect(tree('pop', inputs: 2), hasLength(1));
    });

    test('copy duplicates nodes', () {
      expect(tree('2 copy', inputs: 2), hasLength(4));
    });

    test('index copies an earlier node', () {
      final nodes = tree('1 index', inputs: 2);
      expect(identical(nodes[0], nodes[2]), isTrue);
    });

    test('folds addition by zero', () {
      expect(tree('0 add').single, isA<PsArgNode>());
    });

    test('folds multiplication by one', () {
      expect(tree('1 mul').single, isA<PsArgNode>());
    });

    test('folds multiplication by zero', () {
      final node = tree('0 mul').single as PsConstNode;
      expect(node.value, 0);
    });

    test('folds exponent one', () {
      expect(tree('1 exp').single, isA<PsArgNode>());
    });

    test('folds exponent zero', () {
      expect((tree('0 exp').single as PsConstNode).value, 1);
    });

    test('folds exponent one half into sqrt', () {
      final node = tree('.5 exp').single as PsUnaryNode;
      expect(node.operator, TOKEN.sqrt);
    });

    test('eliminates double negation', () {
      expect(tree('neg neg').single, isA<PsArgNode>());
    });

    test('eliminates double boolean not', () {
      expect(tree('0 gt not not').single, isA<PsBinaryNode>());
    });

    test('retains value type for arguments', () {
      expect(tree('').single.valueType, PSValueType.number);
    });

    test('assigns boolean value type to comparisons', () {
      expect(tree('0 gt').single.valueType, PSValueType.boolean);
    });

    test('assigns numeric value type to arithmetic', () {
      expect(tree('2 add').single.valueType, PSValueType.number);
    });

    test('fails cleanly on stack underflow', () {
      final converter = PSStackToTree(0);
      expect(converter.convert(parsePostScriptFunction('{ add }')), isNull);
      expect(converter.failed, isTrue);
    });
  });
}
