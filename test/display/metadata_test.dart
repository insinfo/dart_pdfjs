import 'package:pdfjs/src/core/metadata_parser.dart';
import 'package:pdfjs/src/display/metadata.dart';
import 'package:test/test.dart';

Metadata parseMetadata(String data) {
  final value = MetadataParser(data).serializable;
  return Metadata(parsedData: value.parsedData, rawData: value.rawData);
}

void main() {
  group('Metadata and MetadataParser', () {
    test('parses scalar and alternative metadata', () {
      final metadata = parseMetadata(
        "<x:xmpmeta xmlns:x='adobe:ns:meta/'>"
        "<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>"
        "<rdf:Description xmlns:dc='http://purl.org/dc/elements/1.1/'>"
        '<dc:title><rdf:Alt><rdf:li xml:lang="x-default">Foo bar baz</rdf:li>'
        '</rdf:Alt></dc:title></rdf:Description></rdf:RDF></x:xmpmeta>',
      );

      expect(metadata.get('dc:title'), 'Foo bar baz');
      expect(metadata.get('dc:qux'), isNull);
      expect(metadata.has('dc:title'), isTrue);
      expect(metadata.entries.map((entry) => entry.key), ['dc:title']);
    });

    test('repairs UTF-16 octal escapes and XML entities', () {
      final metadata = parseMetadata(
        "<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>"
        "<rdf:Description xmlns:dc='http://purl.org/dc/elements/1.1/'>"
        r'<dc:title>\376\377\000P\000D\000F\000&amp;</dc:title>'
        '</rdf:Description></rdf:RDF>',
      );
      expect(metadata.get('dc:title'), 'PDF&');
    });

    test('parses creator and subject sequences', () {
      final metadata = parseMetadata(
        "<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>"
        "<rdf:Description xmlns:dc='http://purl.org/dc/elements/1.1/'>"
        '<dc:creator><rdf:Seq><rdf:li>Ada</rdf:li><rdf:li>Linus</rdf:li>'
        '</rdf:Seq></dc:creator><dc:subject><rdf:Bag><rdf:li>PDF</rdf:li>'
        '</rdf:Bag></dc:subject></rdf:Description></rdf:RDF>',
      );
      expect(metadata.get('dc:creator'), ['Ada', 'Linus']);
      expect(metadata.get('dc:subject'), ['PDF']);
    });

    test('keeps empty metadata values and empty bags', () {
      final metadata = parseMetadata(
        "<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>"
        "<rdf:Description xmlns:dc='http://purl.org/dc/elements/1.1/'>"
        '<dc:title><rdf:Alt><rdf:li xml:lang="x-default"></rdf:li>'
        '</rdf:Alt></dc:title><dc:subject><rdf:Bag /></dc:subject>'
        '</rdf:Description></rdf:RDF>',
      );
      expect(metadata.get('dc:title'), '');
      expect(metadata.get('dc:subject'), isEmpty);
    });

    test('ignores incomplete documents without an RDF root', () {
      final metadata = parseMetadata(
        '<x:xmpmeta><rdf:Description><dc:title>bad</dc:title>'
        '</rdf:Description></x:xmpmeta>',
      );
      expect(metadata.entries, isEmpty);
    });

    test('does not expand declared entities', () {
      final metadata = parseMetadata(
        '<?xml version="1.0"?><!DOCTYPE lolz [<!ENTITY lol "lol">]>'
        "<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>"
        "<rdf:Description xmlns:dc='http://purl.org/dc/elements/1.1/'>"
        '<dc:title><rdf:Alt><rdf:li>a&lol;b</rdf:li></rdf:Alt></dc:title>'
        '</rdf:Description></rdf:RDF>',
      );
      expect(metadata.get('dc:title'), 'a&lol;b');
    });

    test('exposes the repaired raw metadata', () {
      final metadata = parseMetadata('junk<rdf:RDF></rdf:RDF>');
      expect(metadata.getRaw(), '<rdf:RDF></rdf:RDF>');
    });
  });
}
