// Copyright 2024 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import '../shared/math_clamp.dart';
import '../shared/util.dart';
import 'colorspace.dart';
import 'primitives.dart';

class BaseColorSpaceCache {
  BaseColorSpaceCache({bool onlyRefs = false}) : _onlyRefs = onlyRefs;

  final bool _onlyRefs;
  final Map<String, Ref> _nameRefMap = <String, Ref>{};
  final Map<String, ColorSpace> _nameMap = <String, ColorSpace>{};
  final RefSetCache _cache = RefSetCache();

  ColorSpace? getByName(String? name) {
    if (_onlyRefs || name == null) {
      return null;
    }
    final ref = _nameRefMap[name];
    if (ref != null) {
      return getByRef(ref);
    }
    return _nameMap[name];
  }

  ColorSpace? getByRef(Ref? ref) {
    if (ref == null) {
      return null;
    }
    return _cache.get(ref) as ColorSpace?;
  }

  void set(String? name, Ref? ref, ColorSpace data) {
    if (ref != null) {
      if (_cache.has(ref)) {
        return;
      }
      if (!_onlyRefs && name != null) {
        _nameRefMap[name] = ref;
      }
      _cache.put(ref, data);
      return;
    }
    if (_onlyRefs || name == null || _nameMap.containsKey(name)) {
      return;
    }
    _nameMap[name] = data;
  }

  void clear() {
    _nameRefMap.clear();
    _nameMap.clear();
    _cache.clear();
  }
}

class LocalColorSpaceCache extends BaseColorSpaceCache {}

class GlobalColorSpaceCache extends BaseColorSpaceCache {
  GlobalColorSpaceCache() : super(onlyRefs: true);
}

class ColorSpaceParseOptions {
  const ColorSpaceParseOptions({
    required this.xref,
    this.resources,
    this.pdfFunctionFactory,
    required this.globalColorSpaceCache,
    required this.localColorSpaceCache,
  });

  final dynamic xref;
  final Dict? resources;
  final dynamic pdfFunctionFactory;
  final GlobalColorSpaceCache globalColorSpaceCache;
  final LocalColorSpaceCache localColorSpaceCache;
}

class ColorSpaceUtils {
  static final DeviceGrayCS gray = DeviceGrayCS();
  static final DeviceRgbCS rgb = DeviceRgbCS();
  static final DeviceRgbaCS rgba = DeviceRgbaCS();
  static final DeviceCmykCS cmyk = DeviceCmykCS();

  static ColorSpace parse({
    required dynamic cs,
    required dynamic xref,
    Dict? resources,
    dynamic pdfFunctionFactory,
    required GlobalColorSpaceCache globalColorSpaceCache,
    required LocalColorSpaceCache localColorSpaceCache,
    bool asyncIfNotCached = false,
  }) {
    final options = ColorSpaceParseOptions(
      xref: xref,
      resources: resources,
      pdfFunctionFactory: pdfFunctionFactory,
      globalColorSpaceCache: globalColorSpaceCache,
      localColorSpaceCache: localColorSpaceCache,
    );
    String? csName;
    Ref? csRef;

    if (cs is Ref) {
      csRef = cs;
      final cached = globalColorSpaceCache.getByRef(csRef) ??
          localColorSpaceCache.getByRef(csRef);
      if (cached != null) {
        return cached;
      }
      cs = xref.fetch(cs);
    }
    if (cs is Name) {
      csName = cs.name;
      final cached = localColorSpaceCache.getByName(csName);
      if (cached != null) {
        return cached;
      }
    }

    final parsedCS = _parse(cs, options);
    if (csName != null || csRef != null) {
      localColorSpaceCache.set(csName, csRef, parsedCS);
      if (csRef != null) {
        globalColorSpaceCache.set(null, csRef, parsedCS);
      }
    }
    return parsedCS;
  }

  static ColorSpace _subParse(dynamic cs, ColorSpaceParseOptions options) {
    Ref? csRef;
    if (cs is Ref) {
      csRef = cs;
      final cached = options.globalColorSpaceCache.getByRef(csRef);
      if (cached != null) {
        return cached;
      }
    }
    final parsedCS = _parse(cs, options);
    if (csRef != null) {
      options.globalColorSpaceCache.set(null, csRef, parsedCS);
    }
    return parsedCS;
  }

  static ColorSpace _parse(dynamic cs, ColorSpaceParseOptions options) {
    final xref = options.xref;
    cs = xref.fetchIfRef(cs);

    if (cs is Name) {
      switch (cs.name) {
        case 'G':
        case 'DeviceGray':
          return gray;
        case 'RGB':
        case 'DeviceRGB':
          return rgb;
        case 'DeviceRGBA':
          return rgba;
        case 'CMYK':
        case 'DeviceCMYK':
          return cmyk;
        case 'Pattern':
          return PatternCS(null);
        default:
          final resources = options.resources;
          if (resources != null) {
            final colorSpaces = resources.get('ColorSpace');
            if (colorSpaces is Dict) {
              final resourcesCS = colorSpaces.get(cs.name);
              if (resourcesCS != null) {
                return _parse(resourcesCS, options);
              }
            }
          }
          warn('Unrecognized ColorSpace: ${cs.name}');
          return gray;
      }
    }

    if (cs is List) {
      final rawMode = xref.fetchIfRef(cs[0]);
      final mode = rawMode is Name ? rawMode.name : rawMode.toString();
      switch (mode) {
        case 'G':
        case 'DeviceGray':
          return gray;
        case 'RGB':
        case 'DeviceRGB':
          return rgb;
        case 'CMYK':
        case 'DeviceCMYK':
          return cmyk;
        case 'CalGray':
          final params = xref.fetchIfRef(cs[1]) as Dict;
          return CalGrayCS(
            _numList(params.getArray('WhitePoint')),
            _numList(params.getArray('BlackPoint')),
            params.get('Gamma') as num?,
          );
        case 'CalRGB':
          final params = xref.fetchIfRef(cs[1]) as Dict;
          return CalRGBCS(
            _numList(params.getArray('WhitePoint')),
            _numList(params.getArray('BlackPoint')),
            _numList(params.getArray('Gamma')),
            _numList(params.getArray('Matrix')),
          );
        case 'ICCBased':
          final stream = xref.fetchIfRef(cs[1]);
          final dict = (stream as dynamic).dict as Dict;
          final numComps = dict.get('N');
          final altRaw = dict.getRaw('Alternate');
          if (altRaw != null) {
            final altCS = _subParse(altRaw, options);
            if (altCS.numComps == numComps) {
              return altCS;
            }
            warn('ICCBased color space: Ignoring incorrect /Alternate entry.');
          }
          if (numComps == 1) {
            return gray;
          } else if (numComps == 3) {
            return rgb;
          } else if (numComps == 4) {
            return cmyk;
          }
          break;
        case 'Pattern':
          final baseCS =
              cs.length > 1 && cs[1] != null ? _subParse(cs[1], options) : null;
          return PatternCS(baseCS);
        case 'I':
        case 'Indexed':
          final baseCS = _subParse(cs[1], options);
          final hiVal =
              mathClamp(xref.fetchIfRef(cs[2]) as num, 0, 255).toInt();
          final lookup = xref.fetchIfRef(cs[3]);
          return IndexedCS(baseCS, hiVal, lookup);
        case 'Separation':
        case 'DeviceN':
          final name = xref.fetchIfRef(cs[1]);
          final numComps = name is List ? name.length : 1;
          final baseCS = _subParse(cs[2], options);
          final tintFn = options.pdfFunctionFactory?.create(cs[3]);
          if (tintFn is TintFunction) {
            return AlternateCS(numComps, baseCS, tintFn);
          }
          warn('Unimplemented ColorSpace tint function: $mode');
          return baseCS;
        case 'Lab':
          final params = xref.fetchIfRef(cs[1]) as Dict;
          return LabCS(
            _numList(params.getArray('WhitePoint')),
            _numList(params.getArray('BlackPoint')),
            _numList(params.getArray('Range')),
          );
      }
    }

    warn('Unrecognized ColorSpace object: $cs');
    return gray;
  }
}

List<num>? _numList(dynamic value) {
  if (value is List) {
    return value.cast<num>();
  }
  return null;
}
