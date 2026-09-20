import 'package:pdfjs/src/scripting_api/color.dart';
import 'package:test/test.dart';

void main() {
  final color = Color();

  test('exposes Acrobat color constants', () {
    expect(color.transparent, ['T']);
    expect(color.red, ['RGB', 1, 0, 0]);
    expect(color.cyan, ['CMYK', 1, 0, 0, 0]);
    expect(color.dkGray, ['G', 0.25]);
  });

  test('validates spaces and component arrays', () {
    expect(Color.isValidSpace('RGB'), isTrue);
    expect(Color.isValidSpace(1), isFalse);
    expect(Color.isValidColor(['G', 0.5]), isTrue);
    expect(Color.isValidColor(['RGB', 0, 0.5, 1]), isTrue);
    expect(Color.isValidColor(['RGB', 0, 1]), isFalse);
    expect(Color.isValidColor(['G', double.nan]), isFalse);
    expect(Color.isValidColor(['G', 2]), isFalse);
    expect(Color.isValidColor('G'), isFalse);
  });

  test('converts colors and applies the JavaScript fallbacks', () {
    expect(color.convert(['G', 0.5], 'RGB'), ['RGB', 0.5, 0.5, 0.5]);
    final gray = color.convert(['RGB', 1, 1, 1], 'G');
    expect(gray[0], 'G');
    expect(gray[1], closeTo(1, 1e-14));
    expect(color.convert(['T'], 'RGB'), ['RGB', 0, 0, 0]);
    expect(color.convert(['RGB', 1, 0, 0], 'T'), ['T']);
    expect(color.convert(['bad'], 'RGB'), ['RGB', 0, 0, 0]);
    expect(identical(color.convert(['G', 0], 'bad'), color.black), isTrue);
  });

  test('compares colors, converting spaces when required', () {
    expect(color.equal(['G', 0], ['RGB', 0, 0, 0]), isTrue);
    // JavaScript uses strict numeric equality; no epsilon is applied.
    expect(color.equal(['G', 1], ['RGB', 1, 1, 1]), isFalse);
    expect(color.equal(['T'], ['T']), isTrue);
    expect(color.equal(['T'], ['G', 0]), isFalse);
    expect(color.equal(null, ['G', 0]), isTrue);
    expect(color.equal(['RGB', 1, 0, 0], ['RGB', 0, 1, 0]), isFalse);
  });
}
