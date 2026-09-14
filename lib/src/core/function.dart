// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;
import 'dart:typed_data';

import '../shared/math_clamp.dart';
import '../shared/util.dart';
import 'base_stream.dart';
import 'image_utils.dart';
import 'postscript/evaluator.dart' as postscript;
import 'primitives.dart';

abstract class FunctionType {
  static const int sampled = 0;
  static const int exponentialInterpolation = 2;
  static const int stitching = 3;
  static const int postscriptCalculator = 4;
}

typedef PDFFunctionEvaluator = void Function(
  List<num> src,
  int srcOffset,
  List<num> dest,
  int destOffset,
);

class PDFFunctionFactory {
  PDFFunctionFactory({required this.xref});

  final dynamic xref;
  final LocalFunctionCache _localFunctionCache = LocalFunctionCache();

  static bool useWasm = false;

  static void setOptions({bool useWasm = false}) {
    PDFFunctionFactory.useWasm = useWasm;
  }

  PDFFunctionEvaluator create(dynamic fn, [bool parseArray = false]) {
    Ref? fnRef;

    if (fn is Ref) {
      fnRef = fn;
    } else if (fn is Dict) {
      fnRef = fn.objId;
    } else if (fn is BaseStream) {
      fnRef = fn.dict?.objId;
    }

    if (fnRef != null) {
      final cachedFn = _localFunctionCache.getByRef(fnRef);
      if (cachedFn is PDFFunctionEvaluator) {
        return cachedFn;
      }
    }

    final dynamic fnObj = xref?.fetchIfRef(fn) ?? fn;
    PDFFunctionEvaluator parsedFn;
    if (fnObj is List) {
      if (!parseArray) {
        throw ArgumentError(
          'PDFFunctionFactory.create - expected "parseArray" argument.',
        );
      }
      parsedFn = PDFFunction.parseArray(this, fnObj);
    } else {
      parsedFn = PDFFunction.parse(this, fnObj);
    }

    if (fnRef != null) {
      _localFunctionCache.set(null, fnRef, parsedFn);
    }
    return parsedFn;
  }
}

List<num>? _toNumberArray(dynamic arr) {
  if (arr is! List) {
    return null;
  }
  return arr
      .map((x) => x is num ? x : num.tryParse(x.toString()) ?? 0)
      .toList();
}

class PDFFunction {
  static List<num> getSampleArray(
    List<num> size,
    int outputSize,
    int bps,
    dynamic stream,
  ) {
    var length = outputSize;
    for (final s in size) {
      length *= s.toInt();
    }

    final array = List<num>.filled(length, 0);
    var codeSize = 0;
    var codeBuf = 0;
    final sampleMul = 1.0 / (math.pow(2.0, bps) - 1);

    final numBytes = ((length * bps + 7) / 8).floor();
    final strBytes = (stream as BaseStream).getBytes(numBytes);
    var strIdx = 0;

    for (var i = 0; i < length; i++) {
      while (codeSize < bps) {
        codeBuf <<= 8;
        if (strIdx < strBytes.length) {
          codeBuf |= strBytes[strIdx++];
        }
        codeSize += 8;
      }
      codeSize -= bps;
      array[i] = (codeBuf >> codeSize) * sampleMul;
      codeBuf &= (1 << codeSize) - 1;
    }
    return array;
  }

  static PDFFunctionEvaluator parse(PDFFunctionFactory factory, dynamic fn) {
    final Dict dict = fn is BaseStream ? (fn.dict ?? Dict(null)) : (fn as Dict);
    final dynamic typeNum = dict.get('FunctionType');

    switch (typeNum) {
      case FunctionType.sampled:
        return constructSampled(factory, fn, dict);
      case FunctionType.exponentialInterpolation:
        return constructInterpolated(factory, dict);
      case FunctionType.stitching:
        return constructStitched(factory, dict);
      case FunctionType.postscriptCalculator:
        return constructPostScript(factory, fn, dict);
      default:
        throw FormatError('Unknown function type: $typeNum');
    }
  }

  static PDFFunctionEvaluator parseArray(
    PDFFunctionFactory factory,
    List<dynamic> fnObj,
  ) {
    final xref = factory.xref;
    final fnArray = <PDFFunctionEvaluator>[];
    for (final fn in fnObj) {
      fnArray.add(parse(factory, xref?.fetchIfRef(fn) ?? fn));
    }

    return (List<num> src, int srcOffset, List<num> dest, int destOffset) {
      for (var i = 0; i < fnArray.length; i++) {
        fnArray[i](src, srcOffset, dest, destOffset + i);
      }
    };
  }

  static PDFFunctionEvaluator constructSampled(
    PDFFunctionFactory factory,
    dynamic fn,
    Dict dict,
  ) {
    double interpolate(num x, num xmin, num xmax, num ymin, num ymax) {
      if (xmax == xmin) return ymin.toDouble();
      return ymin + (x - xmin) * ((ymax - ymin) / (xmax - xmin));
    }

    final domain = _toNumberArray(dict.getArray('Domain'));
    final range = _toNumberArray(dict.getArray('Range'));

    if (domain == null || range == null) {
      throw FormatError('No domain or range in sampled function');
    }

    final inputSize = domain.length ~/ 2;
    final outputSize = range.length ~/ 2;

    final size = _toNumberArray(dict.getArray('Size'))!;
    final bps = (dict.get('BitsPerSample') as num).toInt();

    final List<num> encode = _toNumberArray(dict.getArray('Encode')) ??
        [
          for (var i = 0; i < inputSize; ++i) ...[0, size[i] - 1],
        ];

    final decode = _toNumberArray(dict.getArray('Decode')) ?? range;
    final samples = getSampleArray(size, outputSize, bps, fn);

    return (List<num> src, int srcOffset, List<num> dest, int destOffset) {
      final cubeVertices = 1 << inputSize;
      final cubeN = Float64List(cubeVertices)..fillRange(0, cubeVertices, 1.0);
      final cubeVertex = Uint32List(cubeVertices);

      var k = outputSize;
      var pos = 1;

      for (var i = 0; i < inputSize; ++i) {
        final domain2i = domain[2 * i];
        final domain2i1 = domain[2 * i + 1];
        final xi = mathClamp(src[srcOffset + i], domain2i, domain2i1);

        var e = interpolate(
          xi,
          domain2i,
          domain2i1,
          encode[2 * i],
          encode[2 * i + 1],
        );

        final sizeI = size[i];
        e = mathClamp(e, 0, sizeI - 1).toDouble();

        final e0 = e < sizeI - 1 ? e.floor() : (e - 1).toInt();
        final n0 = e0 + 1 - e;
        final n1 = e - e0;
        final offset0 = e0 * k;
        final offset1 = offset0 + k;

        for (var j = 0; j < cubeVertices; j++) {
          if ((j & pos) != 0) {
            cubeN[j] *= n1;
            cubeVertex[j] += offset1;
          } else {
            cubeN[j] *= n0;
            cubeVertex[j] += offset0;
          }
        }

        k *= sizeI.toInt();
        pos <<= 1;
      }

      for (var j = 0; j < outputSize; ++j) {
        var rj = 0.0;
        for (var i = 0; i < cubeVertices; i++) {
          rj += samples[cubeVertex[i] + j] * cubeN[i];
        }

        rj = interpolate(rj, 0, 1, decode[2 * j], decode[2 * j + 1]);
        dest[destOffset + j] = mathClamp(rj, range[2 * j], range[2 * j + 1]);
      }
    };
  }

  static PDFFunctionEvaluator constructInterpolated(
    PDFFunctionFactory factory,
    Dict dict,
  ) {
    final c0 = _toNumberArray(dict.getArray('C0')) ?? [0.0];
    final c1 = _toNumberArray(dict.getArray('C1')) ?? [1.0];
    final n = (dict.get('N') as num?)?.toDouble() ?? 1.0;

    final diff = <num>[];
    for (var i = 0; i < c0.length; ++i) {
      diff.add(c1[i] - c0[i]);
    }
    final length = diff.length;

    return (List<num> src, int srcOffset, List<num> dest, int destOffset) {
      final xVal = src[srcOffset];
      final x = n == 1 ? xVal : math.pow(xVal, n);

      for (var j = 0; j < length; ++j) {
        dest[destOffset + j] = c0[j] + x * diff[j];
      }
    };
  }

  static PDFFunctionEvaluator constructStitched(
    PDFFunctionFactory factory,
    Dict dict,
  ) {
    final domain = _toNumberArray(dict.getArray('Domain'));
    if (domain == null) {
      throw FormatError('No domain in stitched function');
    }

    final inputSize = domain.length ~/ 2;
    if (inputSize != 1) {
      throw FormatError('Bad domain for stitched function');
    }

    final xref = factory.xref;
    final fns = <PDFFunctionEvaluator>[];
    final functionsArray = dict.get('Functions');
    if (functionsArray is List) {
      for (final fn in functionsArray) {
        fns.add(parse(factory, xref?.fetchIfRef(fn) ?? fn));
      }
    }

    final bounds = _toNumberArray(dict.getArray('Bounds')) ?? [];
    final encode = _toNumberArray(dict.getArray('Encode')) ?? [];
    final tmpBuf = Float32List(1);

    return (List<num> src, int srcOffset, List<num> dest, int destOffset) {
      final v = mathClamp(src[srcOffset], domain[0], domain[1]);
      final length = bounds.length;
      var i = 0;
      for (; i < length; ++i) {
        if (v < bounds[i]) {
          break;
        }
      }

      final dmin = i > 0 ? bounds[i - 1] : domain[0];
      final dmax = i < length ? bounds[i] : domain[1];

      final rmin = encode[2 * i];
      final rmax = encode[2 * i + 1];

      tmpBuf[0] = dmin == dmax
          ? rmin.toDouble()
          : (rmin + ((v - dmin) * (rmax - rmin)) / (dmax - dmin)).toDouble();

      fns[i](tmpBuf, 0, dest, destOffset);
    };
  }

  static PDFFunctionEvaluator constructPostScript(
    PDFFunctionFactory factory,
    dynamic fn,
    Dict dict,
  ) {
    final domain = _toNumberArray(dict.getArray('Domain'));
    final range = _toNumberArray(dict.getArray('Range'));

    if (domain == null || range == null) {
      throw FormatError('PostScript function requires Domain and Range');
    }

    final psCode = fn is BaseStream ? fn.getString() : '';
    final evaluator = postscript.buildPostScriptFunction(
      source: psCode,
      domain: domain.map((value) => value.toDouble()).toList(),
      range: range.map((value) => value.toDouble()).toList(),
    );
    final inputCount = domain.length ~/ 2;
    final outputCount = range.length ~/ 2;
    return (src, srcOffset, dest, destOffset) {
      final output = evaluator([
        for (var i = 0; i < inputCount; i++) src[srcOffset + i].toDouble(),
      ]);
      for (var i = 0; i < outputCount; i++) {
        dest[destOffset + i] = output[i];
      }
    };
  }
}

// Kept temporarily as a compatibility baseline while the new AST evaluator
// is exercised against the full reference suite.
// ignore: unused_element
PDFFunctionEvaluator _buildPostScriptEvaluator(
  String code,
  List<num> domain,
  List<num> range,
) {
  // Tokenize the PostScript snippet
  final tokens = <String>[];
  final buffer = StringBuffer();

  for (var i = 0; i < code.length; i++) {
    final char = code[i];
    if (char == '{') {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
      tokens.add('{');
    } else if (char == '}') {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
      tokens.add('}');
    } else if (char.trim().isEmpty) {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
    } else {
      buffer.write(char);
    }
  }
  if (buffer.isNotEmpty) {
    tokens.add(buffer.toString());
  }

  var mainTokens = tokens;
  while (mainTokens.length >= 2 &&
      mainTokens.first == '{' &&
      mainTokens.last == '}') {
    mainTokens = mainTokens.sublist(1, mainTokens.length - 1);
  }

  final inputCount = domain.length ~/ 2;
  final outputCount = range.length ~/ 2;

  return (List<num> src, int srcOffset, List<num> dest, int destOffset) {
    final stack = <dynamic>[];

    // Push clamped inputs
    for (var i = 0; i < inputCount; i++) {
      final val =
          mathClamp(src[srcOffset + i], domain[2 * i], domain[2 * i + 1]);
      stack.add(val.toDouble());
    }

    void executeTokens(List<String> tks) {
      var idx = 0;
      while (idx < tks.length) {
        final token = tks[idx++];
        final numVal = num.tryParse(token);
        if (numVal != null) {
          stack.add(numVal.toDouble());
          continue;
        }

        switch (token) {
          case 'true':
            stack.add(true);
            break;
          case 'false':
            stack.add(false);
            break;
          case 'abs':
            final a = (stack.removeLast() as num).abs();
            stack.add(a.toDouble());
            break;
          case 'neg':
            final a = -(stack.removeLast() as num);
            stack.add(a.toDouble());
            break;
          case 'ceiling':
            final a = (stack.removeLast() as num).ceilToDouble();
            stack.add(a);
            break;
          case 'floor':
            final a = (stack.removeLast() as num).floorToDouble();
            stack.add(a);
            break;
          case 'round':
            final a = (stack.removeLast() as num).roundToDouble();
            stack.add(a);
            break;
          case 'truncate':
            final a = (stack.removeLast() as num).truncateToDouble();
            stack.add(a);
            break;
          case 'sqrt':
            final a = math.sqrt((stack.removeLast() as num).toDouble());
            stack.add(a);
            break;
          case 'sin':
            final deg = (stack.removeLast() as num).toDouble();
            stack.add(math.sin(deg * (math.pi / 180.0)));
            break;
          case 'cos':
            final deg = (stack.removeLast() as num).toDouble();
            stack.add(math.cos(deg * (math.pi / 180.0)));
            break;
          case 'ln':
            final a = math.log((stack.removeLast() as num).toDouble());
            stack.add(a);
            break;
          case 'log':
            final a =
                math.log((stack.removeLast() as num).toDouble()) / math.ln10;
            stack.add(a);
            break;
          case 'add':
            final b = stack.removeLast() as num;
            final a = stack.removeLast() as num;
            stack.add((a + b).toDouble());
            break;
          case 'sub':
            final b = stack.removeLast() as num;
            final a = stack.removeLast() as num;
            stack.add((a - b).toDouble());
            break;
          case 'mul':
            final b = stack.removeLast() as num;
            final a = stack.removeLast() as num;
            stack.add((a * b).toDouble());
            break;
          case 'div':
            final b = stack.removeLast() as num;
            final a = stack.removeLast() as num;
            stack.add(b == 0 ? 0.0 : (a / b).toDouble());
            break;
          case 'idiv':
            final b = (stack.removeLast() as num).toInt();
            final a = (stack.removeLast() as num).toInt();
            stack.add(b == 0 ? 0.0 : (a ~/ b).toDouble());
            break;
          case 'mod':
            final b = (stack.removeLast() as num).toInt();
            final a = (stack.removeLast() as num).toInt();
            stack.add(b == 0 ? 0.0 : (a % b).toDouble());
            break;
          case 'exp':
            final b = stack.removeLast() as num;
            final a = stack.removeLast() as num;
            stack.add(math.pow(a, b).toDouble());
            break;
          case 'pop':
            if (stack.isNotEmpty) stack.removeLast();
            break;
          case 'dup':
            if (stack.isNotEmpty) stack.add(stack.last);
            break;
          case 'exch':
            if (stack.length >= 2) {
              final b = stack.removeLast();
              final a = stack.removeLast();
              stack.add(b);
              stack.add(a);
            }
            break;
          case 'index':
            final n = (stack.removeLast() as num).toInt();
            if (n >= 0 && n < stack.length) {
              stack.add(stack[stack.length - 1 - n]);
            }
            break;
          case 'roll':
            final j = (stack.removeLast() as num).toInt();
            final n = (stack.removeLast() as num).toInt();
            if (n > 0 && stack.length >= n) {
              final sub = stack.sublist(stack.length - n);
              stack.length -= n;
              final rot = j % n;
              final rolled = <dynamic>[
                ...sub.sublist(sub.length - rot),
                ...sub.sublist(0, sub.length - rot),
              ];
              stack.addAll(rolled);
            }
            break;
          case 'eq':
            final b = stack.removeLast();
            final a = stack.removeLast();
            stack.add(a == b);
            break;
          case 'ne':
            final b = stack.removeLast();
            final a = stack.removeLast();
            stack.add(a != b);
            break;
          case 'gt':
            final b = stack.removeLast() as num;
            final a = stack.removeLast() as num;
            stack.add(a > b);
            break;
          case 'ge':
            final b = stack.removeLast() as num;
            final a = stack.removeLast() as num;
            stack.add(a >= b);
            break;
          case 'lt':
            final b = stack.removeLast() as num;
            final a = stack.removeLast() as num;
            stack.add(a < b);
            break;
          case 'le':
            final b = stack.removeLast() as num;
            final a = stack.removeLast() as num;
            stack.add(a <= b);
            break;
          case 'not':
            final a = stack.removeLast();
            if (a is bool) {
              stack.add(!a);
            } else if (a is num) {
              stack.add((~(a.toInt())).toDouble());
            }
            break;
          case 'and':
            final b = stack.removeLast();
            final a = stack.removeLast();
            if (a is bool && b is bool) {
              stack.add(a && b);
            } else if (a is num && b is num) {
              stack.add(((a.toInt()) & (b.toInt())).toDouble());
            }
            break;
          case 'or':
            final b = stack.removeLast();
            final a = stack.removeLast();
            if (a is bool && b is bool) {
              stack.add(a || b);
            } else if (a is num && b is num) {
              stack.add(((a.toInt()) | (b.toInt())).toDouble());
            }
            break;
          case 'xor':
            final b = stack.removeLast();
            final a = stack.removeLast();
            if (a is bool && b is bool) {
              stack.add(a ^ b);
            } else if (a is num && b is num) {
              stack.add(((a.toInt()) ^ (b.toInt())).toDouble());
            }
            break;
          case '{':
            // Collect code block until matching '}'
            final block = <String>[];
            var depth = 1;
            while (idx < tks.length && depth > 0) {
              final tk = tks[idx++];
              if (tk == '{') depth++;
              if (tk == '}') depth--;
              if (depth > 0) block.add(tk);
            }
            stack.add(block);
            break;
          case 'if':
            final block = stack.removeLast() as List<String>;
            final cond = stack.removeLast() as bool;
            if (cond) {
              executeTokens(block);
            }
            break;
          case 'ifelse':
            final block2 = stack.removeLast() as List<String>;
            final block1 = stack.removeLast() as List<String>;
            final cond = stack.removeLast() as bool;
            if (cond) {
              executeTokens(block1);
            } else {
              executeTokens(block2);
            }
            break;
        }
      }
    }

    executeTokens(mainTokens);

    // Populate outputs clamped to range
    for (var i = outputCount - 1; i >= 0; i--) {
      final val = stack.isNotEmpty ? (stack.removeLast() as num) : 0.0;
      dest[destOffset + i] = mathClamp(val, range[2 * i], range[2 * i + 1]);
    }
  };
}

bool isPDFFunction(dynamic v) {
  Dict? fnDict;
  if (v is Dict) {
    fnDict = v;
  } else if (v is BaseStream) {
    fnDict = v.dict;
  } else {
    return false;
  }
  return fnDict?.has('FunctionType') == true;
}
