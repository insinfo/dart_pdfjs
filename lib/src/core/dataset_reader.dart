// Copyright 2022 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import '../shared/util.dart';
import 'core_utils.dart';
import 'xml_parser.dart';

String decodeDatasetString(String str) {
  try {
    return stringToUTF8String(str);
  } catch (ex) {
    warn('UTF-8 decoding failed: "$ex".');
    return str;
  }
}

class DatasetReader {
  DatasetReader(Map<String, String> data) {
    final datasets = data['datasets'];
    if (datasets != null) {
      node = SimpleXMLParser(hasAttributes: true)
          .parseFromString(datasets)
          ?.documentElement;
    } else {
      final xdp = data['xdp:xdp'];
      if (xdp != null) {
        final document =
            SimpleXMLParser(hasAttributes: true).parseFromString(xdp);
        node = document?.documentElement.searchNode(
          parseXFAPath('xfa:datasets'),
          0,
        );
      }
    }
  }

  SimpleDOMNode? node;

  dynamic getValue(String? path) {
    final root = node;
    if (root == null || path == null || path.isEmpty) {
      return '';
    }
    final found = root.searchNode(parseXFAPath(path), 0);
    if (found == null) {
      return '';
    }

    final first = found.firstChild;
    if (first?.nodeName == 'value') {
      return found.children
          .map((child) => decodeDatasetString(child.textContent))
          .toList(growable: false);
    }

    return decodeDatasetString(found.textContent);
  }
}
