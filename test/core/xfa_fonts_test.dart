import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/xfa_fonts.dart';
import 'package:test/test.dart';

void main() {
  group('XFA Fonts', () {
    test('getXfaFontName finds registered fonts with normalization', () {
      final info1 = getXfaFontName('MyriadPro-Regular');
      expect(info1, isNotNull);
      expect(info1!.name, equals('LiberationSans-Regular'));
      expect(info1.factors, isNotNull);
      expect(info1.metrics?.lineHeight, closeTo(1.22, 0.05));

      final info2 = getXfaFontName('Calibri,Bold');
      expect(info2, isNotNull);
      expect(info2!.name, equals('LiberationSans-Bold'));

      final info3 = getXfaFontName('Helvetica');
      expect(info3, isNotNull);
      expect(info3!.name, equals('LiberationSans-Regular'));

      final infoArial = getXfaFontName('Arial-Bold');
      expect(infoArial, isNotNull);
      expect(infoArial!.factors, isNull);

      final unknown = getXfaFontName('Unknown-Font-XYZ');
      expect(unknown, isNull);
    });

    test('getXfaFontWidths computes rescaled widths array', () {
      final widths = getXfaFontWidths('Calibri-Regular');
      expect(widths, isNotNull);
      expect(widths!.isNotEmpty, isTrue);

      // Structure is: [charCode1, [w1, w2, ...], charCode2, ...]
      expect(widths[0], isA<int>());
      expect(widths[1], isA<List<double>>());

      final firstCode = widths[0] as int;
      final firstList = widths[1] as List<double>;
      expect(firstCode, isNonNegative);
      expect(firstList.isNotEmpty, isTrue);
      expect(firstList[0], isPositive);
    });

    test('getXfaFontDict builds valid PDF font dictionary', () {
      final dict = getXfaFontDict('Helvetica-Bold');
      expect(dict, isNotNull);

      final baseFont = dict.get('BaseFont') as Name;
      expect(baseFont.name, equals('Helvetica-Bold'));

      final type = dict.get('Type') as Name;
      expect(type.name, equals('Font'));

      final subtype = dict.get('Subtype') as Name;
      expect(subtype.name, equals('CIDFontType2'));

      final encoding = dict.get('Encoding') as Name;
      expect(encoding.name, equals('Identity-H'));

      final cidToGid = dict.get('CIDToGIDMap') as Name;
      expect(cidToGid.name, equals('Identity'));

      final w = dict.get('W') as List<dynamic>?;
      expect(w, isNotNull);
      expect(w!.isNotEmpty, isTrue);

      final firstChar = dict.get('FirstChar');
      expect(firstChar, equals(w[0]));

      final lastChar = dict.get('LastChar') as int?;
      expect(lastChar, isNotNull);
      expect(lastChar, greaterThanOrEqualTo(firstChar as int));

      final descriptor = dict.get('FontDescriptor') as Dict?;
      expect(descriptor, isNotNull);

      final cidSystemInfo = dict.get('CIDSystemInfo') as Dict?;
      expect(cidSystemInfo, isNotNull);
      expect(cidSystemInfo!.get('Registry'), equals('Adobe'));
      expect(cidSystemInfo.get('Ordering'), equals('Identity'));
      expect(cidSystemInfo.get('Supplement'), equals(0));
    });
  });
}
