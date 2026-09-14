// Copyright 2026. Apache License 2.0.

@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:pdfjs/src/core/operator_list.dart';
import 'package:pdfjs/src/display/canvas.dart';
import 'package:pdfjs/src/display/pdf_objects.dart';
import 'package:pdfjs/src/shared/util.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

class _Surface {
  final web.HTMLCanvasElement canvas;
  final web.CanvasRenderingContext2D context;
  final CanvasGraphics graphics;

  _Surface._(this.canvas, this.context, this.graphics);

  factory _Surface.create([int width = 32, int height = 16]) {
    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = width;
    canvas.height = height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    return _Surface._(canvas, context, CanvasGraphics(context));
  }

  void begin() => graphics.beginDrawing();
  void end() => graphics.endDrawing();

  List<int> pixel(int x, int y) {
    final data = context.getImageData(x, y, 1, 1).data.toDart;
    return <int>[data[0], data[1], data[2], data[3]];
  }
}

web.HTMLCanvasElement _maskCanvas(int width, int height, String color) {
  final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
  canvas.width = width;
  canvas.height = height;
  final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
  context.fillStyle = color.toJS;
  context.fillRect(0, 0, width.toDouble(), height.toDouble());
  return canvas;
}

List<dynamic> _axial({String from = '#ff0000', String to = '#0000ff'}) =>
    <dynamic>[
      'RadialAxial',
      'axial',
      null,
      <dynamic>[
        <dynamic>[0, from],
        <dynamic>[1, to],
      ],
      <num>[0, 0],
      <num>[20, 0],
      null,
      null,
    ];

void main() {
  group('shading patterns', () {
    test('fills with an axial gradient IR', () {
      final s = _Surface.create(20, 10)..begin();
      s.graphics.shadingFill(_axial());
      final left = s.pixel(1, 5);
      final right = s.pixel(18, 5);
      expect(left[0], greaterThan(left[2]));
      expect(right[2], greaterThan(right[0]));
      s.end();
    });

    test('fills a path through setFillColorN', () {
      final s = _Surface.create(20, 10)..begin();
      s.graphics.setFillColorN(<dynamic>[_axial()]);
      s.graphics.rectangle(0, 0, 20, 10);
      s.graphics.fill();
      expect(s.pixel(2, 5)[0], greaterThan(s.pixel(2, 5)[2]));
      expect(s.pixel(17, 5)[2], greaterThan(s.pixel(17, 5)[0]));
      s.end();
    });

    test('strokes a path through setStrokeColorN', () {
      final s = _Surface.create(20, 10)..begin();
      s.graphics.setStrokeColorN(<dynamic>[_axial()]);
      s.graphics.setLineWidth(4);
      s.graphics.moveTo(0, 5);
      s.graphics.lineTo(20, 5);
      s.graphics.stroke();
      expect(s.pixel(2, 5)[0], greaterThan(s.pixel(2, 5)[2]));
      expect(s.pixel(17, 5)[2], greaterThan(s.pixel(17, 5)[0]));
      s.end();
    });

    test('resolves named shading IR from PDFObjects', () {
      final objects = PDFObjects()..resolve('shade', _axial());
      final canvas =
          web.document.createElement('canvas') as web.HTMLCanvasElement;
      canvas.width = 20;
      canvas.height = 10;
      final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      final graphics = CanvasGraphics(context, objs: objects);
      graphics.beginDrawing();
      graphics.shadingFill('shade');
      final left = context.getImageData(1, 5, 1, 1).data.toDart;
      expect(left[0], greaterThan(left[2]));
      graphics.endDrawing();
    });

    test('creates a radial gradient IR', () {
      final s = _Surface.create(20, 20)..begin();
      final radial = <dynamic>[
        'RadialAxial',
        'radial',
        null,
        <dynamic>[
          <dynamic>[0, '#ffffff'],
          <dynamic>[1, '#000000'],
        ],
        <num>[10, 10],
        <num>[10, 10],
        0,
        10,
      ];
      s.graphics.shadingFill(radial);
      expect(s.pixel(10, 10)[0], greaterThan(220));
      expect(s.pixel(1, 1)[0], lessThan(100));
      s.end();
    });
  });

  group('tiling patterns', () {
    List<dynamic> tileIR() {
      final tileOps = OperatorList()
        ..addOp(OPS.setFillRGBColor, <dynamic>[1, 0, 0])
        ..addOp(OPS.rectangle, <dynamic>[0, 0, 2, 2])
        ..addOp(OPS.fill);
      return <dynamic>[
        'TilingPattern',
        <num>[1, 0, 0],
        tileOps,
        <num>[1, 0, 0, 1, 0, 0],
        <num>[0, 0, 4, 4],
        4,
        4,
        1,
        1,
        true,
      ];
    }

    test('repeats a colored operator-list tile', () {
      final s = _Surface.create(12, 8)..begin();
      s.graphics.setFillColorN(<dynamic>[tileIR()]);
      s.graphics.rectangle(0, 0, 12, 8);
      s.graphics.fill();
      expect(s.pixel(1, 1), <int>[255, 0, 0, 255]);
      expect(s.pixel(5, 1), <int>[255, 0, 0, 255]);
      expect(s.pixel(3, 3), <int>[255, 255, 255, 255]);
      s.end();
    });

    test('dispatches tiling pattern through an operator list', () {
      final s = _Surface.create(12, 8)..begin();
      final ops = OperatorList()
        ..addOp(OPS.setFillColorN, <dynamic>[tileIR()])
        ..addOp(OPS.rectangle, <dynamic>[0, 0, 12, 8])
        ..addOp(OPS.fill);
      s.graphics.executeOperatorList(ops);
      expect(s.pixel(1, 1)[0], 255);
      expect(s.pixel(5, 1)[1], 0);
      s.end();
    });
  });

  group('soft masks', () {
    test('uses alpha mask samples during group composition', () {
      final s = _Surface.create(12, 8)..begin();
      s.graphics.beginGroup(<String, dynamic>{
        'bbox': <num>[0, 0, 12, 8],
        'smask': <String, dynamic>{
          'subtype': 'Alpha',
          'canvas': _maskCanvas(12, 8, 'rgba(0,0,0,0.5)'),
        },
      });
      s.graphics.setFillRGBColor(1, 0, 0);
      s.graphics.rectangle(0, 0, 12, 8);
      s.graphics.fill();
      s.graphics.endGroup(const <String, dynamic>{});
      final p = s.pixel(4, 4);
      expect(p[0], 255);
      expect(p[1], inInclusiveRange(126, 129));
      expect(p[2], inInclusiveRange(126, 129));
      s.end();
    });

    test('derives mask alpha from luminosity', () {
      final s = _Surface.create(12, 8)..begin();
      s.graphics.beginGroup(<String, dynamic>{
        'bbox': <num>[0, 0, 12, 8],
        'smask': <String, dynamic>{
          'subtype': 'Luminosity',
          'canvas': _maskCanvas(12, 8, 'rgb(128,128,128)'),
        },
      });
      s.graphics.setFillRGBColor(0, 0, 1);
      s.graphics.rectangle(0, 0, 12, 8);
      s.graphics.fill();
      s.graphics.endGroup(const <String, dynamic>{});
      final p = s.pixel(4, 4);
      expect(p[0], inInclusiveRange(126, 129));
      expect(p[1], inInclusiveRange(126, 129));
      expect(p[2], 255);
      s.end();
    });

    test('applies a serialized transfer map', () {
      final transfer = List<int>.generate(256, (i) => 255 - i);
      final s = _Surface.create(12, 8)..begin();
      s.graphics.beginGroup(<String, dynamic>{
        'bbox': <num>[0, 0, 12, 8],
        'smask': <String, dynamic>{
          'subtype': 'Alpha',
          'canvas': _maskCanvas(12, 8, 'rgba(0,0,0,1)'),
          'transferMap': transfer,
        },
      });
      s.graphics.setFillRGBColor(1, 0, 0);
      s.graphics.rectangle(0, 0, 12, 8);
      s.graphics.fill();
      s.graphics.endGroup(const <String, dynamic>{});
      expect(s.pixel(4, 4), <int>[255, 255, 255, 255]);
      s.end();
    });

    test('uses backdrop behind a transparent luminosity mask', () {
      final s = _Surface.create(12, 8)..begin();
      s.graphics.beginGroup(<String, dynamic>{
        'bbox': <num>[0, 0, 12, 8],
        'smask': <String, dynamic>{
          'subtype': 'Luminosity',
          'canvas': _maskCanvas(12, 8, 'rgba(0,0,0,0)'),
          'backdrop': <num>[1, 1, 1],
        },
      });
      s.graphics.setFillRGBColor(0, 1, 0);
      s.graphics.rectangle(0, 0, 12, 8);
      s.graphics.fill();
      s.graphics.endGroup(const <String, dynamic>{});
      expect(s.pixel(4, 4), <int>[0, 255, 0, 255]);
      s.end();
    });
  });
}
