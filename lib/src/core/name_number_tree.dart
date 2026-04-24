import '../shared/util.dart';
import 'primitives.dart';
import 'xref.dart';

/// A NameTree/NumberTree is like a Dict but has some advantageous properties,
/// see the specification (7.9.6 and 7.9.7) for additional details.
abstract class NameOrNumberTree {
  final dynamic root;
  final XRef xref;
  final String _type;

  NameOrNumberTree(this.root, this.xref, this._type);

  Map<dynamic, dynamic> getAll({bool isRaw = false}) {
    final map = <dynamic, dynamic>{};
    if (root == null) {
      return map;
    }
    
    final processed = RefSet();
    if (root is Ref) {
      processed.put(root as Ref);
    }
    
    final queue = [root];
    while (queue.isNotEmpty) {
      final obj = xref.fetchIfRef(queue.removeAt(0));
      if (obj is! Dict) {
        continue;
      }
      if (obj.has('Kids')) {
        final kids = obj.get('Kids');
        if (kids is! List) {
          continue;
        }
        for (final kid in kids) {
          if (kid is Ref) {
            if (processed.has(kid)) {
              throw FormatException('Duplicate entry in "$_type" tree.');
            }
            processed.put(kid);
          }
          queue.add(kid);
        }
        continue;
      }
      
      final entries = obj.get(_type);
      if (entries is! List) {
        continue;
      }
      for (var i = 0; i < entries.length; i += 2) {
        final key = xref.fetchIfRef(entries[i]);
        final value = isRaw ? entries[i + 1] : xref.fetchIfRef(entries[i + 1]);
        map[key] = value;
      }
    }
    return map;
  }

  dynamic getRaw(dynamic key) {
    if (root == null) {
      return null;
    }
    
    dynamic kidsOrEntries = xref.fetchIfRef(root);
    var loopCount = 0;
    const maxLevels = 10;

    // Perform a binary search to quickly find the entry that
    // contains the key we are looking for.
    while (kidsOrEntries is Dict && kidsOrEntries.has('Kids')) {
      if (++loopCount > maxLevels) {
        warn('Search depth limit reached for "$_type" tree.');
        return null;
      }

      final kids = kidsOrEntries.get('Kids');
      if (kids is! List) {
        return null;
      }

      var l = 0;
      var r = kids.length - 1;
      while (l <= r) {
        final m = (l + r) >> 1;
        final kid = xref.fetchIfRef(kids[m]);
        if (kid is! Dict) {
          return null;
        }
        final limits = kid.get('Limits');
        if (limits is! List) {
           return null;
        }

        final limit0 = xref.fetchIfRef(limits[0]);
        final limit1 = xref.fetchIfRef(limits[1]);
        
        if (_compare(key, limit0) < 0) {
          r = m - 1;
        } else if (_compare(key, limit1) > 0) {
          l = m + 1;
        } else {
          kidsOrEntries = kid;
          break;
        }
      }
      if (l > r) {
        return null;
      }
    }

    if (kidsOrEntries is! Dict) return null;

    // If we get here, then we have found the right entry. Now go through the
    // entries in the dictionary until we find the key we're looking for.
    final entries = kidsOrEntries.get(_type);
    if (entries is List) {
      // Perform a binary search to reduce the lookup time.
      var l = 0;
      var r = entries.length - 2;
      while (l <= r) {
        // Check only even indices (0, 2, 4, ...) because the
        // odd indices contain the actual data.
        final tmp = (l + r) >> 1;
        final m = tmp + (tmp & 1);
        final currentKey = xref.fetchIfRef(entries[m]);
        final comp = _compare(key, currentKey);
        
        if (comp < 0) {
          r = m - 2;
        } else if (comp > 0) {
          l = m + 2;
        } else {
          return entries[m + 1];
        }
      }
    }
    return null;
  }

  dynamic get(dynamic key) {
    return xref.fetchIfRef(getRaw(key));
  }
  
  int _compare(dynamic a, dynamic b) {
    if (a is num && b is num) {
      return a.compareTo(b);
    }
    if (a is String && b is String) {
      return a.compareTo(b);
    }
    return a.toString().compareTo(b.toString());
  }
}

class NameTree extends NameOrNumberTree {
  NameTree(dynamic root, XRef xref) : super(root, xref, 'Names');
}

class NumberTree extends NameOrNumberTree {
  NumberTree(dynamic root, XRef xref) : super(root, xref, 'Nums');
}
