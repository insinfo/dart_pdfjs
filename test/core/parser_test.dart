// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'package:test/test.dart';

import 'package:pdfjs/src/core/stream.dart';
import 'package:pdfjs/src/core/parser.dart';
import 'package:pdfjs/src/core/primitives.dart';

void main() {
  group('Lexer', () {
    test('parsea tokens simples corretamente', () {
      final stream = Stream(Uint8List.fromList("123 -4.5 /Name (String) [ 1 2 ] << /Key true >>".codeUnits));
      final lexer = Lexer(stream);

      expect(lexer.getObj(), equals(123));
      expect(lexer.getObj(), equals(-4.5));
      
      final name = lexer.getObj();
      expect(name, isA<Name>());
      expect((name as Name).name, equals("Name"));
      
      final str = lexer.getObj();
      expect(str, equals("String"));
      
      final arrayStart = lexer.getObj();
      expect(arrayStart, isA<Cmd>());
      expect((arrayStart as Cmd).cmd, equals("["));
      
      expect(lexer.getObj(), equals(1));
      expect(lexer.getObj(), equals(2));
      
      final arrayEnd = lexer.getObj();
      expect(arrayEnd, isA<Cmd>());
      expect((arrayEnd as Cmd).cmd, equals("]"));
      
      final dictStart = lexer.getObj();
      expect(dictStart, isA<Cmd>());
      expect((dictStart as Cmd).cmd, equals("<<"));
      
      final dictKey = lexer.getObj();
      expect((dictKey as Name).name, equals("Key"));
      
      expect(lexer.getObj(), isTrue);
      
      final dictEnd = lexer.getObj();
      expect((dictEnd as Cmd).cmd, equals(">>"));
      
      expect(lexer.getObj(), equals(eof));
    });

    test('parsea dicts com o Parser', () {
      final stream = Stream(Uint8List.fromList("<< /Type /Catalog /Pages 10 0 R >>".codeUnits));
      final parser = Parser(lexer: Lexer(stream));
      
      final dict = parser.getObj();
      expect(dict, isA<Dict>());
      final typedDict = dict as Dict;
      
      expect((typedDict.get("Type") as Name).name, equals("Catalog"));
      final ref = typedDict.getRaw("Pages");
      expect(ref, isA<Ref>());
      expect((ref as Ref).num, equals(10));
      expect(ref.gen, equals(0));
    });

    test('parsea numeros com erros de espacos mas recupera', () {
      final stream = Stream(Uint8List.fromList("1 2\n3\r4\r\n5".codeUnits));
      final lexer = Lexer(stream);
      expect(lexer.getObj(), equals(1));
      expect(lexer.getObj(), equals(2));
      expect(lexer.getObj(), equals(3));
      expect(lexer.getObj(), equals(4));
      expect(lexer.getObj(), equals(5));
    });
  });
}
