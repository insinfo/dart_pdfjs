import 'package:pdfjs/src/shared/obj_bin_transform_utils.dart';
import 'package:pdfjs/src/shared/scripting_utils.dart';
import 'package:test/test.dart';

void main() {
  group('scripting_utils', () {
    test('ColorConverters G and RGB conversions', () {
      expect(ColorConverters.gToRgb([0.5]), ['RGB', 0.5, 0.5, 0.5]);
      expect(ColorConverters.gToRgb255([0.5]), [127.5, 127.5, 127.5]);
      expect(ColorConverters.gToHtml([1.0]), '#ffffff');
      expect(ColorConverters.gToHtml([0.0]), '#000000');

      final rgbG = ColorConverters.rgbToG([1.0, 1.0, 1.0]);
      expect(rgbG[0], 'G');
      expect((rgbG[1] as num).toStringAsFixed(2), '1.00');

      expect(ColorConverters.rgbToHtml([1.0, 0.0, 0.0]), '#ff0000');
      expect(ColorConverters.tToHtml(), '#00000000');
    });

    test('ColorConverters CMYK conversions', () {
      final cmykG = ColorConverters.cmykToG([0, 0, 0, 0]);
      expect(cmykG, ['G', 1.0]);

      final cmykRgb = ColorConverters.cmykToRgb([0, 0, 0, 0]);
      expect(cmykRgb, ['RGB', 1.0, 1.0, 1.0]);

      final rgbCmyk = ColorConverters.rgbToCmyk([1.0, 1.0, 1.0]);
      expect(rgbCmyk, ['CMYK', 0.0, 0.0, 0.0, 0.0]);
    });

    test('dateFormats and timeFormats are populated', () {
      expect(dateFormats, contains('yy-mm-dd'));
      expect(timeFormats, contains('HH:MM'));
    });
  });

  group('obj_bin_transform_utils', () {
    test('FontInfo and PatternInfo offsets are correct', () {
      expect(FONT_INFO.offsetNumbers, greaterThan(0));
      expect(FONT_INFO.offsetBbox, greaterThan(FONT_INFO.offsetNumbers));
      expect(PATTERN_INFO.kind, 0);
      expect(PATTERN_INFO.nColor, 8);
    });
  });
}
