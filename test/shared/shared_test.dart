import 'dart:typed_data';
import 'package:test/test.dart';

import 'package:pdfjs/src/shared/math_clamp.dart';
import 'package:pdfjs/src/shared/murmurhash3.dart';

void main() {
  group('MathClamp', () {
    test('clamps values correctly', () {
      expect(mathClamp(5, 1, 10), equals(5));
      expect(mathClamp(-5, 1, 10), equals(1));
      expect(mathClamp(15, 1, 10), equals(10));
      expect(mathClamp(3.14, 0, 5), equals(3.14));
      expect(mathClamp(-0.5, 0, 5), equals(0));
    });
  });

  group('MurmurHash3', () {
    test('can instantiate and update with string', () {
      final hasher = MurmurHash3_64(0);
      hasher.update('pdf.js');
      final digest = hasher.hexdigest();
      expect(digest, isNotEmpty);
      expect(digest.length, equals(16)); // 64 bits = 16 hex chars
    });

    test('can update with Uint8List', () {
      final hasher = MurmurHash3_64(42);
      final data = Uint8List.fromList([104, 101, 108, 108, 111]); // "hello"
      hasher.update(data);
      final digest = hasher.hexdigest();
      expect(digest, isNotEmpty);
      expect(digest.length, equals(16));
    });
    
    test('produces consistent hashes for same input', () {
      final hasher1 = MurmurHash3_64(12345);
      hasher1.update('Mozilla PDF.js');
      final hash1 = hasher1.hexdigest();

      final hasher2 = MurmurHash3_64(12345);
      hasher2.update('Mozilla PDF.js');
      final hash2 = hasher2.hexdigest();

      expect(hash1, equals(hash2));
    });
  });
}
