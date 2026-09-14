// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../core/operator_list.dart';
import '../shared/util.dart';
import 'pdf_objects.dart';

/// Mutable PDF graphics state used by [CanvasGraphics].
///
/// Canvas itself keeps path, clipping and paint state. This object contains the
/// PDF-specific text state which has no direct Canvas 2D equivalent.
class CanvasExtraState {
  double charSpacing;
  double wordSpacing;
  double textHScale;
  double leading;
  double fontSize;
  String fontFamily;
  int textRenderingMode;
  double textRise;
  List<double> textMatrix;
  double textLineX;
  double textLineY;
  double x;
  double y;

  CanvasExtraState({
    this.charSpacing = 0,
    this.wordSpacing = 0,
    this.textHScale = 1,
    this.leading = 0,
    this.fontSize = 0,
    this.fontFamily = 'sans-serif',
    this.textRenderingMode = TextRenderingMode.fill,
    this.textRise = 0,
    List<double>? textMatrix,
    this.textLineX = 0,
    this.textLineY = 0,
    this.x = 0,
    this.y = 0,
  }) : textMatrix = textMatrix ?? <double>[1, 0, 0, 1, 0, 0];

  CanvasExtraState clone() => CanvasExtraState(
        charSpacing: charSpacing,
        wordSpacing: wordSpacing,
        textHScale: textHScale,
        leading: leading,
        fontSize: fontSize,
        fontFamily: fontFamily,
        textRenderingMode: textRenderingMode,
        textRise: textRise,
        textMatrix: List<double>.from(textMatrix),
        textLineX: textLineX,
        textLineY: textLineY,
        x: x,
        y: y,
      );
}

class _CanvasGroupState {
  final web.CanvasRenderingContext2D parent;
  final web.HTMLCanvasElement canvas;
  final double offsetX;
  final double offsetY;
  final double alpha;
  final String composite;

  const _CanvasGroupState(this.parent, this.canvas, this.offsetX, this.offsetY,
      this.alpha, this.composite);
}

class _AnnotationState {
  final int stackDepth;
  const _AnnotationState(this.stackDepth);
}

/// Executes PDF.js operator lists against a browser Canvas 2D context.
///
/// This is intentionally the small, dependable rendering core. It covers the
/// operators emitted for ordinary text, vector paths and raster images while
/// leaving patterns, soft masks and transparency groups for later layers.
class CanvasGraphics {
  web.CanvasRenderingContext2D ctx;
  final PDFObjects commonObjs;
  final PDFObjects objs;
  CanvasExtraState current = CanvasExtraState();
  final List<CanvasExtraState> _stateStack = <CanvasExtraState>[];
  int? _pendingClip;
  double _currentX = 0;
  double _currentY = 0;
  final List<_CanvasGroupState> _groupStack = <_CanvasGroupState>[];
  final List<_AnnotationState> _annotationStack = <_AnnotationState>[];

  CanvasGraphics(
    this.ctx, {
    PDFObjects? commonObjs,
    PDFObjects? objs,
  })  : commonObjs = commonObjs ?? PDFObjects(),
        objs = objs ?? PDFObjects();

  void beginDrawing({
    List<num>? transform,
    List<num>? viewportTransform,
    String background = '#ffffff',
  }) {
    final oldFill = ctx.fillStyle;
    ctx.save();
    ctx.resetTransform();
    ctx.fillStyle = background.toJS;
    ctx.fillRect(0, 0, ctx.canvas.width, ctx.canvas.height);
    ctx.fillStyle = oldFill;
    if (transform != null) _transformList(transform);
    if (viewportTransform != null) _transformList(viewportTransform);
    ctx.beginPath();
  }

  void endDrawing() {
    while (_stateStack.isNotEmpty) {
      restore();
    }
    ctx.restore();
  }

  /// Runs an [OperatorList] or a serialized operator-list map.
  int executeOperatorList(
    dynamic operatorList, {
    int startIndex = 0,
    bool Function(int index)? operationsFilter,
  }) {
    final List<int> functions;
    final List<dynamic> arguments;
    if (operatorList is OperatorList) {
      functions = operatorList.fnArray;
      arguments = operatorList.argsArray;
    } else if (operatorList is Map) {
      functions = List<int>.from(operatorList['fnArray'] as Iterable);
      arguments = List<dynamic>.from(operatorList['argsArray'] as Iterable);
    } else {
      throw ArgumentError.value(operatorList, 'operatorList');
    }
    if (functions.length != arguments.length) {
      throw StateError('Operator and argument arrays have different lengths.');
    }
    for (var index = startIndex; index < functions.length; index++) {
      if (operationsFilter?.call(index) == false) continue;
      _execute(functions[index], _args(arguments[index]));
    }
    return functions.length;
  }

  List<dynamic> _args(dynamic value) {
    if (value == null) return const <dynamic>[];
    if (value is List<dynamic>) return value;
    if (value is Iterable) return List<dynamic>.from(value);
    return <dynamic>[value];
  }

  void _execute(int op, List<dynamic> a) {
    switch (op) {
      case OPS.dependency:
        return;
      case OPS.save:
        save();
      case OPS.restore:
        restore();
      case OPS.transform:
        transform(a);
      case OPS.setLineWidth:
        setLineWidth(a[0]);
      case OPS.setLineCap:
        setLineCap(a[0]);
      case OPS.setLineJoin:
        setLineJoin(a[0]);
      case OPS.setMiterLimit:
        setMiterLimit(a[0]);
      case OPS.setDash:
        setDash(a[0], a.length > 1 ? a[1] : 0);
      case OPS.setGState:
        setGState(a[0]);
      case OPS.moveTo:
        moveTo(a[0], a[1]);
      case OPS.lineTo:
        lineTo(a[0], a[1]);
      case OPS.curveTo:
        curveTo(a[0], a[1], a[2], a[3], a[4], a[5]);
      case OPS.curveTo2:
        curveTo2(a[0], a[1], a[2], a[3]);
      case OPS.curveTo3:
        curveTo3(a[0], a[1], a[2], a[3]);
      case OPS.closePath:
        closePath();
      case OPS.rectangle:
        rectangle(a[0], a[1], a[2], a[3]);
      case OPS.stroke:
        stroke();
      case OPS.closeStroke:
        closeStroke();
      case OPS.fill:
        fill();
      case OPS.eoFill:
        eoFill();
      case OPS.fillStroke:
        fillStroke();
      case OPS.eoFillStroke:
        eoFillStroke();
      case OPS.closeFillStroke:
        closeFillStroke();
      case OPS.closeEOFillStroke:
        closeEOFillStroke();
      case OPS.endPath:
        endPath();
      case OPS.clip:
        clip();
      case OPS.eoClip:
        eoClip();
      case OPS.constructPath:
        constructPath(a);
      case OPS.rawFillPath:
        rawFillPath(a);
      case OPS.setStrokeGray:
        setStrokeGray(a[0]);
      case OPS.setFillGray:
        setFillGray(a[0]);
      case OPS.setStrokeRGBColor:
        setStrokeRGBColor(a[0], a[1], a[2]);
      case OPS.setFillRGBColor:
        setFillRGBColor(a[0], a[1], a[2]);
      case OPS.setStrokeCMYKColor:
        setStrokeCMYKColor(a[0], a[1], a[2], a[3]);
      case OPS.setFillCMYKColor:
        setFillCMYKColor(a[0], a[1], a[2], a[3]);
      case OPS.setStrokeTransparent:
        ctx.strokeStyle = 'rgba(0,0,0,0)'.toJS;
      case OPS.setFillTransparent:
        ctx.fillStyle = 'rgba(0,0,0,0)'.toJS;
      case OPS.beginText:
        beginText();
      case OPS.endText:
        endText();
      case OPS.setCharSpacing:
        current.charSpacing = _number(a[0]);
      case OPS.setWordSpacing:
        current.wordSpacing = _number(a[0]);
      case OPS.setHScale:
        current.textHScale = _number(a[0]) / 100;
      case OPS.setLeading:
        current.leading = _number(a[0]);
      case OPS.setFont:
        setFont(a[0], a[1]);
      case OPS.setTextRenderingMode:
        current.textRenderingMode = (a[0] as num).toInt();
      case OPS.setTextRise:
        current.textRise = _number(a[0]);
      case OPS.moveText:
        moveText(a[0], a[1]);
      case OPS.setLeadingMoveText:
        setLeadingMoveText(a[0], a[1]);
      case OPS.setTextMatrix:
        setTextMatrix(a);
      case OPS.nextLine:
        nextLine();
      case OPS.showText:
        showText(a.isEmpty ? '' : a[0]);
      case OPS.showSpacedText:
        showSpacedText(a.isEmpty ? const [] : a[0]);
      case OPS.nextLineShowText:
        nextLine();
        showText(a[0]);
      case OPS.nextLineSetSpacingShowText:
        current.wordSpacing = _number(a[0]);
        current.charSpacing = _number(a[1]);
        nextLine();
        showText(a[2]);
      case OPS.paintImageXObject:
      case OPS.paintInlineImageXObject:
        paintImageXObject(a[0]);
      case OPS.paintImageXObjectRepeat:
        paintImageXObjectRepeat(a);
      case OPS.paintImageMaskXObject:
        paintImageMaskXObject(a[0]);
      case OPS.paintImageMaskXObjectRepeat:
        paintImageMaskXObjectRepeat(a);
      case OPS.paintImageMaskXObjectGroup:
        paintImageMaskXObjectGroup(a[0]);
      case OPS.paintSolidColorImageMask:
        ctx.fillRect(0, 0, 1, 1);
      case OPS.beginGroup:
        beginGroup(a.isEmpty ? const <String, dynamic>{} : a.last);
      case OPS.endGroup:
        endGroup(a.isEmpty ? const <String, dynamic>{} : a.last);
      case OPS.beginAnnotation:
        beginAnnotation(a);
      case OPS.endAnnotation:
        endAnnotation();
      case OPS.paintFormXObjectBegin:
        save();
        if (a.isNotEmpty && a[0] is List) transform(a[0]);
      case OPS.paintFormXObjectEnd:
        restore();
      case OPS.beginCompat:
      case OPS.endCompat:
      case OPS.markPoint:
      case OPS.markPointProps:
      case OPS.beginMarkedContent:
      case OPS.beginMarkedContentProps:
      case OPS.endMarkedContent:
        return;
      default:
        // Unknown advanced operators are ignored here so a basic page remains
        // renderable. The full renderer can layer those operations later.
        return;
    }
  }

  void save() {
    ctx.save();
    _stateStack.add(current);
    current = current.clone();
  }

  void restore() {
    if (_stateStack.isEmpty) return;
    _consumePath();
    ctx.restore();
    current = _stateStack.removeLast();
  }

  void transform(List<dynamic> values) => _transformList(values);

  void _transformList(List<dynamic> m) {
    if (m.length < 6) throw ArgumentError('A transform needs six values.');
    ctx.transform(
      _number(m[0]),
      _number(m[1]),
      _number(m[2]),
      _number(m[3]),
      _number(m[4]),
      _number(m[5]),
    );
  }

  void setLineWidth(dynamic width) => ctx.lineWidth = _number(width);

  void setLineCap(dynamic style) {
    const values = <String>['butt', 'round', 'square'];
    ctx.lineCap = style is num ? values[style.toInt().clamp(0, 2)] : '$style';
  }

  void setLineJoin(dynamic style) {
    const values = <String>['miter', 'round', 'bevel'];
    ctx.lineJoin = style is num ? values[style.toInt().clamp(0, 2)] : '$style';
  }

  void setMiterLimit(dynamic limit) => ctx.miterLimit = _number(limit);

  void setDash(dynamic dashArray, dynamic dashPhase) {
    final values = dashArray is Iterable ? dashArray : const <dynamic>[];
    ctx.setLineDash(values.map((v) => _number(v).toJS).toList().toJS);
    ctx.lineDashOffset = _number(dashPhase);
  }

  void setGState(dynamic states) {
    if (states is! Iterable) return;
    for (final entry in states) {
      if (entry is! List || entry.length < 2) continue;
      final key = entry[0].toString();
      final value = entry[1];
      switch (key) {
        case 'LW':
          setLineWidth(value);
        case 'LC':
          setLineCap(value);
        case 'LJ':
          setLineJoin(value);
        case 'ML':
          setMiterLimit(value);
        case 'D':
          if (value is List && value.length >= 2) setDash(value[0], value[1]);
        case 'ca':
        case 'CA':
          ctx.globalAlpha = _number(value).clamp(0, 1);
        case 'BM':
          ctx.globalCompositeOperation = _blendMode(value.toString());
      }
    }
  }

  void moveTo(dynamic x, dynamic y) {
    _currentX = _number(x);
    _currentY = _number(y);
    ctx.moveTo(_currentX, _currentY);
  }

  void lineTo(dynamic x, dynamic y) {
    _currentX = _number(x);
    _currentY = _number(y);
    ctx.lineTo(_currentX, _currentY);
  }

  void curveTo(
      dynamic x1, dynamic y1, dynamic x2, dynamic y2, dynamic x3, dynamic y3) {
    _currentX = _number(x3);
    _currentY = _number(y3);
    ctx.bezierCurveTo(_number(x1), _number(y1), _number(x2), _number(y2),
        _currentX, _currentY);
  }

  void curveTo2(dynamic x2, dynamic y2, dynamic x3, dynamic y3) =>
      curveTo(_currentX, _currentY, x2, y2, x3, y3);

  void curveTo3(dynamic x1, dynamic y1, dynamic x3, dynamic y3) =>
      curveTo(x1, y1, x3, y3, x3, y3);

  void closePath() => ctx.closePath();

  void rectangle(dynamic x, dynamic y, dynamic width, dynamic height) {
    final dx = _number(x), dy = _number(y);
    ctx.rect(dx, dy, _number(width), _number(height));
    _currentX = dx;
    _currentY = dy;
  }

  void clip() => _pendingClip = OPS.clip;
  void eoClip() => _pendingClip = OPS.eoClip;

  void _consumePath() {
    if (_pendingClip == OPS.eoClip) {
      ctx.clip('evenodd'.toJS);
    } else if (_pendingClip == OPS.clip) {
      ctx.clip();
    }
    _pendingClip = null;
    ctx.beginPath();
  }

  void stroke() {
    ctx.stroke();
    _consumePath();
  }

  void closeStroke() {
    ctx.closePath();
    stroke();
  }

  void fill() {
    ctx.fill();
    _consumePath();
  }

  void eoFill() {
    ctx.fill('evenodd'.toJS);
    _consumePath();
  }

  void fillStroke() {
    ctx.fill();
    ctx.stroke();
    _consumePath();
  }

  void eoFillStroke() {
    ctx.fill('evenodd'.toJS);
    ctx.stroke();
    _consumePath();
  }

  void closeFillStroke() {
    ctx.closePath();
    fillStroke();
  }

  void closeEOFillStroke() {
    ctx.closePath();
    eoFillStroke();
  }

  void endPath() => _consumePath();

  void constructPath(List<dynamic> args) {
    if (args.isEmpty) return;
    final ops = List<int>.from(args[0] as Iterable);
    final values =
        args.length > 1 ? List<dynamic>.from(args[1] as Iterable) : <dynamic>[];
    var pos = 0;
    for (final op in ops) {
      switch (op) {
        case OPS.moveTo:
        case DrawOPS.moveTo:
          moveTo(values[pos++], values[pos++]);
        case OPS.lineTo:
        case DrawOPS.lineTo:
          lineTo(values[pos++], values[pos++]);
        case OPS.curveTo:
        case DrawOPS.curveTo:
          curveTo(values[pos++], values[pos++], values[pos++], values[pos++],
              values[pos++], values[pos++]);
        case DrawOPS.quadraticCurveTo:
          ctx.quadraticCurveTo(_number(values[pos++]), _number(values[pos++]),
              _number(values[pos++]), _number(values[pos++]));
        case OPS.closePath:
        case DrawOPS.closePath:
          closePath();
        case OPS.rectangle:
          rectangle(values[pos++], values[pos++], values[pos++], values[pos++]);
      }
    }
  }

  void rawFillPath(List<dynamic> args) {
    constructPath(args);
    fill();
  }

  void setStrokeGray(dynamic gray) => ctx.strokeStyle = _gray(gray).toJS;
  void setFillGray(dynamic gray) => ctx.fillStyle = _gray(gray).toJS;

  void setStrokeRGBColor(dynamic r, dynamic g, dynamic b) =>
      ctx.strokeStyle = _rgb(r, g, b).toJS;
  void setFillRGBColor(dynamic r, dynamic g, dynamic b) =>
      ctx.fillStyle = _rgb(r, g, b).toJS;

  void setStrokeCMYKColor(dynamic c, dynamic m, dynamic y, dynamic k) =>
      ctx.strokeStyle = _cmyk(c, m, y, k).toJS;
  void setFillCMYKColor(dynamic c, dynamic m, dynamic y, dynamic k) =>
      ctx.fillStyle = _cmyk(c, m, y, k).toJS;

  void beginText() {
    current.textMatrix = <double>[1, 0, 0, 1, 0, 0];
    current.textLineX = current.textLineY = current.x = current.y = 0;
  }

  void endText() {}

  void setFont(dynamic fontRef, dynamic size) {
    current.fontSize = _number(size).abs();
    dynamic font;
    if (fontRef is String) {
      if (commonObjs.has(fontRef)) font = commonObjs.get(fontRef);
      if (font == null && objs.has(fontRef)) font = objs.get(fontRef);
    } else {
      font = fontRef;
    }
    current.fontFamily = _fontFamily(font) ?? 'sans-serif';
    ctx.font = '${current.fontSize}px ${_quoteFont(current.fontFamily)}';
  }

  void moveText(dynamic x, dynamic y) {
    current.textLineX += _number(x);
    current.textLineY += _number(y);
    current.x = current.textLineX;
    current.y = current.textLineY;
  }

  void setLeadingMoveText(dynamic x, dynamic y) {
    current.leading = -_number(y);
    moveText(x, y);
  }

  void setTextMatrix(List<dynamic> m) {
    if (m.length < 6) throw ArgumentError('A text matrix needs six values.');
    current.textMatrix = m.take(6).map(_number).toList();
    current.textLineX = current.textLineY = current.x = current.y = 0;
  }

  void nextLine() => moveText(0, -current.leading);

  void showText(dynamic glyphs) {
    if (glyphs is String) {
      _paintText(glyphs);
      return;
    }
    if (glyphs is! Iterable) {
      _paintText(glyphs?.toString() ?? '');
      return;
    }
    for (final glyph in glyphs) {
      if (glyph is num) {
        current.x -= glyph.toDouble() * current.fontSize / 1000;
        continue;
      }
      if (glyph is String) {
        _paintText(glyph);
        continue;
      }
      if (glyph is Map) {
        final text =
            glyph['unicode'] ?? glyph['fontChar'] ?? glyph['char'] ?? '';
        _paintText(text.toString(),
            width: (glyph['width'] as num?)?.toDouble());
      } else {
        _paintText(glyph.toString());
      }
    }
  }

  void showSpacedText(dynamic values) {
    if (values is Iterable) {
      for (final value in values) {
        if (value is num) {
          current.x -= value.toDouble() * current.fontSize / 1000;
        } else {
          showText(value);
        }
      }
    }
  }

  void _paintText(String text, {double? width}) {
    if (text.isEmpty) return;
    final m = current.textMatrix;
    ctx.save();
    ctx.transform(m[0], m[1], m[2], m[3], m[4], m[5]);
    ctx.translate(current.x, current.y + current.textRise);
    ctx.scale(current.textHScale, -1);
    final mode = current.textRenderingMode & TextRenderingMode.fillStrokeMask;
    if (mode == TextRenderingMode.fill ||
        mode == TextRenderingMode.fillStroke) {
      ctx.fillText(text, 0, 0);
    }
    if (mode == TextRenderingMode.stroke ||
        mode == TextRenderingMode.fillStroke) {
      ctx.strokeText(text, 0, 0);
    }
    ctx.restore();
    final measured = width == null
        ? ctx.measureText(text).width
        : width * current.fontSize / 1000;
    var advance = measured + current.charSpacing;
    if (text == ' ') advance += current.wordSpacing;
    current.x += advance;
  }

  /// Starts an isolated transparency group on a scratch canvas.
  ///
  /// PDF.js calculates a device-space bounding box and redirects all drawing
  /// until [endGroup]. This port follows the same model and deliberately caps
  /// the scratch surface to the destination canvas, preventing malformed PDFs
  /// from allocating an unbounded bitmap.
  void beginGroup(dynamic group) {
    final map = group is Map ? group : const <String, dynamic>{};
    final bbox = map['bbox'] is Iterable
        ? List<dynamic>.from(map['bbox'] as Iterable)
        : <dynamic>[0, 0, ctx.canvas.width, ctx.canvas.height];
    var x = bbox.length > 0 ? _number(bbox[0]).floor() : 0;
    var y = bbox.length > 1 ? _number(bbox[1]).floor() : 0;
    var width =
        bbox.length > 2 ? (_number(bbox[2]) - x).ceil() : ctx.canvas.width;
    var height =
        bbox.length > 3 ? (_number(bbox[3]) - y).ceil() : ctx.canvas.height;
    x = x.clamp(0, ctx.canvas.width);
    y = y.clamp(0, ctx.canvas.height);
    width = width.clamp(1, math.max(1, ctx.canvas.width - x));
    height = height.clamp(1, math.max(1, ctx.canvas.height - y));

    final scratch =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    scratch.width = width;
    scratch.height = height;
    final scratchCtx =
        scratch.getContext('2d') as web.CanvasRenderingContext2D?;
    if (scratchCtx == null) return;
    final alpha = map['alpha'] is num
        ? _number(map['alpha']).clamp(0, 1).toDouble()
        : ctx.globalAlpha;
    final composite = map['blendMode'] == null
        ? ctx.globalCompositeOperation
        : _blendMode(map['blendMode'].toString());
    _groupStack.add(_CanvasGroupState(
        ctx, scratch, x.toDouble(), y.toDouble(), alpha, composite));
    ctx = scratchCtx;
    ctx.translate(-x.toDouble(), -y.toDouble());
    if (map['matrix'] is List) _transformList(map['matrix'] as List);
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';
  }

  /// Composites the current transparency group into its parent surface.
  void endGroup(dynamic group) {
    if (_groupStack.isEmpty) return;
    final state = _groupStack.removeLast();
    ctx = state.parent;
    ctx.save();
    ctx.resetTransform();
    ctx.globalAlpha = state.alpha;
    ctx.globalCompositeOperation = state.composite;
    ctx.drawImage(state.canvas, state.offsetX, state.offsetY);
    ctx.restore();
  }

  /// Establishes the annotation appearance transform and rectangular clip.
  void beginAnnotation(List<dynamic> args) {
    final before = _stateStack.length;
    save();
    _annotationStack.add(_AnnotationState(before));
    // Arguments are id, rect, transform, matrix, hasOwnCanvas in PDF.js.
    final rect = args.length > 1 && args[1] is Iterable
        ? List<dynamic>.from(args[1] as Iterable)
        : const <dynamic>[];
    final transformValues =
        args.length > 2 && args[2] is List ? args[2] as List<dynamic> : null;
    final matrix =
        args.length > 3 && args[3] is List ? args[3] as List<dynamic> : null;
    if (transformValues != null) _transformList(transformValues);
    if (matrix != null) _transformList(matrix);
    if (rect.length >= 4) {
      final x0 = math.min(_number(rect[0]), _number(rect[2]));
      final y0 = math.min(_number(rect[1]), _number(rect[3]));
      final x1 = math.max(_number(rect[0]), _number(rect[2]));
      final y1 = math.max(_number(rect[1]), _number(rect[3]));
      ctx.beginPath();
      ctx.rect(x0, y0, x1 - x0, y1 - y0);
      ctx.clip();
      ctx.beginPath();
    }
  }

  void endAnnotation() {
    if (_annotationStack.isEmpty) return;
    final state = _annotationStack.removeLast();
    while (_stateStack.length > state.stackDepth) restore();
  }

  dynamic _resolveObject(dynamic source) {
    if (source is! String) return source;
    if (objs.has(source)) return objs.get(source);
    if (commonObjs.has(source)) return commonObjs.get(source);
    return null;
  }

  /// Paints a one-bit stencil using the current fill style.
  void paintImageMaskXObject(dynamic source) {
    final image = _resolveObject(source);
    if (image == null) return;
    if (image is web.CanvasImageSource) {
      _drawUnitImage(image);
      return;
    }
    if (image is! Map) return;
    final width = (image['width'] as num?)?.toInt() ?? 0;
    final height = (image['height'] as num?)?.toInt() ?? 0;
    final raw = image['data'];
    if (width <= 0 || height <= 0 || raw is! Iterable<int>) return;
    final bytes = Uint8List.fromList(raw.toList());
    final inverse = image['inverseDecode'] == true;
    final rgba = Uint8ClampedList(width * height * 4);
    final rowBytes = (width + 7) >> 3;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final byteIndex = y * rowBytes + (x >> 3);
        final bit = byteIndex < bytes.length
            ? (bytes[byteIndex] >> (7 - (x & 7))) & 1
            : 0;
        final visible = inverse ? bit == 0 : bit != 0;
        rgba[(y * width + x) * 4 + 3] = visible ? 255 : 0;
      }
    }
    final maskCanvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    maskCanvas.width = width;
    maskCanvas.height = height;
    final maskCtx =
        maskCanvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (maskCtx == null) return;
    final data = maskCtx.createImageData(width.toJS, height);
    data.data.toDart.setAll(0, rgba);
    maskCtx.putImageData(data, 0, 0);
    maskCtx.globalCompositeOperation = 'source-in';
    maskCtx.fillStyle = ctx.fillStyle;
    maskCtx.fillRect(0, 0, width.toDouble(), height.toDouble());
    _drawUnitImage(maskCanvas);
  }

  void paintImageMaskXObjectRepeat(List<dynamic> args) {
    if (args.isEmpty) return;
    final image = args[0];
    final scaleX = args.length > 1 ? _number(args[1]) : 1.0;
    final scaleY = args.length > 2 ? _number(args[2]) : 1.0;
    final positions = args.length > 3 && args[3] is Iterable
        ? List<dynamic>.from(args[3] as Iterable)
        : const <dynamic>[];
    for (var i = 0; i + 1 < positions.length; i += 2) {
      ctx.save();
      ctx.transform(scaleX, 0, 0, scaleY, _number(positions[i]),
          _number(positions[i + 1]));
      paintImageMaskXObject(image);
      ctx.restore();
    }
  }

  void paintImageMaskXObjectGroup(dynamic images) {
    if (images is! Iterable) return;
    for (final entry in images) {
      if (entry is! Map) continue;
      ctx.save();
      if (entry['transform'] is List) {
        _transformList(entry['transform'] as List);
      }
      paintImageMaskXObject(entry);
      ctx.restore();
    }
  }

  void paintImageXObjectRepeat(List<dynamic> args) {
    if (args.isEmpty) return;
    final image = args[0];
    final scaleX = args.length > 1 ? _number(args[1]) : 1.0;
    final scaleY = args.length > 2 ? _number(args[2]) : 1.0;
    final positions = args.length > 3 && args[3] is Iterable
        ? List<dynamic>.from(args[3] as Iterable)
        : const <dynamic>[];
    for (var i = 0; i + 1 < positions.length; i += 2) {
      ctx.save();
      ctx.transform(scaleX, 0, 0, scaleY, _number(positions[i]),
          _number(positions[i + 1]));
      paintImageXObject(image);
      ctx.restore();
    }
  }

  void paintImageXObject(dynamic source) {
    dynamic image = source;
    if (source is String) {
      if (!objs.has(source) && !commonObjs.has(source)) return;
      image = objs.has(source) ? objs.get(source) : commonObjs.get(source);
    }
    if (image is web.CanvasImageSource) {
      _drawUnitImage(image);
      return;
    }
    if (image is Map) {
      final bitmap = image['bitmap'];
      if (bitmap is web.CanvasImageSource) {
        _drawUnitImage(bitmap);
        return;
      }
      final width = (image['width'] as num?)?.toInt();
      final height = (image['height'] as num?)?.toInt();
      final data = image['data'];
      if (width != null && height != null && data is Iterable<int>) {
        paintInlineImageData(width, height, Uint8List.fromList(data.toList()));
      }
    }
  }

  void paintInlineImageData(int width, int height, Uint8List bytes) {
    if (width <= 0 || height <= 0) return;
    final rgba = _toRgba(bytes, width, height);
    final imageData = ctx.createImageData(width.toJS, height);
    imageData.data.toDart.setAll(0, rgba);
    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = width;
    canvas.height = height;
    final imageCtx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (imageCtx == null) return;
    imageCtx.putImageData(imageData, 0, 0);
    _drawUnitImage(canvas);
  }

  void _drawUnitImage(web.CanvasImageSource image) {
    ctx.save();
    ctx.scale(1, -1);
    ctx.drawImage(image, 0, -1, 1, 1);
    ctx.restore();
  }

  Uint8ClampedList _toRgba(Uint8List data, int width, int height) {
    final count = width * height;
    if (data.length >= count * 4)
      return Uint8ClampedList.fromList(data.take(count * 4).toList());
    final rgba = Uint8ClampedList(count * 4);
    if (data.length >= count * 3) {
      for (var i = 0; i < count; i++) {
        rgba[i * 4] = data[i * 3];
        rgba[i * 4 + 1] = data[i * 3 + 1];
        rgba[i * 4 + 2] = data[i * 3 + 2];
        rgba[i * 4 + 3] = 255;
      }
    } else {
      for (var i = 0; i < count; i++) {
        final value = i < data.length ? data[i] : 0;
        rgba.setRange(i * 4, i * 4 + 4, <int>[value, value, value, 255]);
      }
    }
    return rgba;
  }

  static double _number(dynamic value) => (value as num).toDouble();

  static String _gray(dynamic value) {
    final channel = (_number(value).clamp(0, 1) * 255).round();
    return 'rgb($channel,$channel,$channel)';
  }

  static String _rgb(dynamic r, dynamic g, dynamic b) {
    int channel(dynamic v) {
      final n = _number(v);
      return (n <= 1 ? n * 255 : n).clamp(0, 255).round();
    }

    return 'rgb(${channel(r)},${channel(g)},${channel(b)})';
  }

  static String _cmyk(dynamic c, dynamic m, dynamic y, dynamic k) {
    final cd = _number(c).clamp(0, 1), md = _number(m).clamp(0, 1);
    final yd = _number(y).clamp(0, 1), kd = _number(k).clamp(0, 1);
    final r = (255 * (1 - math.min(1, cd + kd))).round();
    final g = (255 * (1 - math.min(1, md + kd))).round();
    final b = (255 * (1 - math.min(1, yd + kd))).round();
    return 'rgb($r,$g,$b)';
  }

  static String _blendMode(String value) {
    const modes = <String, String>{
      'Normal': 'source-over',
      'Multiply': 'multiply',
      'Screen': 'screen',
      'Overlay': 'overlay',
      'Darken': 'darken',
      'Lighten': 'lighten',
      'ColorDodge': 'color-dodge',
      'ColorBurn': 'color-burn',
      'HardLight': 'hard-light',
      'SoftLight': 'soft-light',
      'Difference': 'difference',
      'Exclusion': 'exclusion',
      'Hue': 'hue',
      'Saturation': 'saturation',
      'Color': 'color',
      'Luminosity': 'luminosity',
    };
    return modes[value] ?? 'source-over';
  }

  static String? _fontFamily(dynamic font) {
    if (font is String) return font;
    if (font is Map) {
      return (font['loadedName'] ?? font['fallbackName'] ?? font['name'])
          ?.toString();
    }
    return null;
  }

  static String _quoteFont(String family) {
    if (!family.contains(RegExp(r'''[\s,'"]'''))) return family;
    return '"${family.replaceAll('"', '')}"';
  }
}
