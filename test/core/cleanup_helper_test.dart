import 'package:test/test.dart';

import 'package:pdfjs/src/core/cleanup_helper.dart';
import 'package:pdfjs/src/core/primitives.dart';

void main() {
  group('clearGlobalCaches', () {
    test('clears primitive caches', () {
      final firstName = Name.get('CachedName');
      final firstCmd = Cmd.get('CachedCmd');
      final firstRef = Ref.get(10, 0);

      expect(Name.get('CachedName'), same(firstName));
      expect(Cmd.get('CachedCmd'), same(firstCmd));
      expect(Ref.get(10, 0), same(firstRef));

      clearGlobalCaches();

      expect(Name.get('CachedName'), isNot(same(firstName)));
      expect(Cmd.get('CachedCmd'), isNot(same(firstCmd)));
      expect(Ref.get(10, 0), isNot(same(firstRef)));
    });
  });
}
