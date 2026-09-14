// Copyright 2015 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:math' as math;
import 'package:web/web.dart' as web;

import 'display_utils.dart' show getRGB, isDataScheme, SVG_NS, updateUrlHash;
import '../shared/util.dart' show Util, warn;

/// Base class for filter factories.
/// Subclasses override methods to create SVG-based filters.
class BaseFilterFactory {
  String addFilter(dynamic maps) => 'none';

  String addHCMFilter(String? fgColor, String? bgColor) => 'none';

  String addAlphaFilter(dynamic map) => 'none';

  String addLuminosityFilter(dynamic map) => 'none';

  String addHighlightHCMFilter(
    String filterName,
    String? fgColor,
    String? bgColor,
    String? newFgColor,
    String? newBgColor,
  ) =>
      'none';

  void destroy({bool keepHCM = false}) {}
}

/// DOMFilterFactory creates SVG filters for canvas rendering.
class DOMFilterFactory extends BaseFilterFactory {
  final String _docId;
  String? _baseUrl;
  Map<dynamic, String>? __cache;
  web.SVGDefsElement? __defs;
  Map<String, _HCMInfo>? __hcmCache;
  int _id = 0;

  DOMFilterFactory({required String docId}) : _docId = docId;

  Map<dynamic, String> get _cache => __cache ??= {};

  Map<String, _HCMInfo> get _hcmCache => __hcmCache ??= {};

  web.SVGDefsElement get _defs {
    if (__defs == null) {
      final div = web.document.createElement('div') as web.HTMLDivElement;
      final style = div.style;
      style.visibility = 'hidden';
      style.contain = 'strict';
      style.width = '0';
      style.height = '0';
      style.position = 'absolute';
      style.top = '0';
      style.left = '0';
      style.zIndex = '-1';

      final svg =
          web.document.createElementNS(SVG_NS, 'svg') as web.SVGSVGElement;
      svg.setAttribute('width', '0');
      svg.setAttribute('height', '0');
      __defs = web.document.createElementNS(SVG_NS, 'defs')
          as web.SVGDefsElement;
      div.append(svg);
      svg.append(__defs!);
      web.document.body!.append(div);
    }
    return __defs!;
  }

  List<String> _createTables(List<List<int>> maps) {
    if (maps.length == 1) {
      final mapR = maps[0];
      final buffer =
          List<String>.generate(256, (i) => (mapR[i] / 255).toString());
      final table = buffer.join(',');
      return [table, table, table];
    }

    final mapR = maps[0];
    final mapG = maps[1];
    final mapB = maps[2];
    final bufferR =
        List<String>.generate(256, (i) => (mapR[i] / 255).toString());
    final bufferG =
        List<String>.generate(256, (i) => (mapG[i] / 255).toString());
    final bufferB =
        List<String>.generate(256, (i) => (mapB[i] / 255).toString());
    return [bufferR.join(','), bufferG.join(','), bufferB.join(',')];
  }

  String _createUrl(String id) {
    if (_baseUrl == null) {
      _baseUrl = '';
      final url = web.document.URL;
      final baseURI = web.document.baseURI;
      if (url != baseURI) {
        if (isDataScheme(url)) {
          warn('#createUrl: ignore "data:"-URL for performance reasons.');
        } else {
          _baseUrl = updateUrlHash(url, '');
        }
      }
    }
    return 'url($_baseUrl#$id)';
  }

  @override
  String addFilter(dynamic maps) {
    if (maps == null) return 'none';

    final mapsList = maps as List<List<int>>;
    final tables = _createTables(mapsList);
    final tableR = tables[0];
    final tableG = tables[1];
    final tableB = tables[2];
    final key =
        mapsList.length == 1 ? tableR : '$tableR$tableG$tableB';

    final existing = _cache[key];
    if (existing != null) return existing;

    final id = 'g_${_docId}_transfer_map_${_id++}';
    final url = _createUrl(id);
    _cache[key] = url;

    final filter = _createFilter(id);
    _addTransferMapConversion(tableR, tableG, tableB, filter);

    return url;
  }

  @override
  String addHCMFilter(String? fgColor, String? bgColor) {
    final key = '$fgColor-$bgColor';
    const filterName = 'base';
    var info = _hcmCache[filterName];
    if (info != null && info.key == key) {
      return info.url;
    }

    if (info != null) {
      info.filter?.remove();
      info.key = key;
      info.url = 'none';
      info.filter = null;
    } else {
      info = _HCMInfo(key: key, url: 'none');
      _hcmCache[filterName] = info;
    }

    if (fgColor == null || bgColor == null) {
      return info.url;
    }

    final fgRGB = _getRGB(fgColor);
    fgColor = Util.makeHexColor(fgRGB[0], fgRGB[1], fgRGB[2]);
    final bgRGB = _getRGB(bgColor);
    bgColor = Util.makeHexColor(bgRGB[0], bgRGB[1], bgRGB[2]);
    _defs.style.color = '';

    if ((fgColor == '#000000' && bgColor == '#ffffff') ||
        fgColor == bgColor) {
      return info.url;
    }

    final map = List<double>.generate(256, (i) {
      final x = i / 255;
      return x <= 0.03928
          ? x / 12.92
          : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
    });
    final table = map.join(',');

    final id = 'g_${_docId}_hcm_filter';
    final filter = _createFilter(id);
    info.filter = filter;
    _addTransferMapConversion(table, table, table, filter);
    _addGrayConversion(filter);

    String getSteps(int c, int n) {
      final start = fgRGB[c] / 255;
      final end = bgRGB[c] / 255;
      final arr =
          List<double>.generate(n + 1, (i) => start + (i / n) * (end - start));
      return arr.join(',');
    }

    _addTransferMapConversion(
        getSteps(0, 5), getSteps(1, 5), getSteps(2, 5), filter);

    info.url = _createUrl(id);
    return info.url;
  }

  @override
  String addAlphaFilter(dynamic map) {
    final mapList = map as List<int>;
    final tables = _createTables([mapList]);
    final tableA = tables[0];
    final key = 'alpha_$tableA';

    final existing = _cache[key];
    if (existing != null) return existing;

    final id = 'g_${_docId}_alpha_map_${_id++}';
    final url = _createUrl(id);
    _cache[key] = url;

    final filter = _createFilter(id);
    _addTransferMapAlphaConversion(tableA, filter);

    return url;
  }

  @override
  String addLuminosityFilter(dynamic map) {
    final cacheKey = map ?? 'luminosity';
    final existing = _cache[cacheKey];
    if (existing != null) return existing;

    String? tableA;
    String key;
    if (map != null) {
      final tables = _createTables([map as List<int>]);
      tableA = tables[0];
      key = 'luminosity_$tableA';
    } else {
      key = 'luminosity';
    }

    final existingKey = _cache[key];
    if (existingKey != null) {
      _cache[cacheKey] = existingKey;
      return existingKey;
    }

    final id = 'g_${_docId}_luminosity_map_${_id++}';
    final url = _createUrl(id);
    _cache[cacheKey] = url;
    _cache[key] = url;

    final filter = _createFilter(id);
    _addLuminosityConversion(filter);
    if (tableA != null) {
      _addTransferMapAlphaConversion(tableA, filter);
    }

    return url;
  }

  @override
  String addHighlightHCMFilter(
    String filterName,
    String? fgColor,
    String? bgColor,
    String? newFgColor,
    String? newBgColor,
  ) {
    final key = '$fgColor-$bgColor-$newFgColor-$newBgColor';
    var info = _hcmCache[filterName];
    if (info != null && info.key == key) {
      return info.url;
    }

    if (info != null) {
      info.filter?.remove();
      info.key = key;
      info.url = 'none';
      info.filter = null;
    } else {
      info = _HCMInfo(key: key, url: 'none');
      _hcmCache[filterName] = info;
    }

    if (fgColor == null || bgColor == null) {
      return info.url;
    }

    final fgRGBOrig = _getRGB(fgColor);
    final bgRGBOrig = _getRGB(bgColor);
    var fgGray = (0.2126 * fgRGBOrig[0] +
            0.7152 * fgRGBOrig[1] +
            0.0722 * fgRGBOrig[2])
        .round();
    var bgGray = (0.2126 * bgRGBOrig[0] +
            0.7152 * bgRGBOrig[1] +
            0.0722 * bgRGBOrig[2])
        .round();
    var newFgRGB = newFgColor != null ? _getRGB(newFgColor) : [0, 0, 0];
    var newBgRGB = newBgColor != null ? _getRGB(newBgColor) : [255, 255, 255];
    if (bgGray < fgGray) {
      final tmpGray = fgGray;
      fgGray = bgGray;
      bgGray = tmpGray;
      final tmpRGB = newFgRGB;
      newFgRGB = newBgRGB;
      newBgRGB = tmpRGB;
    }
    _defs.style.color = '';

    String getSteps(int fg, int bg, int n) {
      final arr = List<double>.filled(256, 0);
      final step = (bgGray - fgGray) / n;
      final newStart = fg / 255;
      final newStep = (bg - fg) / (255 * n);
      var prev = 0;
      for (var i = 0; i <= n; i++) {
        final k = (fgGray + i * step).round();
        final value = newStart + i * newStep;
        for (var j = prev; j <= k; j++) {
          arr[j] = value;
        }
        prev = k + 1;
      }
      for (var i = prev; i < 256; i++) {
        arr[i] = arr[prev - 1];
      }
      return arr.join(',');
    }

    final id = 'g_${_docId}_hcm_${filterName}_filter';
    final filter = _createFilter(id);
    info.filter = filter;

    _addGrayConversion(filter);
    _addTransferMapConversion(
      getSteps(newFgRGB[0], newBgRGB[0], 5),
      getSteps(newFgRGB[1], newBgRGB[1], 5),
      getSteps(newFgRGB[2], newBgRGB[2], 5),
      filter,
    );

    info.url = _createUrl(id);
    return info.url;
  }

  @override
  void destroy({bool keepHCM = false}) {
    if (keepHCM && (__hcmCache?.isNotEmpty ?? false)) {
      return;
    }
    final defsNode = __defs;
    if (defsNode != null) {
      defsNode.parentNode?.parentNode
          ?.removeChild(defsNode.parentNode!.parentNode!);
    }
    __defs = null;

    __cache?.clear();
    __cache = null;

    __hcmCache?.clear();
    __hcmCache = null;

    _id = 0;
  }

  void _addLuminosityConversion(web.Element filter) {
    final feColorMatrix =
        web.document.createElementNS(SVG_NS, 'feColorMatrix');
    feColorMatrix.setAttribute('type', 'matrix');
    feColorMatrix.setAttribute(
        'values', '0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.3 0.59 0.11 0 0');
    filter.append(feColorMatrix);
  }

  void _addGrayConversion(web.Element filter) {
    final feColorMatrix =
        web.document.createElementNS(SVG_NS, 'feColorMatrix');
    feColorMatrix.setAttribute('type', 'matrix');
    feColorMatrix.setAttribute('values',
        '0.2126 0.7152 0.0722 0 0 0.2126 0.7152 0.0722 0 0 0.2126 0.7152 0.0722 0 0 0 0 0 1 0');
    filter.append(feColorMatrix);
  }

  web.Element _createFilter(String id) {
    final filter = web.document.createElementNS(SVG_NS, 'filter');
    filter.setAttribute('color-interpolation-filters', 'sRGB');
    filter.setAttribute('id', id);
    _defs.append(filter);
    return filter;
  }

  void _appendFeFunc(
      web.Element feComponentTransfer, String func, String table) {
    final feFunc = web.document.createElementNS(SVG_NS, func);
    feFunc.setAttribute('type', 'discrete');
    feFunc.setAttribute('tableValues', table);
    feComponentTransfer.append(feFunc);
  }

  void _addTransferMapConversion(
      String rTable, String gTable, String bTable, web.Element filter) {
    final feComponentTransfer =
        web.document.createElementNS(SVG_NS, 'feComponentTransfer');
    filter.append(feComponentTransfer);
    _appendFeFunc(feComponentTransfer, 'feFuncR', rTable);
    _appendFeFunc(feComponentTransfer, 'feFuncG', gTable);
    _appendFeFunc(feComponentTransfer, 'feFuncB', bTable);
  }

  void _addTransferMapAlphaConversion(String aTable, web.Element filter) {
    final feComponentTransfer =
        web.document.createElementNS(SVG_NS, 'feComponentTransfer');
    filter.append(feComponentTransfer);
    _appendFeFunc(feComponentTransfer, 'feFuncA', aTable);
  }

  List<int> _getRGB(String color) {
    _defs.style.color = color;
    final computed =
        web.window.getComputedStyle(_defs).getPropertyValue('color');
    return getRGB(computed);
  }
}

class _HCMInfo {
  String key;
  String url;
  web.Element? filter;

  _HCMInfo({required this.key, required this.url});
}
