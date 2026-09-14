// Copyright 2020 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import '../shared/murmurhash3.dart';
import '../shared/util.dart';

class OptionalContentGroup {
  bool _isDisplay = false;
  bool _isPrint = false;
  bool _userSet = false;
  bool _visible = true;

  final String? name;
  final dynamic intent;
  final Map<String, dynamic>? usage;
  final List<dynamic> rbGroups;

  OptionalContentGroup(int renderingIntent, Map<String, dynamic> group)
      : name = group['name'] as String?,
        intent = group['intent'],
        usage = group['usage'] as Map<String, dynamic>?,
        rbGroups = (group['rbGroups'] as List?) ?? const [] {
    _isDisplay = (renderingIntent & RenderingIntentFlag.DISPLAY) != 0;
    _isPrint = (renderingIntent & RenderingIntentFlag.PRINT) != 0;
  }

  bool get visible {
    if (_userSet) {
      return _visible;
    }
    if (!_visible) {
      return false;
    }
    final u = usage;
    if (u != null) {
      final print = u['print'] as Map<String, dynamic>?;
      final view = u['view'] as Map<String, dynamic>?;
      if (_isDisplay) {
        return view?['viewState'] != 'OFF';
      } else if (_isPrint) {
        return print?['printState'] != 'OFF';
      }
    }
    return true;
  }

  void setVisible(bool visible, [bool userSet = false]) {
    _userSet = userSet;
    _visible = visible;
  }
}

class OptionalContentConfig {
  String? _cachedGetHash;
  final Map<String, OptionalContentGroup> _groups = {};
  String? _initialHash;
  List<dynamic>? _order;
  final int renderingIntent;
  String? name;
  String? creator;

  OptionalContentConfig(
    Map<String, dynamic>? data, [
    this.renderingIntent = RenderingIntentFlag.DISPLAY,
  ]) {
    if (data == null) {
      return;
    }
    name = data['name'] as String?;
    creator = data['creator'] as String?;
    _order = data['order'] as List<dynamic>?;

    final groups = data['groups'] as List<dynamic>? ?? const [];
    for (final rawGroup in groups) {
      final group = rawGroup as Map<String, dynamic>;
      final id = group['id'] as String;
      _groups[id] = OptionalContentGroup(renderingIntent, group);
    }

    if (data['baseState'] == 'OFF') {
      for (final group in _groups.values) {
        group.setVisible(false);
      }
    }

    final onList = data['on'] as List<dynamic>? ?? const [];
    for (final on in onList) {
      _groups[on.toString()]?.setVisible(true);
    }

    final offList = data['off'] as List<dynamic>? ?? const [];
    for (final off in offList) {
      _groups[off.toString()]?.setVisible(false);
    }

    _initialHash = getHash();
  }

  bool _evaluateVisibilityExpression(List<dynamic> array) {
    final length = array.length;
    if (length < 2) {
      return true;
    }
    final operator = array[0].toString();
    for (var i = 1; i < length; i++) {
      final element = array[i];
      late bool state;
      if (element is List) {
        state = _evaluateVisibilityExpression(element);
      } else if (_groups.containsKey(element.toString())) {
        state = _groups[element.toString()]!.visible;
      } else {
        warn('Optional content group not found: $element');
        return true;
      }

      switch (operator) {
        case 'And':
          if (!state) return false;
          break;
        case 'Or':
          if (state) return true;
          break;
        case 'Not':
          return !state;
        default:
          return true;
      }
    }
    return operator == 'And';
  }

  bool isVisible(Map<String, dynamic>? group) {
    if (_groups.isEmpty || group == null) {
      return true;
    }
    final type = group['type'];
    if (type == 'OCG') {
      final id = group['id']?.toString();
      if (!_groups.containsKey(id)) {
        warn('Optional content group not found: $id');
        return true;
      }
      return _groups[id]!.visible;
    } else if (type == 'OCMD') {
      final expr = group['expression'];
      if (expr is List) {
        return _evaluateVisibilityExpression(expr);
      }

      final policy = group['policy'] ?? 'AnyOn';
      final ids = (group['ids'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[];

      if (policy == 'AnyOn') {
        for (final id in ids) {
          if (!_groups.containsKey(id)) {
            warn('Optional content group not found: $id');
            return true;
          }
          if (_groups[id]!.visible) return true;
        }
        return false;
      } else if (policy == 'AllOn') {
        for (final id in ids) {
          if (!_groups.containsKey(id)) {
            warn('Optional content group not found: $id');
            return true;
          }
          if (!_groups[id]!.visible) return false;
        }
        return true;
      } else if (policy == 'AnyOff') {
        for (final id in ids) {
          if (!_groups.containsKey(id)) {
            warn('Optional content group not found: $id');
            return true;
          }
          if (!_groups[id]!.visible) return true;
        }
        return false;
      } else if (policy == 'AllOff') {
        for (final id in ids) {
          if (!_groups.containsKey(id)) {
            warn('Optional content group not found: $id');
            return true;
          }
          if (_groups[id]!.visible) return false;
        }
        return true;
      }
      warn('Unknown optional content policy $policy.');
      return true;
    }
    warn('Unknown group type $type.');
    return true;
  }

  void setVisibility(String id, [bool visible = true, bool preserveRB = true]) {
    final group = _groups[id];
    if (group == null) {
      warn('Optional content group not found: $id');
      return;
    }

    if (preserveRB && visible && group.rbGroups.isNotEmpty) {
      for (final rawRb in group.rbGroups) {
        if (rawRb is List) {
          for (final otherId in rawRb) {
            if (otherId.toString() != id) {
              _groups[otherId.toString()]?.setVisible(false, true);
            }
          }
        }
      }
    }

    group.setVisible(visible, true);
    _cachedGetHash = null;
  }

  void setOCGState({required List<dynamic> state, bool preserveRB = true}) {
    String? op;
    for (final elem in state) {
      if (elem == 'ON' || elem == 'OFF' || elem == 'Toggle') {
        op = elem.toString();
        continue;
      }
      final id = elem.toString();
      final group = _groups[id];
      if (group == null) continue;

      switch (op) {
        case 'ON':
          setVisibility(id, true, preserveRB);
          break;
        case 'OFF':
          setVisibility(id, false, preserveRB);
          break;
        case 'Toggle':
          setVisibility(id, !group.visible, preserveRB);
          break;
      }
    }
    _cachedGetHash = null;
  }

  bool get hasInitialVisibility {
    return _initialHash == null || getHash() == _initialHash;
  }

  List<dynamic>? getOrder() {
    if (_groups.isEmpty) {
      return null;
    }
    if (_order != null) {
      return List<dynamic>.from(_order!);
    }
    return _groups.keys.toList();
  }

  OptionalContentGroup? getGroup(String id) => _groups[id];

  String getHash() {
    if (_cachedGetHash != null) {
      return _cachedGetHash!;
    }
    final hash = MurmurHash3_64();
    for (final entry in _groups.entries) {
      hash.update('${entry.key}:${entry.value.visible}');
    }
    return _cachedGetHash = hash.hexdigest();
  }

  Iterable<MapEntry<String, OptionalContentGroup>> get entries =>
      _groups.entries;
}
