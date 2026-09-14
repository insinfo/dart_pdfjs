import 'package:pdfjs/src/core/bidi.dart';
import 'package:test/test.dart';

void main() {
  group('bidi algorithm', () {
    test('handles empty and vertical text', () {
      expect(bidi('').str, '');
      expect(bidi('').dir, 'ltr');
      expect(bidi('abc', -1, true).dir, 'ttb');
    });

    test('retains LTR for plain Latin text', () {
      final res = bidi('Hello World');
      expect(res.str, 'Hello World');
      expect(res.dir, 'ltr');
    });

    test('reverses RTL text', () {
      // Arabic or Hebrew text
      final arabic = '\u0627\u0644\u0633\u0644\u0627\u0645';
      final res = bidi(arabic);
      expect(res.dir, 'rtl');
      // characters should be reversed
      expect(res.str, arabic.split('').reversed.join(''));
    });

    test('strips < and > chars as per pdf.js behavior in bidi text', () {
      final res = bidi('<\u0627\u0644\u0633>');
      expect(res.str.contains('<'), isFalse);
      expect(res.str.contains('>'), isFalse);
    });
  });
}
