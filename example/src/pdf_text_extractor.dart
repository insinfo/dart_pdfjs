// Copyright 2024 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';

import 'event_utils.dart';

/// Viewer capability required by [PdfTextExtractor].
abstract interface class TextProvidingViewer {
  Future<String> getAllText();
}

/// Host service receiving extracted document text.
abstract interface class TextReportingService {
  void reportText({required String text, required int requestId});
}

/// A text request originating outside of the viewer.
class TextContentRequest {
  final int requestId;

  const TextContentRequest(this.requestId);
}

typedef CacheTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

/// Extracts all document text and forwards it to the embedding service.
///
/// Extraction is shared by concurrent consumers and cached for five seconds,
/// mirroring the PDF.js viewer. A `pagesdestroy` event invalidates both the
/// current viewer and cached text; the next `pagesinit` supplies a new viewer.
class PdfTextExtractor {
  static const Duration cacheDuration = Duration(seconds: 5);

  final TextReportingService _externalServices;
  final EventBus _eventBus;
  final CacheTimerFactory _timerFactory;
  StreamSubscription<TextContentRequest>? _requestSubscription;

  Completer<TextProvidingViewer> _viewerCapability = Completer();
  Future<String>? _textFuture;
  Timer? _cacheTimer;
  bool _disposed = false;

  late final EventBusListener _pagesInitListener;
  late final EventBusListener _pagesDestroyListener;

  PdfTextExtractor(
    this._externalServices,
    TextProvidingViewer initialViewer,
    this._eventBus, {
    Stream<TextContentRequest>? requests,
    CacheTimerFactory timerFactory = _defaultTimerFactory,
  }) : _timerFactory = timerFactory {
    // The viewer passed by the application becomes usable only after
    // `pagesinit`, exactly as in the reference implementation.
    _pagesInitListener = (data) {
      final viewer = data is TextProvidingViewer ? data : initialViewer;
      if (!_viewerCapability.isCompleted) {
        _viewerCapability.complete(viewer);
      }
    };
    _pagesDestroyListener = (_) {
      if (!_viewerCapability.isCompleted) {
        _viewerCapability.completeError(StateError('pagesdestroy'));
      }
      _textFuture = null;
      _cacheTimer?.cancel();
      _cacheTimer = null;
      _viewerCapability = Completer<TextProvidingViewer>();
    };
    _eventBus
      ..internalOn('pagesinit', _pagesInitListener)
      ..internalOn('pagesdestroy', _pagesDestroyListener);

    if (requests != null) {
      _requestSubscription = requests.listen(
        (request) => unawaited(extractTextContent(request.requestId)),
      );
    }
  }

  Future<void> extractTextContent(int requestId) async {
    if (_disposed) {
      throw StateError('PdfTextExtractor has been disposed.');
    }
    var textFuture = _textFuture;
    if (textFuture == null) {
      textFuture = _viewerCapability.future.then(
        (viewer) => viewer.getAllText(),
      );
      _textFuture = textFuture;
      textFuture.then((_) {
        _cacheTimer?.cancel();
        _cacheTimer = _timerFactory(cacheDuration, () {
          if (identical(_textFuture, textFuture)) {
            _textFuture = null;
          }
          _cacheTimer = null;
        });
      }, onError: (_) {
        if (identical(_textFuture, textFuture)) {
          _textFuture = null;
        }
      });
    }

    _externalServices.reportText(
      text: await textFuture,
      requestId: requestId,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _eventBus
      ..internalOff('pagesinit', _pagesInitListener)
      ..internalOff('pagesdestroy', _pagesDestroyListener);
    _cacheTimer?.cancel();
    await _requestSubscription?.cancel();
    _textFuture = null;
  }
}

Timer _defaultTimerFactory(Duration duration, void Function() callback) =>
    Timer(duration, callback);
