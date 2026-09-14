// Copyright 2026 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'lexer.dart';

abstract final class PSValueType {
  static const unknown = 0;
  static const number = 1;
  static const boolean = 2;
}

sealed class PsNode {
  const PsNode();
  int get valueType => PSValueType.unknown;
}

final class PsProgram extends PsNode {
  final List<PsNode> children;
  const PsProgram(this.children);
}

final class PsBlock extends PsNode {
  final List<PsNode> children;
  const PsBlock(this.children);
}

final class PsNumber extends PsNode {
  final double value;
  const PsNumber(this.value);
  @override
  int get valueType => PSValueType.number;
}

final class PsOperator extends PsNode {
  final int operator;
  final String name;
  const PsOperator(this.operator, this.name);
}

final class PsIf extends PsNode {
  final PsBlock body;
  const PsIf(this.body);
}

final class PsIfElse extends PsNode {
  final PsBlock thenBody;
  final PsBlock elseBody;
  const PsIfElse(this.thenBody, this.elseBody);
}

final class PsArgNode extends PsNode {
  final int index;
  const PsArgNode(this.index);
  @override
  int get valueType => PSValueType.number;
}

final class PsConstNode extends PsNode {
  final Object value;
  const PsConstNode(this.value);
  @override
  int get valueType => value is bool ? PSValueType.boolean : PSValueType.number;
}

final class PsUnaryNode extends PsNode {
  final int operator;
  final PsNode argument;
  final int resultType;
  const PsUnaryNode(this.operator, this.argument,
      [this.resultType = PSValueType.number]);
  @override
  int get valueType => resultType;
}

final class PsBinaryNode extends PsNode {
  final int operator;
  final PsNode left;
  final PsNode right;
  final int resultType;
  const PsBinaryNode(this.operator, this.left, this.right,
      [this.resultType = PSValueType.number]);
  @override
  int get valueType => resultType;
}

final class PsTernaryNode extends PsNode {
  final PsNode condition;
  final PsNode whenTrue;
  final PsNode whenFalse;
  const PsTernaryNode(this.condition, this.whenTrue, this.whenFalse);
  @override
  int get valueType => whenTrue.valueType == whenFalse.valueType
      ? whenTrue.valueType
      : PSValueType.unknown;
}

/// Parses a PDF Type 4 PostScript calculator function.
class PsParser {
  final PsLexer lexer;
  Token? _lookahead;

  PsParser(String source) : lexer = PsLexer(source);

  Token _next() {
    final token = _lookahead;
    if (token != null) {
      _lookahead = null;
      return token;
    }
    return lexer.next();
  }

  PsProgram parse() {
    if (_next().id != TOKEN.lbrace) {
      throw FormatException('Invalid PostScript function: expected `{`.');
    }
    return PsProgram(_parseBody(topLevel: true));
  }

  List<PsNode> _parseBody({required bool topLevel}) {
    final nodes = <PsNode>[];
    while (true) {
      final token = _next();
      switch (token.id) {
        case TOKEN.eof:
          if (!topLevel) {
            throw FormatException('Unterminated PostScript procedure block.');
          }
          return nodes;
        case TOKEN.rbrace:
          return nodes;
        case TOKEN.lbrace:
          final first = PsBlock(_parseBody(topLevel: false));
          final following = _next();
          if (following.id == TOKEN.ifToken) {
            nodes.add(PsIf(first));
          } else if (following.id == TOKEN.lbrace) {
            final second = PsBlock(_parseBody(topLevel: false));
            if (_next().id != TOKEN.ifelse) {
              throw FormatException('Expected `ifelse` after two procedures.');
            }
            nodes.add(PsIfElse(first, second));
          } else {
            throw FormatException(
                'Procedure must be followed by if or ifelse.');
          }
          break;
        case TOKEN.number:
          nodes.add(PsNumber((token.value as num).toDouble()));
          break;
        case TOKEN.ifToken:
        case TOKEN.ifelse:
          throw FormatException('Control operator has no procedure block.');
        default:
          nodes.add(PsOperator(token.id, token.value as String));
      }
    }
  }
}

PsProgram parsePostScriptFunction(String source) => PsParser(source).parse();

/// Converts stack-oriented PostScript into an expression tree.
class PSStackToTree {
  final List<PsNode> stack;
  bool failed = false;

  PSStackToTree(int inputCount)
      : stack = [for (var i = 0; i < inputCount; i++) PsArgNode(i)];

  List<PsNode>? convert(PsProgram program) {
    for (final node in program.children) {
      if (!_consume(node)) {
        failed = true;
        return null;
      }
    }
    return List.unmodifiable(stack);
  }

  bool _consume(PsNode node) {
    if (node is PsNumber) {
      stack.add(PsConstNode(node.value));
      return true;
    }
    if (node is PsIf || node is PsIfElse) return _control(node);
    if (node is! PsOperator) return false;
    final op = node.operator;
    if (op == TOKEN.trueToken || op == TOKEN.falseToken) {
      stack.add(PsConstNode(op == TOKEN.trueToken));
      return true;
    }
    if (_unaryOps.contains(op)) return _unary(op);
    if (_binaryOps.contains(op)) return _binary(op);
    switch (op) {
      case TOKEN.dup:
        if (stack.isEmpty) return false;
        stack.add(stack.last);
        return true;
      case TOKEN.exch:
        if (stack.length < 2) return false;
        final last = stack.removeLast();
        final previous = stack.removeLast();
        stack
          ..add(last)
          ..add(previous);
        return true;
      case TOKEN.pop:
        if (stack.isEmpty) return false;
        stack.removeLast();
        return true;
      case TOKEN.copy:
        return _copy();
      case TOKEN.index:
        return _index();
      case TOKEN.roll:
        return _roll();
      default:
        return false;
    }
  }

  bool _unary(int op) {
    if (stack.isEmpty) return false;
    final argument = stack.removeLast();
    final type = op == TOKEN.not ? argument.valueType : PSValueType.number;
    stack.add(_simplifyUnary(op, argument, type));
    return true;
  }

  bool _binary(int op) {
    if (stack.length < 2) return false;
    final right = stack.removeLast();
    final left = stack.removeLast();
    final type =
        _comparisonOps.contains(op) ? PSValueType.boolean : PSValueType.number;
    stack.add(_simplifyBinary(op, left, right, type));
    return true;
  }

  bool _copy() {
    if (stack.isEmpty || stack.last is! PsConstNode) return false;
    final count = ((stack.removeLast() as PsConstNode).value as num).toInt();
    if (count < 0 || count > stack.length) return false;
    stack.addAll(stack.sublist(stack.length - count));
    return true;
  }

  bool _index() {
    if (stack.isEmpty || stack.last is! PsConstNode) return false;
    final index = ((stack.removeLast() as PsConstNode).value as num).toInt();
    if (index < 0 || index >= stack.length) return false;
    stack.add(stack[stack.length - index - 1]);
    return true;
  }

  bool _roll() {
    if (stack.length < 2 ||
        stack.last is! PsConstNode ||
        stack[stack.length - 2] is! PsConstNode) {
      return false;
    }
    var shift = ((stack.removeLast() as PsConstNode).value as num).toInt();
    final count = ((stack.removeLast() as PsConstNode).value as num).toInt();
    if (count < 0 || count > stack.length || count == 0) return count == 0;
    shift %= count;
    if (shift < 0) shift += count;
    final start = stack.length - count;
    final values = stack.sublist(start);
    stack.replaceRange(start, stack.length, [
      ...values.sublist(count - shift),
      ...values.sublist(0, count - shift)
    ]);
    return true;
  }

  bool _control(PsNode node) {
    if (stack.isEmpty) return false;
    final condition = stack.removeLast();
    if (node is PsIfElse) {
      final before = List<PsNode>.from(stack);
      final yes = PSStackToTree(0)..stack.addAll(before);
      final no = PSStackToTree(0)..stack.addAll(before);
      if (yes.convert(PsProgram(node.thenBody.children)) == null ||
          no.convert(PsProgram(node.elseBody.children)) == null ||
          yes.stack.length != no.stack.length) return false;
      stack
        ..clear()
        ..addAll([
          for (var i = 0; i < yes.stack.length; i++)
            _makeTernary(condition, yes.stack[i], no.stack[i]),
        ]);
      return true;
    }
    final branch = PSStackToTree(0)..stack.addAll(stack);
    if (branch.convert(PsProgram((node as PsIf).body.children)) == null ||
        branch.stack.length != stack.length) return false;
    for (var i = 0; i < stack.length; i++) {
      stack[i] = _makeTernary(condition, branch.stack[i], stack[i]);
    }
    return true;
  }

  static PsNode _makeTernary(PsNode condition, PsNode yes, PsNode no) {
    if (condition is PsConstNode && condition.value is bool) {
      return condition.value as bool ? yes : no;
    }
    if (identical(yes, no)) return yes;
    if (yes is PsConstNode &&
        no is PsConstNode &&
        yes.value == true &&
        no.value == false) return condition;
    return PsTernaryNode(condition, yes, no);
  }

  static PsNode _simplifyUnary(int op, PsNode value, int type) {
    if (op == TOKEN.neg &&
        value is PsUnaryNode &&
        value.operator == TOKEN.neg) {
      return value.argument;
    }
    if (op == TOKEN.not &&
        value is PsUnaryNode &&
        value.operator == TOKEN.not) {
      return value.argument;
    }
    if (op == TOKEN.abs &&
        value is PsUnaryNode &&
        value.operator == TOKEN.abs) {
      return value;
    }
    return PsUnaryNode(op, value, type);
  }

  static PsNode _simplifyBinary(int op, PsNode left, PsNode right, int type) {
    if (right is PsConstNode && right.value is num) {
      final value = (right.value as num).toDouble();
      if ((op == TOKEN.add || op == TOKEN.sub) && value == 0) return left;
      if ((op == TOKEN.mul || op == TOKEN.div || op == TOKEN.exp) && value == 1)
        return left;
      if (op == TOKEN.mul && value == 0) return right;
      if (op == TOKEN.exp && value == 0) return const PsConstNode(1.0);
      if (op == TOKEN.mul && value == -1) return PsUnaryNode(TOKEN.neg, left);
      if (op == TOKEN.exp && value == .5) return PsUnaryNode(TOKEN.sqrt, left);
    }
    if (left is PsConstNode && left.value is num) {
      final value = (left.value as num).toDouble();
      if (op == TOKEN.add && value == 0) return right;
      if (op == TOKEN.mul && value == 1) return right;
      if (op == TOKEN.mul && value == 0) return left;
      if (op == TOKEN.mul && value == -1) return PsUnaryNode(TOKEN.neg, right);
    }
    if (identical(left, right)) {
      if (op == TOKEN.sub || op == TOKEN.xor) return const PsConstNode(0.0);
      if (op == TOKEN.eq || op == TOKEN.ge || op == TOKEN.le)
        return const PsConstNode(true);
      if (op == TOKEN.ne || op == TOKEN.gt || op == TOKEN.lt)
        return const PsConstNode(false);
      if (op == TOKEN.and || op == TOKEN.or) return left;
    }
    return PsBinaryNode(op, left, right, type);
  }

  static const _unaryOps = {
    TOKEN.abs,
    TOKEN.neg,
    TOKEN.ceiling,
    TOKEN.floor,
    TOKEN.round,
    TOKEN.truncate,
    TOKEN.not,
    TOKEN.sqrt,
    TOKEN.sin,
    TOKEN.cos,
    TOKEN.ln,
    TOKEN.log,
    TOKEN.cvi,
    TOKEN.cvr,
  };
  static const _binaryOps = {
    TOKEN.add,
    TOKEN.sub,
    TOKEN.mul,
    TOKEN.div,
    TOKEN.idiv,
    TOKEN.mod,
    TOKEN.exp,
    TOKEN.eq,
    TOKEN.ne,
    TOKEN.gt,
    TOKEN.ge,
    TOKEN.lt,
    TOKEN.le,
    TOKEN.and,
    TOKEN.or,
    TOKEN.xor,
    TOKEN.bitshift,
    TOKEN.atan,
  };
  static const _comparisonOps = {
    TOKEN.eq,
    TOKEN.ne,
    TOKEN.gt,
    TOKEN.ge,
    TOKEN.lt,
    TOKEN.le,
  };
}
