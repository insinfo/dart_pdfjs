// Copyright 2021 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;

import '../shared/util.dart';
import 'base_stream.dart';
import 'core_utils.dart';
import 'name_number_tree.dart';
import 'primitives.dart';

const int _maxDepth = 40;

abstract class StructElementType {
  static const int pageContent = 1;
  static const int streamContent = 2;
  static const int object = 3;
  static const int annotation = 4;
  static const int element = 5;
}

class StructTreeRoot {
  final dynamic xref;
  final Dict dict;
  final Ref? ref;

  final Map<String, String> roleMap = <String, String>{};
  RefSetCache? structParentIds;
  NumberTree? parentTree;
  Map<String, int>? _kidRefToPosition;
  bool _kidRefPositionsInitialized = false;

  StructTreeRoot(this.xref, this.dict, dynamic ref)
      : ref = ref is Ref ? ref : null;

  int getKidPosition(dynamic kidRef) {
    if (!_kidRefPositionsInitialized) {
      _kidRefPositionsInitialized = true;
      final obj = dict.get('K');
      if (obj is List) {
        final map = <String, int>{};
        for (var i = 0; i < obj.length; i++) {
          final r = obj[i];
          if (r != null) {
            map[r.toString()] = i;
          }
        }
        _kidRefToPosition = map;
      } else if (obj is Dict && obj.objId != null) {
        _kidRefToPosition = <String, int>{obj.objId.toString(): 0};
      } else if (obj == null) {
        _kidRefToPosition = <String, int>{};
      } else {
        _kidRefToPosition = null;
      }
    }
    final positions = _kidRefToPosition;
    if (positions != null) {
      return positions[kidRef.toString()] ?? double.nan.toInt();
    }
    return -1;
  }

  void init() {
    readRoleMap();
    final tree = dict.get('ParentTree');
    if (tree == null) {
      return;
    }
    parentTree = NumberTree(tree, xref);
  }

  void _addIdToPage(dynamic pageRef, int id, int type) {
    if (pageRef is! Ref || id < 0) {
      return;
    }
    structParentIds ??= RefSetCache();
    var ids = structParentIds!.get(pageRef) as List<List<int>>?;
    if (ids == null) {
      ids = <List<int>>[];
      structParentIds!.put(pageRef, ids);
    }
    ids.add(<int>[id, type]);
  }

  void addAnnotationIdToPage(dynamic pageRef, int id) {
    _addIdToPage(pageRef, id, StructElementType.annotation);
  }

  void readRoleMap() {
    final roleMapDict = dict.get('RoleMap');
    if (roleMapDict is! Dict) {
      return;
    }
    for (final entry in roleMapDict.iterable) {
      final key = entry[0];
      final value = entry[1];
      if (key is String && value is Name) {
        roleMap[key] = value.name;
      }
    }
  }

  static Future<bool> canCreateStructureTree({
    required dynamic catalogRef,
    required dynamic pdfManager,
    required Map<int, List<dynamic>> newAnnotationsByPage,
  }) async {
    if (catalogRef is! Ref) {
      warn('Cannot save the struct tree: no catalog reference.');
      return false;
    }

    var nextKey = 0;
    var hasNothingToUpdate = true;

    for (final entry in newAnnotationsByPage.entries) {
      final pageIndex = entry.key;
      final elements = entry.value;
      final page = await pdfManager.getPage(pageIndex);
      final pageRef = page.ref;
      if (pageRef is! Ref) {
        warn('Cannot save the struct tree: page $pageIndex has no ref.');
        hasNothingToUpdate = true;
        break;
      }
      for (final element in elements) {
        if (element is Map &&
            element['accessibilityData'] is Map &&
            (element['accessibilityData'] as Map)['type'] != null) {
          element['parentTreeId'] = nextKey++;
          hasNothingToUpdate = false;
        }
      }
    }

    if (hasNothingToUpdate) {
      for (final elements in newAnnotationsByPage.values) {
        for (final element in elements) {
          if (element is Map) {
            element.remove('parentTreeId');
          }
        }
      }
      return false;
    }

    return true;
  }

  static Future<void> createStructureTree({
    required Map<int, List<dynamic>> newAnnotationsByPage,
    required dynamic xref,
    required dynamic catalogRef,
    required dynamic pdfManager,
    required dynamic changes,
  }) async {
    final root = await pdfManager.ensureCatalog('cloneDict');
    final cache = RefSetCache();
    cache.put(catalogRef, root);

    final structTreeRootRef = xref.getNewTemporaryRef();
    root.set('StructTreeRoot', structTreeRootRef);

    final structTreeRoot = Dict(xref);
    structTreeRoot.set('Type', Name.get('StructTreeRoot'));
    final parentTreeRef = xref.getNewTemporaryRef();
    structTreeRoot.set('ParentTree', parentTreeRef);
    final kids = <dynamic>[];
    structTreeRoot.set('K', kids);
    cache.put(structTreeRootRef, structTreeRoot);

    final parentTree = Dict(xref);
    final nums = <dynamic>[];
    parentTree.set('Nums', nums);

    final nextKey = await _writeKids(
      newAnnotationsByPage: newAnnotationsByPage,
      structTreeRootRef: structTreeRootRef,
      structTreeRoot: null,
      kids: kids,
      nums: nums,
      xref: xref,
      pdfManager: pdfManager,
      changes: changes,
      cache: cache,
    );
    structTreeRoot.set('ParentTreeNextKey', nextKey);

    cache.put(parentTreeRef, parentTree);

    for (final entry in cache.items()) {
      final ref = entry[0];
      final obj = entry[1];
      changes.put(ref, {'data': obj});
    }
  }

  Future<bool> canUpdateStructTree({
    required dynamic pdfManager,
    required Map<int, List<dynamic>> newAnnotationsByPage,
  }) async {
    if (ref == null) {
      warn('Cannot update the struct tree: no root reference.');
      return false;
    }

    var nextKey = dict.get('ParentTreeNextKey');
    if (nextKey is! int || nextKey < 0) {
      warn('Cannot update the struct tree: invalid next key.');
      return false;
    }

    final parentTreeDict = dict.get('ParentTree');
    if (parentTreeDict is! Dict) {
      warn("Cannot update the struct tree: ParentTree isn't a dict.");
      return false;
    }
    final nums = parentTreeDict.get('Nums');
    if (nums is! List) {
      warn("Cannot update the struct tree: nums isn't an array.");
      return false;
    }
    final numberTree = NumberTree(parentTreeDict, xref);

    for (final pageIndex in newAnnotationsByPage.keys) {
      final page = await pdfManager.getPage(pageIndex);
      final pageDict = page.pageDict as Dict;
      if (!pageDict.has('StructParents')) {
        continue;
      }
      final id = pageDict.get('StructParents');
      if (id is! int || numberTree.get(id) is! List) {
        warn('Cannot save the struct tree: page $pageIndex has a wrong id.');
        return false;
      }
    }

    var hasNothingToUpdate = true;
    for (final entry in newAnnotationsByPage.entries) {
      final pageIndex = entry.key;
      final elements = entry.value;
      final page = await pdfManager.getPage(pageIndex);
      final pageDict = page.pageDict as Dict;
      _collectParents(
        elements: elements,
        xref: xref,
        pageDict: pageDict,
        numberTree: numberTree,
      );

      for (final element in elements) {
        if (element is Map &&
            element['accessibilityData'] is Map &&
            (element['accessibilityData'] as Map)['type'] != null) {
          final structParent =
              (element['accessibilityData'] as Map)['structParent'];
          if (!(structParent is int && structParent >= 0)) {
            element['parentTreeId'] = nextKey++;
          }
          hasNothingToUpdate = false;
        }
      }
    }

    if (hasNothingToUpdate) {
      for (final elements in newAnnotationsByPage.values) {
        for (final element in elements) {
          if (element is Map) {
            element.remove('parentTreeId');
            element.remove('structTreeParent');
          }
        }
      }
      return false;
    }

    return true;
  }

  Future<void> updateStructureTree({
    required Map<int, List<dynamic>> newAnnotationsByPage,
    required dynamic pdfManager,
    required dynamic changes,
  }) async {
    final structTreeRootRef = ref!;
    final structTreeRootClone = dict.clone();
    final cache = RefSetCache();
    cache.put(structTreeRootRef, structTreeRootClone);

    var parentTreeRef = structTreeRootClone.getRaw('ParentTree');
    Dict parentTreeDict;
    if (parentTreeRef is Ref) {
      parentTreeDict = xref.fetch(parentTreeRef) as Dict;
    } else {
      parentTreeDict = parentTreeRef as Dict;
      parentTreeRef = xref.getNewTemporaryRef();
      structTreeRootClone.set('ParentTree', parentTreeRef);
    }
    parentTreeDict = parentTreeDict.clone();
    cache.put(parentTreeRef, parentTreeDict);

    var numsRaw = parentTreeDict.getRaw('Nums');
    Ref? numsRef;
    if (numsRaw is Ref) {
      numsRef = numsRaw;
      numsRaw = xref.fetch(numsRef);
    }
    var nums = (numsRaw as List).toList();
    if (numsRef == null) {
      parentTreeDict.set('Nums', nums);
    }

    final newNextKey = await _writeKids(
      newAnnotationsByPage: newAnnotationsByPage,
      structTreeRootRef: structTreeRootRef,
      structTreeRoot: this,
      kids: null,
      nums: nums,
      xref: xref,
      pdfManager: pdfManager,
      changes: changes,
      cache: cache,
    );

    if (newNextKey == -1) {
      return;
    }

    structTreeRootClone.set('ParentTreeNextKey', newNextKey);

    if (numsRef != null) {
      cache.put(numsRef, nums);
    }

    for (final entry in cache.items()) {
      final ref = entry[0];
      final obj = entry[1];
      changes.put(ref, {'data': obj});
    }
  }

  static Future<int> _writeKids({
    required Map<int, List<dynamic>> newAnnotationsByPage,
    required dynamic structTreeRootRef,
    required StructTreeRoot? structTreeRoot,
    required List<dynamic>? kids,
    required List<dynamic> nums,
    required dynamic xref,
    required dynamic pdfManager,
    required dynamic changes,
    required RefSetCache cache,
  }) async {
    final objr = Name.get('OBJR');
    var nextKey = -1;
    Map<int, Map<int, dynamic>?>? structTreePageObjs;

    for (final entry in newAnnotationsByPage.entries) {
      final pageIndex = entry.key;
      final elements = entry.value;
      final page = await pdfManager.getPage(pageIndex);
      final pageRef = page.ref;
      final isPageRef = pageRef is Ref;

      for (final element in elements) {
        if (element is! Map) continue;
        final accessibilityData = element['accessibilityData'] as Map?;
        if (accessibilityData == null || accessibilityData['type'] == null) {
          continue;
        }

        final ref = element['ref'];
        final parentTreeId = element['parentTreeId'] as int?;
        final structTreeParent = element['structTreeParent'] as Map?;
        final structParent = accessibilityData['structParent'];

        if (structTreeRoot != null &&
            structParent is int &&
            structParent >= 0) {
          structTreePageObjs ??= {};
          var objs = structTreePageObjs[pageIndex];
          if (objs == null) {
            final structTreePage =
                StructTreePage(structTreeRoot, page.pageDict as Dict);
            objs = structTreePage.collectObjects(pageRef);
            structTreePageObjs[pageIndex] = objs;
          }
          final objRef = objs?[structParent];
          if (objRef != null) {
            final tagDict = (xref.fetch(objRef) as Dict).clone();
            _writeProperties(tagDict, accessibilityData);
            changes.put(objRef, {'data': tagDict});
            continue;
          }
        }
        if (parentTreeId != null) {
          nextKey = math.max(nextKey, parentTreeId);
        }

        final tagRef = xref.getNewTemporaryRef();
        final tagDict = Dict(xref);

        _writeProperties(tagDict, accessibilityData);

        await _updateParentTag(
          structTreeParent: structTreeParent,
          tagDict: tagDict,
          newTagRef: tagRef,
          structTreeRootRef: structTreeRootRef,
          fallbackKids: kids,
          xref: xref,
          cache: cache,
        );

        final objDict = Dict(xref);
        tagDict.set('K', objDict);
        objDict.set('Type', objr);
        if (isPageRef) {
          objDict.set('Pg', pageRef);
        }
        objDict.set('Obj', ref);

        cache.put(tagRef, tagDict);
        if (parentTreeId != null) {
          nums.add(parentTreeId);
          nums.add(tagRef);
        }
      }
    }
    return nextKey + 1;
  }

  static void _writeProperties(Dict tagDict, Map accessibilityData) {
    final type = accessibilityData['type'];
    tagDict.set('S', Name.get(type as String));

    final title = accessibilityData['title'];
    if (title is String && title.isNotEmpty) {
      tagDict.set('T', stringToAsciiOrUTF16BE(title));
    }
    final lang = accessibilityData['lang'];
    if (lang is String && lang.isNotEmpty) {
      tagDict.set('Lang', stringToAsciiOrUTF16BE(lang));
    }
    final alt = accessibilityData['alt'];
    if (alt is String && alt.isNotEmpty) {
      tagDict.set('Alt', stringToAsciiOrUTF16BE(alt));
    }
    final expanded = accessibilityData['expanded'];
    if (expanded is String && expanded.isNotEmpty) {
      tagDict.set('E', stringToAsciiOrUTF16BE(expanded));
    }
    final actualText = accessibilityData['actualText'];
    if (actualText is String && actualText.isNotEmpty) {
      tagDict.set('ActualText', stringToAsciiOrUTF16BE(actualText));
    }
  }

  static void _collectParents({
    required List<dynamic> elements,
    required dynamic xref,
    required Dict pageDict,
    required NumberTree numberTree,
  }) {
    final idToElements = <int, List<dynamic>>{};
    for (final element in elements) {
      if (element is Map && element['structTreeParentId'] is String) {
        final parts = (element['structTreeParentId'] as String).split('_mc');
        if (parts.length > 1) {
          final id = int.tryParse(parts[1]);
          if (id != null) {
            idToElements.putIfAbsent(id, () => []).add(element);
          }
        }
      }
    }

    final id = pageDict.get('StructParents');
    if (id is! int) {
      return;
    }
    final parentArray = numberTree.get(id) as List?;
    if (parentArray == null) return;

    bool updateElement(int kid, Dict pageKid, dynamic kidRef) {
      final elems = idToElements[kid];
      if (elems != null) {
        final parentRef = pageKid.getRaw('P');
        final parentDict = xref.fetchIfRef(parentRef);
        if (parentRef is Ref && parentDict is Dict) {
          final params = {'ref': kidRef, 'dict': pageKid};
          for (final elem in elems) {
            if (elem is Map) {
              elem['structTreeParent'] = params;
            }
          }
        }
        return true;
      }
      return false;
    }

    for (final kidRef in parentArray) {
      if (kidRef is! Ref) continue;
      final pageKid = xref.fetch(kidRef) as Dict;
      final k = pageKid.get('K');
      if (k is int) {
        updateElement(k, pageKid, kidRef);
        continue;
      }

      if (k is! List) continue;
      for (var rawKid in k) {
        rawKid = xref.fetchIfRef(rawKid);
        if (rawKid is int && updateElement(rawKid, pageKid, kidRef)) {
          break;
        }
        if (rawKid is! Dict) continue;
        if (!isName(rawKid.get('Type'), 'MCR')) {
          break;
        }
        final mcid = rawKid.get('MCID');
        if (mcid is int && updateElement(mcid, pageKid, kidRef)) {
          break;
        }
      }
    }
  }

  static Future<void> _updateParentTag({
    required Map? structTreeParent,
    required Dict tagDict,
    required dynamic newTagRef,
    required dynamic structTreeRootRef,
    required List<dynamic>? fallbackKids,
    required dynamic xref,
    required RefSetCache cache,
  }) async {
    dynamic ref;
    dynamic parentRef;
    if (structTreeParent != null) {
      ref = structTreeParent['ref'];
      parentRef =
          (structTreeParent['dict'] as Dict).getRaw('P') ?? structTreeRootRef;
    } else {
      parentRef = structTreeRootRef;
    }

    tagDict.set('P', parentRef);

    final parentDict = xref.fetchIfRef(parentRef);
    if (parentDict == null) {
      fallbackKids?.add(newTagRef);
      return;
    }

    var cachedParentDict = cache.get(parentRef) as Dict?;
    if (cachedParentDict == null) {
      cachedParentDict = (parentDict as Dict).clone();
      cache.put(parentRef, cachedParentDict);
    }
    final parentKidsRaw = cachedParentDict.getRaw('K');
    List<dynamic>? cachedParentKids;
    if (parentKidsRaw is Ref) {
      cachedParentKids = cache.get(parentKidsRaw) as List<dynamic>?;
    }
    if (cachedParentKids == null) {
      final fetched = xref.fetchIfRef(parentKidsRaw);
      cachedParentKids =
          fetched is List ? fetched.toList() : [parentKidsRaw];
      final parentKidsRef = xref.getNewTemporaryRef();
      cachedParentDict.set('K', parentKidsRef);
      cache.put(parentKidsRef, cachedParentKids);
    }

    final index = cachedParentKids.indexOf(ref);
    cachedParentKids.insert(
        index >= 0 ? index + 1 : cachedParentKids.length, newTagRef);
  }
}

/// Represents a node in the structure tree for a specific page.
class StructElementNode {
  final StructTreePage tree;
  final dynamic xref;
  final Dict dict;
  final List<StructElement> kids = [];

  StructElementNode(this.tree, this.dict) : xref = tree.xref {
    parseKids();
  }

  String get role {
    final nameObj = dict.get('S');
    final name = nameObj is Name ? nameObj.name : '';
    return tree.root.roleMap[name] ?? name;
  }

  String? get mathML {
    var afs = dict.get('AF');
    if (afs != null && afs is! List) {
      afs = [afs];
    }
    if (afs is List) {
      for (var af in afs) {
        af = xref.fetchIfRef(af);
        if (af is! Dict) continue;
        if (!isName(af.get('Type'), 'Filespec')) continue;
        if (!isName(af.get('AFRelationship'), 'Supplement')) continue;
        final ef = af.get('EF');
        if (ef is! Dict) continue;
        final fileStream = ef.get('UF') ?? ef.get('F');
        if (fileStream is! BaseStream) continue;
        if (!isName(fileStream.dict?.get('Type'), 'EmbeddedFile')) continue;
        if (!isName(
            fileStream.dict?.get('Subtype'), 'application/mathml+xml')) {
          continue;
        }
        return stringToUTF8String(fileStream.getString());
      }
    }
    final a = dict.get('A');
    if (a is Dict) {
      final o = a.get('O');
      if (isName(o, 'MSFT_Office')) {
        final mathml = a.get('MSFT_MathML');
        return mathml is String ? stringToPDFString(mathml) : null;
      }
    }
    return null;
  }

  void parseKids() {
    String? pageObjId;
    final objRef = dict.getRaw('Pg');
    if (objRef is Ref) {
      pageObjId = objRef.toString();
    }
    final kidsRaw = dict.get('K');
    if (kidsRaw is List) {
      for (final kid in kidsRaw) {
        final element = parseKid(pageObjId, xref.fetchIfRef(kid));
        if (element != null) {
          kids.add(element);
        }
      }
    } else {
      final element = parseKid(pageObjId, kidsRaw);
      if (element != null) {
        kids.add(element);
      }
    }
  }

  StructElement? parseKid(String? pageObjId, dynamic kid) {
    if (kid is int) {
      if (tree.pageDict.objId != pageObjId) {
        return null;
      }
      return StructElement(
        type: StructElementType.pageContent,
        mcid: kid,
        pageObjId: pageObjId,
      );
    }

    if (kid is! Dict) {
      return null;
    }

    final pageRef = kid.getRaw('Pg');
    if (pageRef is Ref) {
      pageObjId = pageRef.toString();
    }

    final typeObj = kid.get('Type');
    final typeName = typeObj is Name ? typeObj.name : null;
    if (typeName == 'MCR') {
      if (tree.pageDict.objId != pageObjId) {
        return null;
      }
      final kidRef = kid.getRaw('Stm');
      return StructElement(
        type: StructElementType.streamContent,
        refObjId: kidRef is Ref ? kidRef.toString() : null,
        pageObjId: pageObjId,
        mcid: kid.get('MCID') as int?,
      );
    }

    if (typeName == 'OBJR') {
      if (tree.pageDict.objId != pageObjId) {
        return null;
      }
      final kidRef = kid.getRaw('Obj');
      return StructElement(
        type: StructElementType.object,
        refObjId: kidRef is Ref ? kidRef.toString() : null,
        pageObjId: pageObjId,
      );
    }

    return StructElement(
      type: StructElementType.element,
      dict: kid,
    );
  }
}

/// Represents a single structure element in the tree.
class StructElement {
  int type;
  final Dict? dict;
  final int? mcid;
  final String? pageObjId;
  final String? refObjId;
  StructElementNode? parentNode;

  StructElement({
    required this.type,
    this.dict,
    this.mcid,
    this.pageObjId,
    this.refObjId,
  });
}

/// Handles the structure tree for a single page.
class StructTreePage {
  final StructTreeRoot root;
  final dynamic xref;
  final Dict? rootDict;
  final Dict pageDict;
  final List<StructElementNode?> nodes = [];

  StructTreePage(this.root, this.pageDict)
      : xref = root.xref,
        rootDict = root.dict;

  /// Collect all objects (tags) that are part of this page.
  Map<int, dynamic>? collectObjects(dynamic pageRef) {
    if (rootDict == null || pageRef is! Ref) {
      return null;
    }

    final parentTree = rootDict!.get('ParentTree');
    if (parentTree == null) {
      return null;
    }
    final ids =
        root.structParentIds?.get(pageRef) as List<List<int>>?;
    if (ids == null) {
      return null;
    }

    final map = <int, dynamic>{};
    final numberTree = NumberTree(parentTree, xref);

    for (final idPair in ids) {
      final elemId = idPair[0];
      final obj = numberTree.getRaw(elemId);
      if (obj is Ref) {
        map[elemId] = obj;
      }
    }
    return map;
  }

  void parse(dynamic pageRef) {
    if (rootDict == null || pageRef is! Ref) {
      return;
    }

    final parentTreeNode = root.parentTree;
    if (parentTreeNode == null) {
      return;
    }
    final id = pageDict.get('StructParents');
    final ids =
        root.structParentIds?.get(pageRef) as List<List<int>>?;
    if (id is! int && ids == null) {
      return;
    }

    final map = <Dict, StructElementNode>{};

    if (id is int) {
      final parentArray = parentTreeNode.get(id);
      if (parentArray is List) {
        for (final ref in parentArray) {
          if (ref is Ref) {
            addNode(xref.fetch(ref), map);
          }
        }
      }
    }

    if (ids == null) {
      return;
    }
    for (final idPair in ids) {
      final elemId = idPair[0];
      final type = idPair[1];
      final obj = parentTreeNode.get(elemId);
      if (obj != null) {
        final elem = addNode(xref.fetchIfRef(obj), map);
        if (elem != null &&
            elem.kids.length == 1 &&
            elem.kids[0].type == StructElementType.object) {
          elem.kids[0].type = type;
        }
      }
    }
  }

  StructElementNode? addNode(dynamic dict, Map<Dict, StructElementNode> map,
      [int level = 0]) {
    if (level > _maxDepth) {
      warn('StructTree MAX_DEPTH reached.');
      return null;
    }
    if (dict is! Dict) {
      return null;
    }

    final existing = map[dict];
    if (existing != null) {
      return existing;
    }

    final element = StructElementNode(this, dict);
    map[dict] = element;

    switch (element.role) {
      case 'L':
      case 'LBody':
      case 'LI':
      case 'Table':
      case 'THead':
      case 'TBody':
      case 'TFoot':
      case 'TR':
        for (final kid in element.kids) {
          if (kid.type == StructElementType.element) {
            addNode(kid.dict, map, level - 1);
          }
        }
    }

    final parent = dict.get('P');

    if (parent is! Dict || isName(parent.get('Type'), 'StructTreeRoot')) {
      if (!addTopLevelNode(dict, element)) {
        map.remove(dict);
      }
      return element;
    }

    final parentNode = addNode(parent, map, level + 1);
    if (parentNode == null) {
      return element;
    }
    var save = false;
    for (final kid in parentNode.kids) {
      if (kid.type == StructElementType.element && identical(kid.dict, dict)) {
        kid.parentNode = element;
        save = true;
      }
    }
    if (!save) {
      map.remove(dict);
    }
    return element;
  }

  bool addTopLevelNode(Dict dict, StructElementNode element) {
    final index = root.getKidPosition(dict.objId);
    // NaN check: in Dart, after toInt() of NaN, we get 0.
    // We use a sentinel approach here.
    if (index == double.nan.toInt()) {
      return false;
    }
    if (index != -1) {
      while (nodes.length <= index) {
        nodes.add(null);
      }
      nodes[index] = element;
    }
    return true;
  }

  /// Convert the tree structure into a simplified object for serialization.
  Map<String, dynamic> get serializable {
    void nodeToSerializable(
        StructElementNode node, Map<String, dynamic> parent,
        [int level = 0]) {
      if (level > _maxDepth) {
        warn('StructTree too deep to be fully serialized.');
        return;
      }
      final obj = <String, dynamic>{
        'role': node.role,
        'children': <Map<String, dynamic>>[],
      };
      (parent['children'] as List<Map<String, dynamic>>).add(obj);

      var alt = node.dict.get('Alt');
      if (alt is! String) {
        alt = node.dict.get('ActualText');
      }
      if (alt is String) {
        obj['alt'] = stringToPDFString(alt);
      }
      if (obj['role'] == 'Formula') {
        final ml = node.mathML;
        if (ml != null) {
          obj['mathML'] = ml;
        }
      }

      final a = node.dict.get('A');
      if (a is Dict) {
        final bbox = lookupNormalRect(a.getArray('BBox'), null);
        if (bbox != null) {
          obj['bbox'] = bbox;
        } else {
          final width = a.get('Width');
          final height = a.get('Height');
          if (width is num && width > 0 && height is num && height > 0) {
            obj['bbox'] = [0, 0, width, height];
          }
        }
      }

      final lang = node.dict.get('Lang');
      if (lang is String) {
        obj['lang'] = stringToPDFString(lang);
      }

      for (final kid in node.kids) {
        final kidElement =
            kid.type == StructElementType.element ? kid.parentNode : null;
        if (kidElement != null) {
          nodeToSerializable(kidElement, obj, level + 1);
          continue;
        } else if (kid.type == StructElementType.pageContent ||
            kid.type == StructElementType.streamContent) {
          (obj['children'] as List).add({
            'type': 'content',
            'id': 'p${kid.pageObjId}_mc${kid.mcid}',
          });
        } else if (kid.type == StructElementType.object) {
          (obj['children'] as List).add({
            'type': 'object',
            'id': kid.refObjId,
          });
        } else if (kid.type == StructElementType.annotation) {
          (obj['children'] as List).add({
            'type': 'annotation',
            'id': '${annotationPrefix}${kid.refObjId}',
          });
        }
      }
    }

    final rootObj = <String, dynamic>{
      'children': <Map<String, dynamic>>[],
      'role': 'Root',
    };
    for (final child in nodes) {
      if (child == null) continue;
      nodeToSerializable(child, rootObj);
    }
    return rootObj;
  }
}
