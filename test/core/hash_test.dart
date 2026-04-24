import 'dart:convert';
import 'dart:typed_data';
import 'package:test/test.dart';

import 'package:pdfjs/src/core/calculate_md5.dart';
import 'package:pdfjs/src/core/calculate_sha256.dart';
import 'package:pdfjs/src/core/calculate_sha_other.dart';

String bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
}

void main() {
  group('Hashing Algorithms', () {
    test('calculateMD5', () {
      final input1 = utf8.encode('hello');
      final hash1 = calculateMD5(input1, 0, input1.length);
      expect(bytesToHex(hash1), '5d41402abc4b2a76b9719d911017c592');

      final input2 = utf8.encode('The quick brown fox jumps over the lazy dog');
      final hash2 = calculateMD5(input2, 0, input2.length);
      expect(bytesToHex(hash2), '9e107d9d372bb6826bd81d3542a419d6');
    });

    test('calculateSHA256', () {
      final input1 = utf8.encode('hello');
      final hash1 = calculateSHA256(input1, 0, input1.length);
      expect(bytesToHex(hash1), '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824');

      final input2 = utf8.encode('The quick brown fox jumps over the lazy dog');
      final hash2 = calculateSHA256(input2, 0, input2.length);
      expect(bytesToHex(hash2), 'd7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592');
    });

    test('calculateSHA384', () {
      final input1 = utf8.encode('hello');
      final hash1 = calculateSHA384(input1, 0, input1.length);
      expect(bytesToHex(hash1), '59e1748777448c69de6b800d7a33bbfb9ff1b463e44354c3553bcdb9c666fa90125a3c79f90397bdf5f6a13de828684f');

      final input2 = utf8.encode('The quick brown fox jumps over the lazy dog');
      final hash2 = calculateSHA384(input2, 0, input2.length);
      expect(bytesToHex(hash2), 'ca737f1014a48f4c0b6dd43cb177b0afd9e5169367544c494011e3317dbf9a509cb1e5dc1e85a941bbee3d7f2afbc9b1');
    });

    test('calculateSHA512', () {
      final input1 = utf8.encode('hello');
      final hash1 = calculateSHA512(input1, 0, input1.length);
      expect(bytesToHex(hash1), '9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca72323c3d99ba5c11d7c7acc6e14b8c5da0c4663475c2e5c3adef46f73bcdec043');

      final input2 = utf8.encode('The quick brown fox jumps over the lazy dog');
      final hash2 = calculateSHA512(input2, 0, input2.length);
      expect(bytesToHex(hash2), '07e547d9586f6a73f73fbac0435ed76951218fb7d0c8d788a309d785436bbb642e93a252a954f23912547d1e8a3b5ed6e1bfd7097821233fa0538f3db854fee6');
    });
  });
}
