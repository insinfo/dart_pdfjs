// Copyright 2017 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:test/test.dart';
import 'package:pdfjs/src/display/network_utils.dart';
import 'package:pdfjs/src/shared/util.dart';

void main() {
  group('network_utils', () {
    group('createHeaders', () {
      test('returns empty `Headers` for invalid input', () {
        final headersArr = [
          createHeaders(false, {'Content-Length': 100}),
          createHeaders(true, null),
          createHeaders(true, 'abc'),
          createHeaders(true, 123),
        ];

        for (final headers in headersArr) {
          expect(headers.toMap(), isEmpty);
        }
      });

      test('returns populated `Headers` for valid input', () {
        final headers = createHeaders(
          true,
          {
            'Content-Length': 100,
            'Accept-Ranges': 'bytes',
            'Dummy-null': null,
          },
        );

        expect(headers.toMap(), equals({
          'content-length': '100',
          'accept-ranges': 'bytes',
          'dummy-null': 'null',
        }));
      });
    });

    group('validateRangeRequestCapabilities', () {
      test('rejects invalid rangeChunkSize', () {
        expect(
          () => validateRangeRequestCapabilities(
            rangeChunkSize: 'abc',
            responseHeaders: Headers(),
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => validateRangeRequestCapabilities(
            rangeChunkSize: 0,
            responseHeaders: Headers(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects disabled or non-HTTP range requests', () {
        expect(
          validateRangeRequestCapabilities(
            disableRange: true,
            isHttp: true,
            responseHeaders: Headers({'Content-Length': 1024}),
            rangeChunkSize: 64,
          ),
          equals(RangeRequestCapabilities(
            isRangeSupported: false,
            contentLength: 1024,
          )),
        );

        expect(
          validateRangeRequestCapabilities(
            disableRange: false,
            isHttp: false,
            responseHeaders: Headers({'Content-Length': 1024}),
            rangeChunkSize: 64,
          ),
          equals(RangeRequestCapabilities(
            isRangeSupported: false,
            contentLength: 1024,
          )),
        );
      });

      test('rejects invalid Accept-Ranges header values', () {
        expect(
          validateRangeRequestCapabilities(
            disableRange: false,
            isHttp: true,
            responseHeaders: Headers({
              'Accept-Ranges': 'none',
              'Content-Length': 1024,
            }),
            rangeChunkSize: 64,
          ),
          equals(RangeRequestCapabilities(
            isRangeSupported: false,
            contentLength: 1024,
          )),
        );
      });

      test('rejects invalid Content-Encoding header values', () {
        expect(
          validateRangeRequestCapabilities(
            disableRange: false,
            isHttp: true,
            responseHeaders: Headers({
              'Accept-Ranges': 'bytes',
              'Content-Encoding': 'gzip',
              'Content-Length': 1024,
            }),
            rangeChunkSize: 64,
          ),
          equals(RangeRequestCapabilities(
            isRangeSupported: false,
            contentLength: 1024,
          )),
        );
      });

      test('rejects invalid Content-Length header values', () {
        expect(
          validateRangeRequestCapabilities(
            disableRange: false,
            isHttp: true,
            responseHeaders: Headers({
              'Accept-Ranges': 'bytes',
              'Content-Length': 'one thousand and twenty four',
            }),
            rangeChunkSize: 64,
          ),
          equals(RangeRequestCapabilities(
            isRangeSupported: false,
            contentLength: 0,
          )),
        );
      });

      test('rejects file sizes that are too small for range requests', () {
        expect(
          validateRangeRequestCapabilities(
            disableRange: false,
            isHttp: true,
            responseHeaders: Headers({
              'Accept-Ranges': 'bytes',
              'Content-Length': 128,
            }),
            rangeChunkSize: 64,
          ),
          equals(RangeRequestCapabilities(
            isRangeSupported: false,
            contentLength: 128,
          )),
        );
      });

      test('accepts file sizes large enough for range requests', () {
        expect(
          validateRangeRequestCapabilities(
            disableRange: false,
            isHttp: true,
            responseHeaders: Headers({
              'Accept-Ranges': 'bytes',
              'Content-Length': 1024,
            }),
            rangeChunkSize: 64,
          ),
          equals(RangeRequestCapabilities(
            isRangeSupported: true,
            contentLength: 1024,
          )),
        );
      });
    });

    group('extractFilenameFromHeader', () {
      test('returns null when content disposition header is blank', () {
        expect(extractFilenameFromHeader(Headers({})), isNull);
        expect(
            extractFilenameFromHeader(Headers({'Content-Disposition': ''})),
            isNull);
      });

      test('gets the filename from the response header', () {
        expect(
            extractFilenameFromHeader(
                Headers({'Content-Disposition': 'inline'})),
            isNull);

        expect(
            extractFilenameFromHeader(
                Headers({'Content-Disposition': 'attachment'})),
            isNull);

        expect(
          extractFilenameFromHeader(Headers(
              {'Content-Disposition': 'attachment; filename="filename.pdf"'})),
          equals('filename.pdf'),
        );

        expect(
          extractFilenameFromHeader(Headers({
            'Content-Disposition':
                'attachment; filename="filename.pdf and spaces.pdf"'
          })),
          equals('filename.pdf and spaces.pdf'),
        );

        expect(
          extractFilenameFromHeader(Headers(
              {'Content-Disposition': 'attachment; filename="tl;dr.pdf"'})),
          equals('tl;dr.pdf'),
        );

        expect(
          extractFilenameFromHeader(Headers(
              {'Content-Disposition': 'attachment; filename=filename.pdf'})),
          equals('filename.pdf'),
        );

        expect(
          extractFilenameFromHeader(Headers({
            'Content-Disposition':
                'attachment; filename=filename.pdf someotherparam'
          })),
          equals('filename.pdf'),
        );

        expect(
          extractFilenameFromHeader(Headers({
            'Content-Disposition':
                'attachment; filename="%e4%b8%ad%e6%96%87.pdf"'
          })),
          equals('中文.pdf'),
        );

        expect(
          extractFilenameFromHeader(Headers(
              {'Content-Disposition': 'attachment; filename="100%.pdf"'})),
          equals('100%.pdf'),
        );
      });

      test('gets the filename from the response header (RFC 6266)', () {
        expect(
          extractFilenameFromHeader(Headers(
              {'Content-Disposition': 'attachment; filename*=filename.pdf'})),
          equals('filename.pdf'),
        );

        expect(
          extractFilenameFromHeader(Headers(
              {'Content-Disposition': "attachment; filename*=''filename.pdf"})),
          equals('filename.pdf'),
        );

        expect(
          extractFilenameFromHeader(Headers({
            'Content-Disposition':
                "attachment; filename*=utf-8''filename.pdf"
          })),
          equals('filename.pdf'),
        );

        expect(
          extractFilenameFromHeader(Headers({
            'Content-Disposition':
                "attachment; filename=no.pdf; filename*=utf-8''filename.pdf"
          })),
          equals('filename.pdf'),
        );

        expect(
          extractFilenameFromHeader(Headers({
            'Content-Disposition':
                "attachment; filename*=utf-8''filename.pdf; filename=no.pdf"
          })),
          equals('filename.pdf'),
        );
      });

      test('gets the filename from the response header (RFC 2231)', () {
        expect(
          extractFilenameFromHeader(Headers({
            'Content-Disposition':
                'attachment; filename*0=filename; filename*1=.pdf'
          })),
          equals('filename.pdf'),
        );
      });

      test('only extracts filename with pdf extension', () {
        expect(
          extractFilenameFromHeader(Headers(
              {'Content-Disposition': 'attachment; filename="filename.png"'})),
          isNull,
        );
      });

      test('extension validation is case insensitive', () {
        expect(
          extractFilenameFromHeader(Headers({
            'Content-Disposition':
                'form-data; name="fieldName"; filename="file.PdF"'
          })),
          equals('file.PdF'),
        );
      });
    });

    group('createResponseError', () {
      void testCreateResponseError(Uri url, int status, bool missing) {
        final error = createResponseError(status, url);

        expect(error, isA<ResponseException>());
        expect(
          error.message,
          equals(
              'Unexpected server response ($status) while retrieving PDF "$url".'),
        );
        expect(error.status, equals(status));
        expect(error.missing, equals(missing));
      }

      test('handles missing PDF file responses', () {
        testCreateResponseError(Uri.parse('https://foo.com/bar.pdf'), 404, true);
        testCreateResponseError(Uri.parse('file://foo.pdf'), 0, true);
      });

      test('handles unexpected responses', () {
        testCreateResponseError(Uri.parse('https://foo.com/bar.pdf'), 302, false);
        testCreateResponseError(Uri.parse('https://foo.com/bar.pdf'), 0, false);
      });
    });
  });
}
