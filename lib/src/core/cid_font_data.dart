// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'base_stream.dart';
import 'cmap.dart';
import 'primitives.dart';
import 'stream.dart' as pdf_stream;

/// Values extracted from a Type 0 font and its descendant CIDFont.
class CidFontData {
  const CidFontData({
    required this.cMap,
    required this.cidEncoding,
    required this.vertical,
    required this.widths,
    required this.defaultWidth,
    required this.vmetrics,
    required this.defaultVMetrics,
    required this.cidToGidMap,
    required this.cidSystemInfo,
  });

  final CMap cMap;
  final String cidEncoding;
  final bool vertical;
  final Map<int, num> widths;
  final num defaultWidth;
  final Map<int, List<num>> vmetrics;
  final List<num>? defaultVMetrics;
  final Map<int, int> cidToGidMap;
  final Map<String, dynamic>? cidSystemInfo;
}

/// Synchronous extraction used by the page evaluator.
///
/// Network supplied predefined CMaps remain the responsibility of
/// [CMapFactory]. This helper handles Identity CMaps, embedded textual CMaps,
/// and predefined maps supplied by the embedding application through
/// `options['builtInCMaps']`.
CidFontData readCidFontData(
  Dict type0,
  Dict? descendant,
  Map<String, dynamic> options,
) {
  final encoding = type0.get('Encoding');
  final encodingName = encoding is Name ? encoding.name : '';
  final supplied = options['builtInCMaps'];
  CMap cmap;
  if (encoding is BaseStream) {
    cmap = parseEmbeddedCMap(encoding);
  } else if (encodingName == 'Identity-V') {
    cmap = IdentityCMap(true, 2);
  } else if (encodingName == 'Identity-H' || encodingName.isEmpty) {
    cmap = IdentityCMap(false, 2);
  } else {
    final value = supplied is Map ? supplied[encodingName] : null;
    if (value is CMap) {
      cmap = value;
    } else if (value is Uint8List) {
      cmap = parseEmbeddedCMap(pdf_stream.Stream(value), name: encodingName);
    } else if (value is List<int>) {
      cmap = parseEmbeddedCMap(
        pdf_stream.Stream(Uint8List.fromList(value)),
        name: encodingName,
      );
    } else {
      // Retain two-byte character boundaries for an unavailable predefined
      // CMap. This is safer than splitting a CID into two simple characters.
      cmap = IdentityCMap(encodingName.endsWith('-V'), 2);
    }
  }

  final widths = readCidWidths(descendant?.getArray('W'));
  final defaultWidth = _number(descendant?.get('DW')) ?? 1000;
  final vertical = cmap.vertical || encodingName.endsWith('-V');
  final dw2 = descendant?.getArray('DW2');
  List<num>? defaultVMetrics;
  if (vertical) {
    final vy =
        dw2 is List && dw2.length >= 2 && dw2[0] is num ? dw2[0] as num : 880;
    final w1y =
        dw2 is List && dw2.length >= 2 && dw2[1] is num ? dw2[1] as num : -1000;
    defaultVMetrics = <num>[w1y, defaultWidth * .5, vy];
  }
  return CidFontData(
    cMap: cmap,
    cidEncoding: encodingName.isEmpty ? cmap.name : encodingName,
    vertical: vertical,
    widths: widths,
    defaultWidth: defaultWidth,
    vmetrics: readCidVerticalMetrics(descendant?.getArray('W2')),
    defaultVMetrics: defaultVMetrics,
    cidToGidMap: readCidToGidMap(descendant?.get('CIDToGIDMap')),
    cidSystemInfo: readCidSystemInfo(descendant?.get('CIDSystemInfo')),
  );
}

Map<int, num> readCidWidths(dynamic values) {
  final result = <int, num>{};
  if (values is! List) return result;
  var i = 0;
  while (i < values.length) {
    final startValue = values[i++];
    if (startValue is! num || i >= values.length) break;
    var cid = startValue.toInt();
    final next = values[i++];
    if (next is List) {
      for (final width in next) {
        if (width is num) result[cid] = width;
        cid++;
      }
      continue;
    }
    if (next is! num || i >= values.length) break;
    final width = values[i++];
    if (width is! num) continue;
    final end = next.toInt();
    if (end < cid || end - cid > 0xffffff) continue;
    while (cid <= end) {
      result[cid++] = width;
    }
  }
  return result;
}

Map<int, List<num>> readCidVerticalMetrics(dynamic values) {
  final result = <int, List<num>>{};
  if (values is! List) return result;
  var i = 0;
  while (i < values.length) {
    final startValue = values[i++];
    if (startValue is! num || i >= values.length) break;
    var cid = startValue.toInt();
    final next = values[i++];
    if (next is List) {
      for (var j = 0; j + 2 < next.length; j += 3) {
        final triple = next.sublist(j, j + 3);
        if (triple.every((value) => value is num)) {
          result[cid] = triple.cast<num>();
        }
        cid++;
      }
      continue;
    }
    if (next is! num || i + 2 >= values.length) break;
    final triple = values.sublist(i, i + 3);
    i += 3;
    if (!triple.every((value) => value is num)) continue;
    final metric = triple.cast<num>();
    final end = next.toInt();
    if (end < cid || end - cid > 0xffffff) continue;
    while (cid <= end) {
      result[cid++] = List<num>.from(metric);
    }
  }
  return result;
}

Map<int, int> readCidToGidMap(dynamic value) {
  if (value is Name && value.name == 'Identity') return <int, int>{};
  if (value is! BaseStream) return <int, int>{};
  value.reset();
  final bytes = value.getBytes();
  value.reset();
  final result = <int, int>{};
  for (var offset = 0; offset + 1 < bytes.length; offset += 2) {
    final gid = (bytes[offset] << 8) | bytes[offset + 1];
    // Keep explicit zero mappings. They mean .notdef and are distinct from a
    // missing entry, where the CID itself is used.
    result[offset >> 1] = gid;
  }
  return result;
}

Map<String, dynamic>? readCidSystemInfo(dynamic value) {
  if (value is! Dict) return null;
  String text(dynamic item) {
    if (item is String) return item;
    if (item is Name) return item.name;
    return '';
  }

  return <String, dynamic>{
    'registry': text(value.get('Registry')),
    'ordering': text(value.get('Ordering')),
    'supplement': (value.get('Supplement') as num?)?.toInt() ?? 0,
  };
}

/// Parses the mapping operators relevant to a Type 0 encoding CMap.
CMap parseEmbeddedCMap(BaseStream stream, {String? name}) {
  stream.reset();
  final bytes = stream.getBytes();
  stream.reset();
  final source = String.fromCharCodes(bytes);
  final tokens = RegExp(r'<[0-9A-Fa-f]+>|/[A-Za-z0-9_.-]+|-?\d+|\S+')
      .allMatches(source)
      .map((match) => match.group(0)!)
      .toList(growable: false);
  final cmap = CMap();
  cmap.name = name ?? '';
  var i = 0;
  while (i < tokens.length) {
    if (tokens[i] == '/CMapName' && i + 1 < tokens.length) {
      cmap.name = tokens[i + 1].replaceFirst('/', '');
      i += 2;
      continue;
    }
    if (tokens[i] == '/WMode' && i + 1 < tokens.length) {
      cmap.vertical = int.tryParse(tokens[i + 1]) == 1;
      i += 2;
      continue;
    }
    final count = int.tryParse(tokens[i]);
    if (count == null || i + 1 >= tokens.length) {
      i++;
      continue;
    }
    final operator = tokens[i + 1];
    i += 2;
    if (operator == 'begincodespacerange') {
      for (var n = 0; n < count && i + 1 < tokens.length; n++) {
        final lowBytes = _hexBytes(tokens[i++]);
        final highBytes = _hexBytes(tokens[i++]);
        if (lowBytes != null && highBytes != null && lowBytes.isNotEmpty) {
          cmap.addCodespaceRange(
            lowBytes.length,
            _bytesToInt(lowBytes),
            _bytesToInt(highBytes),
          );
        }
      }
    } else if (operator == 'begincidchar' || operator == 'beginbfchar') {
      for (var n = 0; n < count && i + 1 < tokens.length; n++) {
        final sourceBytes = _hexBytes(tokens[i++]);
        final destination = tokens[i++];
        if (sourceBytes == null) continue;
        final code = _bytesToInt(sourceBytes);
        if (operator == 'begincidchar') {
          final cid = int.tryParse(destination);
          if (cid != null) cmap.mapOne(code, cid);
        } else {
          final bytes = _hexBytes(destination);
          if (bytes != null) cmap.mapOne(code, String.fromCharCodes(bytes));
        }
      }
    } else if (operator == 'begincidrange' || operator == 'beginbfrange') {
      for (var n = 0; n < count && i + 2 < tokens.length; n++) {
        final low = _hexBytes(tokens[i++]);
        final high = _hexBytes(tokens[i++]);
        final destination = tokens[i++];
        if (low == null || high == null) continue;
        final lowCode = _bytesToInt(low);
        final highCode = _bytesToInt(high);
        if (operator == 'begincidrange') {
          final cid = int.tryParse(destination);
          if (cid != null) cmap.mapCidRange(lowCode, highCode, cid);
        } else {
          final bytes = _hexBytes(destination);
          if (bytes != null) {
            cmap.mapBfRange(lowCode, highCode, String.fromCharCodes(bytes));
          }
        }
      }
    }
  }
  if (cmap.numCodespaceRanges == 0) {
    cmap.addCodespaceRange(2, 0, 0xffff);
  }
  return cmap;
}

List<int>? _hexBytes(String token) {
  if (!token.startsWith('<') || !token.endsWith('>')) return null;
  var hex = token.substring(1, token.length - 1);
  if (hex.length.isOdd) hex += '0';
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    final byte = int.tryParse(hex.substring(i, i + 2), radix: 16);
    if (byte == null) return null;
    bytes.add(byte);
  }
  return bytes;
}

int _bytesToInt(List<int> bytes) {
  var value = 0;
  for (final byte in bytes) value = (value << 8) | byte;
  return value;
}

num? _number(dynamic value) => value is num ? value : null;
