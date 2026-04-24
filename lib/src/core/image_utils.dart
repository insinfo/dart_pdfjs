// Copyright 2024 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import '../shared/util.dart';
import 'primitives.dart';

class GlobalImageCache {
  static const int numPagesThreshold = 2;
  static const int minImagesToCache = 10;
  static const int maxByteSize = 50000000;

  final RefSet _decodeFailedSet = RefSet();
  final RefSetCache _refCache = RefSetCache();
  final RefSetCache _imageCache = RefSetCache();

  int get _byteSize {
    var byteSize = 0;
    for (final imageData in _imageCache.values) {
      if (imageData is Map && imageData['byteSize'] is int) {
        byteSize += imageData['byteSize'] as int;
      } else {
        try {
          final value = (imageData as dynamic).byteSize;
          if (value is int) {
            byteSize += value;
          }
        } catch (_) {}
      }
    }
    return byteSize;
  }

  bool get _cacheLimitReached {
    if (_imageCache.size < minImagesToCache) {
      return false;
    }
    return _byteSize >= maxByteSize;
  }

  bool shouldCache(Ref ref, int pageIndex) {
    var pageIndexSet = _refCache.get(ref) as Set<int>?;
    if (pageIndexSet == null) {
      pageIndexSet = <int>{};
      _refCache.put(ref, pageIndexSet);
    }
    pageIndexSet.add(pageIndex);

    if (pageIndexSet.length < numPagesThreshold) {
      return false;
    }
    if (!_imageCache.has(ref) && _cacheLimitReached) {
      return false;
    }
    return true;
  }

  void addDecodeFailed(Ref ref) {
    _decodeFailedSet.put(ref);
  }

  bool hasDecodeFailed(Ref ref) {
    return _decodeFailedSet.has(ref);
  }

  void addByteSize(Ref ref, int byteSize) {
    final imageData = _imageCache.get(ref);
    if (imageData == null) {
      return;
    }
    if (imageData is Map) {
      if (imageData['byteSize'] != null) {
        return;
      }
      imageData['byteSize'] = byteSize;
      return;
    }
    try {
      if ((imageData as dynamic).byteSize != null) {
        return;
      }
      (imageData as dynamic).byteSize = byteSize;
    } catch (_) {}
  }

  dynamic getData(Ref ref, int pageIndex) {
    final pageIndexSet = _refCache.get(ref) as Set<int>?;
    if (pageIndexSet == null || pageIndexSet.length < numPagesThreshold) {
      return null;
    }
    final imageData = _imageCache.get(ref);
    if (imageData == null) {
      return null;
    }
    pageIndexSet.add(pageIndex);
    return imageData;
  }

  void setData(Ref ref, dynamic data) {
    if (!_refCache.has(ref)) {
      throw StateError(
        'GlobalImageCache.setData - expected "shouldCache" to have been called.',
      );
    }
    if (_imageCache.has(ref)) {
      return;
    }
    if (_cacheLimitReached) {
      warn('GlobalImageCache.setData - cache limit reached.');
      return;
    }
    _imageCache.put(ref, data);
  }

  void clear({bool onlyData = false}) {
    if (!onlyData) {
      _decodeFailedSet.clear();
      _refCache.clear();
    }
    _imageCache.clear();
  }
}
