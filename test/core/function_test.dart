import 'package:pdfjs/src/core/function.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/stream.dart';
import 'package:test/test.dart';

void main() {
  group('PDFFunction', () {
    final factory = PDFFunctionFactory(xref: null);

    test('Type 2: Exponential interpolation function', () {
      final dict = Dict(null);
      dict.set('FunctionType', 2);
      dict.set('Domain', [0.0, 1.0]);
      dict.set('Range', [0.0, 10.0]);
      dict.set('C0', [0.0]);
      dict.set('C1', [10.0]);
      dict.set('N', 1.0);

      final fn = PDFFunction.parse(factory, dict);
      final dest = [0.0];

      fn([0.5], 0, dest, 0);
      expect(dest[0], closeTo(5.0, 0.001));

      fn([0.0], 0, dest, 0);
      expect(dest[0], closeTo(0.0, 0.001));

      fn([1.0], 0, dest, 0);
      expect(dest[0], closeTo(10.0, 0.001));
    });

    test('Type 4: PostScript calculator function', () {
      final dict = Dict(null);
      dict.set('FunctionType', 4);
      dict.set('Domain', [0.0, 100.0]);
      dict.set('Range', [0.0, 200.0]);

      // PS snippet: x * 2
      final stream = StringStream('{ 2 mul }')..dict = dict;

      final fn = PDFFunction.parse(factory, stream);
      final dest = [0.0];

      fn([15.0], 0, dest, 0);
      expect(dest[0], closeTo(30.0, 0.001));

      fn([60.0], 0, dest, 0);
      expect(dest[0], closeTo(120.0, 0.001));
    });

    test('Type 4: Conditional logic in PostScript calculator', () {
      final dict = Dict(null);
      dict.set('FunctionType', 4);
      dict.set('Domain', [0.0, 10.0]);
      dict.set('Range', [0.0, 100.0]);

      // If x > 5 then x * 10 else x * 2
      final stream = StringStream('{ dup 5 gt { 10 mul } { 2 mul } ifelse }')
        ..dict = dict;

      final fn = PDFFunction.parse(factory, stream);
      final dest = [0.0];

      fn([3.0], 0, dest, 0);
      expect(dest[0], closeTo(6.0, 0.001));

      fn([7.0], 0, dest, 0);
      expect(dest[0], closeTo(70.0, 0.001));
    });
  });
}
