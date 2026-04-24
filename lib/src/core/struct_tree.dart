import '../shared/util.dart';
import 'name_number_tree.dart';
import 'primitives.dart';
import 'xref.dart';

abstract class StructElementType {
  static const int pageContent = 1;
  static const int streamContent = 2;
  static const int object = 3;
  static const int annotation = 4;
  static const int element = 5;
}

class StructTreeRoot {
  final XRef xref;
  final Dict dict;
  final Ref? ref;

  final Map<String, String> roleMap = <String, String>{};
  RefSetCache? structParentIds;
  NumberTree? parentTree;
  Map<String, int>? _kidRefToPosition;
  bool _kidRefPositionsInitialized = false;

  StructTreeRoot(this.xref, this.dict, Ref? ref)
      : ref = ref is Ref ? ref : null;

  int getKidPosition(dynamic kidRef) {
    if (!_kidRefPositionsInitialized) {
      _kidRefPositionsInitialized = true;
      final obj = dict.get('K');
      if (obj is List) {
        final map = <String, int>{};
        for (var i = 0; i < obj.length; i++) {
          final ref = obj[i];
          if (ref != null) {
            map[ref.toString()] = i;
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
    return positions != null ? positions[kidRef.toString()] ?? -1 : -1;
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
      } else if (key is String) {
        warn('Skipping invalid StructTreeRoot RoleMap entry: $key.');
      }
    }
  }
}
