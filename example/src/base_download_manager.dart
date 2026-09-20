// Copyright 2013 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'package:pdfjs/src/display/display_utils.dart' show isPdfFile;

/// Browser services used by [BaseDownloadManager].
abstract interface class DownloadRuntime {
  String createObjectUrl(Uint8List data, String contentType);

  void revokeObjectUrl(String url);

  void openWindow(String url);
}

/// Common download/open behavior shared by viewer-specific managers.
abstract class BaseDownloadManager {
  final DownloadRuntime runtime;
  final Map<Uint8List, String> _openBlobUrls = Map.identity();

  BaseDownloadManager(this.runtime);

  void triggerDownload(
    String? blobUrl,
    String originalUrl,
    String filename, {
    bool isAttachment = false,
  });

  String getOpenDataUrl(String blobUrl, String filename, [String? dest]);

  void downloadData(
    Uint8List data,
    String filename, [
    String contentType = '',
  ]) {
    final blobUrl = runtime.createObjectUrl(data, contentType);
    triggerDownload(
      blobUrl,
      blobUrl,
      filename,
      isAttachment: true,
    );
  }

  /// Opens PDF data in the viewer, falling back to download on any failure.
  bool openOrDownloadData(
    Uint8List data,
    String filename, [
    String? dest,
  ]) {
    final isPdfData = isPdfFile(filename);
    final contentType = isPdfData ? 'application/pdf' : '';

    if (isPdfData) {
      final blobUrl = _openBlobUrls.putIfAbsent(
        data,
        () => runtime.createObjectUrl(data, contentType),
      );
      try {
        runtime.openWindow(getOpenDataUrl(blobUrl, filename, dest));
        return true;
      } catch (_) {
        runtime.revokeObjectUrl(blobUrl);
        _openBlobUrls.remove(data);
      }
    }

    downloadData(data, filename, contentType);
    return false;
  }

  void download(Uint8List? data, String url, String filename) {
    final blobUrl =
        data == null ? null : runtime.createObjectUrl(data, 'application/pdf');
    triggerDownload(blobUrl, url, filename);
  }
}
