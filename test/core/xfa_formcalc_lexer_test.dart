import 'package:pdfjs/src/core/xfa/formcalc_lexer.dart';
import 'package:test/test.dart';

void main() {
  const eof = Token(TOKEN.eof);

  group('FormCalc lexer', () {
    test('lexes decimal and exponential numbers', () {
      final lexer = Lexer(
        '1 7 12 1.2345 .7 .12345 1e-2 1.2E+3 1e2 1.2E3 '
        'nan 12. 2.e3 infinity 99999999999999999 '
        '123456789.012345678 9e99999',
      );
      final expected = <num>[
        1,
        7,
        12,
        1.2345,
        .7,
        .12345,
        1e-2,
        1.2e3,
        1e2,
        1.2e3,
        double.nan,
        12,
        2e3,
        double.infinity,
        100000000000000000,
        123456789.01234567,
        double.infinity,
      ];

      for (final value in expected) {
        final token = lexer.next();
        expect(token.id, TOKEN.number);
        if (value.isNaN) {
          expect(token.value, isNaN);
        } else {
          expect(token.value, value);
        }
      }
      expect(lexer.next(), eof);
    });

    test('lexes strings, doubled quotes, and unicode escapes', () {
      final lexer = Lexer(
        r'''"hello world" "hello ""world" "hello ""world"" ""world""""hello""" "hello \uabcdeh \Uabcd \u00000123abc" "a \a \ub \Uc \b"''',
      );
      expect(lexer.next(), const Token(TOKEN.string, 'hello world'));
      expect(lexer.next(), const Token(TOKEN.string, 'hello "world'));
      expect(
        lexer.next(),
        const Token(TOKEN.string, 'hello "world" "world""hello"'),
      );
      expect(
        lexer.next(),
        const Token(TOKEN.string, 'hello \u{abcd}eh \u{abcd} \u{0123}abc'),
      );
      expect(lexer.next(), const Token(TOKEN.string, r'a \a \ub \Uc \b'));
      expect(lexer.next(), eof);
    });

    test('lexes symbolic operators', () {
      final lexer = Lexer('( , ) <= <> = == >= < > / * . .. .* .# [ ] & |');
      final ids = <int>[
        TOKEN.leftParen,
        TOKEN.comma,
        TOKEN.rightParen,
        TOKEN.le,
        TOKEN.ne,
        TOKEN.assign,
        TOKEN.eq,
        TOKEN.ge,
        TOKEN.lt,
        TOKEN.gt,
        TOKEN.divide,
        TOKEN.times,
        TOKEN.dot,
        TOKEN.dotDot,
        TOKEN.dotStar,
        TOKEN.dotHash,
        TOKEN.leftBracket,
        TOKEN.rightBracket,
        TOKEN.and,
        TOKEN.or,
      ];
      for (final id in ids) {
        expect(lexer.next(), Token(id));
      }
      expect(lexer.next(), eof);
    });

    test('skips semicolon and double-slash comments', () {
      final lexer = Lexer('''
        1
        ; ignored until end of line
        2
        // another comment
        3
      ''');
      expect(lexer.next(), const Token(TOKEN.number, 1));
      expect(lexer.next(), const Token(TOKEN.number, 2));
      expect(lexer.next(), const Token(TOKEN.number, 3));
      expect(lexer.next(), eof);
    });

    test('recognizes keywords case-insensitively and unicode identifiers', () {
      final lexer = Lexer(
        'EQ for fore WHILE continue hello こんにちは世界 '
        r'$!hello今日は12今日は',
      );
      expect(lexer.next(), const Token(TOKEN.eq));
      expect(lexer.next(), const Token(TOKEN.forToken));
      expect(lexer.next(), const Token(TOKEN.identifier, 'fore'));
      expect(lexer.next(), const Token(TOKEN.whileToken));
      expect(lexer.next(), const Token(TOKEN.continueToken));
      expect(lexer.next(), const Token(TOKEN.identifier, 'hello'));
      expect(lexer.next(), const Token(TOKEN.identifier, 'こんにちは世界'));
      expect(lexer.next(), const Token(TOKEN.identifier, r'$'));
      expect(
        lexer.next(),
        const Token(TOKEN.identifier, '!hello今日は12今日は'),
      );
      expect(lexer.next(), eof);
    });

    test('covers every keyword token', () {
      final cases = <String, int>{
        'and': TOKEN.and,
        'break': TOKEN.breakToken,
        'continue': TOKEN.continueToken,
        'do': TOKEN.doToken,
        'downto': TOKEN.downto,
        'else': TOKEN.elseToken,
        'elseif': TOKEN.elseif,
        'end': TOKEN.end,
        'endfor': TOKEN.endfor,
        'endfunc': TOKEN.endfunc,
        'endif': TOKEN.endif,
        'endwhile': TOKEN.endwhile,
        'eq': TOKEN.eq,
        'exit': TOKEN.exit,
        'for': TOKEN.forToken,
        'foreach': TOKEN.foreach,
        'func': TOKEN.func,
        'ge': TOKEN.ge,
        'gt': TOKEN.gt,
        'if': TOKEN.ifToken,
        'in': TOKEN.inToken,
        'le': TOKEN.le,
        'lt': TOKEN.lt,
        'ne': TOKEN.ne,
        'not': TOKEN.not,
        'null': TOKEN.nullToken,
        'or': TOKEN.or,
        'return': TOKEN.returnToken,
        'step': TOKEN.step,
        'then': TOKEN.then,
        'this': TOKEN.thisToken,
        'throw': TOKEN.throwToken,
        'upto': TOKEN.upto,
        'var': TOKEN.varToken,
        'while': TOKEN.whileToken,
      };
      final lexer = Lexer(cases.keys.join(' '));
      for (final entry in cases.entries) {
        expect(lexer.next(), Token(entry.value), reason: entry.key);
      }
      expect(lexer.next(), eof);
    });

    test('rejects invalid token starts with a useful position', () {
      expect(
        () => Lexer('@').next(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('position 0'),
          ),
        ),
      );
    });

    test('keeps lone slash and unterminated strings deterministic', () {
      final lexer = Lexer('/ "unterminated');
      expect(lexer.next(), const Token(TOKEN.divide));
      expect(lexer.next(), const Token(TOKEN.string, 'unterminate'));
      expect(lexer.next(), eof);
    });
  });
}
