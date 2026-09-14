// Copyright 2020 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/stream.dart';
import 'package:pdfjs/src/core/writer.dart';
import 'package:pdfjs/src/shared/util.dart';
import 'package:test/test.dart';

void main() {
  group('Writer', () {
    group('Incremental update', () {
      test('should update a file with new objects', () async {
        final originalData = Uint8List(0);
        final changes = RefSetCache();
        changes.put(Ref.get(123, 0x2d), {'data': 'abc\n'});
        changes.put(Ref.get(456, 0x4e), {'data': 'defg\n'});
        final xrefInfo = XRefInfo(
          newRef: Ref.get(789, 0),
          startXRef: 314,
          fileIds: ['id', ''],
          rootRef: null,
          infoRef: null,
          encryptRef: null,
          filename: 'foo.pdf',
          infoMap: {},
          time: 0,
        );

        var dataBytes = await incrementalUpdate(
          originalData: originalData,
          xrefInfo: xrefInfo,
          changes: changes,
          xref: {},
          useXrefStream: true,
        );
        var data = bytesToString(dataBytes);

        var expected = '\nabc\n'
            'defg\n'
            '789 0 obj\n'
            '<< /Prev 314 /Size 790 /Type /XRef /Index [123 1 456 1 789 1] '
            '/W [1 1 1] /ID [(id) (\xeb\x4b\x2a\xe7\x31\x36\xf0\xcd\x83\x35\x94\x2a\x36\xcf\xaa\xb0)] '
            '/Length 9>> stream\n'
            '\x01\x01\x2d'
            '\x01\x05\x4e'
            '\x01\x0a\x00\n'
            'endstream\n'
            'endobj\n'
            'startxref\n'
            '10\n'
            '%%EOF\n';
        expect(data, equals(expected));

        dataBytes = await incrementalUpdate(
          originalData: originalData,
          xrefInfo: xrefInfo,
          changes: changes,
          xref: {},
          useXrefStream: false,
        );
        data = bytesToString(dataBytes);

        expected = '\nabc\n'
            'defg\n'
            'xref\n'
            '123 1\n'
            '0000000001 00045 n\r\n'
            '456 1\n'
            '0000000005 00078 n\r\n'
            '789 1\n'
            '0000000010 00000 n\r\n'
            'trailer\n'
            '<< /Prev 314 /Size 789 '
            '/ID [(id) (\xeb\x4b\x2a\xe7\x31\x36\xf0\xcd\x83\x35\x94\x2a\x36\xcf\xaa\xb0)]>>\n'
            'startxref\n'
            '10\n'
            '%%EOF\n';
        expect(data, equals(expected));
      });

      test('should update a file, missing the /ID-entry, with new objects',
          () async {
        final originalData = Uint8List(0);
        final changes = RefSetCache();
        changes.put(Ref.get(123, 0x2d), {'data': 'abc\n'});
        final xrefInfo = XRefInfo(
          newRef: Ref.get(789, 0),
          startXRef: 314,
          fileIds: null,
          rootRef: null,
          infoRef: null,
          encryptRef: null,
          filename: 'foo.pdf',
          infoMap: {},
          time: 0,
        );

        final dataBytes = await incrementalUpdate(
          originalData: originalData,
          xrefInfo: xrefInfo,
          changes: changes,
          xref: {},
          useXrefStream: true,
        );
        final data = bytesToString(dataBytes);

        const expected = '\nabc\n'
            '789 0 obj\n'
            '<< /Prev 314 /Size 790 /Type /XRef /Index [123 1 789 1] '
            '/W [1 1 1] /Length 6>> stream\n'
            '\x01\x01\x2d'
            '\x01\x05\x00\n'
            'endstream\n'
            'endobj\n'
            'startxref\n'
            '5\n'
            '%%EOF\n';

        expect(data, equals(expected));
      });
    });

    group('writeDict', () {
      test('should write a Dict', () async {
        final dict = Dict(null);
        dict.set('A', Name.get('B'));
        dict.set('B', Ref.get(123, 456));
        dict.set('C', 789);
        dict.set('D', 'hello world');
        dict.set('E', '(hello\\world)');
        dict.set('F', [1.23001, 4.50001, 6]);

        final gdict = Dict(null);
        gdict.set('H', 123.00001);
        const string = 'a stream';
        final stream = StringStream(string);
        stream.dict = Dict(null);
        stream.dict!.set('Length', string.length);
        gdict.set('I', stream);

        dict.set('G', gdict);
        dict.set('J', true);
        dict.set('K', false);

        dict.set('NullArr', [null, 10]);
        dict.set('NullVal', null);

        final buffer = <String>[];
        await writeDict(dict, buffer, null);

        const expected = '<< /A /B /B 123 456 R /C 789 /D (hello world) '
            '/E (\\(hello\\\\world\\)) /F [1.23001 4.50001 6] '
            '/G << /H 123.00001 /I << /Length 8>> stream\n'
            'a stream\n'
            'endstream>> /J true /K false '
            '/NullArr [null 10] /NullVal null>>';

        expect(buffer.join(''), equals(expected));
      });

      test('should write a Dict in escaping PDF names', () async {
        final dict = Dict(null);
        dict.set('\xfeA#', Name.get('hello'));
        dict.set('B', Name.get('#hello'));
        dict.set('C', Name.get('he\xfello\xff'));

        final buffer = <String>[];
        await writeDict(dict, buffer, null);

        const expected = '<< /#feA#23 /hello /B /#23hello /C /he#fello#ff>>';

        expect(buffer.join(''), equals(expected));
      });
    });

    group('XFA', () {
      test('should update AcroForm when no datasets in XFA array', () async {
        final originalData = Uint8List(0);
        final changes = RefSetCache();

        final acroForm = Dict(null);
        acroForm.set('XFA', [
          'preamble',
          Ref.get(123, 0),
          'postamble',
          Ref.get(456, 0),
        ]);
        final acroFormRef = Ref.get(789, 0);
        final xfaDatasetsRef = Ref.get(101112, 0);
        const xfaData = '<hello>world</hello>';

        final xrefInfo = XRefInfo(
          newRef: Ref.get(131415, 0),
          startXRef: 314,
          fileIds: null,
          rootRef: null,
          infoRef: null,
          encryptRef: null,
          filename: 'foo.pdf',
          infoMap: {},
          time: 0,
        );

        final dataBytes = await incrementalUpdate(
          originalData: originalData,
          xrefInfo: xrefInfo,
          changes: changes,
          hasXfa: true,
          xfaDatasetsRef: xfaDatasetsRef,
          hasXfaDatasetsEntry: false,
          acroFormRef: acroFormRef,
          acroForm: acroForm,
          xfaData: xfaData,
          xref: {},
          useXrefStream: true,
        );
        final data = bytesToString(dataBytes);

        const expected = '\n'
            '789 0 obj\n'
            '<< /XFA [(preamble) 123 0 R (datasets) 101112 0 R (postamble) 456 0 R]>>\n'
            'endobj\n'
            '101112 0 obj\n'
            '<< /Type /EmbeddedFile /Length 20>> stream\n'
            '<hello>world</hello>\n'
            'endstream\n'
            'endobj\n'
            '131415 0 obj\n'
            '<< /Prev 314 /Size 131416 /Type /XRef /Index [789 1 101112 1 131415 1] /W [1 1 0] /Length 6>> stream\n'
            '\x01\x01\x01[\x01¹\n'
            'endstream\n'
            'endobj\n'
            'startxref\n'
            '185\n'
            '%%EOF\n';

        expect(data, equals(expected));
      });
    });

    group('writeValue numbers', () {
      Future<String> serialize(num value) async {
        final buffer = <String>[];
        await writeValue(value, buffer, null);
        return buffer.join('');
      }

      test('should write integers unchanged', () async {
        expect(await serialize(0), equals('0'));
        expect(await serialize(1), equals('1'));
        expect(await serialize(-42), equals('-42'));
        expect(await serialize(123456789), equals('123456789'));
      });

      test('should write normal floats without trailing zeros', () async {
        expect(await serialize(1.5), equals('1.5'));
        expect(await serialize(-3.14), equals('-3.14'));
        expect(await serialize(1.23001), equals('1.23001'));
        expect(await serialize(1.1), equals('1.1'));
        expect(await serialize(2.0), equals('2'));
      });

      test('should not use scientific notation for very small numbers',
          () async {
        expect(await serialize(0.000008), equals('0.000008'));
        expect(await serialize(0.000001), equals('0.000001'));
        expect(await serialize(0.0000001), equals('0.0000001'));
        expect(await serialize(-0.000008), equals('-0.000008'));
      });

      test('should not use scientific notation for very large numbers',
          () async {
        expect(await serialize(1e10), equals('10000000000'));
        expect(await serialize(1.5e6), equals('1500000'));
      });

      test('should round to at most 10 decimal places', () async {
        final result = await serialize(1 / 3);
        expect(RegExp(r'^0\.\d{1,10}$').hasMatch(result), isTrue);
        expect(result.replaceFirst('0.', '').length, lessThanOrEqualTo(10));
      });

      test('should handle zero and negative zero', () async {
        expect(await serialize(0), equals('0'));
        expect(await serialize(-0.0), equals('0'));
      });
    });

    test('should update a file with a deleted object', () async {
      final originalData = Uint8List(0);
      final changes = RefSetCache();
      changes.put(Ref.get(123, 0x2d), {'data': null});
      changes.put(Ref.get(456, 0x4e), {'data': 'abc\n'});
      final xrefInfo = XRefInfo(
        newRef: Ref.get(789, 0),
        startXRef: 314,
        fileIds: ['id', ''],
        rootRef: null,
        infoRef: null,
        encryptRef: null,
        filename: 'foo.pdf',
        infoMap: {},
        time: 0,
      );

      var dataBytes = await incrementalUpdate(
        originalData: originalData,
        xrefInfo: xrefInfo,
        changes: changes,
        xref: {},
        useXrefStream: true,
      );
      var data = bytesToString(dataBytes);

      var expected = '\nabc\n'
          '789 0 obj\n'
          '<< /Prev 314 /Size 790 /Type /XRef /Index [123 1 456 1 789 1] '
          '/W [1 1 1] /ID [(id) (\x5f\xd1\x43\x8e\xf8\x62\x79\x80\xbb\xd6\xf7\xb6\xd2\xb5\x6f\xd8)] '
          '/Length 9>> stream\n'
          '\x00\x00\x2e'
          '\x01\x01\x4e'
          '\x01\x05\x00\n'
          'endstream\n'
          'endobj\n'
          'startxref\n'
          '5\n'
          '%%EOF\n';
      expect(data, equals(expected));

      dataBytes = await incrementalUpdate(
        originalData: originalData,
        xrefInfo: xrefInfo,
        changes: changes,
        xref: {},
        useXrefStream: false,
      );
      data = bytesToString(dataBytes);

      expected = '\nabc\n'
          'xref\n'
          '123 1\n'
          '0000000000 00046 f\r\n'
          '456 1\n'
          '0000000001 00078 n\r\n'
          '789 1\n'
          '0000000005 00000 n\r\n'
          'trailer\n'
          '<< /Prev 314 /Size 789 '
          '/ID [(id) (\x5f\xd1\x43\x8e\xf8\x62\x79\x80\xbb\xd6\xf7\xb6\xd2\xb5\x6f\xd8)]>>\n'
          'startxref\n'
          '5\n'
          '%%EOF\n';
      expect(data, equals(expected));
    });
  });
}
