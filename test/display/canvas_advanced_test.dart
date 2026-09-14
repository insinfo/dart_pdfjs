// Copyright 2026. Apache License 2.0.

@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:pdfjs/src/core/operator_list.dart';
import 'package:pdfjs/src/display/canvas.dart';
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

  void begin([String background = '#ffffff']) =>
      graphics.beginDrawing(background: background);
  void end() => graphics.endDrawing();

  List<int> pixel(int x, int y) {
    final p = context.getImageData(x, y, 1, 1).data.toDart;
    return <int>[p[0], p[1], p[2], p[3]];
  }
}

void main() {
  group('transparency groups', () {
    test('isolates drawing until the group ends', () {
      final s = _Surface.create(20, 20)..begin();
      s.graphics.beginGroup(<String, dynamic>{
        'bbox': <num>[2, 2, 12, 12],
      });
      s.graphics.setFillRGBColor(1, 0, 0);
      s.graphics.rectangle(2, 2, 8, 8);
      s.graphics.fill();

      expect(s.pixel(5, 5), <int>[255, 255, 255, 255]);
      s.graphics.endGroup(const <String, dynamic>{});
      expect(s.pixel(5, 5), <int>[255, 0, 0, 255]);
      s.end();
    });

    test('applies group alpha while compositing', () {
      final s = _Surface.create(12, 12)..begin();
      s.graphics.beginGroup(<String, dynamic>{
        'bbox': <num>[0, 0, 12, 12],
        'alpha': 0.5,
      });
      s.graphics.setFillRGBColor(0, 0, 1);
      s.graphics.rectangle(0, 0, 12, 12);
      s.graphics.fill();
      s.graphics.endGroup(const <String, dynamic>{});

      final p = s.pixel(5, 5);
      expect(p[0], inInclusiveRange(126, 129));
      expect(p[1], inInclusiveRange(126, 129));
      expect(p[2], 255);
      s.end();
    });

    test('supports nested isolated groups', () {
      final s = _Surface.create(20, 20)..begin();
      s.graphics.beginGroup(<String, dynamic>{
        'bbox': <num>[0, 0, 20, 20],
      });
      s.graphics.setFillRGBColor(1, 0, 0);
      s.graphics.rectangle(0, 0, 20, 20);
      s.graphics.fill();
      s.graphics.beginGroup(<String, dynamic>{
        'bbox': <num>[5, 5, 15, 15],
        'alpha': 0.5,
      });
      s.graphics.setFillRGBColor(0, 0, 1);
      s.graphics.rectangle(5, 5, 10, 10);
      s.graphics.fill();
      s.graphics.endGroup(const <String, dynamic>{});
      s.graphics.endGroup(const <String, dynamic>{});

      final outer = s.pixel(2, 2);
      final inner = s.pixel(8, 8);
      expect(outer, <int>[255, 0, 0, 255]);
      expect(inner[0], inInclusiveRange(126, 129));
      expect(inner[2], inInclusiveRange(126, 129));
      s.end();
    });

    test('operator list dispatches beginGroup and endGroup', () {
      final s = _Surface.create(16, 16)..begin();
      final ops = OperatorList()
        ..addOp(OPS.beginGroup, <dynamic>[
          <String, dynamic>{
            'bbox': <num>[0, 0, 16, 16]
          }
        ])
        ..addOp(OPS.setFillRGBColor, <dynamic>[0, 1, 0])
        ..addOp(OPS.rectangle, <dynamic>[0, 0, 16, 16])
        ..addOp(OPS.fill)
        ..addOp(OPS.endGroup, <dynamic>[const <String, dynamic>{}]);
      s.graphics.executeOperatorList(ops);
      expect(s.pixel(7, 7), <int>[0, 255, 0, 255]);
      s.end();
    });
  });

  group('annotation boundaries', () {
    test('clips an appearance to its annotation rectangle', () {
      final s = _Surface.create(24, 24)..begin();
      s.graphics.beginAnnotation(<dynamic>[
        'annotation-1',
        <num>[4, 4, 12, 12],
        <num>[1, 0, 0, 1, 0, 0],
        <num>[1, 0, 0, 1, 0, 0],
        false,
      ]);
      s.graphics.setFillRGBColor(1, 0, 0);
      s.graphics.rectangle(0, 0, 20, 20);
      s.graphics.fill();
      s.graphics.endAnnotation();

      expect(s.pixel(7, 7), <int>[255, 0, 0, 255]);
      expect(s.pixel(2, 2), <int>[255, 255, 255, 255]);
      expect(s.pixel(15, 15), <int>[255, 255, 255, 255]);
      s.end();
    });

    test('restores transformations and clipping at the boundary', () {
      final s = _Surface.create(24, 24)..begin();
      s.graphics.beginAnnotation(<dynamic>[
        'annotation-2',
        <num>[0, 0, 5, 5],
        <num>[1, 0, 0, 1, 10, 10],
        null,
        false,
      ]);
      s.graphics.setFillRGBColor(1, 0, 0);
      s.graphics.rectangle(0, 0, 5, 5);
      s.graphics.fill();
      s.graphics.endAnnotation();
      s.graphics.setFillRGBColor(0, 0, 1);
      s.graphics.rectangle(0, 0, 4, 4);
      s.graphics.fill();

      expect(s.pixel(2, 2), <int>[0, 0, 255, 255]);
      expect(s.pixel(12, 12), <int>[255, 0, 0, 255]);
      s.end();
    });
  });

  group('image masks', () {
    test('uses one-bit samples as a stencil of the fill color', () {
      final s = _Surface.create(16, 8)..begin();
      s.graphics.setFillRGBColor(1, 0, 0);
      s.graphics.transform(<dynamic>[8, 0, 0, 8, 0, 0]);
      s.graphics.paintImageMaskXObject(<String, dynamic>{
        'width': 8,
        'height': 1,
        'data': Uint8List.fromList(<int>[0xaa]),
      });

      expect(s.pixel(0, 3), <int>[255, 0, 0, 255]);
      expect(s.pixel(1, 3), <int>[255, 255, 255, 255]);
      expect(s.pixel(2, 3), <int>[255, 0, 0, 255]);
      s.end();
    });

    test('honors inverseDecode', () {
      final s = _Surface.create(8, 8)..begin();
      s.graphics.setFillRGBColor(0, 0, 1);
      s.graphics.transform(<dynamic>[8, 0, 0, 8, 0, 0]);
      s.graphics.paintImageMaskXObject(<String, dynamic>{
        'width': 2,
        'height': 1,
        'data': Uint8List.fromList(<int>[0x80]),
        'inverseDecode': true,
      });

      expect(s.pixel(1, 3), <int>[255, 255, 255, 255]);
      expect(s.pixel(6, 3), <int>[0, 0, 255, 255]);
      s.end();
    });

    test('repeats a stencil at all supplied positions', () {
      final s = _Surface.create(20, 10)..begin();
      s.graphics.setFillRGBColor(0, 1, 0);
      s.graphics.paintImageMaskXObjectRepeat(<dynamic>[
        <String, dynamic>{
          'width': 1,
          'height': 1,
          'data': Uint8List.fromList(<int>[0x80]),
        },
        4,
        4,
        <num>[1, 5, 10, 5],
      ]);

      expect(s.pixel(2, 7), <int>[0, 255, 0, 255]);
      expect(s.pixel(11, 7), <int>[0, 255, 0, 255]);
      expect(s.pixel(7, 7), <int>[255, 255, 255, 255]);
      s.end();
    });

    test('paints a transformed mask group', () {
      final s = _Surface.create(16, 16)..begin();
      s.graphics.setFillRGBColor(1, 0, 1);
      s.graphics.paintImageMaskXObjectGroup(<dynamic>[
        <String, dynamic>{
          'width': 1,
          'height': 1,
          'data': Uint8List.fromList(<int>[0x80]),
          'transform': <num>[5, 0, 0, 5, 3, 8],
        }
      ]);
      expect(s.pixel(4, 10), <int>[255, 0, 255, 255]);
      expect(s.pixel(10, 10), <int>[255, 255, 255, 255]);
      s.end();
    });
  });

  group('text rendering modes', () {
    void prepare(_Surface s, int mode) {
      s.graphics.beginText();
      s.graphics.setFont('sans-serif', 18);
      s.graphics.setTextMatrix(<dynamic>[1, 0, 0, 1, 2, 20]);
      s.graphics.current.textRenderingMode = mode;
    }

    bool hasInk(_Surface s) {
      final data = s.context
          .getImageData(0, 0, s.canvas.width, s.canvas.height)
          .data
          .toDart;
      for (var i = 0; i < data.length; i += 4) {
        if (data[i] < 240 || data[i + 1] < 240 || data[i + 2] < 240) {
          return true;
        }
      }
      return false;
    }

    test('invisible mode advances without painting', () {
      final s = _Surface.create(50, 28)..begin();
      prepare(s, TextRenderingMode.invisible);
      s.graphics.showText('M');
      expect(s.graphics.current.x, greaterThan(0));
      expect(hasInk(s), isFalse);
      s.end();
    });

    test('fill mode paints glyph interiors', () {
      final s = _Surface.create(50, 28)..begin();
      prepare(s, TextRenderingMode.fill);
      s.graphics.setFillRGBColor(1, 0, 0);
      s.graphics.showText('M');
      expect(hasInk(s), isTrue);
      s.end();
    });

    test('stroke mode paints glyph outlines', () {
      final s = _Surface.create(50, 28)..begin();
      prepare(s, TextRenderingMode.stroke);
      s.graphics.setStrokeRGBColor(0, 0, 1);
      s.graphics.setLineWidth(2);
      s.graphics.showText('M');
      expect(hasInk(s), isTrue);
      s.end();
    });

    test('fill-stroke mode paints and advances', () {
      final s = _Surface.create(50, 28)..begin();
      prepare(s, TextRenderingMode.fillStroke);
      s.graphics.setFillRGBColor(1, 0, 0);
      s.graphics.setStrokeRGBColor(0, 0, 1);
      s.graphics.showText('M');
      expect(hasInk(s), isTrue);
      expect(s.graphics.current.x, greaterThan(0));
      s.end();
    });
  });
}
