import 'dart:typed_data';
import 'package:test/test.dart';

import 'package:pdfjs/src/core/stream.dart';
import 'package:pdfjs/src/core/xref.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/parser.dart';

void main() {
  group('XRef', () {
    test('XRef table simple processing', () {
      final xrefStr = "xref\n0 1\n0000000000 65535 f \n1 2\n0000000010 00000 n \n0000000020 00000 n \ntrailer << /Size 3 >>";
      final stream = Stream(Uint8List.fromList(xrefStr.codeUnits));
      final parser = Parser(lexer: Lexer(stream));
      final xref = XRef(stream, null);
      
      parser.getObj(); // consome 'xref'
      
      final dict = xref.processXRefTable(parser);
      
      expect(dict, isA<Dict>());
      expect(dict.get("Size"), equals(3));
      
      expect(xref.entries.length, equals(3));
      expect(xref.entries[0]!.free, isTrue);
      expect(xref.entries[1]!.offset, equals(10));
      expect(xref.entries[1]!.uncompressed, isTrue);
      expect(xref.entries[2]!.offset, equals(20));
      expect(xref.entries[2]!.uncompressed, isTrue);
    });
  });
}
