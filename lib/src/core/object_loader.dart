// Copyright 2021 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import '../shared/util.dart';
import 'base_stream.dart';
import 'core_utils.dart';
import 'primitives.dart';

bool _mayHaveChildren(dynamic value) {
  return value is Ref || value is Dict || value is BaseStream || value is List;
}

void _addChildren(dynamic node, List<dynamic> nodesToVisit) {
  Iterable<dynamic>? values;
  if (node is Dict) {
    values = node.getRawValues();
  } else if (node is BaseStream && node.dict is Dict) {
    values = (node.dict as Dict).getRawValues();
  } else if (node is List) {
    values = node;
  } else {
    return;
  }
  for (final rawValue in values) {
    if (_mayHaveChildren(rawValue)) {
      nodesToVisit.add(rawValue);
    }
  }
}

/// A helper for loading missing data in `Dict` graphs. It traverses the graph
/// depth first and queues up any objects that have missing data. Once it has
/// traversed as many objects that are available it attempts to bundle the
/// missing data requests and then resume from the nodes that weren't ready.
class ObjectLoader {
  RefSet? refSet = RefSet();
  final Dict dict;
  final List<String> keys;
  final dynamic xref;

  ObjectLoader(this.dict, this.keys, this.xref);

  Future<void> _load() async {
    final nodesToVisit = <dynamic>[];
    for (final key in keys) {
      final rawValue = dict.getRaw(key);
      if (rawValue != null) {
        nodesToVisit.add(rawValue);
      }
    }
    await _walk(nodesToVisit);
    refSet = null; // Everything is loaded, clear the cache.
  }

  Future<void> _walk(List<dynamic> nodesToVisit) async {
    final nodesToRevisit = <dynamic>[];
    final pendingRequests = <({int begin, int end})>[];

    // DFS walk of the object graph.
    while (nodesToVisit.isNotEmpty) {
      var currentNode = nodesToVisit.removeLast();

      // Only references or chunked streams can cause missing data exceptions.
      if (currentNode is Ref) {
        if (refSet != null && refSet!.has(currentNode)) {
          continue;
        }
        try {
          refSet?.put(currentNode);
          currentNode = xref.fetch(currentNode);
        } catch (ex) {
          if (ex is! MissingDataException) {
            warn('ObjectLoader.#walk - requesting all data: "$ex".');
            await xref.stream.manager.requestAllChunks();
            return;
          }
          nodesToRevisit.add(currentNode);
          pendingRequests.add((begin: ex.begin, end: ex.end));
        }
      }

      if (currentNode is BaseStream) {
        final baseStreams = currentNode.getBaseStreams();
        if (baseStreams != null) {
          var foundMissingData = false;
          for (final stream in baseStreams) {
            if (stream.isDataLoaded) {
              continue;
            }
            foundMissingData = true;
            final dynamic s = stream;
            final int start = s.start as int? ?? 0;
            final int end = s.end as int? ?? 0;
            pendingRequests.add((begin: start, end: end));
          }
          if (foundMissingData) {
            nodesToRevisit.add(currentNode);
          }
        }
      }

      _addChildren(currentNode, nodesToVisit);
    }

    if (pendingRequests.isNotEmpty) {
      await xref.stream.manager.requestRanges(pendingRequests);

      for (final node in nodesToRevisit) {
        // Remove any reference nodes from the current `RefSet` so they
        // aren't skipped when we revisit them.
        if (node is Ref && refSet != null) {
          refSet!.remove(node);
        }
      }
      await _walk(nodesToRevisit);
    }
  }

  static Future<void> load(dynamic obj, List<String> keys, dynamic xref) async {
    // Don't walk the graph if all the data is already loaded.
    if (xref.stream?.isDataLoaded == true) {
      return;
    }
    final objLoader = ObjectLoader(obj as Dict, keys, xref);
    await objLoader._load();
  }
}

