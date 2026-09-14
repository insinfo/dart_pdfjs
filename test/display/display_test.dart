// Copyright 2026. Apache License 2.0.

import 'package:pdfjs/src/display/annotation_storage.dart';
import 'package:pdfjs/src/display/content_disposition.dart';
import 'package:pdfjs/src/display/metadata.dart';
import 'package:pdfjs/src/display/network_utils.dart';
import 'package:pdfjs/src/display/optional_content_config.dart';
import 'package:pdfjs/src/display/pdf_objects.dart';
import 'package:pdfjs/src/display/worker_options.dart';
import 'package:test/test.dart';

void main() {
  group('Display - Metadata', () {
    test('Metadata returns parsed and raw data', () {
      final meta = Metadata(
        parsedData: {'title': 'PDF Spec', 'author': 'ISO'},
        rawData: '<xml>raw</xml>',
      );

      expect(meta.get('title'), equals('PDF Spec'));
      expect(meta.get('author'), equals('ISO'));
      expect(meta.get('nonexistent'), isNull);
      expect(meta.has('title'), isTrue);
      expect(meta.getRaw(), equals('<xml>raw</xml>'));
      expect(meta.entries.length, equals(2));
    });
  });

  group('Display - PDFObjects', () {
    test('PDFObjects resolve, get and async callback', () async {
      final objs = PDFObjects();
      expect(objs.has('obj_1'), isFalse);

      objs.resolve('obj_1', {'data': 123});
      expect(objs.has('obj_1'), isTrue);
      expect(objs.get('obj_1'), equals({'data': 123}));

      // Async get
      final asyncData = await objs.getAsync('obj_1');
      expect(asyncData, equals({'data': 123}));

      // Callback get
      dynamic callbackResult;
      objs.get('obj_1', (data) {
        callbackResult = data;
      });
      await Future.delayed(Duration.zero);
      expect(callbackResult, equals({'data': 123}));

      // Delete and clear
      expect(objs.delete('obj_1'), isTrue);
      expect(objs.has('obj_1'), isFalse);
    });

    test('PDFObjects throws on unresolved get without callback', () {
      final objs = PDFObjects();
      expect(() => objs.get('not_yet'), throwsStateError);
    });
  });

  group('Display - AnnotationStorage', () {
    test('AnnotationStorage handles setValue, getValue, modified state', () {
      final storage = AnnotationStorage();
      var modifiedCount = 0;
      var resetCount = 0;
      storage.onSetModified = () => modifiedCount++;
      storage.onResetModified = () => resetCount++;

      expect(storage.size, equals(0));
      storage.setValue('field1', {'value': 'Alice'});
      expect(storage.size, equals(1));
      expect(storage.has('field1'), isTrue);
      expect(modifiedCount, equals(1));

      final val = storage.getValue('field1', {'defaultValue': 'none'});
      expect(val['value'], equals('Alice'));

      final defaultVal = storage.getValue('nonexistent', {'defaultValue': 'fallback'});
      expect(defaultVal['defaultValue'], equals('fallback'));

      final ser = storage.serializable;
      expect(ser['map'], isNotNull);
      expect(ser['hash'], isNotEmpty);

      storage.remove('field1');
      expect(storage.size, equals(0));
      expect(resetCount, equals(1));
    });

    test('PrintAnnotationStorage freezes serializable data', () {
      final storage = AnnotationStorage();
      storage.setValue('field_print', {'val': '123'});

      final printStorage = storage.print;
      expect(printStorage.serializable['map'], isNotNull);
      expect(printStorage.serializable['hash'], equals(storage.serializable['hash']));
      expect(() => printStorage.print, throwsUnsupportedError);
    });
  });

  group('Display - OptionalContentConfig', () {
    test('OptionalContentConfig manages layer visibility and expressions', () {
      final data = {
        'name': 'Layers',
        'groups': [
          {'id': 'ocg1', 'name': 'Layer 1'},
          {'id': 'ocg2', 'name': 'Layer 2'},
        ],
        'baseState': 'ON',
        'on': ['ocg1'],
        'off': ['ocg2'],
      };

      final config = OptionalContentConfig(data);
      expect(config.name, equals('Layers'));
      expect(config.hasInitialVisibility, isTrue);

      // ocg1 is visible, ocg2 is hidden
      expect(config.isVisible({'type': 'OCG', 'id': 'ocg1'}), isTrue);
      expect(config.isVisible({'type': 'OCG', 'id': 'ocg2'}), isFalse);

      // OCMD with AnyOn policy
      expect(
        config.isVisible({
          'type': 'OCMD',
          'policy': 'AnyOn',
          'ids': ['ocg1', 'ocg2'],
        }),
        isTrue,
      );

      // OCMD with AllOn policy
      expect(
        config.isVisible({
          'type': 'OCMD',
          'policy': 'AllOn',
          'ids': ['ocg1', 'ocg2'],
        }),
        isFalse,
      );

      // Toggle ocg2
      config.setVisibility('ocg2', true);
      expect(config.isVisible({'type': 'OCG', 'id': 'ocg2'}), isTrue);
      expect(config.hasInitialVisibility, isFalse);
    });
  });

  group('Display - ContentDisposition and NetworkUtils', () {
    test('getFilenameFromContentDispositionHeader parses regular and encoded filenames', () {
      // Basic quoted filename
      expect(
        getFilenameFromContentDispositionHeader('attachment; filename="test.pdf"'),
        equals('test.pdf'),
      );

      // Unquoted filename
      expect(
        getFilenameFromContentDispositionHeader('inline; filename=document.pdf'),
        equals('document.pdf'),
      );

      // RFC 5987 filename*
      expect(
        getFilenameFromContentDispositionHeader("attachment; filename*=UTF-8''my%20report.pdf"),
        equals('my report.pdf'),
      );
    });

    test('NetworkUtils validates range requests and PDF filenames', () {
      expect(isPdfFile('doc.pdf'), isTrue);
      expect(isPdfFile('doc.PDF'), isTrue);
      expect(isPdfFile('doc.txt'), isFalse);

      final caps = validateRangeRequestCapabilities(
        responseHeaders: {
          'Content-Length': '100000',
          'Accept-Ranges': 'bytes',
          'Content-Encoding': 'identity',
        },
        isHttp: true,
        rangeChunkSize: 10000,
      );
      expect(caps.isRangeSupported, isTrue);
      expect(caps.contentLength, equals(100000));
    });

    test('GlobalWorkerOptions stores options', () {
      GlobalWorkerOptions.workerSrc = 'pdf.worker.js';
      expect(GlobalWorkerOptions.workerSrc, equals('pdf.worker.js'));
    });
  });
}
