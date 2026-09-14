// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'dart:typed_data';

import '../shared/util.dart';
import 'base_stream.dart';
import 'calculate_md5.dart';
import 'catalog.dart';
import 'cleanup_helper.dart';
import 'core_utils.dart';
import 'decode_stream.dart';
import 'evaluator.dart';
import 'object_loader.dart';
import 'operator_list.dart';
import 'parser.dart';
import 'pdf_manager.dart';
import 'primitives.dart';
import 'stream.dart';
import 'xfa/factory.dart';
import 'xref.dart';

const List<num> LETTER_SIZE_MEDIABOX = [0, 0, 612, 792];

final Uint8List PDF_HEADER_SIGNATURE =
    Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d]); // %PDF-
final Uint8List STARTXREF_SIGNATURE = Uint8List.fromList(
    [0x73, 0x74, 0x61, 0x72, 0x74, 0x78, 0x72, 0x65, 0x66]); // startxref
final Uint8List ENDOBJ_SIGNATURE =
    Uint8List.fromList([0x65, 0x6e, 0x64, 0x6f, 0x62, 0x6a]); // endobj

String _bytesToHex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

bool find(BaseStream stream, List<int> signature,
    [int limit = 1024, bool backwards = false]) {
  final signatureLength = signature.length;
  final scanBytes = stream.peekBytes(limit);
  final scanLength = scanBytes.length - signatureLength;

  if (scanLength <= 0) {
    return false;
  }

  if (backwards) {
    final signatureEnd = signatureLength - 1;
    var pos = scanBytes.length - 1;
    while (pos >= signatureEnd) {
      var j = 0;
      while (j < signatureLength &&
          scanBytes[pos - j] == signature[signatureEnd - j]) {
        j++;
      }
      if (j >= signatureLength) {
        stream.pos += pos - signatureEnd;
        return true;
      }
      pos--;
    }
  } else {
    var pos = 0;
    while (pos <= scanLength) {
      var j = 0;
      while (j < signatureLength && scanBytes[pos + j] == signature[j]) {
        j++;
      }
      if (j >= signatureLength) {
        stream.pos += pos;
        return true;
      }
      pos++;
    }
  }
  return false;
}

class PageLocalIdFactory {
  final int pageIndex;
  final Ref? ref;
  int _objCounter = 0;

  PageLocalIdFactory(this.pageIndex, this.ref);

  String createObjId() => 'p${pageIndex}_${++_objCounter}';
  String getPageObjId() => ref != null ? 'p${ref.toString()}' : 'p$pageIndex';
}

class Page {
  final BasePdfManager pdfManager;
  final int pageIndex;
  final Dict pageDict;
  final XRef xref;
  final Ref? ref;
  final dynamic fontCache;
  final dynamic builtInCMapCache;
  final dynamic standardFontDataCache;
  final dynamic globalColorSpaceCache;
  final dynamic globalImageCache;
  final dynamic systemFontCache;
  final dynamic nonBlendModesSet;
  final Map<String, dynamic> evaluatorOptions;
  final XFAFactory? xfaFactory;
  final PageLocalIdFactory _localIdFactory;

  Future<dynamic>? _resourcesPromise;

  Page({
    required this.pdfManager,
    required this.xref,
    required this.pageIndex,
    required this.pageDict,
    required this.ref,
    dynamic globalIdFactory,
    this.fontCache,
    this.builtInCMapCache,
    this.standardFontDataCache,
    this.globalColorSpaceCache,
    this.globalImageCache,
    this.systemFontCache,
    this.nonBlendModesSet,
    this.xfaFactory,
  })  : evaluatorOptions = pdfManager.evaluatorOptions,
        _localIdFactory = PageLocalIdFactory(pageIndex, ref);

  PartialEvaluator _createPartialEvaluator(dynamic handler,
      [int? customPageIndex]) {
    return PartialEvaluator(
      xref: xref,
      handler: handler,
      pageIndex: customPageIndex ?? pageIndex,
      idFactory: _localIdFactory,
      fontCache: fontCache,
      builtInCMapCache: builtInCMapCache,
      standardFontDataCache: standardFontDataCache,
      globalColorSpaceCache: globalColorSpaceCache,
      globalImageCache: globalImageCache,
      systemFontCache: systemFontCache,
      options: evaluatorOptions,
    );
  }

  PartialEvaluator createAnnotationEvaluator(dynamic handler) {
    return _createPartialEvaluator(handler);
  }

  dynamic _getInheritableProperty(String key, [bool getArray = false]) {
    final value = getInheritableProperty(
      dict: pageDict,
      key: key,
      getArray: getArray,
      stopWhenFound: false,
    );
    if (value is! List) {
      return value;
    }
    if (value.length == 1 || value[0] is! Dict) {
      return value[0];
    }
    return Dict.merge(xref: xref, dictArray: value.cast<Dict>());
  }

  dynamic get content => pageDict.getArray('Contents');

  Dict get resources {
    final res = _getInheritableProperty('Resources');
    return shadow(this, 'resources', res is Dict ? res : Dict.empty);
  }

  List<num>? getBoundingBox(String name) {
    if (xfaData != null && xfaData!['bbox'] != null) {
      return (xfaData!['bbox'] as List).cast<num>();
    }
    final raw = _getInheritableProperty(name, true);
    final box = lookupNormalRect(raw is List ? raw : null, null);
    if (box != null) {
      if (box[2] - box[0] > 0 && box[3] - box[1] > 0) {
        return box;
      }
      warn('Empty, or invalid, /$name entry.');
    }
    return null;
  }

  List<num> get mediaBox {
    return shadow(
      this,
      'mediaBox',
      getBoundingBox('MediaBox') ?? List<num>.from(LETTER_SIZE_MEDIABOX),
    );
  }

  List<num> get cropBox {
    return shadow(
      this,
      'cropBox',
      getBoundingBox('CropBox') ?? mediaBox,
    );
  }

  double get userUnit {
    final obj = pageDict.get('UserUnit');
    return shadow(
      this,
      'userUnit',
      obj is num && obj > 0 ? obj.toDouble() : 1.0,
    );
  }

  List<num> get view {
    final cBox = cropBox;
    final mBox = mediaBox;

    if (!isArrayEqual(cBox, mBox)) {
      final box = Util.intersect(cBox, mBox);
      if (box != null && box[2] - box[0] > 0 && box[3] - box[1] > 0) {
        return shadow(this, 'view', box);
      }
      warn('Empty /CropBox and /MediaBox intersection.');
    }
    return shadow(this, 'view', mBox);
  }

  int get rotate {
    var r = _getInheritableProperty('Rotate');
    var rot = r is num ? r.toInt() : 0;
    if (rot % 90 != 0) {
      rot = 0;
    } else if (rot >= 360) {
      rot %= 360;
    } else if (rot < 0) {
      rot = ((rot % 360) + 360) % 360;
    }
    return shadow(this, 'rotate', rot);
  }

  void _onSubStreamError(dynamic reason, dynamic objId) {
    if (evaluatorOptions['ignoreErrors'] == true) {
      warn('getContentStream - ignoring sub-stream ($objId): "$reason".');
      return;
    }
    throw reason;
  }

  Future<BaseStream> getContentStream() async {
    final dynamic c = await pdfManager.ensure(this, 'content');
    if (c is BaseStream && !c.isImageStream) {
      if (c.isAsync) {
        final bytes = await c.asyncGetBytes();
        return Stream(bytes, 0, bytes.length, c.dict);
      }
      return c;
    }
    if (c is List) {
      final streamsList = <BaseStream>[];
      for (var i = 0; i < c.length; i++) {
        final item = c[i];
        if (item is BaseStream) {
          if (item.isAsync) {
            final bytes = await item.asyncGetBytes();
            streamsList.add(Stream(bytes, 0, bytes.length, item.dict));
          } else {
            streamsList.add(item);
          }
        }
      }
      return StreamsSequenceStream(streamsList, _onSubStreamError);
    }
    return NullStream();
  }

  Map<String, dynamic>? get xfaData {
    return shadow(
      this,
      'xfaData',
      xfaFactory != null ? {'bbox': xfaFactory!.getBoundingBox(pageIndex)} : null,
    );
  }

  Future<void> loadResources(List<String> keys) async {
    _resourcesPromise ??= pdfManager.ensure(this, 'resources');
    await _resourcesPromise;
    await ObjectLoader.load(resources, keys, xref);
  }

  Future<OperatorList> getOperatorList({
    dynamic handler,
    dynamic sink,
    dynamic task,
    dynamic intent,
    dynamic cacheKey,
    int? customPageIndex,
    dynamic annotationStorage,
    dynamic modifiedIds,
  }) async {
    final operatorList = OperatorList((intent as int?) ?? 0, sink);
    await getContentStream();
    await loadResources(RESOURCES_KEYS_OPERATOR_LIST);

    final partialEvaluator =
        _createPartialEvaluator(handler, customPageIndex ?? pageIndex);
    await partialEvaluator.getOperatorList(
      contentStream: await getContentStream(),
      executionContext: this,
      operatorList: operatorList,
      resources: resources,
    );
    return operatorList;
  }

  Future<Map<String, dynamic>> extractTextContent({
    dynamic handler,
    dynamic task,
    dynamic normalizeWhitespace = false,
    dynamic includeMarkedContent = false,
  }) async {
    final stream = await getContentStream();
    await loadResources(RESOURCES_KEYS_TEXT_CONTENT);

    final partialEvaluator = _createPartialEvaluator(handler);
    return partialEvaluator.getTextContent(
      contentStream: stream,
      resources: resources,
    );
  }

  void cleanup() {
    _resourcesPromise = null;
  }
}

class PDFGlobalIdFactory {
  final String docId;
  int _fontCounter = 0;

  PDFGlobalIdFactory(this.docId);

  String getDocId() => 'g_$docId';
  String createFontId() => 'f${++_fontCounter}';
}

class PDFDocument {
  final BasePdfManager pdfManager;
  final BaseStream stream;
  late final XRef xref;
  late final PDFGlobalIdFactory _globalIdFactory;
  Catalog? catalog;

  final Map<int, Future<Page>> _pagePromises = {};
  String? _version;

  PDFDocument(this.pdfManager, this.stream) {
    if (stream.length <= 0) {
      throw InvalidPDFException(
          'The PDF file is empty, i.e. its size is zero bytes.');
    }
    xref = XRef(stream, pdfManager);
    _globalIdFactory = PDFGlobalIdFactory(pdfManager.docId ?? 'default');
  }

  void parse([bool recoveryMode = false]) {
    xref.parse(recoveryMode);
    catalog = Catalog(pdfManager, xref);
  }

  Map<String, dynamic>? get linearization {
    Map<String, dynamic>? lin;
    try {
      lin = Linearization.create(stream);
    } catch (err) {
      if (err is MissingDataException) {
        rethrow;
      }
      info(err.toString());
    }
    return shadow(this, 'linearization', lin);
  }

  int get startXRef {
    var startX = 0;
    if (linearization != null) {
      stream.reset();
      if (find(stream, ENDOBJ_SIGNATURE)) {
        stream.skip(6);
        var ch = stream.peekByte();
        while (isWhiteSpace(ch)) {
          stream.pos++;
          ch = stream.peekByte();
        }
        startX = stream.pos - (stream is Stream ? (stream as Stream).start : 0);
      }
    } else {
      const step = 1024;
      final startXRefLength = STARTXREF_SIGNATURE.length;
      var found = false;
      var pos = stream.end;

      while (!found && pos > 0) {
        pos -= step - startXRefLength;
        if (pos < 0) {
          pos = 0;
        }
        stream.pos = pos;
        found = find(stream, STARTXREF_SIGNATURE, step, true);
      }

      if (found) {
        stream.skip(9);
        int ch;
        do {
          ch = stream.getByte();
        } while (isWhiteSpace(ch));
        var str = '';
        while (ch >= 0x20 && ch <= 0x39) {
          str += String.fromCharCode(ch);
          ch = stream.getByte();
        }
        startX = int.tryParse(str) ?? 0;
      }
    }
    return shadow(this, 'startXRef', startX);
  }

  void checkHeader() {
    stream.reset();
    if (!find(stream, PDF_HEADER_SIGNATURE)) {
      return;
    }
    stream.moveStart();
    stream.skip(PDF_HEADER_SIGNATURE.length);

    var ver = '';
    int ch;
    while ((ch = stream.getByte()) > 0x20 && ver.length < 7) {
      ver += String.fromCharCode(ch);
    }

    if (PDF_VERSION_REGEXP.hasMatch(ver)) {
      _version = ver;
    } else {
      warn('Invalid PDF header version: $ver');
    }
  }

  void parseStartXRef() {
    xref.setStartXRef(startXRef);
  }

  int get numPages {
    var num = 0;
    if (catalog?.hasActualNumPages == true) {
      num = catalog!.numPages;
    } else if (linearization != null && linearization!['numPages'] != null) {
      num = linearization!['numPages'] as int;
    } else if (catalog != null) {
      num = catalog!.numPages;
    }
    return shadow(this, 'numPages', num);
  }

  String? get version => catalog?.version ?? _version;

  Map<String, bool> get formInfo {
    final info = {
      'hasFields': false,
      'hasAcroForm': false,
      'hasXfa': false,
      'hasSignatures': false,
    };
    final acro = catalog?.acroForm;
    if (acro == null) {
      return shadow(this, 'formInfo', info);
    }

    try {
      final fields = acro.get('Fields');
      final hasFields = fields is List && fields.isNotEmpty;
      info['hasFields'] = hasFields;

      final xfa = acro.get('XFA');
      info['hasXfa'] = (xfa is List && xfa.isNotEmpty) ||
          (xfa is BaseStream && !xfa.isEmpty);

      final sigFlags = acro.get('SigFlags');
      final hasSignatures = sigFlags is num && ((sigFlags.toInt() & 1) != 0);
      info['hasSignatures'] = hasSignatures;
      info['hasAcroForm'] = hasFields;
    } catch (ex) {
      if (ex is MissingDataException) {
        rethrow;
      }
      warn('Cannot fetch form information: "$ex".');
    }
    return shadow(this, 'formInfo', info);
  }

  Map<String, dynamic> get documentInfo {
    final cat = catalog!;
    final fInfo = formInfo;
    final docInfo = <String, dynamic>{
      'PDFFormatVersion': version,
      'Language': cat.lang,
      'EncryptFilterName': xref.encrypt?.filterName,
      'IsLinearized': linearization != null,
      'IsAcroFormPresent': fInfo['hasAcroForm'],
      'IsXFAPresent': fInfo['hasXfa'],
      'IsCollectionPresent': cat.collection != null,
      'IsSignaturesPresent': fInfo['hasSignatures'],
    };

    Dict? infoDict;
    try {
      final trailerInfo = xref.trailer?.get('Info');
      if (trailerInfo is Dict) {
        infoDict = trailerInfo;
      }
    } catch (err) {
      if (err is MissingDataException) {
        rethrow;
      }
      info('The document information dictionary is invalid.');
    }

    if (infoDict != null) {
      for (final entry in infoDict.getRawEntries()) {
        final key = entry.key;
        final value = entry.value;
        switch (key) {
          case 'Title':
          case 'Author':
          case 'Subject':
          case 'Keywords':
          case 'Creator':
          case 'Producer':
          case 'CreationDate':
          case 'ModDate':
            if (value is String) {
              docInfo[key] = stringToPDFString(value);
            }
            break;
          case 'Trapped':
            if (value is Name) {
              docInfo[key] = value.name;
            }
            break;
          default:
            if (value is String || value is num || value is bool) {
              docInfo.putIfAbsent('Custom', () => <String, dynamic>{})[key] =
                  value is String ? stringToPDFString(value) : value;
            } else if (value is Name) {
              docInfo.putIfAbsent('Custom', () => <String, dynamic>{})[key] =
                  value.name;
            }
            break;
        }
      }
    }
    return shadow(this, 'documentInfo', docInfo);
  }

  List<String?> get fingerprints {
    const fingerprintFirstBytes = 1024;
    final id = xref.trailer?.get('ID');
    String? hashOriginal;
    String? hashModified;

    if (id is List && id.isNotEmpty && id[0] is String && (id[0] as String).length == 16) {
      hashOriginal = _bytesToHex(stringToBytes(id[0] as String));
      if (id.length > 1 && id[1] is String && (id[1] as String).length == 16) {
        hashModified = _bytesToHex(stringToBytes(id[1] as String));
      }
    } else {
      final firstBytes = stream.getByteRange(0, fingerprintFirstBytes);
      final md5 = calculateMD5(firstBytes, 0, firstBytes.length);
      hashOriginal = _bytesToHex(md5);
    }
    return shadow(this, 'fingerprints', [hashOriginal, hashModified]);
  }

  Future<Page> getPage(int pageIndex) {
    final cached = _pagePromises[pageIndex];
    if (cached != null) {
      return cached;
    }

    final promise = catalog!.getPageDict(pageIndex).then((pair) {
      final pageDict = pair[0] as Dict;
      final ref = pair[1] as Ref?;
      return Page(
        pdfManager: pdfManager,
        xref: xref,
        pageIndex: pageIndex,
        pageDict: pageDict,
        ref: ref,
        globalIdFactory: _globalIdFactory,
        fontCache: catalog!.fontCache,
        builtInCMapCache: catalog!.builtInCMapCache,
        standardFontDataCache: catalog!.standardFontDataCache,
        globalColorSpaceCache: catalog!.globalColorSpaceCache,
        globalImageCache: catalog!.globalImageCache,
        systemFontCache: catalog!.systemFontCache,
        nonBlendModesSet: catalog!.nonBlendModesSet,
      );
    });

    _pagePromises[pageIndex] = promise;
    return promise;
  }

  Future<void> checkFirstPage([bool recoveryMode = false]) async {
    if (recoveryMode) return;
    try {
      await getPage(0);
    } on XRefEntryException {
      _pagePromises.remove(0);
      await cleanup();
      throw XRefParseException();
    }
  }

  Future<void> checkLastPage([bool recoveryMode = false]) async {
    final cat = catalog!;
    cat.setActualNumPages();
    var nPages = numPages;
    if (nPages <= 1) return;

    try {
      await getPage(nPages - 1);
    } catch (reason) {
      _pagePromises.remove(nPages - 1);
      await cleanup();
      if (reason is XRefEntryException && !recoveryMode) {
        throw XRefParseException();
      }
      warn('checkLastPage - invalid /Pages tree /Count: $nPages.');
      try {
        final pagesTree = await cat.getAllPageDicts(recoveryMode);
        for (final entry in pagesTree.entries) {
          final pIdx = entry.key;
          final pPair = entry.value;
          final pDict = pPair[0] as Dict;
          final pRef = pPair[1] as Ref?;
          _pagePromises[pIdx] = Future.value(Page(
            pdfManager: pdfManager,
            xref: xref,
            pageIndex: pIdx,
            pageDict: pDict,
            ref: pRef,
            globalIdFactory: _globalIdFactory,
            fontCache: cat.fontCache,
            builtInCMapCache: cat.builtInCMapCache,
            standardFontDataCache: cat.standardFontDataCache,
            globalColorSpaceCache: cat.globalColorSpaceCache,
            globalImageCache: cat.globalImageCache,
            systemFontCache: cat.systemFontCache,
            nonBlendModesSet: cat.nonBlendModesSet,
          ));
        }
        cat.setActualNumPages(pagesTree.length);
      } catch (reasonAll) {
        if (reasonAll is XRefEntryException && !recoveryMode) {
          throw XRefParseException();
        }
        cat.setActualNumPages(1);
      }
    }
  }

  Future<void> cleanup([bool manuallyTriggered = false]) async {
    _pagePromises.clear();
    if (catalog != null) {
      await catalog!.cleanup(manuallyTriggered: manuallyTriggered);
    } else {
      clearGlobalCaches();
    }
  }
}
