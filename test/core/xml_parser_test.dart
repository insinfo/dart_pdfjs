import 'package:test/test.dart';

import 'package:pdfjs/src/core/core_utils.dart';
import 'package:pdfjs/src/core/xml_parser.dart';

void main() {
  group('SimpleXMLParser', () {
    test('parses elements, attributes, entities and cdata', () {
      final parser = SimpleXMLParser(hasAttributes: true);
      final document = parser.parseFromString(
        '<root id="a&amp;b"><child>Tom &amp; Jerry</child>'
        '<empty flag="yes"/><![CDATA[<raw>]]></root>',
      )!;

      final root = document.documentElement;
      expect(root.nodeName, 'root');
      expect(root.attributes!.single.name, 'id');
      expect(root.attributes!.single.value, 'a&b');
      expect(root.children[0].nodeName, 'child');
      expect(root.children[0].textContent, 'Tom & Jerry');
      expect(root.children[1].nodeName, 'empty');
      expect(root.children[1].attributes!.single.value, 'yes');
      expect(root.children[2].textContent, '<raw>');
    });

    test('lowercases names and links siblings after closing elements', () {
      final parser = SimpleXMLParser(lowerCaseName: true);
      final document = parser
          .parseFromString('<XMPMeta><RDF:RDF><A/><B/></RDF:RDF></XMPMeta>')!;

      final root = document.documentElement;
      expect(root.nodeName, 'xmpmeta');
      final rdf = root.firstChild!;
      expect(rdf.nodeName, 'rdf:rdf');
      expect(rdf.firstChild!.nodeName, 'a');
      expect(rdf.firstChild!.nextSibling!.nodeName, 'b');
    });

    test('returns null on malformed XML', () {
      final parser = SimpleXMLParser();

      expect(parser.parseFromString('<root><broken></root'), isNull);
    });

    test('dumps escaped XML', () {
      final parser = SimpleXMLParser(hasAttributes: true);
      final root = parser
          .parseFromString('<root a="1&amp;2">é &lt;</root>')!
          .documentElement;
      final buffer = <String>[];

      root.dump(buffer);

      expect(buffer.join(), '<root a="1&amp;2">&#xE9; &lt;</root>');
      expect(encodeToXmlString('A&B "é"'), 'A&amp;B &quot;&#xE9;&quot;');
    });
  });
}
