// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'dart:typed_data';

import '../shared/message_handler.dart';
import '../shared/util.dart';
import 'document.dart';
import 'pdf_manager.dart';
import 'primitives.dart';

/// A cancellable unit of work owned by a document worker.
class WorkerTask {
  WorkerTask(this.name);

  final String name;
  bool terminated = false;
  final Completer<void> _completer = Completer<void>();

  Future<void> get finished => _completer.future;
  bool get finishedSuccessfully => _completer.isCompleted && !terminated;

  void finish() {
    if (!_completer.isCompleted) _completer.complete();
  }

  void terminate() {
    terminated = true;
  }

  void ensureNotTerminated() {
    if (terminated) throw StateError('Worker task "$name" was terminated');
  }
}

typedef PdfManagerFactory = FutureOr<BasePdfManager> Function(
  Map<String, dynamic> parameters,
);

/// The per-document portion of the PDF worker protocol.
///
/// Keeping this object independent from isolates makes the complete message
/// protocol usable by browsers, isolates and deterministic unit tests alike.
class WorkerDocumentHandler {
  WorkerDocumentHandler({
    required this.docId,
    required this.handler,
    required this.pdfManager,
  });

  final String docId;
  final MessageHandler handler;
  final BasePdfManager pdfManager;
  final Set<WorkerTask> _tasks = <WorkerTask>{};
  bool _terminated = false;
  bool _registered = false;

  bool get terminated => _terminated;
  int get activeTaskCount => _tasks.length;
  Iterable<WorkerTask> get activeTasks => List.unmodifiable(_tasks);

  void ensureNotTerminated() {
    if (_terminated) throw StateError('Worker was terminated');
  }

  WorkerTask startTask(String name) {
    ensureNotTerminated();
    final task = WorkerTask(name);
    _tasks.add(task);
    return task;
  }

  void finishTask(WorkerTask task) {
    task.finish();
    _tasks.remove(task);
  }

  Future<T> runTask<T>(
      String name, FutureOr<T> Function(WorkerTask) body) async {
    final task = startTask(name);
    try {
      final result = await body(task);
      task.ensureNotTerminated();
      return result;
    } finally {
      finishTask(task);
    }
  }

  Future<Map<String, dynamic>> loadDocument({bool recoveryMode = false}) async {
    ensureNotTerminated();
    await pdfManager.ensureDoc('checkHeader');
    await pdfManager.ensureDoc('parseStartXRef');
    await pdfManager.ensureDoc('parse', [recoveryMode]);
    await pdfManager.ensureDoc('checkFirstPage', [recoveryMode]);
    await pdfManager.ensureDoc('checkLastPage', [recoveryMode]);
    final isPureXfa = await pdfManager.ensureDoc('isPureXfa') == true;
    if (isPureXfa) {
      await runTask<void>('loadXfaResources', (task) async {
        await pdfManager.ensureDoc('loadXfaResources', [handler, task]);
      });
    }
    final numPages = await pdfManager.ensureDoc('numPages');
    final fingerprints = await pdfManager.ensureDoc('fingerprints');
    return <String, dynamic>{
      'numPages': numPages,
      'fingerprints': fingerprints,
      'htmlForXfa': isPureXfa ? await pdfManager.ensureDoc('htmlForXfa') : null,
    };
  }

  /// Installs all actions understood by the display-side transport.
  void registerActions() {
    if (_registered) return;
    _registered = true;

    handler.on('Ready', (_) async {
      ensureNotTerminated();
      return loadDocument();
    });
    handler.on('GetPage', _getPage);
    handler.on('GetPageIndex', (dynamic data) {
      ensureNotTerminated();
      final map = _map(data);
      return pdfManager.ensureCatalog(
        'getPageIndex',
        [Ref.get(_int(map['num']), _int(map['gen']))],
      );
    });
    _catalogAction('GetDestinations', 'destinations');
    _catalogAction('GetDestination', 'getDestination', argument: 'id');
    _catalogAction('GetPageLabels', 'pageLabels');
    _catalogAction('GetPageLayout', 'pageLayout');
    _catalogAction('GetPageMode', 'pageMode');
    _catalogAction('GetViewerPreferences', 'viewerPreferences');
    _catalogAction('GetOpenAction', 'openAction');
    _catalogAction('GetAttachments', 'attachments');
    _catalogAction('GetDocJSActions', 'jsActions');
    _catalogAction('GetOutline', 'documentOutline');
    _catalogAction('GetOptionalContentConfig', 'optionalContentConfig');
    _catalogAction('GetPermissions', 'permissions');
    _catalogAction('GetMarkInfo', 'markInfo');

    handler.on('GetPageJSActions', (dynamic data) async {
      ensureNotTerminated();
      final page = await pdfManager.getPage(_pageIndex(data));
      return pdfManager.ensure(page, 'jsActions');
    });
    handler.on('GetMetadata', (_) async {
      ensureNotTerminated();
      return <dynamic>[
        await pdfManager.ensureDoc('documentInfo'),
        await pdfManager.ensureCatalog('metadata'),
        await pdfManager.ensureCatalog('hasStructTree'),
      ];
    });
    handler.on('GetData', (_) async {
      ensureNotTerminated();
      final stream = await pdfManager.requestLoadedStream();
      stream.reset();
      return Uint8List.fromList(stream.getBytes());
    });
    handler.on('GetFieldObjects', (_) async {
      ensureNotTerminated();
      final fields = await pdfManager.ensureDoc('fieldObjects');
      return fields is Map ? fields['allFields'] : fields;
    });
    _documentAction('HasJSActions', 'hasJSActions');
    _documentAction('GetCalculationOrderIds', 'calculationOrderIds');
    handler.on('GetOperatorList', _getOperatorList);
    handler.on('GetTextContent', _getTextContent);
    handler.on('GetStructTree', (dynamic data) async {
      ensureNotTerminated();
      final page = await pdfManager.getPage(_pageIndex(data));
      return pdfManager.ensure(page, 'getStructTree');
    });
    handler.on('FontFallback', (dynamic data) {
      ensureNotTerminated();
      return pdfManager.fontFallback(_map(data)['id'], handler);
    });
    handler.on('Cleanup', (dynamic data) {
      ensureNotTerminated();
      return pdfManager.cleanup(_map(data)['manuallyTriggered'] == true);
    });
    handler.on('Terminate', (_) => terminate());
  }

  void _catalogAction(String action, String property, {String? argument}) {
    handler.on(action, (dynamic data) {
      ensureNotTerminated();
      final args = argument == null ? null : <dynamic>[_map(data)[argument]];
      return pdfManager.ensureCatalog(property, args);
    });
  }

  void _documentAction(String action, String property) {
    handler.on(action, (_) {
      ensureNotTerminated();
      return pdfManager.ensureDoc(property);
    });
  }

  Future<Map<String, dynamic>> _getPage(dynamic data) async {
    ensureNotTerminated();
    final page = await pdfManager.getPage(_pageIndex(data));
    final rotate = await pdfManager.ensure(page, 'rotate');
    final ref = await pdfManager.ensure(page, 'ref');
    return <String, dynamic>{
      'rotate': rotate,
      'ref': ref,
      'refStr': ref?.toString(),
      'userUnit': await pdfManager.ensure(page, 'userUnit'),
      'view': await pdfManager.ensure(page, 'view'),
    };
  }

  Future<dynamic> _getOperatorList(dynamic data, [dynamic sink]) {
    final values = _map(data);
    final index = _pageIndex(values);
    return runTask<dynamic>('GetOperatorList: page $index', (task) async {
      final page = await pdfManager.getPage(index);
      if (page is Page) {
        final list = await page.getOperatorList(
          handler: handler,
          sink: sink,
          task: task,
          intent: values['intent'],
          cacheKey: values['cacheKey'],
          annotationStorage: values['annotationStorage'],
          modifiedIds: values['modifiedIds'],
        );
        return <String, dynamic>{
          'length': list.length,
          'lastChunk': true,
          'separateAnnots': null,
        };
      }
      return pdfManager.ensure(page, 'getOperatorList', [
        handler,
        sink,
        task,
        values,
      ]);
    });
  }

  Future<dynamic> _getTextContent(dynamic data, [dynamic sink]) {
    final values = _map(data);
    final index = _pageIndex(values);
    return runTask<dynamic>('GetTextContent: page $index', (task) async {
      final page = await pdfManager.getPage(index);
      dynamic content;
      if (page is Page) {
        content = await page.extractTextContent(
          handler: handler,
          task: task,
          normalizeWhitespace: values['normalizeWhitespace'] == true,
          includeMarkedContent: values['includeMarkedContent'] == true,
        );
      } else {
        content = await pdfManager.ensure(page, 'extractTextContent', [
          handler,
          task,
          values,
        ]);
      }
      if (sink != null && content is Map && content['items'] is Iterable) {
        sink.enqueue(content);
        sink.close();
        return null;
      }
      return content;
    });
  }

  Future<void> terminate([dynamic reason]) async {
    if (_terminated) return;
    _terminated = true;
    final tasks = List<WorkerTask>.from(_tasks);
    for (final task in tasks) {
      task.terminate();
    }
    pdfManager.terminate(reason ?? AbortException('Worker was terminated.'));
    if (tasks.isNotEmpty) {
      await Future.wait(tasks.map((task) => task.finished));
    }
    _tasks.clear();
    handler.destroy();
  }
}

/// Entry point shared by browser workers and local/in-process transports.
class WorkerMessageHandler {
  static final Map<String, WorkerDocumentHandler> _documents = {};

  static Map<String, WorkerDocumentHandler> get documents =>
      Map.unmodifiable(_documents);

  static void setup(
    MessageHandler handler, {
    PdfManagerFactory? managerFactory,
  }) {
    var testProcessed = false;
    handler.on('test', (dynamic data) {
      if (testProcessed) return null;
      testProcessed = true;
      final supported = data is Uint8List || data is ByteBuffer;
      handler.send('test', supported);
      return supported;
    });
    handler.on('configure', (_) => null);
    handler.on('GetDocRequest', (dynamic data) async {
      final params = Map<String, dynamic>.from(_map(data));
      final doc = await createDocumentHandler(
        params,
        port: handler.comObj,
        managerFactory: managerFactory,
      );
      return doc.handler.sourceName;
    });
    handler.on('GetWorkerCoverage', (_) => const <String, dynamic>{});
  }

  static Future<WorkerDocumentHandler> createDocumentHandler(
    Map<String, dynamic> docParams, {
    ComObj? port,
    MessageHandler? handler,
    PdfManagerFactory? managerFactory,
  }) async {
    final docId = docParams['docId']?.toString() ?? 'document';
    final messageHandler = handler ??
        MessageHandler('${docId}_worker', docId,
            port ?? (throw ArgumentError.notNull('port')));
    final manager = managerFactory != null
        ? await managerFactory(docParams)
        : await getPdfManager(docParams, handler: messageHandler);
    final document = WorkerDocumentHandler(
      docId: docId,
      handler: messageHandler,
      pdfManager: manager,
    );
    document.registerActions();
    _documents[docId] = document;
    return document;
  }

  static Future<BasePdfManager> getPdfManager(
    Map<String, dynamic> data, {
    dynamic handler,
  }) async {
    final source = data['source'] is Map
        ? Map<String, dynamic>.from(data['source'] as Map)
        : data;
    final bytes = source['data'];
    final common = source['evaluatorOptions'] is Map
        ? Map<String, dynamic>.from(source['evaluatorOptions'] as Map)
        : <String, dynamic>{};
    if (bytes != null) {
      return LocalPdfManager(
        source: bytes,
        docBaseUrl: source['docBaseUrl']?.toString(),
        docId: source['docId']?.toString() ?? data['docId']?.toString(),
        enableXfa: source['enableXfa'] == true,
        evaluatorOptions: common,
        handler: handler,
        password: source['password']?.toString(),
      );
    }
    if (source['url'] == null) throw ArgumentError('No PDF source provided');
    return NetworkPdfManager(
      source: source['url'],
      length: _int(source['length']),
      rangeChunkSize: _int(source['rangeChunkSize'], 65536),
      disableAutoFetch: source['disableAutoFetch'] == true,
      docBaseUrl: source['docBaseUrl']?.toString(),
      docId: source['docId']?.toString() ?? data['docId']?.toString(),
      enableXfa: source['enableXfa'] == true,
      evaluatorOptions: common,
      handler: handler,
      password: source['password']?.toString(),
    );
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

int _int(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

int _pageIndex(dynamic data) => _int(_map(data)['pageIndex']);
