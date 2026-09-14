import 'package:pdfjs/src/core/default_appearance.dart';
import 'package:test/test.dart';

void main() {
  group('default_appearance', () {
    test('parseDefaultAppearance extracts font name and size', () {
      final res = parseDefaultAppearance('/Helv 12 Tf 0 g');
      expect(res.fontName, 'Helv');
      expect(res.fontSize, 12.0);
      expect(res.fontColor, [0, 0, 0]);
    });

    test('parseDefaultAppearance extracts RGB color', () {
      final res = parseDefaultAppearance('/TimesNewRoman 14 Tf 1 0 0 rg');
      expect(res.fontName, 'TimesNewRoman');
      expect(res.fontSize, 14.0);
      expect(res.fontColor, [255, 0, 0]);
    });

    test('createDefaultAppearance formats standard DA string', () {
      final da = createDefaultAppearance(
        fontName: 'Helv',
        fontSize: 12,
        fontColor: [255, 0, 0],
      );
      expect(da, '/Helv 12 Tf 1 0 0 rg');

      final daGray = createDefaultAppearance(
        fontName: 'Helv',
        fontSize: 10,
        fontColor: [0, 0, 0],
      );
      expect(daGray, '/Helv 10 Tf 0 g');
    });

    test('getPdfColor returns gray operator when components match', () {
      expect(getPdfColor([0, 0, 0], true), '0 g');
      expect(getPdfColor([255, 255, 255], false), '1 G');
      expect(getPdfColor([255, 0, 0], true), '1 0 0 rg');
    });
  });
}
