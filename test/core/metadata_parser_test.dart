import 'package:test/test.dart';

import 'package:pdfjs/src/core/metadata_parser.dart';

void main() {
  group('MetadataParser', () {
    test('parses scalar and array XMP entries', () {
      final parser = MetadataParser('junk before xml'
          '<x:xmpmeta>'
          '<rdf:RDF>'
          '<rdf:Description>'
          '<dc:title> Example title </dc:title>'
          '<dc:creator><rdf:Seq><rdf:li>Alice</rdf:li><rdf:li>Bob</rdf:li></rdf:Seq></dc:creator>'
          '<dc:subject><rdf:Bag><rdf:li>pdf</rdf:li><rdf:li>dart</rdf:li></rdf:Bag></dc:subject>'
          '</rdf:Description>'
          '</rdf:RDF>'
          '</x:xmpmeta>');

      final serializable = parser.serializable;

      expect(serializable.rawData.startsWith('<x:xmpmeta>'), isTrue);
      expect(serializable.parsedData['dc:title'], 'Example title');
      expect(serializable.parsedData['dc:creator'], ['Alice', 'Bob']);
      expect(serializable.parsedData['dc:subject'], ['pdf', 'dart']);
    });

    test('repairs Ghostscript UTF-16 octal metadata', () {
      final parser = MetadataParser(
        '<rdf:RDF><rdf:Description><dc:title>'
        r'\376\377\000A\000&amp;\000B'
        '</dc:title></rdf:Description></rdf:RDF>',
      );

      expect(parser.serializable.parsedData['dc:title'], 'A&B');
      expect(parser.serializable.rawData, contains('A&#x0026;B'));
    });
  });
}
