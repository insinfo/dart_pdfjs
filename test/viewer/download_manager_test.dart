@TestOn('browser')
library;

import 'package:test/test.dart';

import '../../example/src/base_download_manager.dart';
import '../../example/src/download_manager.dart';

void main() {
  late DownloadManager manager;

  setUp(() => manager = DownloadManager(runtime: _NoopRuntime()));

  test('builds encoded viewer URL for PDF data', () {
    expect(
      manager.getOpenDataUrl('blob:https://host/id', 'a file.pdf'),
      '?file=blob%3Ahttps%3A%2F%2Fhost%2Fid%23a%20file.pdf',
    );
  });

  test('uses legacy escape semantics for destinations', () {
    expect(
      manager.getOpenDataUrl('blob:id', 'a.pdf', 'nameddest=Capítulo 1'),
      '?file=blob%3Aid%23a.pdf#nameddest%3DCap%EDtulo%201',
    );
  });

  test('rejects an invalid fallback URL', () {
    expect(
      () => manager.triggerDownload(null, 'javascript:alert(1)', 'a.pdf'),
      throwsArgumentError,
    );
  });
}

class _NoopRuntime implements DownloadRuntime {
  @override
  String createObjectUrl(data, String contentType) => 'blob:id';

  @override
  void openWindow(String url) {}

  @override
  void revokeObjectUrl(String url) {}
}
