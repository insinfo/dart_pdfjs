// Copyright 2026. Apache License 2.0.

import 'package:pdfjs/src/display/xfa_text.dart';
import 'package:test/test.dart';

void main() {
  group('XfaText', () {
    test('returns an empty TextContent structure for a missing tree', () {
      expect(
        XfaText.textContent(null),
        {'items': <Map<String, dynamic>>[], 'styles': <String, dynamic>{}},
      );
    });

    test('walks text nodes and nested element values in document order', () {
      final content = XfaText.textContent({
        'name': 'div',
        'value': 'parent',
        'children': [
          {'name': '#text', 'value': 'first'},
          {
            'name': 'span',
            'attributes': {'textContent': 'second'},
          },
        ],
      });

      expect(content['items'], [
        {'str': 'parent'},
        {'str': 'first'},
        {'str': 'second'},
      ]);
      expect(content['styles'], isEmpty);
    });

    test('does not walk form controls that own their displayed text', () {
      for (final name in ['textarea', 'input', 'option', 'select']) {
        final content = XfaText.textContent({
          'name': name,
          'value': 'ignored',
          'children': [
            {'name': '#text', 'value': 'also ignored'},
          ],
        });

        expect(content['items'], isEmpty, reason: 'failed for $name');
        expect(XfaText.shouldBuildText(name), isFalse);
      }
      expect(XfaText.shouldBuildText('div'), isTrue);
    });

    test('matches JavaScript truthiness for element text sources', () {
      final content = XfaText.textContent({
        'name': 'div',
        'attributes': {'textContent': ''},
        'value': '',
        'children': [
          {'name': '#text', 'value': ''},
        ],
      });

      expect(content['items'], [
        {'str': ''},
      ]);
    });
  });
}
