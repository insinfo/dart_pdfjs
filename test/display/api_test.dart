// Copyright 2026. Apache License 2.0.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfjs/src/core/operator_list.dart';
import 'package:pdfjs/src/display/api.dart';
import 'package:pdfjs/src/display/display_utils.dart';
import 'package:test/test.dart';

Uint8List _simplePdf() {
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
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] '
    '/Resources << >> /Contents 4 0 R >>',
  );
  object(4, '<< /Length 0 >>\nstream\n\nendstream');
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

class _RecordingRenderer implements PDFPageRenderer {
  OperatorList? operatorList;
  RenderParameters? parameters;
  Object? cancellationReason;
  final Completer<void>? gate;

  _RecordingRenderer({this.gate});

  @override
  Future<void> render(
    OperatorList operatorList,
    RenderParameters parameters,
  ) async {
    this.operatorList = operatorList;
    this.parameters = parameters;
    await gate?.future;
  }

  @override
  void cancel([dynamic reason]) {
    cancellationReason = reason;
  }
}

void main() {
  group('getDocument', () {
    test('loads bytes and exposes document and page proxies', () async {
      final loadingTask = getDocument(_simplePdf());
      final document = await loadingTask.promise;

      expect(loadingTask.docId, startsWith('d'));
      expect(document.numPages, 1);
      expect(document.fingerprints.first, hasLength(32));

      final page = await document.getPage(1);
      expect(page.pageNumber, 1);
      expect(page.pageIndex, 0);
      expect(page.rotate, 0);
      expect(page.userUnit, 1);
      expect(page.view, [0, 0, 200, 300]);
      expect(identical(page, await document.getPage(1)), isTrue);

      final viewport = page.getViewport(scale: 2);
      expect(viewport.width, 400);
      expect(viewport.height, 600);
      expect(viewport.rotation, 0);

      await document.destroy();
      expect(document.destroyed, isTrue);
      expect(() => document.getPage(1), throwsStateError);
    });

    test('accepts a parameter map and reports progress', () async {
      final bytes = _simplePdf();
      final task = getDocument({
        'data': bytes.buffer,
        'docBaseUrl': 'https://example.test/document.pdf',
      });
      Map<String, int>? progress;
      task.onProgress = (value) => progress = value;

      final document = await task.promise;
      expect(progress, {'loaded': bytes.length, 'total': bytes.length});
      await document.destroy();
    });

    test('loads a URL through an embedder-provided loader', () async {
      Uri? requested;
      final task = getDocument(DocumentInitParameters(
        url: 'https://example.test/simple.pdf',
        urlLoader: (url) {
          requested = url;
          return _simplePdf();
        },
      ));

      final document = await task.promise;
      expect(requested.toString(), 'https://example.test/simple.pdf');
      expect(document.numPages, 1);
      await document.destroy();
    });

    test('rejects URL loading without a loader', () async {
      final task = getDocument(Uri.parse('https://example.test/simple.pdf'));
      await expectLater(task.promise, throwsUnsupportedError);
    });

    test('validates page numbers and viewport scale', () async {
      final document = await getDocument(_simplePdf()).promise;
      await expectLater(document.getPage(0), throwsRangeError);
      await expectLater(document.getPage(2), throwsRangeError);
      final page = await document.getPage(1);
      expect(() => page.getViewport(scale: 0), throwsArgumentError);
      expect(() => page.getViewport(scale: double.nan), throwsArgumentError);
      await document.destroy();
    });

    test('destroy can cancel a pending loading task', () async {
      final loaderGate = Completer<Uint8List>();
      final task = getDocument(DocumentInitParameters(
        url: 'https://example.test/slow.pdf',
        urlLoader: (_) => loaderGate.future,
      ));

      final failure = expectLater(task.promise, throwsStateError);
      await task.destroy();
      await failure;
      loaderGate.complete(_simplePdf());
    });
  });

  group('PDFPageProxy rendering', () {
    late PDFDocumentProxy document;
    late PDFPageProxy page;
    late PageViewport viewport;

    setUp(() async {
      document = await getDocument(_simplePdf()).promise;
      page = await document.getPage(1);
      viewport = page.getViewport(scale: 1);
    });

    tearDown(() => document.destroy());

    test('builds an operator list once and invokes renderer', () async {
      final renderer = _RecordingRenderer();
      final parameters = RenderParameters(
        canvasContext: Object(),
        viewport: viewport,
        background: '#123456',
      );

      final task = page.render(
        parameters,
        rendererFactory: (_) => renderer,
      );
      await task.promise;

      expect(task.cancelled, isFalse);
      expect(renderer.operatorList, isNotNull);
      expect(renderer.parameters, same(parameters));
      expect(await page.getOperatorList(), same(renderer.operatorList));
    });

    test('uses a registered default renderer factory', () async {
      final renderer = _RecordingRenderer();
      setDefaultPageRendererFactory((_) => renderer);
      addTearDown(resetDefaultPageRendererFactory);

      final task = page.render(RenderParameters(
        canvasContext: Object(),
        viewport: viewport,
      ));
      await task.promise;
      expect(renderer.operatorList, isNotNull);
    });

    test('fails clearly when no renderer is installed', () {
      setDefaultPageRendererFactory(null);
      addTearDown(resetDefaultPageRendererFactory);
      expect(
        () => page.render(RenderParameters(
          canvasContext: Object(),
          viewport: viewport,
        )),
        throwsStateError,
      );
    });

    test('cancels rendering and notifies the backend', () async {
      final gate = Completer<void>();
      final renderer = _RecordingRenderer(gate: gate);
      final task = page.render(
        RenderParameters(canvasContext: Object(), viewport: viewport),
        rendererFactory: (_) => renderer,
      );
      await Future<void>.delayed(Duration.zero);
      task.cancel(7);

      await expectLater(
        task.promise,
        throwsA(isA<RenderingCancelledException>()),
      );
      expect(task.cancelled, isTrue);
      expect(renderer.cancellationReason, isA<RenderingCancelledException>());
      gate.complete();
    });

    test('destroying the document invalidates pages', () async {
      await document.destroy();
      expect(page.destroyed, isTrue);
      expect(() => page.getViewport(scale: 1), throwsStateError);
    });
  });
}
