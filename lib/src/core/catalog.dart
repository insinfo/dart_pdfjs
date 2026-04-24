import 'dart:typed_data';

import '../shared/util.dart';
import 'core_utils.dart';
import 'primitives.dart';
import 'name_number_tree.dart';
import 'base_stream.dart';
import 'cleanup_helper.dart';
import 'colorspace_utils.dart';
import 'file_spec.dart';
import 'image_utils.dart';
import 'metadata_parser.dart';
import 'struct_tree.dart';
import 'xref.dart';
import 'pdf_manager.dart';

bool _isRef(dynamic v) => v is Ref;

bool _isValidExplicitDest(dynamic dest) {
  return isValidExplicitDest(dest, _isRef, (v) => v is Name);
}

dynamic _fetchDest(dynamic dest) {
  if (dest is Dict) {
    dest = dest.get('D');
  }
  return _isValidExplicitDest(dest) ? dest : null;
}

String? _fetchRemoteDest(Dict action) {
  dynamic dest = action.get('D');
  if (dest != null) {
    if (dest is Name) {
      dest = dest.name;
    }
    if (dest is String) {
      return stringToPDFString(dest, keepEscapeSequence: true);
    } else if (_isValidExplicitDest(dest)) {
      return dest.toString();
    }
  }
  return null;
}

class Catalog {
  final PDFManager pdfManager;
  final XRef xref;

  int? _actualNumPages;
  late final Dict _catDict;

  final builtInCMapCache = <String, dynamic>{};
  final fontCache = RefSetCache();
  final globalColorSpaceCache = GlobalColorSpaceCache();
  final globalImageCache = GlobalImageCache();
  final nonBlendModesSet = RefSet();
  final pageDictCache = RefSetCache();
  final pageIndexCache = RefSetCache();
  final pageKidsCountCache = RefSetCache();
  final standardFontDataCache = <String, dynamic>{};
  final systemFontCache = <String, dynamic>{};

  Dict? _toplevelPagesDict;

  Catalog(this.pdfManager, this.xref) {
    final cat = xref.getCatalogObj();
    if (cat is! Dict) {
      throw FormatException('Catalog object is not a dictionary.');
    }
    _catDict = cat;
  }

  Dict cloneDict() {
    return _catDict.clone();
  }

  String? get version {
    final version = _catDict.get('Version');
    if (version is Name) {
      if (PDF_VERSION_REGEXP.hasMatch(version.name)) {
        return shadow(this, 'version', version.name);
      }
      warn('Invalid PDF catalog version: ${version.name}');
    }
    return shadow(this, 'version', null);
  }

  String? get lang {
    final lang = _catDict.get('Lang');
    return shadow(
      this,
      'lang',
      lang is String ? stringToPDFString(lang) : null,
    );
  }

  bool get needsRendering {
    final needsRendering = _catDict.get('NeedsRendering');
    return shadow(
      this,
      'needsRendering',
      needsRendering is bool ? needsRendering : false,
    );
  }

  Dict? get collection {
    Dict? collection;
    try {
      final obj = _catDict.get('Collection');
      if (obj is Dict && obj.size > 0) {
        collection = obj;
      }
    } catch (ex) {
      if (ex is MissingDataException) {
        rethrow;
      }
      info('Cannot fetch Collection entry; assuming no collection is present.');
    }
    return shadow(this, 'collection', collection);
  }

  Dict? get acroForm {
    Dict? acroForm;
    try {
      final obj = _catDict.get('AcroForm');
      if (obj is Dict && obj.size > 0) {
        acroForm = obj;
      }
    } catch (ex) {
      if (ex is MissingDataException) {
        rethrow;
      }
      info('Cannot fetch AcroForm entry; assuming no forms are present.');
    }
    return shadow(this, 'acroForm', acroForm);
  }

  Ref? get acroFormRef {
    final value = _catDict.getRaw('AcroForm');
    return shadow(this, 'acroFormRef', value is Ref ? value : null);
  }

  MetadataSerializable? get metadata {
    final streamRef = _catDict.getRaw('Metadata');
    if (streamRef is! Ref) {
      return shadow(this, 'metadata', null);
    }

    MetadataSerializable? metadata;
    try {
      final stream = xref.fetch(
        streamRef,
        !(xref.encrypt?.encryptMetadata ?? true),
      );

      if (stream is BaseStream && stream.dict is Dict) {
        final type = stream.dict!.get('Type');
        final subtype = stream.dict!.get('Subtype');

        if (isName(type, 'Metadata') && isName(subtype, 'XML')) {
          final data = stringToUTF8String(stream.getString());
          if (data.isNotEmpty) {
            metadata = MetadataParser(data).serializable;
          }
        }
      }
    } catch (ex) {
      if (ex is MissingDataException) {
        rethrow;
      }
      info('Skipping invalid Metadata: "$ex".');
    }
    return shadow(this, 'metadata', metadata);
  }

  Map<String, bool>? get markInfo {
    Map<String, bool>? markInfo;
    try {
      markInfo = _readMarkInfo();
    } catch (ex) {
      if (ex is MissingDataException) {
        rethrow;
      }
      warn('Unable to read mark info.');
    }
    return shadow(this, 'markInfo', markInfo);
  }

  Map<String, bool>? _readMarkInfo() {
    final obj = _catDict.get('MarkInfo');
    if (obj is! Dict) {
      return null;
    }

    final markInfo = {
      'Marked': false,
      'UserProperties': false,
      'Suspects': false,
    };
    for (final key in markInfo.keys) {
      final value = obj.get(key);
      if (value is bool) {
        markInfo[key] = value;
      }
    }

    return markInfo;
  }

  bool get hasStructTree {
    return _catDict.has('StructTreeRoot');
  }

  StructTreeRoot? get structTreeRoot {
    StructTreeRoot? structTree;
    try {
      structTree = _readStructTreeRoot();
    } catch (ex) {
      if (ex is MissingDataException) {
        rethrow;
      }
      warn('Unable read to structTreeRoot info.');
    }
    return shadow(this, 'structTreeRoot', structTree);
  }

  StructTreeRoot? _readStructTreeRoot() {
    final rawObj = _catDict.getRaw('StructTreeRoot');
    final obj = xref.fetchIfRef(rawObj);
    if (obj is! Dict) {
      return null;
    }

    final root = StructTreeRoot(xref, obj, rawObj is Ref ? rawObj : null);
    root.init();
    return root;
  }

  Dict get toplevelPagesDict {
    if (_toplevelPagesDict != null) {
      return _toplevelPagesDict!;
    }
    final pagesObj = _catDict.get('Pages');
    if (pagesObj is! Dict) {
      throw FormatException('Invalid top-level pages dictionary.');
    }
    _toplevelPagesDict = pagesObj;
    return shadow(this, 'toplevelPagesDict', pagesObj);
  }

  void setActualNumPages(int? num) {
    _actualNumPages = num;
  }

  bool get hasActualNumPages {
    return _actualNumPages != null;
  }

  int get _pagesCount {
    final obj = toplevelPagesDict.get('Count');
    if (obj is! int) {
      throw FormatException(
          'Page count in top-level pages dictionary is not an integer.');
    }
    return shadow(this, '_pagesCount', obj);
  }

  int get numPages {
    return _actualNumPages ?? _pagesCount;
  }

  Future<void> cleanup({bool manuallyTriggered = false}) async {
    clearGlobalCaches();
    globalColorSpaceCache.clear();
    globalImageCache.clear(onlyData: manuallyTriggered);
    pageKidsCountCache.clear();
    pageIndexCache.clear();
    pageDictCache.clear();
    nonBlendModesSet.clear();

    fontCache.clear();
    builtInCMapCache.clear();
    standardFontDataCache.clear();
    systemFontCache.clear();
  }

  Future<List<dynamic>> getPageDict(int pageIndex) async {
    final nodesToVisit = <dynamic>[toplevelPagesDict];
    final visitedNodes = RefSet();

    final pagesRef = _catDict.getRaw('Pages');
    if (pagesRef is Ref) {
      visitedNodes.put(pagesRef);
    }

    var currentPageIndex = 0;

    while (nodesToVisit.isNotEmpty) {
      final currentNode = nodesToVisit.removeLast();

      if (currentNode is Ref) {
        final count = pageKidsCountCache.get(currentNode);
        if (count != null &&
            count >= 0 &&
            currentPageIndex + count <= pageIndex) {
          currentPageIndex += count as int;
          continue;
        }
        if (visitedNodes.has(currentNode)) {
          throw FormatException('Pages tree contains circular reference.');
        }
        visitedNodes.put(currentNode);

        var obj = pageDictCache.get(currentNode);
        if (obj == null) {
          obj = await xref.fetchAsync(currentNode);
        } else if (obj is Future) {
          obj = await obj;
        }

        if (obj is Dict) {
          var type = obj.getRaw('Type');
          if (type is Ref) {
            type = await xref.fetchAsync(type);
          }
          if (isName(type, 'Page') || !obj.has('Kids')) {
            if (!pageKidsCountCache.has(currentNode)) {
              pageKidsCountCache.put(currentNode, 1);
            }
            if (!pageIndexCache.has(currentNode)) {
              pageIndexCache.put(currentNode, currentPageIndex);
            }

            if (currentPageIndex == pageIndex) {
              return [obj, currentNode];
            }
            currentPageIndex++;
            continue;
          }
        }
        nodesToVisit.add(obj);
        continue;
      }

      if (currentNode is! Dict) {
        throw FormatException(
            'Page dictionary kid reference points to wrong type of object.');
      }
      final objId = currentNode.objId;

      dynamic count = currentNode.getRaw('Count');
      if (count is Ref) {
        count = await xref.fetchAsync(count);
      }
      if (count is int && count >= 0) {
        if (objId != null && !pageKidsCountCache.has(objId)) {
          pageKidsCountCache.put(objId, count);
        }

        if (currentPageIndex + count <= pageIndex) {
          currentPageIndex += count;
          continue;
        }
      }

      dynamic kids = currentNode.getRaw('Kids');
      if (kids is Ref) {
        kids = await xref.fetchAsync(kids);
      }
      if (kids is! List) {
        dynamic type = currentNode.getRaw('Type');
        if (type is Ref) {
          type = await xref.fetchAsync(type);
        }
        if (isName(type, 'Page') || !currentNode.has('Kids')) {
          if (currentPageIndex == pageIndex) {
            return [currentNode, null];
          }
          currentPageIndex++;
          continue;
        }

        throw FormatException('Page dictionary kids object is not an array.');
      }

      for (var last = kids.length - 1; last >= 0; last--) {
        final lastKid = kids[last];
        nodesToVisit.add(lastKid);

        if (currentNode == toplevelPagesDict &&
            lastKid is Ref &&
            !pageDictCache.has(lastKid)) {
          pageDictCache.put(lastKid, xref.fetchAsync(lastKid));
        }
      }
    }

    throw Exception('Page index $pageIndex not found.');
  }

  List<dynamic>? get documentOutline {
    List<dynamic>? obj;
    try {
      obj = _readDocumentOutline();
    } catch (ex) {
      if (ex is MissingDataException) {
        rethrow;
      }
      warn('Unable to read document outline.');
    }
    return shadow(this, 'documentOutline', obj);
  }

  List<dynamic>? _readDocumentOutline({bool keepRawDict = false}) {
    var obj = _catDict.get('Outlines');
    if (obj is! Dict) {
      return null;
    }
    obj = obj.getRaw('First');
    if (obj is! Ref) {
      return null;
    }

    final root = {'items': <dynamic>[]};
    final queue = [
      {'obj': obj, 'parent': root}
    ];
    final processed = RefSet();
    processed.put(obj);
    final blackColor = Uint8List(3);

    while (queue.isNotEmpty) {
      final i = queue.removeAt(0);
      final outlineDict = xref.fetchIfRef(i['obj']);
      if (outlineDict == null) {
        continue;
      }
      if (outlineDict is Dict && !outlineDict.has('Title')) {
        warn('Invalid outline item encountered.');
      }

      final data = <String, dynamic>{'url': null, 'dest': null, 'action': null};
      Catalog.parseDestDictionary(
        destDict: outlineDict,
        resultObj: data,
        docBaseUrl: baseUrl,
        docAttachments: attachments,
      );

      final title = outlineDict is Dict ? outlineDict.get('Title') : null;
      final flags = outlineDict is Dict ? (outlineDict.get('F') ?? 0) : 0;
      final color = outlineDict is Dict ? outlineDict.getArray('C') : null;
      final count = outlineDict is Dict ? outlineDict.get('Count') : null;
      var rgbColor = blackColor;

      if (isNumberArray(color, 3) &&
          (color![0] != 0 || color[1] != 0 || color[2] != 0)) {
        // rgbColor = ColorSpaceUtils.rgb.getRgb(color, 0);
      }

      final outlineItem = <String, dynamic>{
        'action': data['action'],
        'attachment': data['attachment'],
        'dest': data['dest'],
        'url': data['url'],
        'unsafeUrl': data['unsafeUrl'],
        'newWindow': data['newWindow'],
        'setOCGState': data['setOCGState'],
        'title': title is String ? stringToPDFString(title) : '',
        'color': rgbColor,
        'count': count is int ? count : null,
        'bold': ((flags as int) & 2) != 0,
        'italic': (flags & 1) != 0,
        'items': <dynamic>[],
      };

      if (keepRawDict) {
        outlineItem['rawDict'] = outlineDict;
      }

      (i['parent'] as Map)['items'].add(outlineItem);
      dynamic nextObj =
          outlineDict is Dict ? outlineDict.getRaw('First') : null;
      if (nextObj is Ref && !processed.has(nextObj)) {
        queue.add({'obj': nextObj, 'parent': outlineItem});
        processed.put(nextObj);
      }
      nextObj = outlineDict is Dict ? outlineDict.getRaw('Next') : null;
      if (nextObj is Ref && !processed.has(nextObj)) {
        queue.add({'obj': nextObj, 'parent': i['parent']!});
        processed.put(nextObj);
      }
    }
    final items = root['items'] as List;
    return items.isNotEmpty ? items : null;
  }

  List<dynamic>? get documentOutlineForEditor {
    List<dynamic>? obj;
    try {
      obj = _readDocumentOutline(keepRawDict: true);
    } catch (ex) {
      if (ex is MissingDataException) {
        rethrow;
      }
      warn('Unable to read document outline.');
    }
    return shadow(this, 'documentOutlineForEditor', obj);
  }

  Map<String, dynamic> get destinations {
    final rawDests = _readDests();
    final dests = <String, dynamic>{};
    for (final obj in rawDests) {
      if (obj is NameTree) {
        for (final entry in obj.getAll().entries) {
          final dest = _fetchDest(entry.value);
          if (dest != null) {
            dests[stringToPDFString(entry.key.toString(),
                keepEscapeSequence: true)] = dest;
          }
        }
      } else if (obj is Dict) {
        for (final key in obj.getKeys()) {
          final value = obj.get(key);
          final dest = _fetchDest(value);
          if (dest != null) {
            final pdfKey = stringToPDFString(key, keepEscapeSequence: true);
            dests[pdfKey] ??= dest;
          }
        }
      }
    }
    return shadow(this, 'destinations', dests);
  }

  dynamic getDestination(String id) {
    final rawDests = _readDests();
    for (final obj in rawDests) {
      if (obj is NameTree || obj is Dict) {
        final dest = _fetchDest(obj.get(id));
        if (dest != null) {
          return dest;
        }
      }
    }
    if (rawDests.isNotEmpty) {
      final dest = destinations[id];
      if (dest != null) {
        return dest;
      }
    }
    return null;
  }

  List<dynamic> _readDests() {
    final obj = _catDict.get('Names');
    final rawDests = <dynamic>[];
    if (obj is Dict && obj.has('Dests')) {
      rawDests.add(NameTree(obj.getRaw('Dests'), xref));
    }
    if (_catDict.has('Dests')) {
      rawDests.add(_catDict.get('Dests'));
    }
    return rawDests;
  }

  Map<dynamic, dynamic>? get rawPageLabels {
    final obj = _catDict.getRaw('PageLabels');
    if (obj == null) {
      return null;
    }
    final numberTree = NumberTree(obj, xref);
    return numberTree.getAll();
  }

  List<String>? get pageLabels {
    List<String>? obj;
    try {
      obj = _readPageLabels();
    } catch (ex) {
      if (ex is MissingDataException) {
        rethrow;
      }
      warn('Unable to read page labels.');
    }
    return shadow(this, 'pageLabels', obj);
  }

  List<String>? _readPageLabels() {
    final nums = rawPageLabels;
    if (nums == null) {
      return null;
    }

    final pageLabelsList = List<String>.filled(numPages, '');
    String? style;
    var prefix = '';
    var currentLabel = '';
    var currentIndex = 1;

    for (var i = 0; i < numPages; i++) {
      final labelDict = nums[i];

      if (labelDict != null) {
        if (labelDict is! Dict) {
          throw FormatException('PageLabel is not a dictionary.');
        }

        if (labelDict.has('Type') &&
            !isName(labelDict.get('Type'), 'PageLabel')) {
          throw FormatException('Invalid type in PageLabel dictionary.');
        }

        if (labelDict.has('S')) {
          final s = labelDict.get('S');
          if (s is! Name) {
            throw FormatException('Invalid style in PageLabel dictionary.');
          }
          style = s.name;
        } else {
          style = null;
        }

        if (labelDict.has('P')) {
          final p = labelDict.get('P');
          if (p is! String) {
            throw FormatException('Invalid prefix in PageLabel dictionary.');
          }
          prefix = stringToPDFString(p);
        } else {
          prefix = '';
        }

        if (labelDict.has('St')) {
          final st = labelDict.get('St');
          if (st is! int || st < 1) {
            throw FormatException('Invalid start in PageLabel dictionary.');
          }
          currentIndex = st;
        } else {
          currentIndex = 1;
        }
      }

      switch (style) {
        case 'D':
          currentLabel = currentIndex.toString();
          break;
        case 'R':
        case 'r':
          currentLabel = toRomanNumerals(currentIndex, style == 'r');
          break;
        case 'A':
        case 'a':
          const limit = 26;
          const aUpperCase = 0x41;
          const aLowerCase = 0x61;
          final baseCharCode = style == 'a' ? aLowerCase : aUpperCase;
          final letterIndex = currentIndex - 1;
          final character =
              String.fromCharCode(baseCharCode + (letterIndex % limit));
          currentLabel = character * ((letterIndex ~/ limit) + 1);
          break;
        default:
          if (style != null) {
            throw FormatException(
                'Invalid style "$style" in PageLabel dictionary.');
          }
          currentLabel = '';
      }

      pageLabelsList[i] = prefix + currentLabel;
      currentIndex++;
    }
    return pageLabelsList;
  }

  String get pageLayout {
    final obj = _catDict.get('PageLayout');
    var pageLayout = '';

    if (obj is Name) {
      switch (obj.name) {
        case 'SinglePage':
        case 'OneColumn':
        case 'TwoColumnLeft':
        case 'TwoColumnRight':
        case 'TwoPageLeft':
        case 'TwoPageRight':
          pageLayout = obj.name;
      }
    }
    return shadow(this, 'pageLayout', pageLayout);
  }

  String get pageMode {
    final obj = _catDict.get('PageMode');
    var pageMode = 'UseNone';

    if (obj is Name) {
      switch (obj.name) {
        case 'UseNone':
        case 'UseOutlines':
        case 'UseThumbs':
        case 'FullScreen':
        case 'UseOC':
        case 'UseAttachments':
          pageMode = obj.name;
      }
    }
    return shadow(this, 'pageMode', pageMode);
  }

  Map<String, dynamic>? get viewerPreferences {
    final obj = _catDict.get('ViewerPreferences');
    if (obj is! Dict) {
      return shadow(this, 'viewerPreferences', null);
    }
    Map<String, dynamic>? prefs;

    for (final key in obj.getKeys()) {
      final value = obj.get(key);
      dynamic prefValue;

      switch (key) {
        case 'HideToolbar':
        case 'HideMenubar':
        case 'HideWindowUI':
        case 'FitWindow':
        case 'CenterWindow':
        case 'DisplayDocTitle':
        case 'PickTrayByPDFSize':
          if (value is bool) {
            prefValue = value;
          }
          break;
        case 'NonFullScreenPageMode':
          if (value is Name) {
            switch (value.name) {
              case 'UseNone':
              case 'UseOutlines':
              case 'UseThumbs':
              case 'UseOC':
                prefValue = value.name;
                break;
              default:
                prefValue = 'UseNone';
            }
          }
          break;
        case 'Direction':
          if (value is Name) {
            switch (value.name) {
              case 'L2R':
              case 'R2L':
                prefValue = value.name;
                break;
              default:
                prefValue = 'L2R';
            }
          }
          break;
        case 'ViewArea':
        case 'ViewClip':
        case 'PrintArea':
        case 'PrintClip':
          if (value is Name) {
            switch (value.name) {
              case 'MediaBox':
              case 'CropBox':
              case 'BleedBox':
              case 'TrimBox':
              case 'ArtBox':
                prefValue = value.name;
                break;
              default:
                prefValue = 'CropBox';
            }
          }
          break;
        case 'PrintScaling':
          if (value is Name) {
            switch (value.name) {
              case 'None':
              case 'AppDefault':
                prefValue = value.name;
                break;
              default:
                prefValue = 'AppDefault';
            }
          }
          break;
        case 'Duplex':
          if (value is Name) {
            switch (value.name) {
              case 'Simplex':
              case 'DuplexFlipShortEdge':
              case 'DuplexFlipLongEdge':
                prefValue = value.name;
                break;
              default:
                prefValue = 'None';
            }
          }
          break;
        case 'PrintPageRange':
          if (value is List && value.length % 2 == 0) {
            var isValid = true;
            for (var i = 0; i < value.length; i++) {
              final page = value[i];
              if (page is! int ||
                  page <= 0 ||
                  (i > 0 && page < value[i - 1]) ||
                  page > numPages) {
                isValid = false;
                break;
              }
            }
            if (isValid) {
              prefValue = value;
            }
          }
          break;
        case 'NumCopies':
          if (value is int && value > 0) {
            prefValue = value;
          }
          break;
        default:
          warn('Ignoring non-standard key in ViewerPreferences: $key.');
          continue;
      }

      if (prefValue == null) {
        warn('Bad value, for key "$key", in ViewerPreferences: $value.');
        continue;
      }
      prefs ??= <String, dynamic>{};
      prefs[key] = prefValue;
    }
    return shadow(this, 'viewerPreferences', prefs);
  }

  Map<String, dynamic>? get openAction {
    final obj = _catDict.get('OpenAction');
    final action = <String, dynamic>{};

    if (obj is Dict) {
      final destDict = Dict(xref);
      destDict.set('A', obj);

      final resultObj = <String, dynamic>{
        'url': null,
        'dest': null,
        'action': null
      };
      Catalog.parseDestDictionary(destDict: destDict, resultObj: resultObj);

      if (resultObj['dest'] is List) {
        action['dest'] = resultObj['dest'];
      } else if (resultObj['action'] != null) {
        action['action'] = resultObj['action'];
      }
    } else if (_isValidExplicitDest(obj)) {
      action['dest'] = obj;
    }
    return shadow(
      this,
      'openAction',
      action.isNotEmpty ? action : null,
    );
  }

  Map<dynamic, dynamic>? get rawEmbeddedFiles {
    final obj = _catDict.get('Names');
    if (obj is! Dict || !obj.has('EmbeddedFiles')) {
      return null;
    }
    final nameTree = NameTree(obj.getRaw('EmbeddedFiles'), xref);
    return nameTree.getAll(isRaw: true);
  }

  Map<String, Uint8List>? get xfaImages {
    final obj = _catDict.get('Names');
    Map<String, Uint8List>? xfaImages;

    if (obj is Dict && obj.has('XFAImages')) {
      final nameTree = NameTree(obj.getRaw('XFAImages'), xref);
      for (final entry in nameTree.getAll().entries) {
        if (entry.value is BaseStream) {
          xfaImages ??= <String, Uint8List>{};
          xfaImages[stringToPDFString(entry.key.toString(),
              keepEscapeSequence: true)] = entry.value.getBytes();
        }
      }
    }
    return shadow(this, 'xfaImages', xfaImages);
  }

  Map<String, String>? _collectJavaScript() {
    final obj = _catDict.get('Names');
    Map<String, String>? javaScript;

    void appendIfJavaScriptDict(String name, dynamic jsDict) {
      if (jsDict is! Dict) {
        return;
      }
      if (!isName(jsDict.get('S'), 'JavaScript')) {
        return;
      }

      dynamic js = jsDict.get('JS');
      if (js is BaseStream) {
        js = js.getString();
      } else if (js is! String) {
        return;
      }
      js = stringToPDFString(js, keepEscapeSequence: true)
          .replaceAll('\x00', '');
      if (js.isNotEmpty) {
        javaScript ??= <String, String>{};
        javaScript![name] = js;
      }
    }

    if (obj is Dict && obj.has('JavaScript')) {
      final nameTree = NameTree(obj.getRaw('JavaScript'), xref);
      for (final entry in nameTree.getAll().entries) {
        appendIfJavaScriptDict(
          stringToPDFString(entry.key.toString(), keepEscapeSequence: true),
          entry.value,
        );
      }
    }
    final openAction = _catDict.get('OpenAction');
    if (openAction != null) {
      appendIfJavaScriptDict('OpenAction', openAction);
    }

    return javaScript;
  }

  Map<String, List<String>>? get jsActions {
    final javaScript = _collectJavaScript();
    final eventType = const <String, String>{};
    var actions = collectActions(xref, _catDict, eventType);

    if (javaScript != null) {
      actions ??= <String, List<String>>{};

      for (final entry in javaScript.entries) {
        final key = entry.key;
        final val = entry.value;
        if (actions.containsKey(key)) {
          actions[key]!.add(val);
        } else {
          actions[key] = [val];
        }
      }
    }
    return shadow(this, 'jsActions', actions);
  }

  String get baseUrl {
    final uri = _catDict.get('URI');
    if (uri is Dict) {
      final base = uri.get('Base');
      if (base is String) {
        final absoluteUrl = createValidAbsoluteUrl(base, null, false, true);
        if (absoluteUrl != null) {
          return shadow(this, 'baseUrl', absoluteUrl.toString());
        }
      }
    }
    return shadow(this, 'baseUrl', pdfManager.docBaseUrl);
  }

  Map<String, dynamic>? get attachments {
    final obj = _catDict.get('Names');
    Map<String, dynamic>? attachments;

    if (obj is Dict && obj.has('EmbeddedFiles')) {
      final nameTree = NameTree(obj.getRaw('EmbeddedFiles'), xref);
      for (final entry in nameTree.getAll().entries) {
        final fs = FileSpec(entry.value);
        attachments ??= <String, dynamic>{};
        attachments[stringToPDFString(entry.key.toString(),
            keepEscapeSequence: true)] = fs.serializable;
      }
    }
    return shadow(this, 'attachments', attachments);
  }

  static void parseDestDictionary({
    required dynamic destDict,
    required Map<String, dynamic> resultObj,
    String? docBaseUrl,
    Map<String, dynamic>? docAttachments,
  }) {
    if (destDict is! Dict) {
      warn('parseDestDictionary: `destDict` must be a dictionary.');
      return;
    }

    dynamic action = destDict.get('A');
    String? url;
    dynamic dest;
    if (action is! Dict) {
      if (destDict.has('Dest')) {
        action = destDict.get('Dest');
      } else {
        action = destDict.get('AA');
        if (action is Dict) {
          if (action.has('D')) {
            action = action.get('D');
          } else if (action.has('U')) {
            action = action.get('U');
          }
        }
      }
    }

    if (action is Dict) {
      final actionType = action.get('S');
      if (actionType is! Name) {
        warn('parseDestDictionary: Invalid type in Action dictionary.');
        return;
      }

      switch (actionType.name) {
        case 'ResetForm':
          final flags = action.get('Flags');
          final include = (((flags is num ? flags : 0).toInt()) & 1) == 0;
          final fields = <String>[];
          final refs = <String>[];
          final actionFields = action.get('Fields');
          if (actionFields is List) {
            for (final obj in actionFields) {
              if (obj is Ref) {
                refs.add(obj.toString());
              } else if (obj is String) {
                fields.add(stringToPDFString(obj));
              }
            }
          }
          resultObj['resetForm'] = {
            'fields': fields,
            'refs': refs,
            'include': include,
          };
          break;

        case 'URI':
          final uri = action.get('URI');
          if (uri is Name) {
            url = '/${uri.name}';
          } else if (uri is String) {
            url = uri;
          }
          break;

        case 'GoTo':
          dest = action.get('D');
          break;

        case 'Launch':
        case 'GoToR':
          final urlDict = action.get('F');
          if (urlDict is Dict) {
            final fs = FileSpec(urlDict, skipContent: true);
            final rawFilename = fs.serializable['rawFilename'];
            if (rawFilename is String) {
              url = rawFilename;
            }
          } else if (urlDict is String) {
            url = urlDict;
          } else {
            break;
          }

          final remoteDest = _fetchRemoteDest(action);
          if (remoteDest != null && url != null) {
            url = '${url.split('#').first}#$remoteDest';
          }

          final newWindow = action.get('NewWindow');
          if (newWindow is bool) {
            resultObj['newWindow'] = newWindow;
          }
          break;

        case 'GoToE':
          final target = action.get('T');
          dynamic attachment;
          if (docAttachments != null && target is Dict) {
            final relationship = target.get('R');
            final name = target.get('N');
            if (isName(relationship, 'C') && name is String) {
              attachment = docAttachments[stringToPDFString(
                name,
                keepEscapeSequence: true,
              )];
            }
          }

          if (attachment != null) {
            resultObj['attachment'] = attachment;
            final attachmentDest = _fetchRemoteDest(action);
            if (attachmentDest != null) {
              resultObj['attachmentDest'] = attachmentDest;
            }
          } else {
            warn('parseDestDictionary - unimplemented "GoToE" action.');
          }
          break;

        case 'Named':
          final namedAction = action.get('N');
          if (namedAction is Name) {
            resultObj['action'] = namedAction.name;
          }
          break;

        case 'SetOCGState':
          final state = action.get('State');
          final preserveRB = action.get('PreserveRB');
          if (state is! List || state.isEmpty) {
            break;
          }

          final stateArr = <String>[];
          for (final elem in state) {
            if (elem is Name) {
              switch (elem.name) {
                case 'ON':
                case 'OFF':
                case 'Toggle':
                  stateArr.add(elem.name);
                  break;
              }
            } else if (elem is Ref) {
              stateArr.add(elem.toString());
            }
          }
          if (stateArr.length != state.length) {
            break;
          }
          resultObj['setOCGState'] = {
            'state': stateArr,
            'preserveRB': preserveRB is bool ? preserveRB : true,
          };
          break;

        case 'JavaScript':
          final jsAction = action.get('JS');
          String? js;
          if (jsAction is BaseStream) {
            js = jsAction.getString();
          } else if (jsAction is String) {
            js = jsAction;
          }
          if (js != null) {
            final jsURL = recoverJsURL(
              stringToPDFString(js, keepEscapeSequence: true),
            );
            if (jsURL != null) {
              url = jsURL.url;
              resultObj['newWindow'] = jsURL.newWindow;
              break;
            }
          }
          break;

        case 'SubmitForm':
          break;

        default:
          warn(
              'parseDestDictionary - unsupported action: "${actionType.name}".');
          break;
      }
    } else if (destDict.has('Dest')) {
      dest = destDict.get('Dest');
    }

    if (url is String) {
      final absoluteUrl = createValidAbsoluteUrl(url, docBaseUrl, true, true);
      if (absoluteUrl != null) {
        resultObj['url'] = absoluteUrl.toString();
      }
      resultObj['unsafeUrl'] = url;
    }

    if (dest != null) {
      if (dest is Name) {
        dest = dest.name;
      }
      if (dest is String) {
        resultObj['dest'] = stringToPDFString(
          dest,
          keepEscapeSequence: true,
        );
      } else if (_isValidExplicitDest(dest)) {
        resultObj['dest'] = dest;
      }
    }
  }
}
