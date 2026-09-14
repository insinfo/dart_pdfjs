import 'package:pdfjs/src/core/intersector.dart';
import 'package:test/test.dart';

class MockAnnotation {
  MockAnnotation(this.data);
  final Map<String, dynamic> data;
}

void main() {
  group('Intersector', () {
    test('captures glyphs intersecting annotation rectangle', () {
      final annot = MockAnnotation({
        'rect': [10, 10, 50, 50],
      });
      final intersector = Intersector([annot]);

      intersector.addGlyph([1, 0, 0, 1, 20, 20], 10, 10, 'A');
      intersector.addGlyph([1, 0, 0, 1, 100, 100], 10, 10, 'Z');
      intersector.setText();

      expect(annot.data['overlaidText'], 'A');
    });

    test('supports extra characters like spaces between glyphs', () {
      final annot = MockAnnotation({
        'rect': [0, 0, 100, 100],
      });
      final intersector = Intersector([annot]);

      intersector.addGlyph([1, 0, 0, 1, 10, 10], 5, 5, 'H');
      intersector.addExtraChar(' ');
      intersector.addGlyph([1, 0, 0, 1, 20, 10], 5, 5, 'i');
      intersector.setText();

      expect(annot.data['overlaidText'], 'H i');
    });
  });
}
