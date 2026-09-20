import 'package:pdfjs/src/core/xfa/utils.dart';
import 'package:test/test.dart';

void main() {
  group('XFA utils', () {
    test('stripQuotes follows the source slicing behavior', () {
      expect(stripQuotes("'hello'"), 'hello');
      expect(stripQuotes('"hello"'), 'hello');
      expect(stripQuotes('hello'), 'hello');
    });

    test('integer and float parsing accepts numeric prefixes', () {
      expect(
        getInteger(data: ' 42px', defaultValue: 7, validate: (x) => x > 0),
        42,
      );
      expect(
        getInteger(data: '-2', defaultValue: 7, validate: (x) => x > 0),
        7,
      );
      expect(
        getFloat(data: ' 1.25em', defaultValue: 3, validate: (x) => x < 2),
        1.25,
      );
    });

    test('keywords and options use defaults for invalid input', () {
      expect(
        getKeyword(
          data: ' yes ',
          defaultValue: 'no',
          validate: (x) => x == 'yes',
        ),
        'yes',
      );
      expect(getStringOption('other', ['left', 'right']), 'left');
    });

    test('measurements are converted to points', () {
      expect(getMeasurement('1in'), 72);
      expect(getMeasurement('2.54cm'), closeTo(72, 1e-10));
      expect(getMeasurement('25.4mm'), closeTo(72, 1e-10));
      expect(getMeasurement('12px'), 12);
      expect(getMeasurement('bad', '3pt'), 3);
      expect(getMeasurement('', ''), 0);
    });

    test('ratios and relevant entries retain PDF.js semantics', () {
      expect(getRatio(null), (num: 1.0, den: 1.0));
      expect(getRatio('4'), (num: 4.0, den: 1.0));
      expect(getRatio('bad:2'), (num: 2.0, den: 1.0));
      expect(getRelevant('+screen -print'), [
        (excluded: false, viewname: 'screen'),
        (excluded: true, viewname: 'print'),
      ]);
    });

    test('colors are clamped and invalid channels become zero', () {
      expect(getColor('260, -3, nope'), (r: 255, g: 0, b: 0));
      expect(getColor('1,2', [4, 5, 6]), (r: 4, g: 5, b: 6));
    });

    test('bounding boxes reject incomplete and negative sizes', () {
      expect(getBBox('1in,2pt,3cm,4mm').x, 72);
      expect(
          getBBox('0,0,-1,3'), (x: -1.0, y: -1.0, width: -1.0, height: -1.0));
      expect(getBBox('1,2,3'), (x: -1.0, y: -1.0, width: -1.0, height: -1.0));
    });

    test('HTMLResult exposes reusable sentinels and factories', () {
      expect(identical(HTMLResult.FAILURE, HTMLResult.FAILURE), isTrue);
      expect(HTMLResult.EMPTY.success, isTrue);
      final broken = HTMLResult.fromBreakNode(Object());
      expect(broken.isBreak(), isTrue);
      final successful = HTMLResult.withSuccess('node', [1, 2, 3, 4]);
      expect(successful.success, isTrue);
      expect(successful.html, 'node');
    });
  });
}
