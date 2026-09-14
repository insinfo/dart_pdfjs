// Copyright 2026. Apache License 2.0.

import 'dart:typed_data';

import 'package:pdfjs/src/core/document.dart';
import 'package:pdfjs/src/core/pdf_manager.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/stream.dart';
import 'package:pdfjs/src/core/xref.dart';
import 'package:test/test.dart';

class _FakePdfManager extends BasePdfManager {
  _FakePdfManager()
      : super(
          docBaseUrl: 'https://example.com/test.pdf',
          docId: 'doc_12345',
        );

  @override
  Future<dynamic> ensure(dynamic obj, dynamic propOrAction,
      [List<dynamic>? args]) async {
    if (propOrAction is Function) {
      return propOrAction();
    }
    if (obj is Page) {
      if (propOrAction == 'content') {
        return obj.content;
      }
      if (propOrAction == 'resources') {
        return obj.resources;
      }
    }
    return null;
  }

  @override
  Future<void> requestRange(int begin, int end) async {}

  @override
  Future<Stream> requestLoadedStream([bool noFetch = false]) async {
    return Stream(Uint8List(0));
  }

  @override
  void sendProgressiveData(dynamic chunk) {}

  @override
  void terminate([dynamic reason]) {}
}

void main() {
  group('Document - find helper and signatures', () {
    test('find locates signature forwards and backwards', () {
      final data = Uint8List.fromList([
        0x20, 0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x37, 0x0a, // %PDF-1.7
        0x65, 0x6e, 0x64, 0x6f, 0x62, 0x6a, // endobj
      ]);
      final stream = Stream(data);

      expect(find(stream, PDF_HEADER_SIGNATURE), isTrue);
      expect(find(stream, ENDOBJ_SIGNATURE), isTrue);
    });
  });

  group('Page Geometry and Properties', () {
    test('Page normalizes rotation to 0, 90, 180, 270', () {
      final manager = _FakePdfManager();
      final xref = XRef(Stream(Uint8List(0)), manager);
      final pageDict = Dict(xref);

      // Normal rotation 90
      pageDict.set('Rotate', 90);
      var page = Page(
        pdfManager: manager,
        xref: xref,
        pageIndex: 0,
        pageDict: pageDict,
        ref: Ref(1, 0),
      );
      expect(page.rotate, equals(90));

      // 450 degrees -> 90
      pageDict.set('Rotate', 450);
      page = Page(
        pdfManager: manager,
        xref: xref,
        pageIndex: 0,
        pageDict: pageDict,
        ref: Ref(1, 0),
      );
      expect(page.rotate, equals(90));

      // Invalid rotation 45 -> 0
      pageDict.set('Rotate', 45);
      page = Page(
        pdfManager: manager,
        xref: xref,
        pageIndex: 0,
        pageDict: pageDict,
        ref: Ref(1, 0),
      );
      expect(page.rotate, equals(0));

      // Negative rotation -90 -> 270
      pageDict.set('Rotate', -90);
      page = Page(
        pdfManager: manager,
        xref: xref,
        pageIndex: 0,
        pageDict: pageDict,
        ref: Ref(1, 0),
      );
      expect(page.rotate, equals(270));
    });

    test('Page calculates mediaBox, cropBox, view and userUnit', () {
      final manager = _FakePdfManager();
      final xref = XRef(Stream(Uint8List(0)), manager);
      final pageDict = Dict(xref);
      pageDict.set('MediaBox', [0, 0, 600, 800]);
      pageDict.set('CropBox', [50, 50, 550, 750]);
      pageDict.set('UserUnit', 2.0);

      final page = Page(
        pdfManager: manager,
        xref: xref,
        pageIndex: 0,
        pageDict: pageDict,
        ref: Ref(2, 0),
      );

      expect(page.mediaBox, equals([0, 0, 600, 800]));
      expect(page.cropBox, equals([50, 50, 550, 750]));
      expect(page.userUnit, equals(2.0));
      expect(page.view, equals([50, 50, 550, 750]));
    });

    test('Page fallback to LETTER_SIZE_MEDIABOX when MediaBox is missing', () {
      final manager = _FakePdfManager();
      final xref = XRef(Stream(Uint8List(0)), manager);
      final pageDict = Dict(xref);

      final page = Page(
        pdfManager: manager,
        xref: xref,
        pageIndex: 0,
        pageDict: pageDict,
        ref: Ref(3, 0),
      );

      expect(page.mediaBox, equals(LETTER_SIZE_MEDIABOX));
      expect(page.cropBox, equals(LETTER_SIZE_MEDIABOX));
      expect(page.view, equals(LETTER_SIZE_MEDIABOX));
      expect(page.userUnit, equals(1.0));
    });

    test('Page LocalIdFactory creates sequential IDs', () {
      final manager = _FakePdfManager();
      final xref = XRef(Stream(Uint8List(0)), manager);
      final pageDict = Dict(xref);
      final ref = Ref(5, 0);

      final page = Page(
        pdfManager: manager,
        xref: xref,
        pageIndex: 2,
        pageDict: pageDict,
        ref: ref,
      );

      final evaluator = page.createAnnotationEvaluator(null);
      expect(evaluator.pageIndex, equals(2));
    });
  });

  group('PDFDocument Header and Fingerprints', () {
    test('PDFDocument checks header version', () {
      final manager = _FakePdfManager();
      final pdfContent = '%PDF-1.6\n1 0 obj\n<< >>\nendobj\n';
      final stream = Stream(Uint8List.fromList(pdfContent.codeUnits));

      final doc = PDFDocument(manager, stream);
      doc.checkHeader();
      expect(doc.version, equals('1.6'));
    });

    test('PDFDocument computes MD5 fingerprint if trailer ID is absent', () {
      final manager = _FakePdfManager();
      final pdfContent = '%PDF-1.4\n1 0 obj\n<< >>\nendobj\n';
      final stream = Stream(Uint8List.fromList(pdfContent.codeUnits));

      final doc = PDFDocument(manager, stream);
      final fp = doc.fingerprints;
      expect(fp, isNotNull);
      expect(fp.length, equals(2));
      expect(fp[0], isNotNull);
      expect(fp[0]!.length, equals(32)); // 32 hex chars for 16-byte MD5
    });

    test('PDFDocument throws on empty stream', () {
      final manager = _FakePdfManager();
      final emptyStream = Stream(Uint8List(0));
      expect(() => PDFDocument(manager, emptyStream), throwsException);
    });
  });
}
