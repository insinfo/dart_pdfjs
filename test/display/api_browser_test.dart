// Copyright 2026. Apache License 2.0.

@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfjs/src/core/operator_list.dart';
import 'package:pdfjs/src/display/api.dart';
import 'package:pdfjs/src/display/display_utils.dart';
import 'package:pdfjs/src/shared/util.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

Uint8List _paintedPdf() {
  const content = '1 0 0 rg 10 10 30 30 re f';
  final output = StringBuffer('%PDF-1.7\n');
  final offsets = <int>[0];
  var length = latin1.encode(output.toString()).length;

  void object(int number, String body) {
    offsets.add(length);
    final value = '$number 0 obj\n$body\nendobj\n';
    output.write(value);
    length += latin1.encode(value).length;
  }

  object(1, '<< /Type /Catalog /Pages 2 0 R >>');
  object(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
  object(
    3,
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 50 50] '
    '/Resources << >> /Contents 4 0 R >>',
  );
  object(
    4,
    '<< /Length ${content.length} >>\nstream\n$content\nendstream',
  );
  final xrefOffset = length;
  output
    ..write('xref\n0 5\n')
    ..write('0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    output.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  output.write(
    'trailer\n<< /Size 5 /Root 1 0 R >>\n'
    'startxref\n$xrefOffset\n%%EOF\n',
  );
  return Uint8List.fromList(latin1.encode(output.toString()));
}

void main() {
  test('CanvasPageRenderer paints with the viewport transformation', () {
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = 20
      ..height = 20;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    final viewport = PageViewport(
      viewBox: [0, 0, 10, 10],
      scale: 2,
      rotation: 0,
    );
    final renderer = CanvasPageRenderer(context);
    final operatorList = OperatorList()
      ..addOp(OPS.setFillRGBColor, [255, 0, 0])
      ..addOp(OPS.rectangle, [1, 1, 4, 4])
      ..addOp(OPS.fill, const []);

    renderer.render(
      operatorList,
      RenderParameters(
        canvasContext: context,
        viewport: viewport,
        background: '#ffffff',
      ),
    );

    final pixel = context.getImageData(4, 14, 1, 1).data.toDart;
    expect(pixel[0], 255);
    expect(pixel[1], 0);
    expect(pixel[2], 0);
    expect(pixel[3], 255);
  });

  test('loads and renders a real one-page PDF end to end', () async {
    final document = await getDocument(_paintedPdf()).promise;
    final page = await document.getPage(1);
    final viewport = page.getViewport(scale: 2);
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = viewport.width.ceil()
      ..height = viewport.height.ceil();
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;

    final operatorList = await page.getOperatorList();
    expect(
        operatorList.fnArray,
        containsAllInOrder([
          OPS.setFillRGBColor,
          OPS.rectangle,
          OPS.fill,
        ]));

    final task = page.render(RenderParameters(
      canvasContext: context,
      viewport: viewport,
      background: '#ffffff',
    ));
    await task.promise;

    final painted = context.getImageData(40, 40, 1, 1).data.toDart;
    expect(painted[0], 255);
    expect(painted[1], 0);
    expect(painted[2], 0);
    expect(painted[3], 255);

    final outside = context.getImageData(5, 5, 1, 1).data.toDart;
    expect(outside[0], 255);
    expect(outside[1], 255);
    expect(outside[2], 255);
    expect(outside[3], 255);
    await document.destroy();
  });
}
