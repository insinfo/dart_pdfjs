// Copyright 2015 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../shared/util.dart' show stringToBytes;

abstract class BaseBinaryDataFactory {
  static const Map<String, String> _errorStr = {
    'cMapUrl': 'CMap',
    'standardFontDataUrl': 'font',
    'wasmUrl': 'wasm',
  };

  final String? cMapUrl;
  final String? standardFontDataUrl;
  final String? wasmUrl;

  BaseBinaryDataFactory({
    this.cMapUrl,
    this.standardFontDataUrl,
    this.wasmUrl,
  });

  String? _getUrl(String kind) {
    switch (kind) {
      case 'cMapUrl':
        return cMapUrl;
      case 'standardFontDataUrl':
        return standardFontDataUrl;
      case 'wasmUrl':
        return wasmUrl;
      default:
        throw UnimplementedError('Not implemented: $kind');
    }
  }

  Future<Uint8List> fetch({
    required String kind,
    required String filename,
  }) async {
    final baseUrl = _getUrl(kind);
    if (baseUrl == null || baseUrl.isEmpty) {
      throw StateError('Ensure that the `$kind` API parameter is provided.');
    }
    final url = '$baseUrl$filename';

    try {
      return await _fetch(url, kind);
    } catch (_) {
      throw Exception(
          'Unable to load ${_errorStr[kind] ?? kind} data at: $url');
    }
  }

  Future<Uint8List> _fetch(String url, String kind);
}

class DOMBinaryDataFactory extends BaseBinaryDataFactory {
  DOMBinaryDataFactory({
    super.cMapUrl,
    super.standardFontDataUrl,
    super.wasmUrl,
  });

  @override
  Future<Uint8List> _fetch(String url, String kind) async {
    final response = await web.window.fetch(url.toJS).toDart;
    if (!response.ok) {
      throw Exception(response.statusText);
    }

    if (kind == 'cMapUrl' && !url.endsWith('.bcmap')) {
      final text = (await response.text().toDart).toDart;
      return stringToBytes(text);
    }

    final buffer = await response.arrayBuffer().toDart;
    return Uint8List.fromList(buffer.toDart.asUint8List());
  }
}
