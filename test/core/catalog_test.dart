import 'package:pdfjs/src/core/catalog.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:test/test.dart';

void main() {
  group('Catalog.parseDestDictionary', () {
    test('parses URI actions', () {
      final action = Dict()
        ..set('S', Name.get('URI'))
        ..set('URI', 'www.example.com.br/path');
      final dict = Dict()..set('A', action);
      final result = <String, dynamic>{};

      Catalog.parseDestDictionary(destDict: dict, resultObj: result);

      expect(result['url'], 'http://www.example.com.br/path');
      expect(result['unsafeUrl'], 'www.example.com.br/path');
    });

    test('parses explicit GoTo destinations', () {
      final dest = [Ref.get(10, 0), Name.get('Fit')];
      final action = Dict()
        ..set('S', Name.get('GoTo'))
        ..set('D', dest);
      final dict = Dict()..set('A', action);
      final result = <String, dynamic>{};

      Catalog.parseDestDictionary(destDict: dict, resultObj: result);

      expect(result['dest'], same(dest));
    });

    test('parses named and optional content actions', () {
      final namedAction = Dict()
        ..set('S', Name.get('Named'))
        ..set('N', Name.get('NextPage'));
      final namedResult = <String, dynamic>{};

      Catalog.parseDestDictionary(
        destDict: Dict()..set('A', namedAction),
        resultObj: namedResult,
      );
      expect(namedResult['action'], 'NextPage');

      final ocgAction = Dict()
        ..set('S', Name.get('SetOCGState'))
        ..set('State', [Name.get('ON'), Ref.get(3, 0)])
        ..set('PreserveRB', false);
      final ocgResult = <String, dynamic>{};

      Catalog.parseDestDictionary(
        destDict: Dict()..set('A', ocgAction),
        resultObj: ocgResult,
      );
      expect(ocgResult['setOCGState'], {
        'state': ['ON', '3R'],
        'preserveRB': false,
      });
    });
  });
}
