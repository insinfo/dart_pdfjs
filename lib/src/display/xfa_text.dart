// Copyright 2021 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

/// Utility class for extracting text content from XFA structures.
class XfaText {
  /// Walk an XFA tree and create a list of text items compatible with
  /// regular PDF TextContent.
  static Map<String, dynamic> textContent(Map<String, dynamic>? xfa) {
    final items = <Map<String, dynamic>>[];
    final output = <String, dynamic>{
      'items': items,
      'styles': <String, dynamic>{},
    };

    void walk(Map<String, dynamic>? node) {
      if (node == null) {
        return;
      }
      String? str;
      final name = node['name'] as String?;
      if (name == '#text') {
        str = node['value'] as String?;
      } else if (!XfaText.shouldBuildText(name ?? '')) {
        return;
      } else if (node['attributes'] is Map &&
          (node['attributes'] as Map)['textContent'] != null) {
        str = (node['attributes'] as Map)['textContent'] as String?;
      } else if (node['value'] is String) {
        str = node['value'] as String;
      }
      if (str != null) {
        items.add({'str': str});
      }
      final children = node['children'];
      if (children == null) {
        return;
      }
      if (children is List) {
        for (final child in children) {
          walk(child as Map<String, dynamic>?);
        }
      }
    }

    walk(xfa);
    return output;
  }

  /// Returns true if the DOM node should have a corresponding text node.
  static bool shouldBuildText(String name) {
    return !(name == 'textarea' ||
        name == 'input' ||
        name == 'option' ||
        name == 'select');
  }
}
