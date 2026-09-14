// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'dart:typed_data';

import '../core/document.dart' as core;
import '../core/operator_list.dart';
import '../core/pdf_manager.dart';
import 'annotation_storage.dart';
import 'api_utils.dart';
import 'canvas_backend_stub.dart'
    if (dart.library.js_interop) 'canvas_backend.dart' as canvas_backend;
import 'display_utils.dart';
import 'source_loader_stub.dart'
    if (dart.library.js_interop) 'source_loader_web.dart' as source_loader;

export 'canvas_backend_stub.dart'
    if (dart.library.js_interop) 'canvas_backend.dart' show CanvasPageRenderer;

/// Data accepted by [getDocument].
///
/// Browser builds fetch [url] directly. Other platforms can supply [urlLoader]
/// to choose their HTTP client, while [data] works on every platform.
class DocumentInitParameters {
  final Uint8List? data;
  final Uri? url;
  final String? password;
  final String? docBaseUrl;
  final bool enableXfa;
  final Map<String, dynamic> evaluatorOptions;
  final FutureOr<Uint8List> Function(Uri url)? urlLoader;

  DocumentInitParameters({
    dynamic data,
    dynamic url,
    this.password,
    this.docBaseUrl,
    this.enableXfa = false,
    this.evaluatorOptions = const {},
    this.urlLoader,
  })  : data = data == null ? null : getDataProp(data),
        url = url == null ? null : getUrlProp(url) {
    if (this.data == null && this.url == null) {
      throw ArgumentError('DocumentInitParameters requires data or url.');
    }
    if (this.data != null && this.url != null) {
      throw ArgumentError('Specify either data or url, not both.');
    }
  }
}

/// Rendering arguments shared by the built-in canvas renderer and custom
/// renderers.
class RenderParameters {
  final dynamic canvasContext;
  final PageViewport viewport;
  final List<num>? transform;
  final String background;
  final String intent;
  final AnnotationStorage? annotationStorage;
  final bool Function(int index)? operationsFilter;

  const RenderParameters({
    required this.canvasContext,
    required this.viewport,
    this.transform,
    this.background = '#ffffff',
    this.intent = 'display',
    this.annotationStorage,
    this.operationsFilter,
  });
}

/// An adapter that consumes a core [OperatorList].
///
/// [CanvasGraphics] implements this contract in web builds. Keeping the
/// contract explicit also makes page rendering deterministic in tests and
/// allows non-canvas targets to provide their own backend.
abstract interface class PDFPageRenderer {
  FutureOr<void> render(
    OperatorList operatorList,
    RenderParameters parameters,
  );

  void cancel([dynamic reason]) {}
}

typedef PDFPageRendererFactory = PDFPageRenderer Function(
  RenderParameters parameters,
);

PDFPageRenderer _createCanvasRenderer(RenderParameters parameters) {
  return canvas_backend.createCanvasPageRenderer(parameters);
}

PDFPageRendererFactory? _defaultRendererFactory = _createCanvasRenderer;

/// Registers the display backend used when [PDFPageProxy.render] does not
/// receive an explicit renderer factory.
void setDefaultPageRendererFactory(PDFPageRendererFactory? factory) {
  _defaultRendererFactory = factory;
}

/// Restores the built-in browser Canvas 2D backend after a custom renderer.
void resetDefaultPageRendererFactory() {
  _defaultRendererFactory = _createCanvasRenderer;
}

/// A cancellable handle returned immediately by [PDFPageProxy.render].
class RenderTask {
  final Completer<void> _completer = Completer<void>();
  PDFPageRenderer? _renderer;
  bool _cancelled = false;
  bool _settled = false;

  Future<void> get promise => _completer.future;
  bool get cancelled => _cancelled;

  void cancel([int extraDelay = 0]) {
    if (_settled || _cancelled) return;
    _cancelled = true;
    final exception = RenderingCancelledException(
      'Rendering cancelled, page rendering is no longer required.',
      extraDelay,
    );
    _renderer?.cancel(exception);
    _fail(exception);
  }

  void _attach(PDFPageRenderer renderer) {
    _renderer = renderer;
    if (_cancelled) {
      renderer.cancel(RenderingCancelledException('Rendering cancelled.'));
    }
  }

  void _complete() {
    if (_settled || _cancelled) return;
    _settled = true;
    _completer.complete();
  }

  void _fail(Object error, [StackTrace? stackTrace]) {
    if (_settled) return;
    _settled = true;
    _completer.completeError(error, stackTrace);
  }
}

/// A cancellable handle for asynchronous document loading.
class PDFDocumentLoadingTask {
  final String docId;
  final Completer<PDFDocumentProxy> _completer = Completer<PDFDocumentProxy>();
  BasePdfManager? _manager;
  bool _destroyed = false;
  void Function(Map<String, int> progress)? onProgress;
  void Function(String reason)? onPassword;

  PDFDocumentLoadingTask._(this.docId);

  Future<PDFDocumentProxy> get promise => _completer.future;
  bool get destroyed => _destroyed;

  Future<void> destroy() async {
    if (_destroyed) return;
    _destroyed = true;
    _manager?.terminate(StateError('Loading task destroyed.'));
    if (!_completer.isCompleted) {
      _completer.completeError(StateError('Loading task destroyed.'));
    } else {
      try {
        final document = await _completer.future;
        await document.destroy();
      } catch (_) {
        // The original loading error remains the authoritative error.
      }
    }
  }

  void _complete(PDFDocumentProxy document) {
    if (_destroyed || _completer.isCompleted) return;
    _completer.complete(document);
  }

  void _fail(Object error, StackTrace stackTrace) {
    if (_completer.isCompleted) return;
    _completer.completeError(error, stackTrace);
  }
}

int _nextDocumentId = 0;

/// Starts loading a PDF document.
///
/// [source] may be a [Uint8List], [ByteBuffer], `List<int>`, String containing
/// binary bytes, URI/String URL, a parameter map, or [DocumentInitParameters].
PDFDocumentLoadingTask getDocument(dynamic source) {
  final parameters = _normalizeSource(source);
  final task = PDFDocumentLoadingTask._('d${++_nextDocumentId}');
  scheduleMicrotask(() => _loadDocument(task, parameters));
  return task;
}

DocumentInitParameters _normalizeSource(dynamic source) {
  if (source is DocumentInitParameters) return source;
  if (source is Uint8List || source is ByteBuffer || source is List<int>) {
    return DocumentInitParameters(data: source);
  }
  if (source is Uri) return DocumentInitParameters(url: source);
  if (source is String) {
    final uri = Uri.tryParse(source);
    if (uri != null && uri.hasScheme) {
      return DocumentInitParameters(url: uri);
    }
    return DocumentInitParameters(data: source);
  }
  if (source is Map) {
    return DocumentInitParameters(
      data: source['data'],
      url: source['url'],
      password: source['password'] as String?,
      docBaseUrl: source['docBaseUrl'] as String?,
      enableXfa: source['enableXfa'] == true,
      evaluatorOptions:
          (source['evaluatorOptions'] as Map?)?.cast<String, dynamic>() ??
              const {},
      urlLoader: source['urlLoader'] as FutureOr<Uint8List> Function(Uri)?,
    );
  }
  throw ArgumentError('Invalid getDocument source.');
}

Future<void> _loadDocument(
  PDFDocumentLoadingTask task,
  DocumentInitParameters parameters,
) async {
  try {
    var bytes = parameters.data;
    if (bytes == null) {
      final loader = parameters.urlLoader;
      bytes = loader != null
          ? await loader(parameters.url!)
          : await source_loader.loadPdfUrl(
              parameters.url!,
              onProgress: task.onProgress,
            );
    }
    if (task.destroyed) return;
    task.onProgress?.call({'loaded': bytes.length, 'total': bytes.length});

    final manager = LocalPdfManager(
      source: bytes,
      docBaseUrl: parameters.docBaseUrl ?? parameters.url?.toString(),
      docId: task.docId,
      enableXfa: parameters.enableXfa,
      evaluatorOptions: parameters.evaluatorOptions,
      password: parameters.password,
    );
    task._manager = manager;
    final document = core.PDFDocument(manager, manager.stream);
    manager.pdfDocument = document;

    document.checkHeader();
    document.parseStartXRef();
    try {
      document.parse(false);
      await document.checkFirstPage(false);
      await document.checkLastPage(false);
    } catch (error) {
      if (task.destroyed) return;
      document.parse(true);
      await document.checkFirstPage(true);
      await document.checkLastPage(true);
    }
    if (task.destroyed) return;
    task._complete(PDFDocumentProxy._(manager, document));
  } catch (error, stackTrace) {
    task._fail(error, stackTrace);
  }
}

/// Public facade for a parsed PDF document.
class PDFDocumentProxy {
  final BasePdfManager _manager;
  final core.PDFDocument _document;
  final Map<int, PDFPageProxy> _pageCache = {};
  final AnnotationStorage annotationStorage = AnnotationStorage();
  bool _destroyed = false;

  PDFDocumentProxy._(this._manager, this._document);

  int get numPages => _document.numPages;
  List<String?> get fingerprints => _document.fingerprints;
  String? get fingerprint => fingerprints.firstOrNull;
  bool get destroyed => _destroyed;

  Future<PDFPageProxy> getPage(int pageNumber) async {
    _ensureActive();
    if (pageNumber < 1 || pageNumber > numPages) {
      throw RangeError.range(pageNumber, 1, numPages, 'pageNumber');
    }
    final cached = _pageCache[pageNumber];
    if (cached != null) return cached;
    final page = await _document.getPage(pageNumber - 1);
    _ensureActive();
    return _pageCache.putIfAbsent(
      pageNumber,
      () => PDFPageProxy._(this, pageNumber - 1, page),
    );
  }

  Map<String, dynamic> getDocumentInfo() {
    _ensureActive();
    return Map<String, dynamic>.unmodifiable(_document.documentInfo);
  }

  Future<void> cleanup() async {
    _ensureActive();
    for (final page in _pageCache.values) {
      page.cleanup();
    }
    await _document.cleanup(true);
  }

  Future<void> destroy() async {
    if (_destroyed) return;
    _destroyed = true;
    for (final page in _pageCache.values) {
      page._destroy();
    }
    _pageCache.clear();
    await _document.cleanup(true);
    _manager.terminate(StateError('PDF document destroyed.'));
  }

  void _ensureActive() {
    if (_destroyed) throw StateError('PDF document has been destroyed.');
  }
}

/// Public facade for one PDF page. Page numbers are one-based while
/// [pageIndex] follows the zero-based core convention.
class PDFPageProxy {
  final PDFDocumentProxy _owner;
  final core.Page _page;
  final Set<RenderTask> _renderTasks = {};
  OperatorList? _operatorList;
  bool _destroyed = false;

  final int pageIndex;

  PDFPageProxy._(this._owner, this.pageIndex, this._page);

  int get pageNumber => pageIndex + 1;
  int get rotate => _page.rotate;
  double get userUnit => _page.userUnit;
  List<num> get view => List<num>.unmodifiable(_page.view);
  bool get destroyed => _destroyed;

  PageViewport getViewport({
    required double scale,
    int? rotation,
    double offsetX = 0,
    double offsetY = 0,
    bool dontFlip = false,
  }) {
    _ensureActive();
    if (!scale.isFinite || scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'must be positive and finite');
    }
    return PageViewport(
      viewBox: view,
      userUnit: userUnit,
      scale: scale,
      rotation: rotation ?? rotate,
      offsetX: offsetX,
      offsetY: offsetY,
      dontFlip: dontFlip,
    );
  }

  Future<OperatorList> getOperatorList({String intent = 'display'}) async {
    _ensureActive();
    final cached = _operatorList;
    if (cached != null) return cached;
    final opList = await _page.getOperatorList(
      intent: intent == 'print' ? 1 : 0,
      annotationStorage: _owner.annotationStorage,
    );
    _ensureActive();
    return _operatorList ??= opList;
  }

  Future<Map<String, dynamic>> getTextContent({
    bool normalizeWhitespace = false,
    bool includeMarkedContent = false,
  }) {
    _ensureActive();
    return _page.extractTextContent(
      normalizeWhitespace: normalizeWhitespace,
      includeMarkedContent: includeMarkedContent,
    );
  }

  RenderTask render(
    RenderParameters parameters, {
    PDFPageRendererFactory? rendererFactory,
  }) {
    _ensureActive();
    final factory = rendererFactory ?? _defaultRendererFactory;
    if (factory == null) {
      throw StateError(
        'No PDF page renderer is registered. Import the canvas backend or '
        'pass rendererFactory.',
      );
    }
    final task = RenderTask();
    _renderTasks.add(task);
    Future<void>(() async {
      try {
        if (task.cancelled) return;
        final renderer = factory(parameters);
        task._attach(renderer);
        if (task.cancelled) return;
        final opList = await getOperatorList(intent: parameters.intent);
        if (task.cancelled) return;
        await renderer.render(opList, parameters);
        task._complete();
      } catch (error, stackTrace) {
        task._fail(error, stackTrace);
      } finally {
        _renderTasks.remove(task);
      }
    });
    return task;
  }

  void cleanup() {
    _ensureActive();
    _operatorList = null;
    _page.cleanup();
  }

  void _destroy() {
    if (_destroyed) return;
    _destroyed = true;
    for (final task in _renderTasks.toList()) {
      task.cancel();
    }
    _renderTasks.clear();
    _operatorList = null;
    _page.cleanup();
  }

  void _ensureActive() {
    _owner._ensureActive();
    if (_destroyed) throw StateError('PDF page has been destroyed.');
  }
}
