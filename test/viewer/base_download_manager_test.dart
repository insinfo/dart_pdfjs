import 'dart:typed_data';

import 'package:test/test.dart';

import '../../example/src/base_download_manager.dart';

void main() {
  late _Runtime runtime;
  late _Manager manager;

  setUp(() {
    runtime = _Runtime();
    manager = _Manager(runtime);
  });

  test('downloadData creates an attachment blob and triggers download', () {
    final data = Uint8List.fromList([1, 2, 3]);
    manager.downloadData(data, 'file.bin', 'application/octet-stream');
    expect(runtime.created.single, (data, 'application/octet-stream'));
    expect(manager.downloads.single, (
      blobUrl: 'blob:1',
      originalUrl: 'blob:1',
      filename: 'file.bin',
      isAttachment: true,
    ));
  });

  test('opens PDFs and reuses object URL for identical data', () {
    final data = Uint8List.fromList([1]);
    expect(manager.openOrDownloadData(data, 'a.pdf', 'page=2'), isTrue);
    expect(manager.openOrDownloadData(data, 'a.pdf'), isTrue);
    expect(runtime.created, hasLength(1));
    expect(
        runtime.opened, ['viewer:blob:1:a.pdf:page=2', 'viewer:blob:1:a.pdf:']);
  });

  test('different byte-list identities receive different object URLs', () {
    expect(
        manager.openOrDownloadData(Uint8List.fromList([1]), 'a.pdf'), isTrue);
    expect(
        manager.openOrDownloadData(Uint8List.fromList([1]), 'a.pdf'), isTrue);
    expect(runtime.created, hasLength(2));
  });

  test('failed PDF opening revokes object URL and downloads instead', () {
    runtime.failOpening = true;
    final data = Uint8List.fromList([1]);
    expect(manager.openOrDownloadData(data, 'a.pdf'), isFalse);
    expect(runtime.revoked, ['blob:1']);
    expect(runtime.created, hasLength(2));
    expect(manager.downloads.last.isAttachment, isTrue);
  });

  test('non-PDF data is downloaded without attempting to open', () {
    expect(
      manager.openOrDownloadData(Uint8List.fromList([1]), 'image.png'),
      isFalse,
    );
    expect(runtime.opened, isEmpty);
    expect(manager.downloads.single.isAttachment, isTrue);
  });

  test('download uses PDF blob when data is available', () {
    manager.download(
        Uint8List.fromList([1]), 'https://example.com/a.pdf', 'a.pdf');
    expect(runtime.created.single.$2, 'application/pdf');
    expect(manager.downloads.single.blobUrl, 'blob:1');
  });

  test('download preserves URL when data is unavailable', () {
    manager.download(null, 'https://example.com/a.pdf', 'a.pdf');
    expect(runtime.created, isEmpty);
    expect(manager.downloads.single.originalUrl, 'https://example.com/a.pdf');
  });
}

class _Runtime implements DownloadRuntime {
  final List<(Uint8List, String)> created = [];
  final List<String> revoked = [];
  final List<String> opened = [];
  var failOpening = false;

  @override
  String createObjectUrl(Uint8List data, String contentType) {
    created.add((data, contentType));
    return 'blob:${created.length}';
  }

  @override
  void openWindow(String url) {
    if (failOpening) throw StateError('blocked');
    opened.add(url);
  }

  @override
  void revokeObjectUrl(String url) => revoked.add(url);
}

class _Manager extends BaseDownloadManager {
  final List<
      ({
        String? blobUrl,
        String originalUrl,
        String filename,
        bool isAttachment
      })> downloads = [];

  _Manager(super.runtime);

  @override
  String getOpenDataUrl(String blobUrl, String filename, [String? dest]) =>
      'viewer:$blobUrl:$filename:${dest ?? ''}';

  @override
  void triggerDownload(
    String? blobUrl,
    String originalUrl,
    String filename, {
    bool isAttachment = false,
  }) {
    downloads.add((
      blobUrl: blobUrl,
      originalUrl: originalUrl,
      filename: filename,
      isAttachment: isAttachment,
    ));
  }
}
