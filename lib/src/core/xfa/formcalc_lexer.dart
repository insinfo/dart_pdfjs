// Copyright 2021 Mozilla Foundation
//
// Licensed under the Apache License, Version 2.0.

/// Token identifiers used by the XFA FormCalc grammar.
///
/// The numeric values deliberately match pdf.js. Keeping them stable makes it
/// possible to port the parser tables without a translation layer.
abstract final class TOKEN {
  static const int and = 0;
  static const int divide = 1;
  static const int dot = 2;
  static const int dotDot = 3;
  static const int dotHash = 4;
  static const int dotStar = 5;
  static const int eq = 6;
  static const int ge = 7;
  static const int gt = 8;
  static const int le = 9;
  static const int leftBracket = 10;
  static const int leftParen = 11;
  static const int lt = 12;
  static const int minus = 13;
  static const int ne = 14;
  static const int not = 15;
  static const int nullToken = 16;
  static const int number = 17;
  static const int or = 18;
  static const int plus = 19;
  static const int rightBracket = 20;
  static const int rightParen = 21;
  static const int string = 22;
  static const int thisToken = 23;
  static const int times = 24;
  static const int identifier = 25;

  static const int breakToken = 26;
  static const int continueToken = 27;
  static const int doToken = 28;
  static const int forToken = 29;
  static const int foreach = 30;
  static const int func = 31;
  static const int ifToken = 32;
  static const int varToken = 33;
  static const int whileToken = 34;

  static const int assign = 35;
  static const int comma = 36;
  static const int downto = 37;
  static const int elseToken = 38;
  static const int elseif = 39;
  static const int end = 40;
  static const int endif = 41;
  static const int endfor = 42;
  static const int endfunc = 43;
  static const int endwhile = 44;
  static const int eof = 45;
  static const int exit = 46;
  static const int inToken = 47;
  static const int infinity = 48;
  static const int nan = 49;
  static const int returnToken = 50;
  static const int step = 51;
  static const int then = 52;
  static const int throwToken = 53;
  static const int upto = 54;
}

/// A lexical token and its optional literal value.
class Token {
  const Token(this.id, [this.value]);

  final int id;
  final Object? value;

  @override
  bool operator ==(Object other) {
    if (other is! Token || id != other.id) {
      return false;
    }
    if (value is double && other.value is double) {
      final a = value! as double;
      final b = other.value! as double;
      return (a.isNaN && b.isNaN) || a == b;
    }
    return value == other.value;
  }

  @override
  int get hashCode => Object.hash(
      id, value is double && (value! as double).isNaN ? 'NaN' : value);

  @override
  String toString() => value == null ? 'Token($id)' : 'Token($id, $value)';
}

const Set<String> _keywords = {
  'and',
  'break',
  'continue',
  'do',
  'downto',
  'else',
  'elseif',
  'end',
  'endfor',
  'endfunc',
  'endif',
  'endwhile',
  'eq',
  'exit',
  'for',
  'foreach',
  'func',
  'ge',
  'gt',
  'if',
  'in',
  'infinity',
  'le',
  'lt',
  'nan',
  'ne',
  'not',
  'null',
  'or',
  'return',
  'step',
  'then',
  'this',
  'throw',
  'upto',
  'var',
  'while',
};

final RegExp _hexPattern = RegExp(r'^[uU]([0-9a-fA-F]{4,8})');
final RegExp _numberPattern = RegExp(r'^\d*(?:\.\d*)?(?:[Ee][+-]?\d+)?');
final RegExp _dotNumberPattern = RegExp(r'^\d*(?:[Ee][+-]?\d+)?');
final RegExp _eolPattern = RegExp(r'[\r\n]+');
final RegExp _identifierPattern = RegExp(
  r'^[\p{L}_$!][\p{L}\p{N}_$]*',
  unicode: true,
);

final Map<String, Token> _singletons = {
  'and': const Token(TOKEN.and),
  'divide': const Token(TOKEN.divide),
  'dot': const Token(TOKEN.dot),
  'dotDot': const Token(TOKEN.dotDot),
  'dotHash': const Token(TOKEN.dotHash),
  'dotStar': const Token(TOKEN.dotStar),
  'eq': const Token(TOKEN.eq),
  'ge': const Token(TOKEN.ge),
  'gt': const Token(TOKEN.gt),
  'le': const Token(TOKEN.le),
  'leftBracket': const Token(TOKEN.leftBracket),
  'leftParen': const Token(TOKEN.leftParen),
  'lt': const Token(TOKEN.lt),
  'minus': const Token(TOKEN.minus),
  'ne': const Token(TOKEN.ne),
  'not': const Token(TOKEN.not),
  'null': const Token(TOKEN.nullToken),
  'or': const Token(TOKEN.or),
  'plus': const Token(TOKEN.plus),
  'rightBracket': const Token(TOKEN.rightBracket),
  'rightParen': const Token(TOKEN.rightParen),
  'this': const Token(TOKEN.thisToken),
  'times': const Token(TOKEN.times),
  'break': const Token(TOKEN.breakToken),
  'continue': const Token(TOKEN.continueToken),
  'do': const Token(TOKEN.doToken),
  'for': const Token(TOKEN.forToken),
  'foreach': const Token(TOKEN.foreach),
  'func': const Token(TOKEN.func),
  'if': const Token(TOKEN.ifToken),
  'var': const Token(TOKEN.varToken),
  'while': const Token(TOKEN.whileToken),
  'assign': const Token(TOKEN.assign),
  'comma': const Token(TOKEN.comma),
  'downto': const Token(TOKEN.downto),
  'else': const Token(TOKEN.elseToken),
  'elseif': const Token(TOKEN.elseif),
  'end': const Token(TOKEN.end),
  'endif': const Token(TOKEN.endif),
  'endfor': const Token(TOKEN.endfor),
  'endfunc': const Token(TOKEN.endfunc),
  'endwhile': const Token(TOKEN.endwhile),
  'eof': const Token(TOKEN.eof),
  'exit': const Token(TOKEN.exit),
  'in': const Token(TOKEN.inToken),
  'return': const Token(TOKEN.returnToken),
  'step': const Token(TOKEN.step),
  'then': const Token(TOKEN.then),
  'throw': const Token(TOKEN.throwToken),
  'upto': const Token(TOKEN.upto),
  'nan': const Token(TOKEN.number, double.nan),
  'infinity': const Token(TOKEN.number, double.infinity),
};

/// Lexer for the XFA FormCalc scripting language.
class Lexer {
  Lexer(this.data);

  final String data;
  int pos = 0;
  late final int len = data.length;
  final List<String> _stringBuffer = [];

  void _skipUntilEol() {
    final match = _eolPattern.firstMatch(data.substring(pos));
    if (match == null) {
      pos = len;
    } else {
      pos += match.start + match.group(0)!.length;
    }
  }

  Token _getIdentifier() {
    pos--;
    final match = _identifierPattern.firstMatch(data.substring(pos));
    if (match == null) {
      throw FormatException(
        'Invalid token in FormCalc expression at position $pos.',
      );
    }
    final identifier = match.group(0)!;
    pos += identifier.length;
    final lower = identifier.toLowerCase();
    if (!_keywords.contains(lower)) {
      return Token(TOKEN.identifier, identifier);
    }
    return _singletons[lower]!;
  }

  Token _getString() {
    final chunks = _stringBuffer;
    var start = pos;
    while (pos < len) {
      final char = data.codeUnitAt(pos++);
      if (char == 0x22) {
        if (pos < len && data.codeUnitAt(pos) == 0x22) {
          chunks.add(data.substring(start, pos++));
          start = pos;
          continue;
        }
        break;
      }
      if (char != 0x5c) {
        continue;
      }
      final end = (pos + 10).clamp(0, len);
      final match = _hexPattern.firstMatch(data.substring(pos, end));
      if (match == null) {
        continue;
      }
      chunks.add(data.substring(start, pos - 1));
      final code = match.group(1)!;
      if (code.length == 4) {
        chunks.add(String.fromCharCode(int.parse(code, radix: 16)));
        start = pos += 5;
      } else if (code.length != 8) {
        chunks.add(
            String.fromCharCode(int.parse(code.substring(0, 4), radix: 16)));
        start = pos += 5;
      } else {
        // JavaScript's String.fromCharCode truncates values to 16 bits.
        chunks.add(String.fromCharCode(int.parse(code, radix: 16) & 0xffff));
        start = pos += 9;
      }
    }
    final lastEnd = pos > 0 ? pos - 1 : pos;
    final lastChunk = data.substring(start, lastEnd);
    if (chunks.isEmpty) {
      return Token(TOKEN.string, lastChunk);
    }
    chunks.add(lastChunk);
    final value = chunks.join();
    chunks.clear();
    return Token(TOKEN.string, value);
  }

  Token _getNumber(int first) {
    final match = _numberPattern.firstMatch(data.substring(pos))!;
    final suffix = match.group(0)!;
    if (suffix.isEmpty) {
      return Token(TOKEN.number, first - 0x30);
    }
    final value = double.parse(data.substring(pos - 1, pos + suffix.length));
    pos += suffix.length;
    return Token(TOKEN.number, value);
  }

  Token _getComparison(Token withEquals, Token plain) {
    if (pos < len && data.codeUnitAt(pos) == 0x3d) {
      pos++;
      return withEquals;
    }
    return plain;
  }

  Token _getLower() {
    if (pos < len) {
      final char = data.codeUnitAt(pos);
      if (char == 0x3d) {
        pos++;
        return _singletons['le']!;
      }
      if (char == 0x3e) {
        pos++;
        return _singletons['ne']!;
      }
    }
    return _singletons['lt']!;
  }

  Token _getDot() {
    if (pos >= len) {
      return _singletons['dot']!;
    }
    final char = data.codeUnitAt(pos);
    if (char == 0x2e) {
      pos++;
      return _singletons['dotDot']!;
    }
    if (char == 0x2a) {
      pos++;
      return _singletons['dotStar']!;
    }
    if (char == 0x23) {
      pos++;
      return _singletons['dotHash']!;
    }
    if (char >= 0x30 && char <= 0x39) {
      pos++;
      final match = _dotNumberPattern.firstMatch(data.substring(pos))!;
      final suffix = match.group(0)!;
      final end = pos + suffix.length;
      final value = double.parse(data.substring(pos - 2, end));
      pos = end;
      return Token(TOKEN.number, value);
    }
    return _singletons['dot']!;
  }

  Token next() {
    while (pos < len) {
      final char = data.codeUnitAt(pos++);
      switch (char) {
        case 0x09:
        case 0x0a:
        case 0x0b:
        case 0x0c:
        case 0x0d:
        case 0x20:
          break;
        case 0x22:
          return _getString();
        case 0x26:
          return _singletons['and']!;
        case 0x28:
          return _singletons['leftParen']!;
        case 0x29:
          return _singletons['rightParen']!;
        case 0x2a:
          return _singletons['times']!;
        case 0x2b:
          return _singletons['plus']!;
        case 0x2c:
          return _singletons['comma']!;
        case 0x2d:
          return _singletons['minus']!;
        case 0x2e:
          return _getDot();
        case 0x2f:
          if (pos < len && data.codeUnitAt(pos) == 0x2f) {
            _skipUntilEol();
            break;
          }
          return _singletons['divide']!;
        case >= 0x30 && <= 0x39:
          return _getNumber(char);
        case 0x3b:
          _skipUntilEol();
          break;
        case 0x3c:
          return _getLower();
        case 0x3d:
          return _getComparison(_singletons['eq']!, _singletons['assign']!);
        case 0x3e:
          return _getComparison(_singletons['ge']!, _singletons['gt']!);
        case 0x5b:
          return _singletons['leftBracket']!;
        case 0x5d:
          return _singletons['rightBracket']!;
        case 0x7c:
          return _singletons['or']!;
        default:
          return _getIdentifier();
      }
    }
    return _singletons['eof']!;
  }
}
