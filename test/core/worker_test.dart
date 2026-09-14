import 'dart:async';
import 'dart:typed_data';

import 'package:pdfjs/src/core/base_stream.dart';
import 'package:pdfjs/src/core/pdf_manager.dart';
import 'package:pdfjs/src/core/stream.dart' as pdf_stream;
import 'package:pdfjs/src/core/worker.dart';
import 'package:pdfjs/src/shared/message_handler.dart';
import 'package:test/test.dart';

class _Event {
  const _Event(this.data);
  final dynamic data;
}

class _Port implements ComObj {
  final List<void Function(dynamic)> _listeners = [];
  _Port? peer;
  final List<dynamic> sent = [];

  @override
  void addEventListener(String type, Function(dynamic) listener,
      {dynamic signal}) {
    expect(type, 'message');
    _listeners.add(listener);
  }

  @override
  void postMessage(dynamic data, [List<dynamic>? transfers]) {
    sent.add(data);
    final target = peer;
    if (target == null) return;
    scheduleMicrotask(() {
      for (final listener in List.of(target._listeners)) {
        listener(_Event(data));
      }
    });
  }
}

(_Port, _Port) _ports() {
  final first = _Port();
  final second = _Port();
  first.peer = second;
  second.peer = first;
  return (first, second);
}

class _FakeManager extends BasePdfManager {
  _FakeManager({Map<String, dynamic>? document, Map<String, dynamic>? catalog})
      : document = document ?? <String, dynamic>{},
        catalog = catalog ?? <String, dynamic>{},
        super(docId: 'fake', evaluatorOptions: const {}) {
    pdfDocument = this.document;
  }

  final Map<String, dynamic> document;
  final Map<String, dynamic> catalog;
  final List<String> calls = [];
  final List<dynamic> terminationReasons = [];
  final Map<int, dynamic> pages = {};
  Uint8List loadedBytes = Uint8List.fromList([37, 80, 68, 70]);
  bool cleaned = false;

  @override
  Future<dynamic> ensure(dynamic obj, dynamic propOrAction,
      [List<dynamic>? args]) async {
    calls.add('ensure:$propOrAction');
    if (obj is Map) {
      final value = obj[propOrAction];
      return value is Function
          ? await Function.apply(value, args ?? const [])
          : value;
    }
    return null;
  }

  @override
  Future<dynamic> ensureDoc(dynamic propOrAction, [List<dynamic>? args]) {
    calls.add('doc:$propOrAction');
    return ensure(document, propOrAction, args);
  }

  @override
  Future<dynamic> ensureCatalog(dynamic propOrAction, [List<dynamic>? args]) {
    calls.add('catalog:$propOrAction');
    return ensure(catalog, propOrAction, args);
  }

  @override
  dynamic getPage(int pageIndex) async {
    calls.add('page:$pageIndex');
    return pages[pageIndex];
  }

  @override
  dynamic fontFallback(dynamic id, dynamic handler) async {
    calls.add('font:$id');
    return 'fallback:$id';
  }

  @override
  dynamic cleanup([bool manuallyTriggered = false]) async {
    cleaned = true;
    calls.add('cleanup:$manuallyTriggered');
    return null;
  }

  @override
  Future<void> requestRange(int begin, int end) async {
    calls.add('range:$begin:$end');
  }

  @override
  Future<BaseStream> requestLoadedStream([bool noFetch = false]) async {
    calls.add('loaded:$noFetch');
    return pdf_stream.Stream(Uint8List.fromList(loadedBytes));
  }

  @override
  void sendProgressiveData(dynamic chunk) {
    calls.add('progressive');
  }

  @override
  void terminate([dynamic reason]) {
    terminationReasons.add(reason);
  }
}

class _Harness {
  _Harness(this.manager, {String id = 'doc'}) {
    final pair = _ports();
    displayPort = pair.$1;
    workerPort = pair.$2;
    display = MessageHandler(id, '${id}_worker', displayPort);
    worker = MessageHandler('${id}_worker', id, workerPort);
    document = WorkerDocumentHandler(
      docId: id,
      handler: worker,
      pdfManager: manager,
    )..registerActions();
  }

  final _FakeManager manager;
  late final _Port displayPort;
  late final _Port workerPort;
  late final MessageHandler display;
  late final MessageHandler worker;
  late final WorkerDocumentHandler document;
}

Map<String, dynamic> _basicDocument() => <String, dynamic>{
      'checkHeader': () {},
      'parseStartXRef': () {},
      'parse': (bool recovery) {},
      'checkFirstPage': (bool recovery) {},
      'checkLastPage': (bool recovery) {},
      'isPureXfa': false,
      'numPages': 2,
      'fingerprints': ['abc', null],
      'documentInfo': {'Title': 'Worker test'},
      'fieldObjects': {
        'allFields': [
          {'id': 'field1'}
        ]
      },
      'hasJSActions': true,
      'calculationOrderIds': ['field1'],
    };

Map<String, dynamic> _basicCatalog() => <String, dynamic>{
      'destinations': {
        'chapter': [0, 'Fit']
      },
      'getDestination': (String id) => [id, 'XYZ'],
      'pageLabels': ['i', '1'],
      'pageLayout': 'OneColumn',
      'pageMode': 'UseOutlines',
      'viewerPreferences': {'HideToolbar': true},
      'openAction': {'action': 'Print'},
      'attachments': {'readme.txt': 'data'},
      'jsActions': {'OpenAction': 'app.alert(1)'},
      'documentOutline': [
        {'title': 'Chapter'}
      ],
      'optionalContentConfig': {'groups': []},
      'permissions': [4, 8],
      'metadata': '<xmp/>',
      'hasStructTree': true,
      'markInfo': {'Marked': true},
      'getPageIndex': (dynamic ref) => ref.num == 7 ? 3 : -1,
    };

void main() {
  group('WorkerTask', () {
    test('finishes exactly once', () async {
      final task = WorkerTask('parse');
      expect(task.name, 'parse');
      expect(task.terminated, isFalse);
      task.finish();
      task.finish();
      await task.finished;
      expect(task.finishedSuccessfully, isTrue);
    });

    test('reports cancellation', () {
      final task = WorkerTask('render')..terminate();
      expect(task.terminated, isTrue);
      expect(task.ensureNotTerminated, throwsStateError);
      task.finish();
      expect(task.finishedSuccessfully, isFalse);
    });
  });

  group('document loading', () {
    test('executes parser stages and returns document identity', () async {
      final manager = _FakeManager(document: _basicDocument());
      final harness = _Harness(manager);
      final result = await harness.document.loadDocument();

      expect(result, {
        'numPages': 2,
        'fingerprints': ['abc', null],
        'htmlForXfa': null,
      });
      expect(
          manager.calls,
          containsAllInOrder([
            'doc:checkHeader',
            'doc:parseStartXRef',
            'doc:parse',
            'doc:checkFirstPage',
            'doc:checkLastPage',
            'doc:isPureXfa',
            'doc:numPages',
            'doc:fingerprints',
          ]));
    });

    test('passes recovery mode to parse and page checks', () async {
      final recoveryValues = <bool>[];
      final doc = _basicDocument();
      doc['parse'] = (bool value) => recoveryValues.add(value);
      doc['checkFirstPage'] = (bool value) => recoveryValues.add(value);
      doc['checkLastPage'] = (bool value) => recoveryValues.add(value);
      await _Harness(_FakeManager(document: doc))
          .document
          .loadDocument(recoveryMode: true);
      expect(recoveryValues, [true, true, true]);
    });

    test('loads XFA resources as a tracked task', () async {
      WorkerTask? observed;
      dynamic observedHandler;
      final doc = _basicDocument()
        ..['isPureXfa'] = true
        ..['htmlForXfa'] = '<div>xfa</div>'
        ..['loadXfaResources'] = (dynamic handler, WorkerTask task) async {
          observed = task;
          observedHandler = handler;
          expect(task.finishedSuccessfully, isFalse);
        };
      final harness = _Harness(_FakeManager(document: doc));
      final result = await harness.document.loadDocument();
      expect(result['htmlForXfa'], '<div>xfa</div>');
      expect(observedHandler, same(harness.worker));
      expect(observed!.finishedSuccessfully, isTrue);
      expect(harness.document.activeTaskCount, 0);
    });

    test('Ready exposes loading through RPC', () async {
      final harness = _Harness(_FakeManager(document: _basicDocument()));
      final result = await harness.display.sendWithPromise('Ready', null);
      expect(result['numPages'], 2);
      expect(result['fingerprints'], ['abc', null]);
    });
  });

  group('page protocol', () {
    test('GetPage returns display page information', () async {
      final manager = _FakeManager(document: _basicDocument());
      manager.pages[0] = <String, dynamic>{
        'rotate': 90,
        'ref': null,
        'userUnit': 2.0,
        'view': [0, 0, 300, 500],
      };
      final result = await _Harness(manager)
          .display
          .sendWithPromise('GetPage', {'pageIndex': 0});
      expect(result, {
        'rotate': 90,
        'ref': null,
        'refStr': null,
        'userUnit': 2.0,
        'view': [0, 0, 300, 500],
      });
    });

    test('GetPageIndex recreates an indirect reference', () async {
      final manager = _FakeManager(
        document: _basicDocument(),
        catalog: _basicCatalog(),
      );
      final result = await _Harness(manager).display.sendWithPromise(
        'GetPageIndex',
        {'num': 7, 'gen': 2},
      );
      expect(result, 3);
    });

    test('GetPageJSActions accesses the selected page', () async {
      final manager = _FakeManager(document: _basicDocument());
      manager.pages[4] = {
        'jsActions': {'PageOpen': 'print()'}
      };
      final result = await _Harness(manager)
          .display
          .sendWithPromise('GetPageJSActions', {'pageIndex': 4});
      expect(result, {
        'PageOpen': 'print()',
      });
      expect(manager.calls, contains('page:4'));
    });

    test('GetOperatorList tracks task and forwards arguments', () async {
      final manager = _FakeManager(document: _basicDocument());
      List<dynamic>? arguments;
      manager.pages[1] = <String, dynamic>{
        'getOperatorList': (
          dynamic handler,
          dynamic sink,
          WorkerTask task,
          Map<String, dynamic> options,
        ) {
          arguments = [handler, sink, task, options];
          return {'length': 12, 'lastChunk': true};
        }
      };
      final harness = _Harness(manager);
      final result = await harness.display.sendWithPromise('GetOperatorList', {
        'pageIndex': 1,
        'intent': 4,
        'cacheKey': 'display',
      });
      expect(result, {'length': 12, 'lastChunk': true});
      expect(arguments![0], same(harness.worker));
      expect(arguments![2], isA<WorkerTask>());
      expect(arguments![3]['intent'], 4);
      expect(harness.document.activeTaskCount, 0);
    });

    test('GetTextContent returns extracted items', () async {
      final manager = _FakeManager(document: _basicDocument());
      manager.pages[0] = <String, dynamic>{
        'extractTextContent': (
          dynamic handler,
          WorkerTask task,
          Map<String, dynamic> options,
        ) =>
            {
              'items': [
                {'str': 'Hello worker'}
              ],
              'styles': <String, dynamic>{},
            }
      };
      final result = await _Harness(manager).display.sendWithPromise(
        'GetTextContent',
        {'pageIndex': 0, 'includeMarkedContent': true},
      );
      expect(result['items'].single['str'], 'Hello worker');
    });

    test('GetStructTree reads the page structure tree', () async {
      final manager = _FakeManager(document: _basicDocument());
      manager.pages[2] = <String, dynamic>{
        'getStructTree': () => {
              'role': 'Document',
              'children': [],
            }
      };
      final result = await _Harness(manager)
          .display
          .sendWithPromise('GetStructTree', {'pageIndex': 2});
      expect(result['role'], 'Document');
    });
  });

  group('catalog actions', () {
    late _Harness harness;

    setUp(() {
      harness = _Harness(_FakeManager(
        document: _basicDocument(),
        catalog: _basicCatalog(),
      ));
    });

    test('returns destinations and a named destination', () async {
      expect(
        await harness.display.sendWithPromise('GetDestinations', null),
        contains('chapter'),
      );
      expect(
        await harness.display
            .sendWithPromise('GetDestination', {'id': 'chapter'}),
        ['chapter', 'XYZ'],
      );
    });

    test('returns page presentation settings', () async {
      expect(await harness.display.sendWithPromise('GetPageLabels', null),
          ['i', '1']);
      expect(await harness.display.sendWithPromise('GetPageLayout', null),
          'OneColumn');
      expect(await harness.display.sendWithPromise('GetPageMode', null),
          'UseOutlines');
      expect(
        await harness.display.sendWithPromise('GetViewerPreferences', null),
        {'HideToolbar': true},
      );
      expect(await harness.display.sendWithPromise('GetOpenAction', null),
          {'action': 'Print'});
    });

    test('returns attachments, scripts and outline', () async {
      expect(await harness.display.sendWithPromise('GetAttachments', null),
          {'readme.txt': 'data'});
      expect(await harness.display.sendWithPromise('GetDocJSActions', null),
          {'OpenAction': 'app.alert(1)'});
      final outline =
          await harness.display.sendWithPromise('GetOutline', null) as List;
      expect(outline.single['title'], 'Chapter');
    });

    test('returns optional content, permissions and mark info', () async {
      expect(
          await harness.display
              .sendWithPromise('GetOptionalContentConfig', null),
          {'groups': []});
      expect(await harness.display.sendWithPromise('GetPermissions', null),
          [4, 8]);
      expect(await harness.display.sendWithPromise('GetMarkInfo', null),
          {'Marked': true});
    });
  });

  group('document information', () {
    test('GetMetadata combines info, XMP and structure availability', () async {
      final harness = _Harness(_FakeManager(
        document: _basicDocument(),
        catalog: _basicCatalog(),
      ));
      final result =
          await harness.display.sendWithPromise('GetMetadata', null) as List;
      expect(result[0], {'Title': 'Worker test'});
      expect(result[1], '<xmp/>');
      expect(result[2], isTrue);
    });

    test('GetData returns a detached byte representation', () async {
      final manager = _FakeManager(document: _basicDocument());
      final result = await _Harness(manager)
          .display
          .sendWithPromise('GetData', null) as Uint8List;
      expect(result, [37, 80, 68, 70]);
      result[0] = 0;
      expect(manager.loadedBytes.first, 37);
    });

    test('returns fields, JavaScript flag and calculation order', () async {
      final harness = _Harness(_FakeManager(document: _basicDocument()));
      final fields =
          await harness.display.sendWithPromise('GetFieldObjects', null);
      expect(fields.single['id'], 'field1');
      expect(await harness.display.sendWithPromise('HasJSActions', null), true);
      expect(
        await harness.display.sendWithPromise('GetCalculationOrderIds', null),
        ['field1'],
      );
    });

    test('FontFallback delegates to document manager', () async {
      final manager = _FakeManager(document: _basicDocument());
      final result = await _Harness(manager)
          .display
          .sendWithPromise('FontFallback', {'id': 'g_font1'});
      expect(result, 'fallback:g_font1');
      expect(manager.calls, contains('font:g_font1'));
    });

    test('Cleanup preserves worker and clears manager caches', () async {
      final manager = _FakeManager(document: _basicDocument());
      final harness = _Harness(manager);
      await harness.display
          .sendWithPromise('Cleanup', {'manuallyTriggered': true});
      expect(manager.cleaned, isTrue);
      expect(harness.document.terminated, isFalse);
      expect(manager.calls, contains('cleanup:true'));
    });
  });

  group('lifecycle', () {
    test('runTask removes successful and failed tasks', () async {
      final harness = _Harness(_FakeManager(document: _basicDocument()));
      expect(await harness.document.runTask('ok', (_) => 42), 42);
      expect(harness.document.activeTaskCount, 0);
      await expectLater(
        harness.document.runTask<void>('bad', (_) => throw FormatException()),
        throwsFormatException,
      );
      expect(harness.document.activeTaskCount, 0);
    });

    test('Terminate cancels manager and prevents more operations', () async {
      final manager = _FakeManager(document: _basicDocument());
      final harness = _Harness(manager);
      await harness.display.sendWithPromise('Terminate', null);
      expect(harness.document.terminated, isTrue);
      expect(manager.terminationReasons, hasLength(1));
      expect(harness.document.ensureNotTerminated, throwsStateError);
    });

    test('terminate is idempotent', () async {
      final manager = _FakeManager(document: _basicDocument());
      final harness = _Harness(manager);
      await harness.document.terminate('first');
      await harness.document.terminate('second');
      expect(manager.terminationReasons, ['first']);
    });
  });

  group('manager creation', () {
    test('creates a local manager for byte data', () async {
      final manager = await WorkerMessageHandler.getPdfManager({
        'docId': 'bytes',
        'source': {
          'data': Uint8List.fromList([1, 2, 3]),
          'password': 'secret',
          'enableXfa': true,
        }
      });
      expect(manager, isA<LocalPdfManager>());
      expect(manager.docId, 'bytes');
      expect(manager.password, 'secret');
      expect(manager.enableXfa, isTrue);
    });

    test('rejects a source without bytes or URL', () {
      expect(
        WorkerMessageHandler.getPdfManager({'source': <String, dynamic>{}}),
        throwsArgumentError,
      );
    });

    test('createDocumentHandler accepts an injectable factory', () async {
      final pair = _ports();
      final display = MessageHandler('factory', 'factory_worker', pair.$1);
      final worker = MessageHandler('factory_worker', 'factory', pair.$2);
      final manager = _FakeManager(document: _basicDocument());
      final document = await WorkerMessageHandler.createDocumentHandler(
        {'docId': 'factory'},
        handler: worker,
        managerFactory: (parameters) {
          expect(parameters['docId'], 'factory');
          return manager;
        },
      );
      expect(document.pdfManager, same(manager));
      expect(await display.sendWithPromise('HasJSActions', null), true);
    });
  });
}
