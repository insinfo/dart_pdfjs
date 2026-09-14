// Copyright 2017 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:pdfjs/src/core/predictor_stream.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/stream.dart';

void main() {
  group('stream', () {
    group('PredictorStream', () {
      test('should decode simple predictor data', () {
        final dict = Dict();
        dict.set('Predictor', 12);
        dict.set('Colors', 1);
        dict.set('BitsPerComponent', 8);
        dict.set('Columns', 2);

        final input = Stream(
          Uint8List.fromList([2, 100, 3, 2, 1, 255, 2, 1, 255]),
          0,
          9,
          dict,
        );
        final predictor = PredictorStream(input, 9, dict);
        final result = predictor.getBytes(6);

        expect(result, equals(Uint8List.fromList([100, 3, 101, 2, 102, 1])));
      });
    });
  });
}
