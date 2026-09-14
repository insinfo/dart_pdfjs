// Copyright 2026 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

abstract final class TOKEN {
  // Structural tokens — not keyword operators
  static const int number = 0;
  static const int lbrace = 1;
  static const int rbrace = 2;

  // Boolean literals
  static const int trueToken = 3;
  static const int falseToken = 4;

  // Arithmetic binary operators
  static const int add = 5;
  static const int sub = 6;
  static const int mul = 7;
  static const int div = 8;
  static const int idiv = 9;
  static const int mod = 10;
  static const int exp = 11;

  // Comparison binary operators
  static const int eq = 12;
  static const int ne = 13;
  static const int gt = 14;
  static const int ge = 15;
  static const int lt = 16;
  static const int le = 17;

  // Bitwise / boolean binary operators
  static const int and = 18;
  static const int or = 19;
  static const int xor = 20;
  static const int bitshift = 21;

  // Unary arithmetic operators
  static const int abs = 22;
  static const int neg = 23;
  static const int ceiling = 24;
  static const int floor = 25;
  static const int round = 26;
  static const int truncate = 27;

  // Unary boolean / bitwise operator
  static const int not = 28;

  // Mathematical functions — unary
  static const int sqrt = 29;
  static const int sin = 30;
  static const int cos = 31;
  static const int ln = 32;
  static const int log = 33;

  // Mathematical function — binary
  static const int atan = 34;

  // Type conversion operators
  static const int cvi = 35;
  static const int cvr = 36;

  // Stack operators
  static const int dup = 37;
  static const int exch = 38;
  static const int pop = 39;
  static const int copy = 40;
  static const int index = 41;
  static const int roll = 42;

  // Control flow
  static const int ifToken = 43;
  static const int ifelse = 44;

  // End of input
  static const int eof = 45;

  // Synthetic: produced by the optimizer, never emitted by the lexer.
  static const int min = 46;
  static const int max = 47;
}

class Token {
  final int id;
  final dynamic value;

  const Token(this.id, [this.value]);
}

class PsLexer {
  static final Map<String, Token> _singletons = {};
  static final Map<String, Token> _operatorSingletons = {};
  static bool _initialized = false;

  static const Map<String, int> _tokenMap = {
    'lbrace': TOKEN.lbrace,
    'rbrace': TOKEN.rbrace,
    'true': TOKEN.trueToken,
    'false': TOKEN.falseToken,
    'add': TOKEN.add,
    'sub': TOKEN.sub,
    'mul': TOKEN.mul,
    'div': TOKEN.div,
    'idiv': TOKEN.idiv,
    'mod': TOKEN.mod,
    'exp': TOKEN.exp,
    'eq': TOKEN.eq,
    'ne': TOKEN.ne,
    'gt': TOKEN.gt,
    'ge': TOKEN.ge,
    'lt': TOKEN.lt,
    'le': TOKEN.le,
    'and': TOKEN.and,
    'or': TOKEN.or,
    'xor': TOKEN.xor,
    'bitshift': TOKEN.bitshift,
    'abs': TOKEN.abs,
    'neg': TOKEN.neg,
    'ceiling': TOKEN.ceiling,
    'floor': TOKEN.floor,
    'round': TOKEN.round,
    'truncate': TOKEN.truncate,
    'not': TOKEN.not,
    'sqrt': TOKEN.sqrt,
    'sin': TOKEN.sin,
    'cos': TOKEN.cos,
    'ln': TOKEN.ln,
    'log': TOKEN.log,
    'atan': TOKEN.atan,
    'cvi': TOKEN.cvi,
    'cvr': TOKEN.cvr,
    'dup': TOKEN.dup,
    'exch': TOKEN.exch,
    'pop': TOKEN.pop,
    'copy': TOKEN.copy,
    'index': TOKEN.index,
    'roll': TOKEN.roll,
    'if': TOKEN.ifToken,
    'ifelse': TOKEN.ifelse,
    'eof': TOKEN.eof,
    'min': TOKEN.min,
    'max': TOKEN.max,
  };

  static void _initSingletons() {
    if (_initialized) return;
    for (final entry in _tokenMap.entries) {
      final name = entry.key;
      final id = entry.value;
      final isOperator = id >= TOKEN.trueToken && id <= TOKEN.ifelse;
      final token = Token(id, isOperator ? name : null);
      _singletons[name] = token;
      if (isOperator) {
        _operatorSingletons[name] = token;
      }
    }
    _initialized = true;
  }

  static Token get lbraceToken => _singletons['lbrace']!;
  static Token get rbraceToken => _singletons['rbrace']!;
  static Token get eofToken => _singletons['eof']!;

  final String data;
  int pos = 0;
  final int len;

  static final RegExp _numberPattern =
      RegExp(r'^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?');
  static final RegExp _identifierPattern = RegExp(r'^[a-z]+');

  PsLexer(this.data) : len = data.length {
    _initSingletons();
  }

  void _skipComment() {
    final lf = data.indexOf('\n', pos);
    final cr = data.indexOf('\r', pos);
    final eol = (lf < 0 && cr < 0)
        ? len
        : (lf < 0 ? cr : (cr < 0 ? lf : (lf < cr ? lf : cr)));
    pos = (eol + 1 > len) ? len : eol + 1;
  }

  Token _getNumber() {
    final slice = data.substring(pos);
    final match = _numberPattern.firstMatch(slice);
    if (match == null) {
      return const Token(TOKEN.number, 0);
    }
    final str = match.group(0)!;
    final number = double.tryParse(str);
    if (number == null || !number.isFinite) {
      return const Token(TOKEN.number, 0);
    }
    pos += match.end;
    return Token(TOKEN.number, number);
  }

  Token _getOperator() {
    final slice = data.substring(pos);
    final match = _identifierPattern.firstMatch(slice);
    if (match == null) {
      return const Token(TOKEN.number, 0);
    }
    final op = match.group(0)!;
    pos += match.end;
    final token = _operatorSingletons[op];
    if (token == null) {
      return const Token(TOKEN.number, 0);
    }
    return token;
  }

  Token next() {
    while (pos < len) {
      final ch = data.codeUnitAt(pos++);
      switch (ch) {
        // PostScript whitespace
        case 0x00:
        case 0x09:
        case 0x0a:
        case 0x0c:
        case 0x0d:
        case 0x20:
          break;

        case 0x25: // % comment
          _skipComment();
          break;

        case 0x7b: // {
          return lbraceToken;
        case 0x7d: // }
          return rbraceToken;

        case 0x2b: // +
        case 0x2d: // -
        case 0x2e: // .
          pos--;
          return _getNumber();

        default:
          if (ch >= 0x30 && ch <= 0x39) {
            pos--;
            return _getNumber();
          }
          if (ch >= 0x61 && ch <= 0x7a) {
            pos--;
            return _getOperator();
          }
          return const Token(TOKEN.number, 0);
      }
    }
    return eofToken;
  }
}
