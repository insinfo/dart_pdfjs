// Copyright 2017 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:convert';
import 'dart:typed_data';

import 'package:pdfjs/src/core/calculate_md5.dart';
import 'package:pdfjs/src/core/calculate_sha256.dart';
import 'package:pdfjs/src/core/calculate_sha_other.dart';
import 'package:pdfjs/src/core/crypto.dart';
import 'package:test/test.dart';

import 'crypto_test_vectors.dart';

Uint8List hexBytes(String value) {
  final normalized = value.replaceAll(RegExp(r'\s'), '');
  if (normalized.length.isOdd) throw FormatException('Odd hexadecimal input.');
  return Uint8List.fromList([
    for (var i = 0; i < normalized.length; i += 2)
      int.parse(normalized.substring(i, i + 2), radix: 16),
  ]);
}

Uint8List textBytes(String value) => Uint8List.fromList(utf8.encode(value));

void main() {
  group('MD5 RFC 1321', () {
    const vectors = {
      '': 'd41d8cd98f00b204e9800998ecf8427e',
      'a': '0cc175b9c0f1b6a831c399e269772661',
      'abc': '900150983cd24fb0d6963f7d28e17f72',
      'message digest': 'f96b697d7cb7938d525a2f31aaf161d0',
      'abcdefghijklmnopqrstuvwxyz': 'c3fcd3d76192e4007dfb496cca67e13b',
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789':
          'd174ab98d277d9f5a5611c2c9f419d9f',
      '12345678901234567890123456789012345678901234567890123456789012345678901234567890':
          '57edf4a22be3c955ac49da2e2107b67a',
    };
    for (final entry in vectors.entries) {
      test('hashes ${entry.key.isEmpty ? "empty input" : entry.key}', () {
        final input = textBytes(entry.key);
        expect(calculateMD5(input, 0, input.length), hexBytes(entry.value));
      });
    }
  });

  group('ARCFourCipher', () {
    const vectors = [
      ('0123456789abcdef', '0123456789abcdef', '75b7878099e0c596'),
      ('0123456789abcdef', '0000000000000000', '7494c2e7104b0879'),
      ('0000000000000000', '0000000000000000', 'de188941a3375d3a'),
      ('ef012345', '00000000000000000000', 'd6a141a7ec3c38dfbd61'),
      (
        'fb029e3031323334',
        'aaaa0300000008004500004e661a00008011be640a0001220affffff00890089003a000080a601100001000000000000204543454a4548454346434550464545494546464343414341434143414341414100002000011bd0b604',
        'f69c5806bd6ce84626bcbefb9474650aad1f7909b0f64d5f58a503a258b7ed22eb0ea64930d3a056a55742fcce141d485f8aa836dea18df42c5380805ad0c61a5d6f58f41040b24b7d1a693856ed0d4398e7aee3bf0e2a2ca8f7',
      ),
      (
        '0123456789abcdef',
        '123456789abcdef0123456789abcdef0123456789abcdef012345678',
        '66a0949f8af7d6891f7f832ba833c00c892ebe30143ce28740011ecf',
      ),
    ];
    for (var i = 0; i < vectors.length; i++) {
      test('matches reference vector ${i + 1}', () {
        final vector = vectors[i];
        final cipher = ARCFourCipher(hexBytes(vector.$1));
        expect(cipher.encryptBlock(hexBytes(vector.$2)), hexBytes(vector.$3));
      });
    }

    test('matches the 512-byte reference vector', () {
      final cipher = ARCFourCipher(hexBytes('0123456789abcdef'));
      expect(
        cipher.encryptBlock(Uint8List.fromList(longArcFourInput)),
        Uint8List.fromList(longArcFourExpected),
      );
    });

    test('decrypts by continuing the same stream algorithm', () {
      final key = hexBytes('0123456789abcdef');
      final clear = textBytes('PDF.js stream cipher');
      final encrypted = ARCFourCipher(key).encrypt(clear);
      expect(ARCFourCipher(key).decryptBlock(encrypted), clear);
    });

    test('supports incremental blocks', () {
      final key = hexBytes('0123456789abcdef');
      final whole = ARCFourCipher(key).encrypt(textBytes('abcdefgh'));
      final incremental = ARCFourCipher(key);
      final result = Uint8List.fromList([
        ...incremental.encryptBlock(textBytes('abcd')),
        ...incremental.encryptBlock(textBytes('efgh')),
      ]);
      expect(result, whole);
    });

    test('rejects empty keys explicitly', () {
      expect(() => ARCFourCipher(Uint8List(0)), throwsArgumentError);
    });
  });

  group('secure hashes', () {
    test('SHA-256 hashes abc', () {
      final input = textBytes('abc');
      expect(
        calculateSHA256(input, 0, input.length),
        hexBytes(
            'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD'),
      );
    });

    test('SHA-256 hashes a multiblock message', () {
      final input = textBytes(
        'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
      );
      expect(
        calculateSHA256(input, 0, input.length),
        hexBytes(
            '248D6A61D20638B8E5C026930C3E6039A33CE45964FF2167F6ECEDD419DB06C1'),
      );
    });

    test('SHA-384 hashes abc', () {
      final input = textBytes('abc');
      expect(
        calculateSHA384(input, 0, input.length),
        hexBytes('CB00753F45A35E8BB5A03D699AC65007272C32AB0EDED163'
            '1A8B605A43FF5BED8086072BA1E7CC2358BAECA134C825A7'),
      );
    });

    test('SHA-384 hashes a multiblock message', () {
      final input = textBytes('abcdefghbcdefghicdefghijdefghijkefghijklfghijklm'
          'ghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrs'
          'mnopqrstnopqrstu');
      expect(
        calculateSHA384(input, 0, input.length),
        hexBytes('09330C33F71147E83D192FC782CD1B4753111B173B3B05D2'
            '2FA08086E3B0F712FCC7C71A557E2DB966C3E9FA91746039'),
      );
    });

    test('SHA-512 hashes abc', () {
      final input = textBytes('abc');
      expect(
        calculateSHA512(input, 0, input.length),
        hexBytes('DDAF35A193617ABACC417349AE20413112E6FA4E89A97EA2'
            '0A9EEEE64B55D39A2192992A274FC1A836BA3C23A3FEEBBD'
            '454D4423643CE80E2A9AC94FA54CA49F'),
      );
    });

    test('SHA-512 hashes a multiblock message', () {
      final input = textBytes('abcdefghbcdefghicdefghijdefghijkefghijklfghijklm'
          'ghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrs'
          'mnopqrstnopqrstu');
      expect(
        calculateSHA512(input, 0, input.length),
        hexBytes('8E959B75DAE313DA8CF4F72814FC143F8F7779C6EB9F7FA1'
            '7299AEADB6889018501D289E4900F7E4331B99DEC4B5433A'
            'C7D329EEB6DD26545E96E55B874BE909'),
      );
    });
  });

  group('AES', () {
    final clear = hexBytes('00112233445566778899aabbccddeeff');
    final zeroIv = Uint8List(16);

    test('AES-128 encrypts the NIST block', () {
      final cipher = AES128Cipher(hexBytes('000102030405060708090a0b0c0d0e0f'));
      expect(
        cipher.encrypt(clear, zeroIv),
        hexBytes('69c4e0d86a7b0430d8cdb78070b4c55a'),
      );
    });

    test('AES-128 decrypts with an IV embedded in the stream', () {
      final cipher = AES128Cipher(hexBytes('000102030405060708090a0b0c0d0e0f'));
      final stream = hexBytes('00000000000000000000000000000000'
          '69c4e0d86a7b0430d8cdb78070b4c55a');
      expect(cipher.decryptBlock(stream), clear);
    });

    test('AES-256 encrypts the NIST block', () {
      final cipher = AES256Cipher(hexBytes('000102030405060708090a0b0c0d0e0f'
          '101112131415161718191a1b1c1d1e1f'));
      expect(
        cipher.encrypt(clear, zeroIv),
        hexBytes('8ea2b7ca516745bfeafc49904b496089'),
      );
    });

    test('AES-256 decrypts with an explicit IV', () {
      final cipher = AES256Cipher(hexBytes('000102030405060708090a0b0c0d0e0f'
          '101112131415161718191a1b1c1d1e1f'));
      expect(
        cipher.decryptBlock(
          hexBytes('8ea2b7ca516745bfeafc49904b496089'),
          false,
          zeroIv,
        ),
        clear,
      );
    });

    test('AES-256 decrypts with an IV embedded in the stream', () {
      final cipher = AES256Cipher(hexBytes('000102030405060708090a0b0c0d0e0f'
          '101112131415161718191a1b1c1d1e1f'));
      final stream = hexBytes('00000000000000000000000000000000'
          '8ea2b7ca516745bfeafc49904b496089');
      expect(cipher.decryptBlock(stream), clear);
    });

    test('AES-128 rejects keys with the wrong size', () {
      expect(() => AES128Cipher(Uint8List(15)), throwsArgumentError);
      expect(() => AES128Cipher(Uint8List(17)), throwsArgumentError);
    });

    test('AES-256 rejects keys with the wrong size', () {
      expect(() => AES256Cipher(Uint8List(31)), throwsArgumentError);
      expect(() => AES256Cipher(Uint8List(33)), throwsArgumentError);
    });
  });

  group('PDF 1.7 security algorithm', () {
    final algorithm = PDF17();
    final userPassword = Uint8List.fromList([117, 115, 101, 114]);
    final ownerPassword = Uint8List.fromList([111, 119, 110, 101, 114]);
    final userBytes = Uint8List.fromList([
      131,
      242,
      143,
      160,
      87,
      2,
      138,
      134,
      79,
      253,
      189,
      173,
      224,
      73,
      144,
      241,
      190,
      81,
      197,
      15,
      249,
      105,
      145,
      151,
      15,
      194,
      65,
      3,
      1,
      126,
      187,
      221,
      117,
      169,
      4,
      32,
      159,
      101,
      22,
      220,
      168,
      94,
      215,
      192,
      100,
      38,
      188,
      40,
    ]);

    test('checks a user password', () {
      expect(
        algorithm.checkUserPassword(
          userPassword,
          Uint8List.fromList([117, 169, 4, 32, 159, 101, 22, 220]),
          Uint8List.sublistView(userBytes, 0, 32),
        ),
        isTrue,
      );
    });

    test('checks an owner password', () {
      expect(
        algorithm.checkOwnerPassword(
          ownerPassword,
          Uint8List.fromList([243, 118, 71, 153, 128, 17, 101, 62]),
          userBytes,
          Uint8List.fromList([
            60,
            98,
            137,
            35,
            51,
            101,
            200,
            152,
            210,
            178,
            226,
            228,
            134,
            205,
            163,
            24,
            204,
            126,
            177,
            36,
            106,
            50,
            36,
            125,
            210,
            172,
            171,
            120,
            222,
            108,
            139,
            115,
          ]),
        ),
        isTrue,
      );
    });

    test('derives the file key from the user password', () {
      final result = algorithm.getUserKey(
        userPassword,
        Uint8List.fromList([168, 94, 215, 192, 100, 38, 188, 40]),
        Uint8List.fromList([
          35,
          150,
          195,
          169,
          245,
          51,
          51,
          255,
          158,
          158,
          33,
          242,
          231,
          75,
          125,
          190,
          25,
          126,
          172,
          114,
          195,
          244,
          137,
          245,
          234,
          165,
          42,
          74,
          60,
          38,
          17,
          17,
        ]),
      );
      expect(
          result,
          Uint8List.fromList([
            63,
            114,
            136,
            209,
            87,
            61,
            12,
            30,
            249,
            1,
            186,
            144,
            254,
            248,
            163,
            153,
            151,
            51,
            133,
            10,
            80,
            152,
            206,
            15,
            72,
            187,
            231,
            33,
            224,
            239,
            13,
            213,
          ]));
    });

    test('derives the file key from the owner password', () {
      final result = algorithm.getOwnerKey(
        ownerPassword,
        Uint8List.fromList([200, 245, 242, 12, 218, 123, 24, 120]),
        userBytes,
        Uint8List.fromList([
          213,
          202,
          14,
          189,
          110,
          76,
          70,
          191,
          6,
          195,
          10,
          190,
          157,
          100,
          144,
          85,
          8,
          62,
          123,
          178,
          156,
          229,
          50,
          40,
          229,
          216,
          54,
          222,
          34,
          38,
          106,
          223,
        ]),
      );
      expect(
          result,
          Uint8List.fromList([
            63,
            114,
            136,
            209,
            87,
            61,
            12,
            30,
            249,
            1,
            186,
            144,
            254,
            248,
            163,
            153,
            151,
            51,
            133,
            10,
            80,
            152,
            206,
            15,
            72,
            187,
            231,
            33,
            224,
            239,
            13,
            213,
          ]));
    });
  });

  group('PDF 2.0 security algorithm', () {
    final algorithm = PDF20();
    final userPassword = Uint8List.fromList([117, 115, 101, 114]);
    final ownerPassword = Uint8List.fromList([111, 119, 110, 101, 114]);
    final userBytes = Uint8List.fromList([
      94,
      230,
      205,
      75,
      166,
      99,
      250,
      76,
      219,
      128,
      17,
      85,
      57,
      17,
      33,
      164,
      150,
      46,
      103,
      176,
      160,
      156,
      187,
      233,
      166,
      223,
      163,
      253,
      147,
      235,
      95,
      184,
      83,
      245,
      146,
      101,
      198,
      247,
      34,
      198,
      191,
      11,
      16,
      94,
      237,
      216,
      20,
      175,
    ]);
    final expectedKey = Uint8List.fromList([
      42,
      218,
      213,
      39,
      73,
      91,
      72,
      79,
      67,
      38,
      248,
      133,
      18,
      189,
      61,
      34,
      107,
      79,
      29,
      56,
      59,
      181,
      213,
      118,
      113,
      34,
      65,
      210,
      87,
      174,
      22,
      239,
    ]);

    test('checks a user password', () {
      expect(
        algorithm.checkUserPassword(
          userPassword,
          Uint8List.fromList([83, 245, 146, 101, 198, 247, 34, 198]),
          Uint8List.sublistView(userBytes, 0, 32),
        ),
        isTrue,
      );
    });

    test('checks an owner password', () {
      expect(
        algorithm.checkOwnerPassword(
          ownerPassword,
          Uint8List.fromList([142, 232, 169, 208, 202, 214, 5, 185]),
          userBytes,
          Uint8List.fromList([
            88,
            232,
            62,
            54,
            245,
            26,
            245,
            209,
            137,
            123,
            221,
            72,
            199,
            49,
            37,
            217,
            31,
            74,
            115,
            167,
            127,
            158,
            176,
            77,
            45,
            163,
            87,
            47,
            39,
            90,
            217,
            141,
          ]),
        ),
        isTrue,
      );
    });

    test('derives the file key from the user password', () {
      expect(
        algorithm.getUserKey(
          userPassword,
          Uint8List.fromList([191, 11, 16, 94, 237, 216, 20, 175]),
          Uint8List.fromList([
            121,
            208,
            2,
            181,
            230,
            89,
            156,
            60,
            253,
            143,
            212,
            28,
            84,
            180,
            196,
            177,
            173,
            128,
            221,
            107,
            46,
            20,
            94,
            186,
            135,
            51,
            95,
            24,
            20,
            223,
            254,
            36,
          ]),
        ),
        expectedKey,
      );
    });

    test('derives the file key from the owner password', () {
      expect(
        algorithm.getOwnerKey(
          ownerPassword,
          Uint8List.fromList([29, 208, 185, 46, 11, 76, 135, 149]),
          userBytes,
          Uint8List.fromList([
            209,
            73,
            224,
            77,
            103,
            155,
            201,
            181,
            190,
            68,
            223,
            20,
            62,
            90,
            56,
            210,
            5,
            240,
            178,
            128,
            238,
            124,
            68,
            254,
            253,
            244,
            62,
            108,
            208,
            135,
            10,
            251,
          ]),
        ),
        expectedKey,
      );
    });
  });

  group('NullCipher', () {
    test('returns the same bytes for encryption', () {
      final input = Uint8List.fromList([1, 2, 3]);
      expect(identical(NullCipher().encrypt(input), input), isTrue);
    });

    test('returns the same bytes for decryption', () {
      final input = Uint8List.fromList([1, 2, 3]);
      expect(identical(NullCipher().decryptBlock(input), input), isTrue);
    });
  });
}
