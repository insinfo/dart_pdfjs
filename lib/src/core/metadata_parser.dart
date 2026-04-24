// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'xml_parser.dart';

class MetadataSerializable {
  const MetadataSerializable({
    required this.parsedData,
    required this.rawData,
  });

  final Map<String, dynamic> parsedData;
  final String rawData;
}

class MetadataParser {
  MetadataParser(String data) {
    _data = _repair(data);

    final parser = SimpleXMLParser(lowerCaseName: true);
    final xmlDocument = parser.parseFromString(_data);

    if (xmlDocument != null) {
      _parse(xmlDocument);
    }
  }

  final Map<String, dynamic> _metadataMap = <String, dynamic>{};
  late final String _data;

  String _repair(String data) {
    return data.replaceFirst(RegExp(r'^[^<]+'), '').replaceAllMapped(
      RegExp(r'>\\376\\377([^<]+)'),
      (match) {
        final codes = match.group(1)!;
        final bytes =
            codes.replaceAllMapped(RegExp(r'\\([0-3])([0-7])([0-7])'), (code) {
          final d1 = int.parse(code.group(1)!);
          final d2 = int.parse(code.group(2)!);
          final d3 = int.parse(code.group(3)!);
          return String.fromCharCode(d1 * 64 + d2 * 8 + d3);
        }).replaceAllMapped(RegExp(r'&(amp|apos|gt|lt|quot);'), (entity) {
          switch (entity.group(1)) {
            case 'amp':
              return '&';
            case 'apos':
              return "'";
            case 'gt':
              return '>';
            case 'lt':
              return '<';
            case 'quot':
              return '"';
          }
          throw Exception("_repair: ${entity.group(1)} isn't defined.");
        });

        final charBuf = StringBuffer('>');
        for (var i = 0; i < bytes.length; i += 2) {
          final code = bytes.codeUnitAt(i) * 256 + bytes.codeUnitAt(i + 1);
          if (code >= 32 &&
              code < 127 &&
              code != 60 &&
              code != 62 &&
              code != 38) {
            charBuf.writeCharCode(code);
          } else {
            charBuf.write(
              '&#x${(0x10000 + code).toRadixString(16).substring(1)};',
            );
          }
        }
        return charBuf.toString();
      },
    );
  }

  List<SimpleDOMNode>? _getSequence(SimpleDOMNode entry) {
    final name = entry.nodeName;
    if (name != 'rdf:bag' && name != 'rdf:seq' && name != 'rdf:alt') {
      return null;
    }
    return entry.children.where((node) => node.nodeName == 'rdf:li').toList();
  }

  void _parseArray(SimpleDOMNode entry) {
    if (!entry.hasChildNodes()) {
      return;
    }
    final seqNode = entry.children.first;
    final sequence = _getSequence(seqNode) ?? const <SimpleDOMNode>[];

    _metadataMap[entry.nodeName] =
        sequence.map((node) => node.textContent.trim()).toList(growable: false);
  }

  void _parse(SimpleXMLDocument xmlDocument) {
    var rdf = xmlDocument.documentElement;

    if (rdf.nodeName != 'rdf:rdf') {
      var child = rdf.firstChild;
      while (child != null && child.nodeName != 'rdf:rdf') {
        child = child.nextSibling;
      }
      if (child == null) {
        return;
      }
      rdf = child;
    }

    if (rdf.nodeName != 'rdf:rdf' || !rdf.hasChildNodes()) {
      return;
    }

    for (final desc in rdf.children) {
      if (desc.nodeName != 'rdf:description') {
        continue;
      }

      for (final entry in desc.children) {
        final name = entry.nodeName;
        switch (name) {
          case '#text':
            continue;
          case 'dc:creator':
          case 'dc:subject':
            _parseArray(entry);
            continue;
        }
        _metadataMap[name] = entry.textContent.trim();
      }
    }
  }

  MetadataSerializable get serializable => MetadataSerializable(
        parsedData: _metadataMap,
        rawData: _data,
      );
}
