@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/event_utils.dart';
import '../../example/src/l10n.dart';
import '../../example/src/overlay_manager.dart';
import '../../example/src/pdf_document_properties.dart';

void main() {
  late web.HTMLDialogElement dialog;
  late web.HTMLButtonElement closeButton;
  late Map<String, web.HTMLElement> fields;
  late OverlayManager manager;
  late EventBus eventBus;
  late _Backend backend;
  late PDFDocumentProperties properties;
  late _Document document;

  setUp(() {
    dialog = web.document.createElement('dialog') as web.HTMLDialogElement;
    closeButton = web.document.createElement('button') as web.HTMLButtonElement;
    fields = {
      for (final name in const [
        'fileName',
        'fileSize',
        'title',
        'author',
        'subject',
        'keywords',
        'creationDate',
        'modificationDate',
        'creator',
        'producer',
        'version',
        'pageCount',
        'pageSize',
        'linearized',
      ])
        name: web.document.createElement('span') as web.HTMLElement,
    };
    dialog.append(closeButton);
    for (final field in fields.values) {
      dialog.append(field);
    }
    web.document.body!.append(dialog);
    manager = OverlayManager();
    eventBus = EventBus();
    backend = _Backend();
    document = _Document();
    properties = PDFDocumentProperties(
      dialog: dialog,
      fields: fields,
      closeButton: closeButton,
      overlayManager: manager,
      eventBus: eventBus,
      l10n: L10n(lang: 'en-US', backend: backend),
      fileNameLookup: () => 'sample.pdf',
      titleLookup: () => 'Window title',
    );
  });

  tearDown(() async {
    if (dialog.open) dialog.close();
    await manager.dispose();
    dialog.remove();
  });

  test('opens and populates all document information', () async {
    properties.setDocument(document);
    await properties.open();

    expect(fields['fileName']!.textContent, 'sample.pdf');
    expect(fields['title']!.textContent, 'Window title');
    expect(fields['author']!.textContent, 'Alice\nBob');
    expect(fields['subject']!.textContent, 'Subject from XMP');
    expect(fields['keywords']!.textContent, 'dart,pdf');
    expect(fields['creator']!.textContent, 'Creator Tool');
    expect(fields['producer']!.textContent, 'Producer XMP');
    expect(fields['version']!.textContent, '1.7');
    expect(fields['pageCount']!.textContent, '4');
    expect(fields['linearized']!.textContent, 'yes');
    expect(fields['fileSize']!.textContent, contains('2.00 MB'));
    expect(fields['pageSize']!.textContent, contains('Letter'));
    expect(fields['pageSize']!.textContent, contains('8.5x11'));
    expect(fields['creationDate']!.textContent, startsWith('date:'));
    expect(document.metadataCalls, 1);
    expect(document.pageCalls, [1]);
  });

  test('uses info fallbacks and dash for missing values', () async {
    document = _Document(
      metadata: _Metadata(const {}),
      info: {
        'Author': 'Info Author',
        'CreationDate': 'broken',
        'PDFFormatVersion': '1.4',
        'IsLinearized': false,
      },
      contentLength: 0,
      downloadLength: 0,
    );
    properties.setDocument(document);
    await properties.open();
    expect(fields['author']!.textContent, 'Info Author');
    expect(fields['subject']!.textContent, '-');
    expect(fields['fileSize']!.textContent, '-');
    expect(fields['creationDate']!.textContent, '-');
    expect(fields['linearized']!.textContent, 'no');
  });

  test('uses accurate download length when metadata length differs', () async {
    document = _Document(contentLength: 1024, downloadLength: 2 * 1024 * 1024);
    properties.setDocument(document);
    await properties.open();
    expect(fields['fileSize']!.textContent, contains('2.00 MB'));
    expect(
        backend.requested.where((id) => id.endsWith('size-kb')), hasLength(1));
    expect(
        backend.requested.where((id) => id.endsWith('size-mb')), hasLength(1));
  });

  test('caches data until page or rotation changes', () async {
    properties.setDocument(document);
    await properties.open();
    await properties.close();
    await properties.open();
    expect(document.metadataCalls, 1);

    await properties.close();
    eventBus.dispatch('pagechanging', {'pageNumber': 2});
    await properties.open();
    expect(document.metadataCalls, 2);
    expect(document.pageCalls, [1, 2]);

    await properties.close();
    eventBus.dispatch('rotationchanging', {'pagesRotation': 90});
    await properties.open();
    expect(document.metadataCalls, 3);
    expect(fields['pageSize']!.textContent, contains('11x8.5'));
    expect(fields['pageSize']!.textContent, contains('landscape'));
  });

  test('setDocument resets fields and accepts a replacement', () async {
    properties.setDocument(document);
    await properties.open();
    await properties.close();
    properties.setDocument(null);
    expect(fields.values.every((field) => field.textContent == '-'), isTrue);

    final replacement = _Document(info: {
      'Author': 'Replacement',
      'PDFFormatVersion': '2.0',
      'IsLinearized': false,
    });
    properties.setDocument(replacement);
    await properties.open();
    expect(fields['author']!.textContent, 'Alice\nBob');
    expect(fields['version']!.textContent, '2.0');
  });

  test('close button closes the active overlay', () async {
    properties.setDocument(document);
    await properties.open();
    closeButton.click();
    await Future<void>.delayed(Duration.zero);
    expect(dialog.open, isFalse);
    expect(manager.active, isNull);
  });
}

final class _Document implements DocumentPropertiesDocument {
  _Document({
    _Metadata? metadata,
    Map<String, Object?>? info,
    this.contentLength = 1024,
    this.downloadLength = 2 * 1024 * 1024,
  })  : metadata = metadata ??
            _Metadata({
              'dc:creator': ['Alice', 'Bob'],
              'dc:subject': ['Subject from XMP'],
              'pdf:keywords': 'dart,pdf',
              'xmp:creatortool': 'Creator Tool',
              'pdf:producer': 'Producer XMP',
              'xmp:createdate': '2025-01-02T03:04:05Z',
            }),
        info = info ??
            {
              'Author': 'Info Author',
              'Subject': 'Info Subject',
              'CreationDate': 'D:20200102030405Z',
              'ModDate': 'D:20210102030405Z',
              'Creator': 'Info Creator',
              'Producer': 'Info Producer',
              'PDFFormatVersion': '1.7',
              'IsLinearized': true,
            };

  final _Metadata metadata;
  final Map<String, Object?> info;
  final int contentLength;
  final int downloadLength;
  int metadataCalls = 0;
  final List<int> pageCalls = [];

  @override
  int get numPages => 4;

  @override
  Future<int> getDownloadLength() async => downloadLength;

  @override
  Future<DocumentMetadataResult> getMetadata() async {
    metadataCalls++;
    return DocumentMetadataResult(
      info: info,
      metadata: metadata,
      contentLength: contentLength,
    );
  }

  @override
  Future<DocumentPropertiesPage> getPage(int pageNumber) async {
    pageCalls.add(pageNumber);
    return const _Page();
  }
}

final class _Page implements DocumentPropertiesPage {
  const _Page();
  @override
  int get rotate => 0;
  @override
  num get userUnit => 1;
  @override
  List<num> get view => const [0, 0, 612, 792];
}

final class _Metadata implements DocumentPropertiesMetadata {
  _Metadata(this.values);
  final Map<String, Object?> values;
  @override
  Object? get(String name) => values[name];
}

final class _Backend implements LocalizationBackend {
  final List<String> requested = [];

  @override
  Future<List<L10nMessage>> formatMessages(List<L10nRequest> requests) async {
    return requests.map((request) {
      requested.add(request.id);
      final args = request.args ?? const {};
      final value = switch (request.id) {
        'pdfjs-document-properties-size-kb' =>
          '${(args['kb'] as num).toStringAsFixed(2)} KB',
        'pdfjs-document-properties-size-mb' =>
          '${(args['mb'] as num).toStringAsFixed(2)} MB',
        'pdfjs-document-properties-page-size-unit-inches' => 'in',
        'pdfjs-document-properties-page-size-unit-millimeters' => 'mm',
        'pdfjs-document-properties-page-size-name-letter' => 'Letter',
        'pdfjs-document-properties-page-size-name-legal' => 'Legal',
        'pdfjs-document-properties-page-size-name-a-three' => 'A3',
        'pdfjs-document-properties-page-size-name-a-four' => 'A4',
        'pdfjs-document-properties-page-size-orientation-portrait' =>
          'portrait',
        'pdfjs-document-properties-page-size-orientation-landscape' =>
          'landscape',
        'pdfjs-document-properties-page-size-dimension-name-string' =>
          '${args['width']}x${args['height']} ${args['unit']} ${args['name']} ${args['orientation']}',
        'pdfjs-document-properties-page-size-dimension-string' =>
          '${args['width']}x${args['height']} ${args['unit']} ${args['orientation']}',
        'pdfjs-document-properties-date-time-string' =>
          'date:${args['dateObj']}',
        'pdfjs-document-properties-linearized-yes' => 'yes',
        'pdfjs-document-properties-linearized-no' => 'no',
        _ => request.id,
      };
      return L10nMessage(value);
    }).toList();
  }

  @override
  void connectRoot(Object element) {}
  @override
  void disconnectRoot(Object element) {}
  @override
  void pauseObserving() {}
  @override
  void resumeObserving() {}
  @override
  Future<void> translateElements(List<Object> elements) async {}
  @override
  Future<void> translateRoots() async {}
}
