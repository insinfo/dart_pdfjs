// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'dart:typed_data';

import '../shared/util.dart';
import 'base_stream.dart';
import 'chunked_stream.dart';
import 'core_utils.dart';
import 'image_resizer.dart';
import 'jpeg_stream.dart';
import 'jpx.dart';
import 'operator_list.dart';
import 'stream.dart';

String? _parseDocBaseUrl(String? url) {
  if (url != null && url.isNotEmpty) {
    try {
      final uri = Uri.parse(url);
      if (uri.isAbsolute) {
        return uri.toString();
      }
    } catch (_) {}
    warn('Invalid absolute docBaseUrl: "$url".');
  }
  return null;
}

typedef PDFManager = BasePdfManager;

abstract class BasePdfManager {
  final String? _docBaseUrl;
  final String? _docId;
  String? _password;
  final bool enableXfa;
  final Map<String, dynamic> evaluatorOptions;
  dynamic pdfDocument;

  BasePdfManager({
    String? docBaseUrl,
    String? docId,
    bool enableXfa = false,
    Map<String, dynamic> evaluatorOptions = const {},
    dynamic handler,
    String? password,
  })  : _docBaseUrl = _parseDocBaseUrl(docBaseUrl),
        _docId = docId,
        _password = password,
        enableXfa = enableXfa,
        evaluatorOptions = Map<String, dynamic>.unmodifiable(evaluatorOptions) {
    // Initialize image options
    ImageResizer.setOptions(
      canvasMaxAreaInBytes: evaluatorOptions['canvasMaxAreaInBytes'] ?? -1,
      isImageDecoderSupported: evaluatorOptions['isImageDecoderSupported'] ?? false,
    );
    JpegStream.setOptions(evaluatorOptions);
    OperatorList.setOptions(
      isOffscreenCanvasSupported: evaluatorOptions['isOffscreenCanvasSupported'] ?? false,
    );
    JpxImage.setOptions(
      handler: handler,
      useWasm: evaluatorOptions['useWasm'] ?? false,
      useWorkerFetch: evaluatorOptions['useWorkerFetch'] ?? true,
      wasmUrl: evaluatorOptions['wasmUrl'],
    );
  }

  String? get docId => _docId;
  String? get password => _password;
  String? get docBaseUrl => _docBaseUrl;

  Future<dynamic> ensureDoc(dynamic propOrAction, [List<dynamic>? args]) {
    return ensure(pdfDocument, propOrAction, args);
  }

  Future<dynamic> ensureXRef(dynamic propOrAction, [List<dynamic>? args]) {
    return ensure(pdfDocument?.xref, propOrAction, args);
  }

  Future<dynamic> ensureCatalog(dynamic propOrAction, [List<dynamic>? args]) {
    return ensure(pdfDocument?.catalog, propOrAction, args);
  }

  dynamic getPage(int pageIndex) {
    return pdfDocument?.getPage(pageIndex);
  }

  dynamic fontFallback(dynamic id, dynamic handler) {
    return pdfDocument?.fontFallback(id, handler);
  }

  dynamic cleanup([bool manuallyTriggered = false]) {
    return pdfDocument?.cleanup(manuallyTriggered);
  }

  Future<dynamic> ensure(dynamic obj, dynamic propOrAction, [List<dynamic>? args]);

  Future<void> requestRange(int begin, int end);

  Future<BaseStream> requestLoadedStream([bool noFetch = false]);

  void sendProgressiveData(dynamic chunk);

  void updatePassword(String password) {
    _password = password;
  }

  void terminate([dynamic reason]);
}

class LocalPdfManager extends BasePdfManager {
  final BaseStream stream;
  late final Future<BaseStream> _loadedStreamFuture;

  LocalPdfManager({
    required dynamic source,
    String? docBaseUrl,
    String? docId,
    bool enableXfa = false,
    Map<String, dynamic> evaluatorOptions = const {},
    dynamic handler,
    String? password,
    dynamic pdfDocument,
  })  : stream = (source is BaseStream)
            ? source
            : Stream(
                source is Uint8List
                    ? source
                    : (source is ByteBuffer
                        ? Uint8List.view(source)
                        : Uint8List.fromList((source as List).cast<int>())),
              ),
        super(
          docBaseUrl: docBaseUrl,
          docId: docId,
          enableXfa: enableXfa,
          evaluatorOptions: evaluatorOptions,
          handler: handler,
          password: password,
        ) {
    this.pdfDocument = pdfDocument;
    _loadedStreamFuture = Future.value(stream);
  }

  @override
  Future<dynamic> ensure(dynamic obj, dynamic propOrAction, [List<dynamic>? args]) async {
    if (propOrAction is Function) {
      if (args != null && args.isNotEmpty) {
        return Function.apply(propOrAction, args);
      }
      return propOrAction();
    }
    if (obj is Map) {
      final val = obj[propOrAction];
      if (val is Function) {
        return Function.apply(val, args ?? const []);
      }
      return val;
    }
    // Dynamic property access if string
    try {
      final dynamic dObj = obj;
      final val = dObj[propOrAction];
      if (val is Function) {
        return Function.apply(val, args ?? const []);
      }
      return val;
    } catch (_) {}
    return null;
  }

  @override
  Future<void> requestRange(int begin, int end) async {}

  @override
  Future<BaseStream> requestLoadedStream([bool noFetch = false]) {
    return _loadedStreamFuture;
  }

  @override
  void sendProgressiveData(dynamic chunk) {}

  @override
  void terminate([dynamic reason]) {}
}

class NetworkPdfManager extends BasePdfManager {
  late final ChunkedStreamManager streamManager;

  NetworkPdfManager({
    required dynamic source,
    required int length,
    required int rangeChunkSize,
    bool disableAutoFetch = false,
    String? docBaseUrl,
    String? docId,
    bool enableXfa = false,
    Map<String, dynamic> evaluatorOptions = const {},
    dynamic handler,
    String? password,
    dynamic pdfDocument,
  }) : super(
          docBaseUrl: docBaseUrl,
          docId: docId,
          enableXfa: enableXfa,
          evaluatorOptions: evaluatorOptions,
          handler: handler,
          password: password,
        ) {
    this.pdfDocument = pdfDocument;
    streamManager = ChunkedStreamManager(
      source,
      length: length,
      rangeChunkSize: rangeChunkSize,
      disableAutoFetch: disableAutoFetch,
      msgHandler: handler,
    );
  }

  @override
  Future<dynamic> ensure(dynamic obj, dynamic propOrAction, [List<dynamic>? args]) async {
    try {
      if (propOrAction is Function) {
        if (args != null && args.isNotEmpty) {
          return await Function.apply(propOrAction, args);
        }
        return await propOrAction();
      }
      if (obj is Map) {
        final val = obj[propOrAction];
        if (val is Function) {
          return await Function.apply(val, args ?? const []);
        }
        return val;
      }
      final dynamic dObj = obj;
      final val = dObj[propOrAction];
      if (val is Function) {
        return await Function.apply(val, args ?? const []);
      }
      return val;
    } on MissingDataException catch (ex) {
      await requestRange(ex.begin, ex.end);
      return ensure(obj, propOrAction, args);
    }
  }

  @override
  Future<void> requestRange(int begin, int end) {
    return streamManager.requestRange(begin, end);
  }

  @override
  Future<BaseStream> requestLoadedStream([bool noFetch = false]) {
    return streamManager.requestAllChunks(noFetch);
  }

  @override
  void sendProgressiveData(dynamic chunk) {
    final Uint8List bytes = chunk is Uint8List
        ? chunk
        : Uint8List.fromList((chunk as List).cast<int>());
    streamManager.onReceiveData(chunk: bytes);
  }

  @override
  void terminate([dynamic reason]) {
    streamManager.abort(reason);
  }
}
