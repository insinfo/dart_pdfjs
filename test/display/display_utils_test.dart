// Copyright 2017 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:test/test.dart';
import 'package:pdfjs/src/display/display_utils.dart';

void main() {
  group('display_utils', () {
    group('getFilenameFromUrl', () {
      test('should get the filename from an absolute URL', () {
        const url = 'https://server.org/filename.pdf';
        expect(getFilenameFromUrl(url), equals('filename.pdf'));
      });

      test('should get the filename from a relative URL', () {
        const url = '../../filename.pdf';
        expect(getFilenameFromUrl(url), equals('filename.pdf'));
      });

      test('should get the filename from a URL with an anchor', () {
        const url = 'https://server.org/filename.pdf#foo';
        expect(getFilenameFromUrl(url), equals('filename.pdf'));
      });

      test('should get the filename from a URL with query parameters', () {
        const url = 'https://server.org/filename.pdf?foo=bar';
        expect(getFilenameFromUrl(url), equals('filename.pdf'));
      });
    });

    group('getPdfFilenameFromUrl', () {
      test('gets PDF filename', () {
        expect(getPdfFilenameFromUrl('/pdfs/file1.pdf'), equals('file1.pdf'));
        expect(
          getPdfFilenameFromUrl('http://www.example.com/pdfs/file2.pdf'),
          equals('file2.pdf'),
        );
      });

      test('gets fallback filename', () {
        expect(getPdfFilenameFromUrl('/pdfs/file1.txt'), equals('document.pdf'));
        expect(
          getPdfFilenameFromUrl('http://www.example.com/pdfs/file2.txt'),
          equals('document.pdf'),
        );
      });

      test('gets custom fallback filename', () {
        expect(
          getPdfFilenameFromUrl('/pdfs/file1.txt', 'qwerty1.pdf'),
          equals('qwerty1.pdf'),
        );
        expect(
          getPdfFilenameFromUrl(
              'http://www.example.com/pdfs/file2.txt', 'qwerty2.pdf'),
          equals('qwerty2.pdf'),
        );
        expect(getPdfFilenameFromUrl('/pdfs/file3.txt', ''), equals(''));
      });

      test('gets fallback filename when url is not a string', () {
        expect(getPdfFilenameFromUrl(null), equals('document.pdf'));
        expect(getPdfFilenameFromUrl(null, 'file.pdf'), equals('file.pdf'));
      });

      test('gets PDF filename from URL containing leading/trailing whitespace',
          () {
        expect(
            getPdfFilenameFromUrl('   /pdfs/file1.pdf   '), equals('file1.pdf'));
        expect(
          getPdfFilenameFromUrl('   http://www.example.com/pdfs/file2.pdf   '),
          equals('file2.pdf'),
        );
      });

      test('gets PDF filename from query string', () {
        expect(
          getPdfFilenameFromUrl('/pdfs/pdfs.html?name=file1.pdf'),
          equals('file1.pdf'),
        );
        expect(
          getPdfFilenameFromUrl(
              'http://www.example.com/pdfs/pdf.html?file2.pdf'),
          equals('file2.pdf'),
        );
      });

      test('gets PDF filename from hash string', () {
        expect(
          getPdfFilenameFromUrl('/pdfs/pdfs.html#name=file1.pdf'),
          equals('file1.pdf'),
        );
        expect(
          getPdfFilenameFromUrl(
              'http://www.example.com/pdfs/pdf.html#file2.pdf'),
          equals('file2.pdf'),
        );
      });

      test('gets correct PDF filename when multiple ones are present', () {
        expect(
          getPdfFilenameFromUrl('/pdfs/file1.pdf?name=file.pdf'),
          equals('file1.pdf'),
        );
        expect(
          getPdfFilenameFromUrl(
              'http://www.example.com/pdfs/file2.pdf#file.pdf'),
          equals('file2.pdf'),
        );
      });

      test('gets PDF filename from URI-encoded data', () {
        final encodedUrl =
            Uri.encodeComponent('http://www.example.com/pdfs/file1.pdf');
        expect(getPdfFilenameFromUrl(encodedUrl), equals('file1.pdf'));

        final encodedUrlWithQuery =
            Uri.encodeComponent('http://www.example.com/pdfs/file.txt?file2.pdf');
        expect(getPdfFilenameFromUrl(encodedUrlWithQuery), equals('file2.pdf'));
      });

      test('gets PDF filename from data mistaken for URI-encoded', () {
        expect(getPdfFilenameFromUrl('/pdfs/%AA.pdf'), equals('%AA.pdf'));
        expect(getPdfFilenameFromUrl('/pdfs/%2F.pdf'), equals('%2F.pdf'));
      });

      test('gets PDF filename from (some) standard protocols', () {
        expect(
          getPdfFilenameFromUrl('http://www.example.com/file1.pdf'),
          equals('file1.pdf'),
        );
        expect(
          getPdfFilenameFromUrl('https://www.example.com/file2.pdf'),
          equals('file2.pdf'),
        );
        expect(
          getPdfFilenameFromUrl('file:///path/to/files/file3.pdf'),
          equals('file3.pdf'),
        );
        expect(
          getPdfFilenameFromUrl('ftp://www.example.com/file4.pdf'),
          equals('file4.pdf'),
        );
      });

      test('gets PDF filename from query string appended to "blob:" URL', () {
        const blobUrl = 'blob:http://localhost:8080/uuid-1234';
        expect(getPdfFilenameFromUrl('$blobUrl?file.pdf'), equals('file.pdf'));
      });

      test('gets fallback filename from query string appended to "data:" URL',
          () {
        const dataUrl = 'data:application/pdf;base64,AAAA';
        expect(
          getPdfFilenameFromUrl('$dataUrl?file1.pdf'),
          equals('document.pdf'),
        );
        expect(
          getPdfFilenameFromUrl('     $dataUrl?file2.pdf'),
          equals('document.pdf'),
        );
      });

      test('gets PDF filename with a hash sign', () {
        expect(
          getPdfFilenameFromUrl('/foo.html?file=foo%23.pdf'),
          equals('foo#.pdf'),
        );
        expect(
          getPdfFilenameFromUrl('/foo.html?file=%23.pdf'),
          equals('#.pdf'),
        );
        expect(
          getPdfFilenameFromUrl('/foo.html?foo%23.pdf'),
          equals('foo#.pdf'),
        );
        expect(
          getPdfFilenameFromUrl('/foo%23.pdf?a=b#c'),
          equals('foo#.pdf'),
        );
        expect(
          getPdfFilenameFromUrl('foo.html#%23.pdf'),
          equals('#.pdf'),
        );
      });
    });

    group('isValidFetchUrl', () {
      test('handles invalid Fetch URLs', () {
        expect(isValidFetchUrl(null), isFalse);
        expect(isValidFetchUrl(100), isFalse);
        expect(isValidFetchUrl('foo'), isFalse);
        expect(isValidFetchUrl('/foo', 100), isFalse);
      });

      test('handles relative Fetch URLs', () {
        expect(isValidFetchUrl('/foo', 'file://www.example.com'), isFalse);
        expect(isValidFetchUrl('/foo', 'http://www.example.com'), isTrue);
      });

      test('handles unsupported Fetch protocols', () {
        expect(isValidFetchUrl('file://www.example.com'), isFalse);
        expect(isValidFetchUrl('ftp://www.example.com'), isFalse);
      });

      test('handles supported Fetch protocols', () {
        expect(isValidFetchUrl('http://www.example.com'), isTrue);
        expect(isValidFetchUrl('https://www.example.com'), isTrue);
      });
    });

    group('PDFDateString', () {
      test('converts PDF date strings to DateTime objects', () {
        final expectations = <String?, DateTime?>{
          'D:2019': DateTime.utc(2019, 1, 1, 0, 0, 0),
          'D:20190': DateTime.utc(2019, 1, 1, 0, 0, 0),
          'D:201900': DateTime.utc(2019, 1, 1, 0, 0, 0),
          'D:201913': DateTime.utc(2019, 1, 1, 0, 0, 0),
          'D:201902': DateTime.utc(2019, 2, 1, 0, 0, 0),
          'D:2019020': DateTime.utc(2019, 2, 1, 0, 0, 0),
          'D:20190200': DateTime.utc(2019, 2, 1, 0, 0, 0),
          'D:20190232': DateTime.utc(2019, 2, 1, 0, 0, 0),
          'D:20190203': DateTime.utc(2019, 2, 3, 0, 0, 0),
          'D:201902030': DateTime.utc(2019, 2, 3, 0, 0, 0),
          'D:2019020300': DateTime.utc(2019, 2, 3, 0, 0, 0),
          'D:2019020324': DateTime.utc(2019, 2, 3, 0, 0, 0),
          'D:2019020304': DateTime.utc(2019, 2, 3, 4, 0, 0),
          'D:20190203040': DateTime.utc(2019, 2, 3, 4, 0, 0),
          'D:201902030400': DateTime.utc(2019, 2, 3, 4, 0, 0),
          'D:201902030460': DateTime.utc(2019, 2, 3, 4, 0, 0),
          'D:201902030405': DateTime.utc(2019, 2, 3, 4, 5, 0),
          'D:2019020304050': DateTime.utc(2019, 2, 3, 4, 5, 0),
          'D:20190203040500': DateTime.utc(2019, 2, 3, 4, 5, 0),
          'D:20190203040560': DateTime.utc(2019, 2, 3, 4, 5, 0),
          'D:20190203040506': DateTime.utc(2019, 2, 3, 4, 5, 6),
          'D:20190203040506F': DateTime.utc(2019, 2, 3, 4, 5, 6),
          'D:20190203040506Z': DateTime.utc(2019, 2, 3, 4, 5, 6),
          'D:20190203040506-': DateTime.utc(2019, 2, 3, 4, 5, 6),
          'D:20190203040506+': DateTime.utc(2019, 2, 3, 4, 5, 6),
          'D:20190203040506+\'': DateTime.utc(2019, 2, 3, 4, 5, 6),
          'D:20190203040506+0': DateTime.utc(2019, 2, 3, 4, 5, 6),
          'D:20190203040506+01': DateTime.utc(2019, 2, 3, 3, 5, 6),
          'D:20190203040506+00\'': DateTime.utc(2019, 2, 3, 4, 5, 6),
          'D:20190203040506+24\'': DateTime.utc(2019, 2, 3, 4, 5, 6),
          'D:20190203040506+01\'': DateTime.utc(2019, 2, 3, 3, 5, 6),
          'D:20190203040506+01\'0': DateTime.utc(2019, 2, 3, 3, 5, 6),
          'D:20190203040506+01\'00': DateTime.utc(2019, 2, 3, 3, 5, 6),
          'D:20190203040506+01\'60': DateTime.utc(2019, 2, 3, 3, 5, 6),
          'D:20190203040506+0102': DateTime.utc(2019, 2, 3, 3, 3, 6),
          'D:20190203040506+01\'02': DateTime.utc(2019, 2, 3, 3, 3, 6),
          'D:20190203040506+01\'02\'': DateTime.utc(2019, 2, 3, 3, 3, 6),
          'D:20190203040506+05\'07': DateTime.utc(2019, 2, 2, 22, 58, 6),
        };

        for (final entry in expectations.entries) {
          final result = PDFDateString.toDateObject(entry.key);
          expect(result, isNotNull, reason: 'failed on input: ${entry.key}');
          expect(
            result!.millisecondsSinceEpoch,
            equals(entry.value!.millisecondsSinceEpoch),
            reason: 'diff on input: ${entry.key}',
          );
        }

        expect(PDFDateString.toDateObject(null), isNull);
        expect(PDFDateString.toDateObject(42), isNull);
        expect(PDFDateString.toDateObject('2019'), isNull);
        expect(PDFDateString.toDateObject('D2019'), isNull);
        expect(PDFDateString.toDateObject('D:'), isNull);
        expect(PDFDateString.toDateObject('D:201'), isNull);

        final now = DateTime.now();
        expect(PDFDateString.toDateObject(now), equals(now));
      });
    });

    group('findContrastColor', () {
      test('Check that the lightness is changed correctly', () {
        expect(
          findContrastColor([210, 98, 76], [197, 113, 89]),
          equals('#260e09'),
        );
      });
    });

    group('applyOpacity', () {
      test('Check that the opacity is applied correctly', () {
        expect(
          applyOpacity([123, 45, 67], 0.8),
          equals([149, 87, 105]),
        );
      });
    });

    group('PageViewport', () {
      test('transforms points and boxes correctly', () {
        final viewport = PageViewport(
          viewBox: [0, 0, 100, 200],
          scale: 1.5,
          rotation: 0,
        );

        expect(viewport.width, equals(150.0));
        expect(viewport.height, equals(300.0));

        final p = viewport.convertToViewportPoint(10, 20);
        expect(p[0], equals(15.0));
        expect(p[1], equals(270.0)); // flipped y by default

        final back = viewport.convertToPdfPoint(p[0], p[1]);
        expect(back[0], closeTo(10.0, 1e-5));
        expect(back[1], closeTo(20.0, 1e-5));
      });
    });
  });
}
