// Copyright 2013 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:pdfjs/src/shared/util.dart' show createValidAbsoluteUrl;
import 'package:web/web.dart' as web;

import 'base_download_manager.dart';

/// Generic browser download manager used by the standalone viewer.
class DownloadManager extends BaseDownloadManager {
  DownloadManager({DownloadRuntime? runtime})
      : super(runtime ?? const WebDownloadRuntime());

  @override
  void triggerDownload(
    String? blobUrl,
    String originalUrl,
    String filename, {
    bool isAttachment = false,
  }) {
    if (blobUrl == null && !isAttachment) {
      if (createValidAbsoluteUrl(originalUrl, 'http://example.com') == null) {
        throw ArgumentError.value(
          originalUrl,
          'originalUrl',
          'not a valid URL',
        );
      }
      blobUrl = '$originalUrl#pdfjs.action=download';
    }
    if (blobUrl == null) return;

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = blobUrl
      ..target = '_parent'
      ..download = filename;
    (web.document.body ?? web.document.documentElement!).append(anchor);
    anchor.click();
    anchor.remove();
  }

  @override
  String getOpenDataUrl(String blobUrl, String filename, [String? dest]) {
    var url = '?file=${Uri.encodeComponent('$blobUrl#$filename')}';
    if (dest != null && dest.isNotEmpty) {
      url += '#${_legacyEscape(dest)}';
    }
    return url;
  }
}

class WebDownloadRuntime implements DownloadRuntime {
  const WebDownloadRuntime();

  @override
  String createObjectUrl(Uint8List data, String contentType) {
    final blob = web.Blob(
      <JSAny>[data.toJS].toJS,
      web.BlobPropertyBag(type: contentType),
    );
    return web.URL.createObjectURL(blob);
  }

  @override
  void openWindow(String url) {
    final opened = web.window.open(url, '_blank');
    if (opened == null) throw StateError('The browser blocked the PDF window.');
  }

  @override
  void revokeObjectUrl(String url) => web.URL.revokeObjectURL(url);
}

String _legacyEscape(String value) {
  final buffer = StringBuffer();
  for (final codeUnit in value.codeUnits) {
    final isSafe = codeUnit >= 0x41 && codeUnit <= 0x5a ||
        codeUnit >= 0x61 && codeUnit <= 0x7a ||
        codeUnit >= 0x30 && codeUnit <= 0x39 ||
        codeUnit == 0x40 ||
        codeUnit == 0x2a ||
        codeUnit == 0x5f ||
        codeUnit == 0x2b ||
        codeUnit == 0x2d ||
        codeUnit == 0x2e ||
        codeUnit == 0x2f;
    if (isSafe) {
      buffer.writeCharCode(codeUnit);
    } else if (codeUnit < 0x100) {
      buffer
        ..write('%')
        ..write(codeUnit.toRadixString(16).padLeft(2, '0').toUpperCase());
    } else {
      buffer
        ..write('%u')
        ..write(codeUnit.toRadixString(16).padLeft(4, '0').toUpperCase());
    }
  }
  return buffer.toString();
}
