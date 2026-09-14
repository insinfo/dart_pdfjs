// Copyright 2026. Apache License 2.0.

import 'dart:typed_data';

import 'package:pdfjs/src/display/api_utils.dart';
import 'package:test/test.dart';

void main() {
  group('api_utils', () {
    test('normalizes URL, data and factory URL properties', () {
      expect(getUrlProp('https://example.com/file.pdf').host, 'example.com');
      expect(
          getUrlProp(Uri.parse('file:///document.pdf')).path, '/document.pdf');
      expect(getDataProp('PDF'), Uint8List.fromList([80, 68, 70]));
      expect(getDataProp([1, 2, 255]), Uint8List.fromList([1, 2, 255]));
      expect(getFactoryUrlProp('/assets/'), '/assets/');
      expect(getFactoryUrlProp(null), isNull);
      expect(() => getDataProp(Object()), throwsArgumentError);
      expect(() => getFactoryUrlProp('/assets'), throwsArgumentError);
    });

    test('recognizes Ref and Name proxy objects', () {
      expect(isRefProxy({'num': 1, 'gen': 0}), isTrue);
      expect(isRefProxy({'num': -1, 'gen': 0}), isFalse);
      expect(isNameProxy({'name': 'Fit'}), isTrue);
      expect(isNameProxy({'name': 1}), isFalse);
    });

    test('validates explicit destinations represented by proxies', () {
      expect(
          isValidExplicitDest([
            1,
            {'name': 'Fit'}
          ]),
          isTrue);
      expect(
        isValidExplicitDest([
          {'num': 10, 'gen': 0},
          {'name': 'XYZ'},
          null,
          20,
          1.5,
        ]),
        isTrue,
      );
      expect(
        isValidExplicitDest([
          1,
          {'name': 'FitR'},
          0,
          0,
          100,
          200
        ]),
        isTrue,
      );
      expect(
          isValidExplicitDest([
            1,
            {'name': 'Fit'},
            10
          ]),
          isFalse);
      expect(
        isValidExplicitDest([
          1,
          {'name': 'FitR'},
          0,
          null,
          100,
          200
        ]),
        isFalse,
      );
      expect(
          isValidExplicitDest([
            1,
            {'name': 'Unknown'}
          ]),
          isFalse);
    });
  });
}
