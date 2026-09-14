// Copyright 2026. Apache License 2.0.

@TestOn('browser')
library;

import 'dart:typed_data';
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

  factory _Surface.create([int width = 32, int height = 32]) {
    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = width;
    canvas.height = height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    return _Surface._(canvas, context, CanvasGraphics(context));
  }

  List<int> pixel(int x, int y) {
    final data = context.getImageData(x, y, 1, 1).data.toDart;
    return <int>[data[0], data[1], data[2], data[3]];
  }

  void begin({String background = '#ffffff'}) =>
      graphics.beginDrawing(background: background);

  void end() => graphics.endDrawing();
}

void main() {
  group('CanvasExtraState', () {
    test('clone creates an independent text matrix', () {
      final state = CanvasExtraState(
        charSpacing: 2,
        wordSpacing: 3,
        fontSize: 12,
        textMatrix: <double>[1, 0, 0, 1, 10, 20],
      );

      final copy = state.clone();
      copy.textMatrix[4] = 99;
      copy.charSpacing = 8;

      expect(state.textMatrix[4], 10);
      expect(state.charSpacing, 2);
      expect(copy.wordSpacing, 3);
      expect(copy.fontSize, 12);
    });
  });

  group('operator-list execution', () {
    test('fills a rectangle from an OperatorList', () {
      final surface = _Surface.create();
      surface.begin();
      final list = OperatorList()
        ..addOp(OPS.setFillRGBColor, <dynamic>[1, 0, 0])
        ..addOp(OPS.rectangle, <dynamic>[2, 3, 12, 10])
        ..addOp(OPS.fill);

      final result = surface.graphics.executeOperatorList(list);

      expect(result, 3);
      expect(surface.pixel(5, 5), <int>[255, 0, 0, 255]);
      expect(surface.pixel(20, 20), <int>[255, 255, 255, 255]);
      surface.end();
    });

    test('accepts a serialized worker chunk', () {
      final surface = _Surface.create();
      surface.begin();
      final chunk = <String, dynamic>{
        'fnArray': <int>[
          OPS.setFillGray,
          OPS.rectangle,
          OPS.fill,
        ],
        'argsArray': <dynamic>[
          <dynamic>[0],
          <dynamic>[4, 4, 8, 8],
          <dynamic>[],
        ],
      };

      expect(surface.graphics.executeOperatorList(chunk), 3);
      expect(surface.pixel(6, 6), <int>[0, 0, 0, 255]);
      surface.end();
    });

    test('starts at an offset and applies an operation filter', () {
      final surface = _Surface.create();
      surface.begin();
      final chunk = <String, dynamic>{
        'fnArray': <int>[
          OPS.setFillRGBColor,
          OPS.setFillRGBColor,
          OPS.rectangle,
          OPS.fill,
        ],
        'argsArray': <dynamic>[
          <dynamic>[1, 0, 0],
          <dynamic>[0, 0, 1],
          <dynamic>[0, 0, 10, 10],
          <dynamic>[],
        ],
      };

      surface.graphics.executeOperatorList(
        chunk,
        startIndex: 1,
        operationsFilter: (index) => index != 1,
      );

      // The initial red and filtered blue operations were both skipped.
      expect(surface.pixel(2, 2), <int>[0, 0, 0, 255]);
      surface.end();
    });

    test('rejects malformed and unknown list containers', () {
      final surface = _Surface.create();
      expect(
        () => surface.graphics.executeOperatorList(<String, dynamic>{
          'fnArray': <int>[OPS.save],
          'argsArray': <dynamic>[],
        }),
        throwsStateError,
      );
      expect(
        () => surface.graphics.executeOperatorList('invalid'),
        throwsArgumentError,
      );
    });
  });

  group('path painting', () {
    test('strokes lines with width, cap, join and dash settings', () {
      final surface = _Surface.create();
      surface.begin();
      final list = OperatorList()
        ..addOp(OPS.setStrokeRGBColor, <dynamic>[0, 1, 0])
        ..addOp(OPS.setLineWidth, <dynamic>[4])
        ..addOp(OPS.setLineCap, <dynamic>[1])
        ..addOp(OPS.setLineJoin, <dynamic>[2])
        ..addOp(OPS.setDash, <dynamic>[
          <dynamic>[100, 1],
          0,
        ])
        ..addOp(OPS.moveTo, <dynamic>[4, 10])
        ..addOp(OPS.lineTo, <dynamic>[24, 10])
        ..addOp(OPS.stroke);

      surface.graphics.executeOperatorList(list);

      expect(surface.context.lineWidth, 4);
      expect(surface.context.lineCap, 'round');
      expect(surface.context.lineJoin, 'bevel');
      expect(surface.pixel(10, 10)[1], greaterThan(200));
      surface.end();
    });

    test('supports cubic curves and close-fill-stroke', () {
      final surface = _Surface.create();
      surface.begin();
      surface.graphics
        ..setFillRGBColor(0, 0, 1)
        ..setStrokeRGBColor(1, 0, 0)
        ..setLineWidth(2)
        ..moveTo(4, 20)
        ..curveTo(4, 4, 20, 4, 20, 20)
        ..closeFillStroke();

      expect(surface.pixel(12, 12)[2], greaterThan(150));
      expect(surface.pixel(4, 20)[0], greaterThan(150));
      surface.end();
    });

    test('constructPath consumes compact path arrays', () {
      final surface = _Surface.create();
      surface.begin();
      surface.graphics
        ..setFillRGBColor(1, 0, 1)
        ..constructPath(<dynamic>[
          <int>[
            DrawOPS.moveTo,
            DrawOPS.lineTo,
            DrawOPS.lineTo,
            DrawOPS.closePath
          ],
          <num>[2, 2, 20, 2, 2, 20],
        ])
        ..fill();

      final inside = surface.pixel(5, 5);
      expect(inside[0], greaterThan(200));
      expect(inside[2], greaterThan(200));
      expect(surface.pixel(18, 18), <int>[255, 255, 255, 255]);
      surface.end();
    });

    test('applies a pending nonzero clip when ending the path', () {
      final surface = _Surface.create();
      surface.begin();
      surface.graphics
        ..rectangle(0, 0, 10, 32)
        ..clip()
        ..endPath()
        ..setFillRGBColor(1, 0, 0)
        ..rectangle(0, 0, 32, 32)
        ..fill();

      expect(surface.pixel(5, 5), <int>[255, 0, 0, 255]);
      expect(surface.pixel(20, 5), <int>[255, 255, 255, 255]);
      surface.end();
    });

    test('applies even-odd clipping', () {
      final surface = _Surface.create();
      surface.begin();
      surface.graphics
        ..rectangle(0, 0, 30, 30)
        ..rectangle(8, 8, 14, 14)
        ..eoClip()
        ..endPath()
        ..setFillGray(0)
        ..rectangle(0, 0, 30, 30)
        ..fill();

      expect(surface.pixel(4, 4), <int>[0, 0, 0, 255]);
      expect(surface.pixel(12, 12), <int>[255, 255, 255, 255]);
      surface.end();
    });
  });

  group('graphics state and transforms', () {
    test('save and restore isolate colors and text settings', () {
      final surface = _Surface.create();
      surface.begin();
      surface.graphics
        ..setFillRGBColor(1, 0, 0)
        ..current.charSpacing = 2
        ..save()
        ..setFillRGBColor(0, 0, 1)
        ..current.charSpacing = 9
        ..rectangle(0, 0, 8, 8)
        ..fill()
        ..restore()
        ..rectangle(10, 0, 8, 8)
        ..fill();

      expect(surface.pixel(4, 4), <int>[0, 0, 255, 255]);
      expect(surface.pixel(14, 4), <int>[255, 0, 0, 255]);
      expect(surface.graphics.current.charSpacing, 2);
      surface.end();
    });

    test('applies the page transform before operators', () {
      final surface = _Surface.create();
      surface.graphics.beginDrawing(
        transform: <num>[1, 0, 0, 1, 10, 8],
      );
      surface.graphics
        ..setFillGray(0)
        ..rectangle(0, 0, 5, 5)
        ..fill();

      expect(surface.pixel(11, 9), <int>[0, 0, 0, 255]);
      expect(surface.pixel(2, 2), <int>[255, 255, 255, 255]);
      surface.end();
    });

    test('maps PDF blend modes to Canvas compositing modes', () {
      final surface = _Surface.create();
      surface.graphics.setGState(<dynamic>[
        <dynamic>['BM', 'Multiply'],
        <dynamic>['ca', 0.25],
      ]);

      expect(surface.context.globalCompositeOperation, 'multiply');
      expect(surface.context.globalAlpha, closeTo(0.25, 0.001));
    });
  });

  group('colors', () {
    test('converts gray, normalized RGB and byte RGB values', () {
      final surface = _Surface.create();
      surface.begin();
      surface.graphics
        ..setFillGray(0.5)
        ..rectangle(0, 0, 5, 5)
        ..fill()
        ..setFillRGBColor(0, 1, 0)
        ..rectangle(6, 0, 5, 5)
        ..fill()
        ..setFillRGBColor(0, 0, 255)
        ..rectangle(12, 0, 5, 5)
        ..fill();

      expect(surface.pixel(2, 2)[0], closeTo(128, 1));
      expect(surface.pixel(8, 2), <int>[0, 255, 0, 255]);
      expect(surface.pixel(14, 2), <int>[0, 0, 255, 255]);
      surface.end();
    });

    test('converts CMYK to a Canvas RGB color', () {
      final surface = _Surface.create();
      surface.begin();
      surface.graphics
        ..setFillCMYKColor(0, 1, 1, 0)
        ..rectangle(0, 0, 8, 8)
        ..fill();

      expect(surface.pixel(4, 4), <int>[255, 0, 0, 255]);
      surface.end();
    });
  });

  group('text', () {
    test('resolves a font and advances the text position', () {
      final objects = PDFObjects()
        ..resolve('g_font', <String, dynamic>{'loadedName': 'serif'});
      final canvas =
          web.document.createElement('canvas') as web.HTMLCanvasElement
            ..width = 100
            ..height = 40;
      final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      final graphics = CanvasGraphics(context, commonObjs: objects);
      graphics.beginDrawing();
      graphics
        ..beginText()
        ..setFont('g_font', 18)
        ..setTextMatrix(<dynamic>[1, 0, 0, 1, 5, 25])
        ..showText('Hello');

      expect(graphics.current.fontFamily, 'serif');
      expect(graphics.current.x, greaterThan(0));
      expect(context.font, contains('18px'));
      graphics.endDrawing();
    });

    test('spacing arrays adjust the current text coordinate', () {
      final surface = _Surface.create(100, 40);
      surface.begin();
      surface.graphics
        ..beginText()
        ..setFont('sans-serif', 10)
        ..showSpacedText(<dynamic>['A', 500, 'B']);

      expect(surface.graphics.current.x, greaterThan(0));
      expect(surface.graphics.current.x, lessThan(30));
      surface.end();
    });

    test('moveText, leading and nextLine update text coordinates', () {
      final surface = _Surface.create();
      surface.graphics
        ..beginText()
        ..setLeadingMoveText(4, -12)
        ..nextLine();

      expect(surface.graphics.current.leading, 12);
      expect(surface.graphics.current.x, 4);
      expect(surface.graphics.current.y, -24);
    });
  });

  group('images', () {
    test('paints RGBA image bytes into the unit square', () {
      final surface = _Surface.create(8, 8);
      surface.begin();
      surface.graphics
        ..transform(<dynamic>[4, 0, 0, -4, 0, 4])
        ..paintInlineImageData(
          1,
          1,
          Uint8List.fromList(<int>[255, 0, 0, 255]),
        );

      expect(surface.pixel(2, 2), <int>[255, 0, 0, 255]);
      surface.end();
    });

    test('expands RGB data and resolves named image objects', () {
      final objects = PDFObjects()
        ..resolve('img', <String, dynamic>{
          'width': 1,
          'height': 1,
          'data': <int>[0, 255, 0],
        });
      final canvas =
          web.document.createElement('canvas') as web.HTMLCanvasElement
            ..width = 8
            ..height = 8;
      final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      final graphics = CanvasGraphics(context, objs: objects);
      graphics.beginDrawing();
      graphics
        ..transform(<dynamic>[4, 0, 0, -4, 0, 4])
        ..paintImageXObject('img');

      final data = context.getImageData(2, 2, 1, 1).data.toDart;
      expect(<int>[data[0], data[1], data[2], data[3]], <int>[0, 255, 0, 255]);
      graphics.endDrawing();
    });

    test('expands grayscale data', () {
      final surface = _Surface.create(8, 8);
      surface.begin();
      surface.graphics
        ..transform(<dynamic>[4, 0, 0, -4, 0, 4])
        ..paintInlineImageData(1, 1, Uint8List.fromList(<int>[64]));

      expect(surface.pixel(2, 2), <int>[64, 64, 64, 255]);
      surface.end();
    });
  });
}
