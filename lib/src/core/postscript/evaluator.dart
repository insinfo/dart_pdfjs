// Copyright 2026 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;

import 'ast.dart';
import 'lexer.dart';

typedef PostScriptFunction = List<double> Function(List<double> input);

/// Builds an executable PDF Type 4 calculator function.
PostScriptFunction buildPostScriptFunction({
  required String source,
  required List<double> domain,
  required List<double> range,
}) {
  if (domain.isEmpty || domain.length.isOdd) {
    throw ArgumentError('Domain must contain min/max pairs.');
  }
  if (range.isEmpty || range.length.isOdd) {
    throw ArgumentError('Range must contain min/max pairs.');
  }
  final program = parsePostScriptFunction(source);
  final inputCount = domain.length ~/ 2;
  final outputCount = range.length ~/ 2;
  return (input) {
    if (input.length != inputCount) {
      throw ArgumentError('Expected $inputCount inputs, got ${input.length}.');
    }
    final stack = <Object>[
      for (var i = 0; i < inputCount; i++)
        input[i].clamp(domain[i * 2], domain[i * 2 + 1]).toDouble(),
    ];
    PostScriptInterpreter.execute(program.children, stack);
    if (stack.length < outputCount) {
      throw StateError('PostScript function produced too few outputs.');
    }
    final offset = stack.length - outputCount;
    return [
      for (var i = 0; i < outputCount; i++)
        _number(stack[offset + i])
            .clamp(range[i * 2], range[i * 2 + 1])
            .toDouble(),
    ];
  };
}

/// Safe stack-based interpreter for the operators allowed by PDF Type 4.
abstract final class PostScriptInterpreter {
  static const int maxOperations = 100000;
  static const int maxStackSize = 10000;

  static void execute(List<PsNode> nodes, List<Object> stack) {
    var operations = 0;
    void run(List<PsNode> body) {
      for (final node in body) {
        if (++operations > maxOperations) {
          throw StateError('PostScript operation limit exceeded.');
        }
        if (node is PsNumber) {
          _push(stack, node.value);
        } else if (node is PsIf) {
          if (_boolean(_pop(stack))) run(node.body.children);
        } else if (node is PsIfElse) {
          run(_boolean(_pop(stack))
              ? node.thenBody.children
              : node.elseBody.children);
        } else if (node is PsOperator) {
          _operator(node.operator, stack);
        } else {
          throw StateError('Unexpected AST node ${node.runtimeType}.');
        }
      }
    }

    run(nodes);
  }

  static void _operator(int operator, List<Object> stack) {
    switch (operator) {
      case TOKEN.trueToken:
        return _push(stack, true);
      case TOKEN.falseToken:
        return _push(stack, false);
      case TOKEN.add:
        return _numericBinary(stack, (a, b) => a + b);
      case TOKEN.sub:
        return _numericBinary(stack, (a, b) => a - b);
      case TOKEN.mul:
        return _numericBinary(stack, (a, b) => a * b);
      case TOKEN.div:
        return _numericBinary(stack, (a, b) => b == 0 ? 0 : a / b);
      case TOKEN.idiv:
        return _numericBinary(
            stack, (a, b) => b == 0 ? 0 : (a / b).truncateToDouble());
      case TOKEN.mod:
        return _numericBinary(stack, (a, b) => b == 0 ? 0 : a.remainder(b));
      case TOKEN.exp:
        return _numericBinary(stack, (a, b) => math.pow(a, b).toDouble());
      case TOKEN.eq:
        return _compare(stack, (a, b) => a == b);
      case TOKEN.ne:
        return _compare(stack, (a, b) => a != b);
      case TOKEN.gt:
        return _numericCompare(stack, (a, b) => a > b);
      case TOKEN.ge:
        return _numericCompare(stack, (a, b) => a >= b);
      case TOKEN.lt:
        return _numericCompare(stack, (a, b) => a < b);
      case TOKEN.le:
        return _numericCompare(stack, (a, b) => a <= b);
      case TOKEN.and:
        return _logicalBinary(stack, (a, b) => a & b, (a, b) => a && b);
      case TOKEN.or:
        return _logicalBinary(stack, (a, b) => a | b, (a, b) => a || b);
      case TOKEN.xor:
        return _logicalBinary(stack, (a, b) => a ^ b, (a, b) => a != b);
      case TOKEN.bitshift:
        final shift = _integer(_pop(stack));
        final value = _integer(_pop(stack));
        return _push(stack, shift >= 0 ? value << shift : value >> -shift);
      case TOKEN.abs:
        return _unaryNumber(stack, (a) => a.abs());
      case TOKEN.neg:
        return _unaryNumber(stack, (a) => -a);
      case TOKEN.ceiling:
        return _unaryNumber(stack, (a) => a.ceilToDouble());
      case TOKEN.floor:
        return _unaryNumber(stack, (a) => a.floorToDouble());
      case TOKEN.round:
        return _unaryNumber(stack, (a) => (a + .5).floorToDouble());
      case TOKEN.truncate:
      case TOKEN.cvi:
        return _unaryNumber(stack, (a) => a.truncateToDouble());
      case TOKEN.cvr:
        return _unaryNumber(stack, (a) => a);
      case TOKEN.not:
        final value = _pop(stack);
        return _push(stack, value is bool ? !value : ~_integer(value));
      case TOKEN.sqrt:
        return _unaryNumber(stack, math.sqrt);
      case TOKEN.sin:
        return _unaryNumber(stack, (a) => math.sin(_radians(a)));
      case TOKEN.cos:
        return _unaryNumber(stack, (a) => math.cos(_radians(a)));
      case TOKEN.ln:
        return _unaryNumber(stack, math.log);
      case TOKEN.log:
        return _unaryNumber(stack, (a) => math.log(a) / math.ln10);
      case TOKEN.atan:
        final denominator = _number(_pop(stack));
        final numerator = _number(_pop(stack));
        var degrees = math.atan2(numerator, denominator) * 180 / math.pi;
        if (degrees < 0) degrees += 360;
        return _push(stack, degrees);
      case TOKEN.dup:
        if (stack.isEmpty) _underflow();
        return _push(stack, stack.last);
      case TOKEN.exch:
        if (stack.length < 2) _underflow();
        final top = stack.removeLast();
        final below = stack.removeLast();
        stack
          ..add(top)
          ..add(below);
        return;
      case TOKEN.pop:
        _pop(stack);
        return;
      case TOKEN.copy:
        final count = _integer(_pop(stack));
        if (count < 0 || count > stack.length) _range('copy', count);
        final values = stack.sublist(stack.length - count);
        for (final value in values) _push(stack, value);
        return;
      case TOKEN.index:
        final index = _integer(_pop(stack));
        if (index < 0 || index >= stack.length) _range('index', index);
        return _push(stack, stack[stack.length - index - 1]);
      case TOKEN.roll:
        var shift = _integer(_pop(stack));
        final count = _integer(_pop(stack));
        if (count < 0 || count > stack.length) _range('roll', count);
        if (count == 0) return;
        shift %= count;
        if (shift < 0) shift += count;
        final start = stack.length - count;
        final values = stack.sublist(start);
        stack.replaceRange(start, stack.length, [
          ...values.sublist(count - shift),
          ...values.sublist(0, count - shift)
        ]);
        return;
      default:
        throw UnsupportedError('Unsupported PostScript operator $operator.');
    }
  }

  static void _numericBinary(
      List<Object> stack, double Function(double, double) op) {
    final right = _number(_pop(stack));
    final left = _number(_pop(stack));
    _push(stack, op(left, right));
  }

  static void _unaryNumber(List<Object> stack, double Function(double) op) {
    _push(stack, op(_number(_pop(stack))));
  }

  static void _compare(List<Object> stack, bool Function(Object, Object) op) {
    final right = _pop(stack);
    final left = _pop(stack);
    _push(stack, op(left, right));
  }

  static void _numericCompare(
      List<Object> stack, bool Function(double, double) op) {
    final right = _number(_pop(stack));
    final left = _number(_pop(stack));
    _push(stack, op(left, right));
  }

  static void _logicalBinary(List<Object> stack, int Function(int, int) integer,
      bool Function(bool, bool) boolean) {
    final right = _pop(stack);
    final left = _pop(stack);
    if (left is bool && right is bool) {
      _push(stack, boolean(left, right));
    } else {
      _push(stack, integer(_integer(left), _integer(right)));
    }
  }

  static Object _pop(List<Object> stack) {
    if (stack.isEmpty) _underflow();
    return stack.removeLast();
  }

  static void _push(List<Object> stack, Object value) {
    if (stack.length >= maxStackSize)
      throw StateError('PostScript stack overflow.');
    stack.add(value);
  }

  static Never _underflow() => throw StateError('PostScript stack underflow.');
  static Never _range(String op, int value) =>
      throw RangeError('Invalid $op operand: $value.');
}

double _number(Object value) {
  if (value is num) return value.toDouble();
  throw StateError('Expected a number, got $value.');
}

int _integer(Object value) => _number(value).toInt();

bool _boolean(Object value) {
  if (value is bool) return value;
  throw StateError('Expected a boolean, got $value.');
}

double _radians(double degrees) => (degrees % 360) * math.pi / 180;
