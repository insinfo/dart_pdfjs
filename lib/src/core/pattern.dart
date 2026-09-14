// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;
import 'dart:typed_data';

import '../shared/math_clamp.dart';
import '../shared/util.dart';
import 'base_stream.dart';
import 'colorspace.dart';
import 'colorspace_utils.dart';
import 'core_utils.dart';
import 'primitives.dart';

abstract class ShadingType {
  static const int functionBased = 1;
  static const int axial = 2;
  static const int radial = 3;
  static const int freeFormMesh = 4;
  static const int latticeFormMesh = 5;
  static const int coonsPatchMesh = 6;
  static const int tensorPatchMesh = 7;
}

abstract class Pattern {
  static BaseShading parseShading(
    dynamic shading,
    dynamic xref,
    Dict? res,
    dynamic pdfFunctionFactory,
    GlobalColorSpaceCache globalColorSpaceCache,
    LocalColorSpaceCache localColorSpaceCache,
  ) {
    final Dict dict = shading is BaseStream ? shading.dict! : (shading as Dict);
    final type = dict.get('ShadingType') as int?;

    try {
      switch (type) {
        case ShadingType.functionBased:
          return FunctionBasedShading(
            dict,
            xref,
            res,
            pdfFunctionFactory,
            globalColorSpaceCache,
            localColorSpaceCache,
          );
        case ShadingType.axial:
        case ShadingType.radial:
          return RadialAxialShading(
            dict,
            xref,
            res,
            pdfFunctionFactory,
            globalColorSpaceCache,
            localColorSpaceCache,
          );
        case ShadingType.freeFormMesh:
        case ShadingType.latticeFormMesh:
        case ShadingType.coonsPatchMesh:
        case ShadingType.tensorPatchMesh:
          return MeshShading(
            shading,
            xref,
            res,
            pdfFunctionFactory,
            globalColorSpaceCache,
            localColorSpaceCache,
          );
        default:
          throw FormatError('Unsupported ShadingType: $type');
      }
    } catch (ex) {
      if (ex is MissingDataException) {
        rethrow;
      }
      warn(ex.toString());
      return DummyShading();
    }
  }
}

abstract class BaseShading {
  static const double smallNumber = 1e-6;

  dynamic getIR();
}

class RadialAxialShading extends BaseShading {
  final int shadingType;
  final List<num> coordsArr;
  final List<double>? bbox;
  final bool extendStart;
  final bool extendEnd;
  List<dynamic> colorStops = [];

  RadialAxialShading(
    Dict dict,
    dynamic xref,
    Dict? resources,
    dynamic pdfFunctionFactory,
    GlobalColorSpaceCache globalColorSpaceCache,
    LocalColorSpaceCache localColorSpaceCache,
  )   : shadingType = dict.get('ShadingType') as int,
        coordsArr = (dict.getArray('Coords') as List).cast<num>(),
        bbox = lookupNormalRect(dict.getArray('BBox'), null)?.cast<double>(),
        extendStart = (dict.getArray('Extend') is List &&
                (dict.getArray('Extend') as List).isNotEmpty)
            ? (dict.getArray('Extend') as List)[0] == true
            : false,
        extendEnd = (dict.getArray('Extend') is List &&
                (dict.getArray('Extend') as List).length > 1)
            ? (dict.getArray('Extend') as List)[1] == true
            : false {
    final int coordsLen = (shadingType == ShadingType.axial) ? 4 : 6;
    if (!isNumberArray(coordsArr, coordsLen)) {
      throw FormatError('RadialAxialShading: Invalid /Coords array.');
    }

    final cs = ColorSpaceUtils.parse(
      cs: dict.getRaw('CS') ?? dict.getRaw('ColorSpace'),
      xref: xref,
      resources: resources,
      pdfFunctionFactory: pdfFunctionFactory,
      globalColorSpaceCache: globalColorSpaceCache,
      localColorSpaceCache: localColorSpaceCache,
    );

    var t0 = 0.0;
    var t1 = 1.0;
    final domainArr = dict.getArray('Domain');
    if (isNumberArray(domainArr, 2)) {
      final list = (domainArr as List).cast<num>();
      t0 = list[0].toDouble();
      t1 = list[1].toDouble();
    }

    final fnObj = dict.getRaw('Function');
    final dynamic fn = pdfFunctionFactory.create(fnObj, true);

    const int numberOfSamples = 840;
    final step = (t1 - t0) / numberOfSamples;

    if (t0 >= t1 || step <= 0) {
      info('Bad shading domain.');
      return;
    }

    final color = Float32List(cs.numComps ?? 3);
    final ratio = Float32List(1);
    final rgbBuffer = Uint8List(3);

    var iBase = 0;
    ratio[0] = t0;
    _evalFn(fn, ratio, color);
    cs.getRgb(color, 0, rgbBuffer);
    var rBase = rgbBuffer[0];
    var gBase = rgbBuffer[1];
    var bBase = rgbBuffer[2];
    colorStops.add([0.0, Util.makeHexColor(rBase, gBase, bBase)]);

    var iPrev = 1;
    ratio[0] = t0 + step;
    _evalFn(fn, ratio, color);
    cs.getRgb(color, 0, rgbBuffer);
    var rPrev = rgbBuffer[0];
    var gPrev = rgbBuffer[1];
    var bPrev = rgbBuffer[2];

    var maxSlopeR = (rPrev - rBase + 1).toDouble();
    var maxSlopeG = (gPrev - gBase + 1).toDouble();
    var maxSlopeB = (bPrev - bBase + 1).toDouble();
    var minSlopeR = (rPrev - rBase - 1).toDouble();
    var minSlopeG = (gPrev - gBase - 1).toDouble();
    var minSlopeB = (bPrev - bBase - 1).toDouble();

    for (var i = 2; i < numberOfSamples; i++) {
      ratio[0] = t0 + i * step;
      _evalFn(fn, ratio, color);
      cs.getRgb(color, 0, rgbBuffer);
      final r = rgbBuffer[0];
      final g = rgbBuffer[1];
      final b = rgbBuffer[2];

      final run = i - iBase;
      maxSlopeR = math.min(maxSlopeR, (r - rBase + 1) / run);
      maxSlopeG = math.min(maxSlopeG, (g - gBase + 1) / run);
      maxSlopeB = math.min(maxSlopeB, (b - bBase + 1) / run);
      minSlopeR = math.max(minSlopeR, (r - rBase - 1) / run);
      minSlopeG = math.max(minSlopeG, (g - gBase - 1) / run);
      minSlopeB = math.max(minSlopeB, (b - bBase - 1) / run);

      final slopesExist = minSlopeR <= maxSlopeR &&
          minSlopeG <= maxSlopeG &&
          minSlopeB <= maxSlopeB;

      if (!slopesExist) {
        final cssColor = Util.makeHexColor(rPrev, gPrev, bPrev);
        colorStops.add([iPrev / numberOfSamples, cssColor]);

        maxSlopeR = (r - rPrev + 1).toDouble();
        maxSlopeG = (g - gPrev + 1).toDouble();
        maxSlopeB = (b - bPrev + 1).toDouble();
        minSlopeR = (r - rPrev - 1).toDouble();
        minSlopeG = (g - gPrev - 1).toDouble();
        minSlopeB = (b - bPrev - 1).toDouble();

        iBase = iPrev;
        rBase = rPrev;
        gBase = gPrev;
        bBase = bPrev;
      }

      iPrev = i;
      rPrev = r;
      gPrev = g;
      bPrev = b;
    }
    colorStops.add([1.0, Util.makeHexColor(rPrev, gPrev, bPrev)]);

    var background = 'transparent';
    if (dict.has('Background')) {
      final bg = dict.get('Background');
      if (bg is List) {
        final fList = Float32List.fromList(bg.map((e) => (e as num).toDouble()).toList());
        final buf = Uint8List(3);
        cs.getRgb(fList, 0, buf);
        background = Util.makeHexColor(buf[0], buf[1], buf[2]);
      }
    }

    if (!extendStart) {
      colorStops.insert(0, [0.0, background]);
      colorStops[1][0] = (colorStops[1][0] as double) + BaseShading.smallNumber;
    }
    if (!extendEnd) {
      final lastIdx = colorStops.length - 1;
      colorStops[lastIdx][0] =
          (colorStops[lastIdx][0] as double) - BaseShading.smallNumber;
      colorStops.add([1.0, background]);
    }
  }

  static void _evalFn(dynamic fn, Float32List src, Float32List dest) {
    if (fn is Function) {
      fn(src, 0, dest, 0);
    }
  }

  @override
  List<dynamic> getIR() {
    String type;
    List<num> p0;
    List<num> p1;
    num? r0;
    num? r1;

    if (shadingType == ShadingType.axial) {
      p0 = [coordsArr[0], coordsArr[1]];
      p1 = [coordsArr[2], coordsArr[3]];
      r0 = null;
      r1 = null;
      type = 'axial';
    } else if (shadingType == ShadingType.radial) {
      p0 = [coordsArr[0], coordsArr[1]];
      p1 = [coordsArr[3], coordsArr[4]];
      r0 = coordsArr[2];
      r1 = coordsArr[5];
      type = 'radial';
    } else {
      throw FormatError('getPattern type unknown: $shadingType');
    }

    return ['RadialAxial', type, bbox, colorStops, p0, p1, r0, r1];
  }
}

class MeshVertexData {
  final Float32List posData;
  final Uint8List colData;
  final int vertexCount;

  MeshVertexData({
    required this.posData,
    required this.colData,
    required this.vertexCount,
  });
}

MeshVertexData buildMeshVertexData(
  Float32List coords,
  Uint8List colors,
  List<MeshFigure> figures,
) {
  var vertexCount = 0;
  for (final figure in figures) {
    if (figure.type == MeshFigureType.triangles) {
      vertexCount += figure.coords.length;
    } else if (figure.type == MeshFigureType.lattice) {
      final vpr = figure.verticesPerRow!;
      vertexCount += ((figure.coords.length ~/ vpr) - 1) * (vpr - 1) * 6;
    }
  }

  final posData = Float32List(vertexCount * 2);
  final colData = Uint8List(vertexCount * 4);
  var pOff = 0;
  var cOff = 0;

  void addVertex(int pi, int ci) {
    posData[pOff++] = coords[pi * 2];
    posData[pOff++] = coords[pi * 2 + 1];
    colData[cOff++] = colors[ci * 4];
    colData[cOff++] = colors[ci * 4 + 1];
    colData[cOff++] = colors[ci * 4 + 2];
    cOff++; // Alpha padding
  }

  for (final figure in figures) {
    final ps = figure.coords;
    final cs = figure.colors;
    if (figure.type == MeshFigureType.triangles) {
      for (var i = 0, ii = ps.length; i < ii; i++) {
        addVertex(ps[i], cs[i]);
      }
    } else if (figure.type == MeshFigureType.lattice) {
      final vpr = figure.verticesPerRow!;
      final rows = (ps.length ~/ vpr) - 1;
      final cols = vpr - 1;
      for (var i = 0; i < rows; i++) {
        var q = i * vpr;
        for (var j = 0; j < cols; j++, q++) {
          addVertex(ps[q], cs[q]);
          addVertex(ps[q + 1], cs[q + 1]);
          addVertex(ps[q + vpr], cs[q + vpr]);
          addVertex(ps[q + vpr + 1], cs[q + vpr + 1]);
          addVertex(ps[q + 1], cs[q + 1]);
          addVertex(ps[q + vpr], cs[q + vpr]);
        }
      }
    }
  }

  return MeshVertexData(
    posData: posData,
    colData: colData,
    vertexCount: vertexCount,
  );
}

class MeshFigure {
  final int type;
  List<int> coords;
  List<int> colors;
  int? verticesPerRow;

  MeshFigure({
    required this.type,
    required this.coords,
    required this.colors,
    this.verticesPerRow,
  });
}

class FunctionBasedShading extends BaseShading {
  static const int maxStepCount = 512;

  final List<double>? bbox;
  final List<double> bounds;
  final Uint8List? background;
  final Float32List coords;
  final Uint8List colors;
  final List<MeshFigure> figures;

  FunctionBasedShading(
    Dict dict,
    dynamic xref,
    Dict? resources,
    dynamic pdfFunctionFactory,
    GlobalColorSpaceCache globalColorSpaceCache,
    LocalColorSpaceCache localColorSpaceCache,
  )   : bbox = lookupNormalRect(dict.getArray('BBox'), null)?.cast<double>(),
        bounds = List<double>.from(bboxInit),
        background = null,
        coords = Float32List(0),
        colors = Uint8List(0),
        figures = [] {
    final cs = ColorSpaceUtils.parse(
      cs: dict.getRaw('CS') ?? dict.getRaw('ColorSpace'),
      xref: xref,
      resources: resources,
      pdfFunctionFactory: pdfFunctionFactory,
      globalColorSpaceCache: globalColorSpaceCache,
      localColorSpaceCache: localColorSpaceCache,
    );

    final fnObj = dict.getRaw('Function');
    if (fnObj == null) {
      throw FormatError('FunctionBasedShading: missing /Function');
    }
    final dynamic fn = pdfFunctionFactory.create(fnObj, true);

    final domain = (lookupRect(dict.getArray('Domain'), [0, 1, 0, 1]) as List)
        .cast<num>();
    final x0 = domain[0].toDouble();
    final x1 = domain[1].toDouble();
    final y0 = domain[2].toDouble();
    final y1 = domain[3].toDouble();

    final matrix = (lookupMatrix(dict.getArray('Matrix'), IDENTITY_MATRIX) as List)
        .cast<num>();

    Util.axialAlignedBoundingBox([x0, y0, x1, y1], matrix, bounds);

    final bboxW = bounds[2] - bounds[0];
    final bboxH = bounds[3] - bounds[1];

    final stepsX = mathClamp(
      bboxW.ceil(),
      1,
      maxStepCount,
    ).toInt();
    final stepsY = mathClamp(
      bboxH.ceil(),
      1,
      maxStepCount,
    ).toInt();

    final verticesPerRow = stepsX + 1;
    final totalVertices = (stepsY + 1) * verticesPerRow;
    final allocatedCoords = Float32List(totalVertices * 2);
    final allocatedColors = Uint8List(totalVertices * 4);

    final xyBuf = Float32List(2);
    final colorBuf = Float32List(cs.numComps ?? 3);
    final rangeX = (x1 - x0) / stepsX;
    final rangeY = (y1 - y0) / stepsY;
    final halfStepX = rangeX / 2.0;
    final halfStepY = rangeY / 2.0;
    var coordOffset = 0;
    var colorOffset = 0;

    for (var row = 0; row <= stepsY; row++) {
      final yDomain = y0 + rangeY * row;
      xyBuf[1] = row == stepsY ? yDomain - halfStepY : yDomain;
      for (var col = 0; col <= stepsX; col++) {
        final xDomain = x0 + rangeX * col;
        xyBuf[0] = col == stepsX ? xDomain - halfStepX : xDomain;
        RadialAxialShading._evalFn(fn, xyBuf, colorBuf);
        allocatedCoords[coordOffset] = xDomain;
        allocatedCoords[coordOffset + 1] = yDomain;
        Util.applyTransform(allocatedCoords, matrix, coordOffset);
        coordOffset += 2;

        final rgb = Uint8List(3);
        cs.getRgb(colorBuf, 0, rgb);
        allocatedColors[colorOffset] = rgb[0];
        allocatedColors[colorOffset + 1] = rgb[1];
        allocatedColors[colorOffset + 2] = rgb[2];
        colorOffset += 4;
      }
    }

    final ps = List<int>.generate(totalVertices, (i) => i);
    figures.add(
      MeshFigure(
        type: MeshFigureType.lattice,
        coords: ps,
        colors: List<int>.from(ps),
        verticesPerRow: verticesPerRow,
      ),
    );
  }

  @override
  List<dynamic> getIR() {
    final data = buildMeshVertexData(coords, colors, figures);
    return [
      'Mesh',
      ShadingType.functionBased,
      data.posData,
      data.colData,
      data.vertexCount,
      bounds,
      bbox,
      background,
    ];
  }
}

class MeshDecodeContext {
  final int bitsPerCoordinate;
  final int bitsPerComponent;
  final int bitsPerFlag;
  final List<num> decode;
  final dynamic colorFn;
  final ColorSpace colorSpace;
  final int numComps;

  MeshDecodeContext({
    required this.bitsPerCoordinate,
    required this.bitsPerComponent,
    required this.bitsPerFlag,
    required this.decode,
    this.colorFn,
    required this.colorSpace,
    required this.numComps,
  });
}

class MeshStreamReader {
  final dynamic stream;
  final MeshDecodeContext context;
  int buffer = 0;
  int bufferLength = 0;

  final Float32List tmpCompsBuf;
  final Float32List tmpCsCompsBuf;

  MeshStreamReader(this.stream, this.context)
      : tmpCompsBuf = Float32List(context.numComps),
        tmpCsCompsBuf = context.colorFn != null
            ? Float32List(context.colorSpace.numComps ?? 3)
            : Float32List(context.numComps);

  bool get hasData {
    if (stream.end != null && stream.end > 0) {
      return stream.pos < stream.end;
    }
    if (bufferLength > 0) {
      return true;
    }
    final nextByte = stream.getByte() as int;
    if (nextByte < 0) {
      return false;
    }
    buffer = nextByte;
    bufferLength = 8;
    return true;
  }

  int readBits(int n) {
    if (n == 32) {
      if (bufferLength == 0) {
        return (stream.getInt32() as int) & 0xffffffff;
      }
      buffer = (buffer << 24) |
          ((stream.getByte() as int) << 16) |
          ((stream.getByte() as int) << 8) |
          (stream.getByte() as int);
      final nextByte = stream.getByte() as int;
      this.buffer = nextByte & ((1 << bufferLength) - 1);
      return (((buffer << (8 - bufferLength)) |
              ((nextByte & 0xff) >> bufferLength))) &
          0xffffffff;
    }
    if (n == 8 && bufferLength == 0) {
      return stream.getByte() as int;
    }
    while (bufferLength < n) {
      buffer = (buffer << 8) | (stream.getByte() as int);
      bufferLength += 8;
    }
    bufferLength -= n;
    final res = (buffer >> bufferLength) & ((1 << n) - 1);
    buffer &= (1 << bufferLength) - 1;
    return res;
  }

  void align() {
    buffer = 0;
    bufferLength = 0;
  }

  int readFlag() {
    return readBits(context.bitsPerFlag);
  }

  List<double> readCoordinate() {
    final bitsPerCoord = context.bitsPerCoordinate;
    final decode = context.decode;
    final xi = readBits(bitsPerCoord);
    final yi = readBits(bitsPerCoord);
    final scale = bitsPerCoord < 32
        ? 1.0 / ((1 << bitsPerCoord) - 1)
        : 2.3283064365386963e-10;
    return [
      xi * scale * (decode[1] - decode[0]) + decode[0],
      yi * scale * (decode[3] - decode[2]) + decode[2],
    ];
  }

  Uint8List readComponents() {
    final bitsPerComp = context.bitsPerComponent;
    final decode = context.decode;
    final numComps = context.numComps;
    final scale = bitsPerComp < 32
        ? 1.0 / ((1 << bitsPerComp) - 1)
        : 2.3283064365386963e-10;
    for (var i = 0, j = 4; i < numComps; i++, j += 2) {
      final ci = readBits(bitsPerComp);
      tmpCompsBuf[i] = ci * scale * (decode[j + 1] - decode[j]) + decode[j];
    }
    if (context.colorFn != null) {
      RadialAxialShading._evalFn(context.colorFn, tmpCompsBuf, tmpCsCompsBuf);
    }
    final rgb = Uint8List(3);
    context.colorSpace.getRgb(
      context.colorFn != null ? tmpCsCompsBuf : tmpCompsBuf,
      0,
      rgb,
    );
    return rgb;
  }
}

Map<int, List<Float32List>> _bCache = {};

List<Float32List> _buildB(int count) {
  final lut = <Float32List>[];
  for (var i = 0; i <= count; i++) {
    final t = i / count;
    final t_ = 1.0 - t;
    lut.add(Float32List.fromList([
      t_ * t_ * t_,
      3.0 * t * t_ * t_,
      3.0 * t * t * t_,
      t * t * t,
    ]));
  }
  return lut;
}

List<Float32List> _getB(int count) {
  return _bCache.putIfAbsent(count, () => _buildB(count));
}

void clearPatternCaches() {
  _bCache.clear();
}

class MeshShading extends BaseShading {
  static const int minSplitPatchChunksAmount = 3;
  static const int maxSplitPatchChunksAmount = 20;
  static const int triangleDensity = 20;

  final int shadingType;
  final List<double>? bbox;
  final Uint8List? background;

  List<List<double>> rawCoords = [];
  List<Uint8List> rawColors = [];
  Float32List packedCoords = Float32List(0);
  Uint8List packedColors = Uint8List(0);

  final List<MeshFigure> figures = [];
  List<double> bounds = [0, 0, 0, 0];

  MeshShading(
    dynamic stream,
    dynamic xref,
    Dict? resources,
    dynamic pdfFunctionFactory,
    GlobalColorSpaceCache globalColorSpaceCache,
    LocalColorSpaceCache localColorSpaceCache,
  )   : shadingType = (stream is BaseStream ? stream.dict! : (stream as Dict))
            .get('ShadingType') as int,
        bbox = lookupNormalRect(
          (stream is BaseStream ? stream.dict! : (stream as Dict))
              .getArray('BBox'),
          null,
        )?.cast<double>(),
        background = null {
    final Dict dict = stream is BaseStream ? stream.dict! : (stream as Dict);

    final cs = ColorSpaceUtils.parse(
      cs: dict.getRaw('CS') ?? dict.getRaw('ColorSpace'),
      xref: xref,
      resources: resources,
      pdfFunctionFactory: pdfFunctionFactory,
      globalColorSpaceCache: globalColorSpaceCache,
      localColorSpaceCache: localColorSpaceCache,
    );

    final fnObj = dict.getRaw('Function');
    final dynamic fn =
        fnObj != null ? pdfFunctionFactory.create(fnObj, true) : null;

    final decodeContext = MeshDecodeContext(
      bitsPerCoordinate: (dict.get('BitsPerCoordinate') as num?)?.toInt() ?? 8,
      bitsPerComponent: (dict.get('BitsPerComponent') as num?)?.toInt() ?? 8,
      bitsPerFlag: (dict.get('BitsPerFlag') as num?)?.toInt() ?? 2,
      decode: (dict.getArray('Decode') as List? ?? [0, 1, 0, 1, 0, 1])
          .cast<num>(),
      colorFn: fn,
      colorSpace: cs,
      numComps: fn != null ? 1 : (cs.numComps ?? 3),
    );

    final reader = MeshStreamReader(stream, decodeContext);

    var patchMesh = false;
    switch (shadingType) {
      case ShadingType.freeFormMesh:
        _decodeType4Shading(reader);
        break;
      case ShadingType.latticeFormMesh:
        final verticesPerRow = (dict.get('VerticesPerRow') as num).toInt();
        if (verticesPerRow < 2) {
          throw FormatError('Invalid VerticesPerRow');
        }
        _decodeType5Shading(reader, verticesPerRow);
        break;
      case ShadingType.coonsPatchMesh:
        _decodeType6Shading(reader);
        patchMesh = true;
        break;
      case ShadingType.tensorPatchMesh:
        _decodeType7Shading(reader);
        patchMesh = true;
        break;
      default:
        throw FormatError('Unsupported mesh type: $shadingType');
    }

    if (patchMesh) {
      _updateBounds();
      for (var i = 0; i < figures.length; i++) {
        _buildFigureFromPatch(i);
      }
    }
    _updateBounds();
    _packData();
  }

  void _decodeType4Shading(MeshStreamReader reader) {
    final ps = <int>[];
    var verticesLeft = 0;
    while (reader.hasData) {
      final f = reader.readFlag();
      final coord = reader.readCoordinate();
      final color = reader.readComponents();
      if (verticesLeft == 0) {
        if (f < 0 || f > 2) {
          throw FormatError('Unknown type4 flag');
        }
        switch (f) {
          case 0:
            verticesLeft = 3;
            break;
          case 1:
            ps.add(ps[ps.length - 2]);
            ps.add(ps[ps.length - 1]);
            verticesLeft = 1;
            break;
          case 2:
            ps.add(ps[ps.length - 3]);
            ps.add(ps[ps.length - 1]);
            verticesLeft = 1;
            break;
        }
      }
      ps.add(rawCoords.length);
      rawCoords.add(coord);
      rawColors.add(color);
      verticesLeft--;
      reader.align();
    }
    figures.add(
      MeshFigure(
        type: MeshFigureType.triangles,
        coords: ps,
        colors: List<int>.from(ps),
      ),
    );
  }

  void _decodeType5Shading(MeshStreamReader reader, int verticesPerRow) {
    final ps = <int>[];
    while (reader.hasData) {
      final coord = reader.readCoordinate();
      final color = reader.readComponents();
      ps.add(rawCoords.length);
      rawCoords.add(coord);
      rawColors.add(color);
    }
    figures.add(
      MeshFigure(
        type: MeshFigureType.lattice,
        coords: ps,
        colors: List<int>.from(ps),
        verticesPerRow: verticesPerRow,
      ),
    );
  }

  void _decodeType6Shading(MeshStreamReader reader) {
    final ps = List<int>.filled(16, 0);
    final cs = List<int>.filled(4, 0);
    while (reader.hasData) {
      final f = reader.readFlag();
      if (f < 0 || f > 3) {
        throw FormatError('Unknown type6 flag');
      }
      final pi = rawCoords.length;
      final numCoords = f != 0 ? 8 : 12;
      for (var i = 0; i < numCoords; i++) {
        rawCoords.add(reader.readCoordinate());
      }
      final ci = rawColors.length;
      final numColors = f != 0 ? 2 : 4;
      for (var i = 0; i < numColors; i++) {
        rawColors.add(reader.readComponents());
      }
      switch (f) {
        case 0:
          ps[12] = pi + 3; ps[13] = pi + 4; ps[14] = pi + 5; ps[15] = pi + 6;
          ps[8] = pi + 2; ps[11] = pi + 7;
          ps[4] = pi + 1; ps[7] = pi + 8;
          ps[0] = pi; ps[1] = pi + 11; ps[2] = pi + 10; ps[3] = pi + 9;
          cs[2] = ci + 1; cs[3] = ci + 2;
          cs[0] = ci; cs[1] = ci + 3;
          break;
        case 1:
          final tmp1 = ps[12], tmp2 = ps[13], tmp3 = ps[14], tmp4 = ps[15];
          ps[12] = tmp4; ps[13] = pi + 0; ps[14] = pi + 1; ps[15] = pi + 2;
          ps[8] = tmp3; ps[11] = pi + 3;
          ps[4] = tmp2; ps[7] = pi + 4;
          ps[0] = tmp1; ps[1] = pi + 7; ps[2] = pi + 6; ps[3] = pi + 5;
          final cTmp1 = cs[2], cTmp2 = cs[3];
          cs[2] = cTmp2; cs[3] = ci;
          cs[0] = cTmp1; cs[1] = ci + 1;
          break;
        case 2:
          final tmp1 = ps[15], tmp2 = ps[11];
          ps[12] = ps[3]; ps[13] = pi + 0; ps[14] = pi + 1; ps[15] = pi + 2;
          ps[8] = ps[7]; ps[11] = pi + 3;
          ps[4] = tmp2; ps[7] = pi + 4;
          ps[0] = tmp1; ps[1] = pi + 7; ps[2] = pi + 6; ps[3] = pi + 5;
          final cTmp1 = cs[3];
          cs[2] = cs[1]; cs[3] = ci;
          cs[0] = cTmp1; cs[1] = ci + 1;
          break;
        case 3:
          ps[12] = ps[0]; ps[13] = pi + 0; ps[14] = pi + 1; ps[15] = pi + 2;
          ps[8] = ps[1]; ps[11] = pi + 3;
          ps[4] = ps[2]; ps[7] = pi + 4;
          ps[0] = ps[3]; ps[1] = pi + 7; ps[2] = pi + 6; ps[3] = pi + 5;
          cs[2] = cs[0]; cs[3] = ci;
          cs[0] = cs[1]; cs[1] = ci + 1;
          break;
      }
      ps[5] = rawCoords.length;
      rawCoords.add([
        (-4 * rawCoords[ps[0]][0] -
                rawCoords[ps[15]][0] +
                6 * (rawCoords[ps[4]][0] + rawCoords[ps[1]][0]) -
                2 * (rawCoords[ps[12]][0] + rawCoords[ps[3]][0]) +
                3 * (rawCoords[ps[13]][0] + rawCoords[ps[7]][0])) /
            9.0,
        (-4 * rawCoords[ps[0]][1] -
                rawCoords[ps[15]][1] +
                6 * (rawCoords[ps[4]][1] + rawCoords[ps[1]][1]) -
                2 * (rawCoords[ps[12]][1] + rawCoords[ps[3]][1]) +
                3 * (rawCoords[ps[13]][1] + rawCoords[ps[7]][1])) /
            9.0,
      ]);
      ps[6] = rawCoords.length;
      rawCoords.add([
        (-4 * rawCoords[ps[3]][0] -
                rawCoords[ps[12]][0] +
                6 * (rawCoords[ps[2]][0] + rawCoords[ps[7]][0]) -
                2 * (rawCoords[ps[0]][0] + rawCoords[ps[15]][0]) +
                3 * (rawCoords[ps[4]][0] + rawCoords[ps[14]][0])) /
            9.0,
        (-4 * rawCoords[ps[3]][1] -
                rawCoords[ps[12]][1] +
                6 * (rawCoords[ps[2]][1] + rawCoords[ps[7]][1]) -
                2 * (rawCoords[ps[0]][1] + rawCoords[ps[15]][1]) +
                3 * (rawCoords[ps[4]][1] + rawCoords[ps[14]][1])) /
            9.0,
      ]);
      ps[9] = rawCoords.length;
      rawCoords.add([
        (-4 * rawCoords[ps[12]][0] -
                rawCoords[ps[3]][0] +
                6 * (rawCoords[ps[8]][0] + rawCoords[ps[13]][0]) -
                2 * (rawCoords[ps[0]][0] + rawCoords[ps[15]][0]) +
                3 * (rawCoords[ps[11]][0] + rawCoords[ps[1]][0])) /
            9.0,
        (-4 * rawCoords[ps[12]][1] -
                rawCoords[ps[3]][1] +
                6 * (rawCoords[ps[8]][1] + rawCoords[ps[13]][1]) -
                2 * (rawCoords[ps[0]][1] + rawCoords[ps[15]][1]) +
                3 * (rawCoords[ps[11]][1] + rawCoords[ps[1]][1])) /
            9.0,
      ]);
      ps[10] = rawCoords.length;
      rawCoords.add([
        (-4 * rawCoords[ps[15]][0] -
                rawCoords[ps[0]][0] +
                6 * (rawCoords[ps[11]][0] + rawCoords[ps[14]][0]) -
                2 * (rawCoords[ps[12]][0] + rawCoords[ps[3]][0]) +
                3 * (rawCoords[ps[2]][0] + rawCoords[ps[8]][0])) /
            9.0,
        (-4 * rawCoords[ps[15]][1] -
                rawCoords[ps[0]][1] +
                6 * (rawCoords[ps[11]][1] + rawCoords[ps[14]][1]) -
                2 * (rawCoords[ps[12]][1] + rawCoords[ps[3]][1]) +
                3 * (rawCoords[ps[2]][1] + rawCoords[ps[8]][1])) /
            9.0,
      ]);

      figures.add(
        MeshFigure(
          type: MeshFigureType.patch,
          coords: List<int>.from(ps),
          colors: List<int>.from(cs),
        ),
      );
    }
  }

  void _decodeType7Shading(MeshStreamReader reader) {
    final ps = List<int>.filled(16, 0);
    final cs = List<int>.filled(4, 0);
    while (reader.hasData) {
      final f = reader.readFlag();
      if (f < 0 || f > 3) {
        throw FormatError('Unknown type7 flag');
      }
      final pi = rawCoords.length;
      final numCoords = f != 0 ? 12 : 16;
      for (var i = 0; i < numCoords; i++) {
        rawCoords.add(reader.readCoordinate());
      }
      final ci = rawColors.length;
      final numColors = f != 0 ? 2 : 4;
      for (var i = 0; i < numColors; i++) {
        rawColors.add(reader.readComponents());
      }
      switch (f) {
        case 0:
          ps[12] = pi + 3; ps[13] = pi + 4; ps[14] = pi + 5; ps[15] = pi + 6;
          ps[8] = pi + 2; ps[9] = pi + 13; ps[10] = pi + 14; ps[11] = pi + 7;
          ps[4] = pi + 1; ps[5] = pi + 12; ps[6] = pi + 15; ps[7] = pi + 8;
          ps[0] = pi; ps[1] = pi + 11; ps[2] = pi + 10; ps[3] = pi + 9;
          cs[2] = ci + 1; cs[3] = ci + 2;
          cs[0] = ci; cs[1] = ci + 3;
          break;
        case 1:
          final tmp1 = ps[12], tmp2 = ps[13], tmp3 = ps[14], tmp4 = ps[15];
          ps[12] = tmp4; ps[13] = pi + 0; ps[14] = pi + 1; ps[15] = pi + 2;
          ps[8] = tmp3; ps[9] = pi + 9; ps[10] = pi + 10; ps[11] = pi + 3;
          ps[4] = tmp2; ps[5] = pi + 8; ps[6] = pi + 11; ps[7] = pi + 4;
          ps[0] = tmp1; ps[1] = pi + 7; ps[2] = pi + 6; ps[3] = pi + 5;
          final cTmp1 = cs[2], cTmp2 = cs[3];
          cs[2] = cTmp2; cs[3] = ci;
          cs[0] = cTmp1; cs[1] = ci + 1;
          break;
        case 2:
          final tmp1 = ps[15], tmp2 = ps[11];
          ps[12] = ps[3]; ps[13] = pi + 0; ps[14] = pi + 1; ps[15] = pi + 2;
          ps[8] = ps[7]; ps[9] = pi + 9; ps[10] = pi + 10; ps[11] = pi + 3;
          ps[4] = tmp2; ps[5] = pi + 8; ps[6] = pi + 11; ps[7] = pi + 4;
          ps[0] = tmp1; ps[1] = pi + 7; ps[2] = pi + 6; ps[3] = pi + 5;
          final cTmp1 = cs[3];
          cs[2] = cs[1]; cs[3] = ci;
          cs[0] = cTmp1; cs[1] = ci + 1;
          break;
        case 3:
          ps[12] = ps[0]; ps[13] = pi + 0; ps[14] = pi + 1; ps[15] = pi + 2;
          ps[8] = ps[1]; ps[9] = pi + 9; ps[10] = pi + 10; ps[11] = pi + 3;
          ps[4] = ps[2]; ps[5] = pi + 8; ps[6] = pi + 11; ps[7] = pi + 4;
          ps[0] = ps[3]; ps[1] = pi + 7; ps[2] = pi + 6; ps[3] = pi + 5;
          cs[2] = cs[0]; cs[3] = ci;
          cs[0] = cs[1]; cs[1] = ci + 1;
          break;
      }
      figures.add(
        MeshFigure(
          type: MeshFigureType.patch,
          coords: List<int>.from(ps),
          colors: List<int>.from(cs),
        ),
      );
    }
  }

  void _buildFigureFromPatch(int index) {
    final figure = figures[index];
    final pi = figure.coords;
    final ci = figure.colors;

    final figureMinX = math.min(
      rawCoords[pi[0]][0],
      math.min(
        rawCoords[pi[3]][0],
        math.min(rawCoords[pi[12]][0], rawCoords[pi[15]][0]),
      ),
    );
    final figureMinY = math.min(
      rawCoords[pi[0]][1],
      math.min(
        rawCoords[pi[3]][1],
        math.min(rawCoords[pi[12]][1], rawCoords[pi[15]][1]),
      ),
    );
    final figureMaxX = math.max(
      rawCoords[pi[0]][0],
      math.max(
        rawCoords[pi[3]][0],
        math.max(rawCoords[pi[12]][0], rawCoords[pi[15]][0]),
      ),
    );
    final figureMaxY = math.max(
      rawCoords[pi[0]][1],
      math.max(
        rawCoords[pi[3]][1],
        math.max(rawCoords[pi[12]][1], rawCoords[pi[15]][1]),
      ),
    );

    final denomX = (bounds[2] - bounds[0]).abs();
    final denomY = (bounds[3] - bounds[1]).abs();

    var splitXBy = denomX != 0
        ? (((figureMaxX - figureMinX) * triangleDensity) / denomX).ceil()
        : minSplitPatchChunksAmount;
    splitXBy = mathClamp(
      splitXBy,
      minSplitPatchChunksAmount,
      maxSplitPatchChunksAmount,
    ).toInt();

    var splitYBy = denomY != 0
        ? (((figureMaxY - figureMinY) * triangleDensity) / denomY).ceil()
        : minSplitPatchChunksAmount;
    splitYBy = mathClamp(
      splitYBy,
      minSplitPatchChunksAmount,
      maxSplitPatchChunksAmount,
    ).toInt();

    final verticesPerRow = splitXBy + 1;
    final figureCoords = List<int>.filled((splitYBy + 1) * verticesPerRow, 0);
    final figureColors = List<int>.filled((splitYBy + 1) * verticesPerRow, 0);

    var k = 0;
    final cl = Uint8List(3);
    final cr = Uint8List(3);
    final c0 = rawColors[ci[0]];
    final c1 = rawColors[ci[1]];
    final c2 = rawColors[ci[2]];
    final c3 = rawColors[ci[3]];

    final bRow = _getB(splitYBy);
    final bCol = _getB(splitXBy);

    for (var row = 0; row <= splitYBy; row++) {
      cl[0] = ((c0[0] * (splitYBy - row) + c2[0] * row) ~/ splitYBy);
      cl[1] = ((c0[1] * (splitYBy - row) + c2[1] * row) ~/ splitYBy);
      cl[2] = ((c0[2] * (splitYBy - row) + c2[2] * row) ~/ splitYBy);

      cr[0] = ((c1[0] * (splitYBy - row) + c3[0] * row) ~/ splitYBy);
      cr[1] = ((c1[1] * (splitYBy - row) + c3[1] * row) ~/ splitYBy);
      cr[2] = ((c1[2] * (splitYBy - row) + c3[2] * row) ~/ splitYBy);

      for (var col = 0; col <= splitXBy; col++, k++) {
        if ((row == 0 || row == splitYBy) && (col == 0 || col == splitXBy)) {
          continue;
        }
        var x = 0.0;
        var y = 0.0;
        var q = 0;
        for (var i = 0; i <= 3; i++) {
          for (var j = 0; j <= 3; j++, q++) {
            final m = bRow[row][i] * bCol[col][j];
            x += rawCoords[pi[q]][0] * m;
            y += rawCoords[pi[q]][1] * m;
          }
        }
        figureCoords[k] = rawCoords.length;
        rawCoords.add([x, y]);
        figureColors[k] = rawColors.length;
        final newColor = Uint8List(3);
        newColor[0] = ((cl[0] * (splitXBy - col) + cr[0] * col) ~/ splitXBy);
        newColor[1] = ((cl[1] * (splitXBy - col) + cr[1] * col) ~/ splitXBy);
        newColor[2] = ((cl[2] * (splitXBy - col) + cr[2] * col) ~/ splitXBy);
        rawColors.add(newColor);
      }
    }

    figureCoords[0] = pi[0];
    figureColors[0] = ci[0];
    figureCoords[splitXBy] = pi[3];
    figureColors[splitXBy] = ci[1];
    figureCoords[verticesPerRow * splitYBy] = pi[12];
    figureColors[verticesPerRow * splitYBy] = ci[2];
    figureCoords[verticesPerRow * splitYBy + splitXBy] = pi[15];
    figureColors[verticesPerRow * splitYBy + splitXBy] = ci[3];

    figures[index] = MeshFigure(
      type: MeshFigureType.lattice,
      coords: figureCoords,
      colors: figureColors,
      verticesPerRow: verticesPerRow,
    );
  }

  void _updateBounds() {
    if (rawCoords.isEmpty) return;
    var minX = rawCoords[0][0];
    var minY = rawCoords[0][1];
    var maxX = minX;
    var maxY = minY;
    for (var i = 1; i < rawCoords.length; i++) {
      final x = rawCoords[i][0];
      final y = rawCoords[i][1];
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
    bounds = [minX, minY, maxX, maxY];
  }

  void _packData() {
    packedCoords = Float32List(rawCoords.length * 2);
    var j = 0;
    for (var i = 0; i < rawCoords.length; i++) {
      packedCoords[j++] = rawCoords[i][0];
      packedCoords[j++] = rawCoords[i][1];
    }

    packedColors = Uint8List(rawColors.length * 4);
    var k = 0;
    for (var i = 0; i < rawColors.length; i++) {
      packedColors[k++] = rawColors[i][0];
      packedColors[k++] = rawColors[i][1];
      packedColors[k++] = rawColors[i][2];
      k++; // Padding
    }
  }

  @override
  List<dynamic> getIR() {
    final data = buildMeshVertexData(packedCoords, packedColors, figures);
    return [
      'Mesh',
      shadingType,
      data.posData,
      data.colData,
      data.vertexCount,
      bounds,
      bbox,
      background,
    ];
  }
}

class DummyShading extends BaseShading {
  @override
  List<dynamic> getIR() => ['Dummy'];
}

List<dynamic> getTilingPatternIR(
  dynamic operatorList,
  Dict dict,
  dynamic color, [
  bool needsIsolation = true,
]) {
  final matrix = (lookupMatrix(dict.getArray('Matrix'), IDENTITY_MATRIX) as List)
      .cast<num>();
  final bbox = lookupNormalRect(dict.getArray('BBox'), null)?.cast<double>();
  if (bbox == null || bbox[2] - bbox[0] == 0 || bbox[3] - bbox[1] == 0) {
    throw FormatError('Invalid getTilingPatternIR /BBox array.');
  }

  final xstep = dict.get('XStep');
  if (xstep is! num) {
    throw FormatError('Invalid getTilingPatternIR /XStep value.');
  }
  final ystep = dict.get('YStep');
  if (ystep is! num) {
    throw FormatError('Invalid getTilingPatternIR /YStep value.');
  }
  final paintType = dict.get('PaintType');
  if (paintType is! int) {
    throw FormatError('Invalid getTilingPatternIR /PaintType value.');
  }
  final tilingType = dict.get('TilingType');
  if (tilingType is! int) {
    throw FormatError('Invalid getTilingPatternIR /TilingType value.');
  }

  return [
    'TilingPattern',
    color,
    operatorList,
    matrix,
    bbox,
    xstep,
    ystep,
    paintType,
    tilingType,
    needsIsolation,
  ];
}
