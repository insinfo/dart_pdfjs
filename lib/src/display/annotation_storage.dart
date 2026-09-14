// Copyright 2020 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:convert';
import '../shared/murmurhash3.dart';

const Map<String, dynamic> serializableEmpty = {
  'map': null,
  'hash': '',
  'transfer': null,
};

/// Key/value storage for annotation data in forms.
class AnnotationStorage {
  bool _modified = false;
  Map<String, dynamic>? _modifiedIds;
  final Map<String, dynamic> _storage = {};
  Map<String, dynamic>? _editorsMap;

  void Function()? onSetModified;
  void Function()? onResetModified;
  void Function(dynamic type)? onAnnotationEditor;

  AnnotationStorage();

  dynamic getValue(String key, dynamic defaultValue) {
    final value = _storage[key];
    if (value == null) {
      return defaultValue;
    }
    if (defaultValue is Map && value is Map) {
      return {...defaultValue, ...value};
    }
    return value;
  }

  dynamic getRawValue(String key) => _storage[key];

  void remove(String key) {
    if (!_storage.containsKey(key)) {
      return;
    }
    final storedValue = _storage.remove(key);
    if (storedValue is Map && storedValue['annotationElementId'] != null) {
      _editorsMap?.remove(storedValue['annotationElementId']);
    }
    if (_storage.isEmpty) {
      resetModified();
    }
    onAnnotationEditor?.call(null);
  }

  void setValue(String key, dynamic value) {
    final existing = _storage[key];
    var modified = false;
    if (existing is Map && value is Map) {
      for (final entry in value.entries) {
        if (existing[entry.key] != entry.value) {
          modified = true;
          existing[entry.key] = entry.value;
        }
      }
    } else {
      modified = true;
      _storage[key] = value is Map ? Map<String, dynamic>.from(value) : value;
    }

    if (modified) {
      _setModified();
    }
  }

  bool has(String key) => _storage.containsKey(key);

  int get size => _storage.length;

  void _setModified() {
    if (!_modified) {
      _modified = true;
      onSetModified?.call();
    }
  }

  void resetModified() {
    if (_modified) {
      _modified = false;
      onResetModified?.call();
    }
  }

  PrintAnnotationStorage get print => PrintAnnotationStorage(this);

  Map<String, dynamic> get serializable {
    if (_storage.isEmpty) {
      return serializableEmpty;
    }
    final map = <String, dynamic>{};
    final hash = MurmurHash3_64();
    final transfer = <dynamic>[];

    for (final entry in _storage.entries) {
      final key = entry.key;
      final val = entry.value;
      dynamic serialized = val;
      if (serialized != null) {
        map[key] = serialized;
        hash.update('$key:${jsonEncode(serialized)}');
        if (serialized is Map && serialized['bitmap'] != null) {
          transfer.add(serialized['bitmap']);
        }
      }
    }

    return map.isNotEmpty
        ? {
            'map': map,
            'hash': hash.hexdigest(),
            'transfer': transfer,
          }
        : serializableEmpty;
  }

  void resetModifiedIds() {
    _modifiedIds = null;
  }

  Map<String, dynamic> get modifiedIds {
    if (_modifiedIds != null) {
      return _modifiedIds!;
    }
    final ids = <String>[];
    if (_editorsMap != null) {
      for (final value in _editorsMap!.values) {
        if (value is Map && value['annotationElementId'] != null) {
          ids.add(value['annotationElementId'].toString());
        }
      }
    }
    return _modifiedIds = {
      'ids': ids.toSet(),
      'hash': ids.join(','),
    };
  }

  Iterable<MapEntry<String, dynamic>> get entries => _storage.entries;
}

class PrintAnnotationStorage extends AnnotationStorage {
  late final Map<String, dynamic> _serializable;

  PrintAnnotationStorage(AnnotationStorage parent) {
    final parentSerializable = parent.serializable;
    if (parentSerializable == serializableEmpty) {
      _serializable = serializableEmpty;
      return;
    }
    final map = parentSerializable['map'] as Map<String, dynamic>?;
    final hash = parentSerializable['hash'] as String? ?? '';
    final clone = map != null ? Map<String, dynamic>.from(map) : null;
    _serializable = {
      'map': clone,
      'hash': hash,
      'transfer': const [],
    };
  }

  @override
  PrintAnnotationStorage get print {
    throw UnsupportedError('Should not call PrintAnnotationStorage.print');
  }

  @override
  Map<String, dynamic> get serializable => _serializable;

  @override
  Map<String, dynamic> get modifiedIds => {
        'ids': <String>{},
        'hash': '',
      };
}
