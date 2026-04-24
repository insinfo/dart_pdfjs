// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import '../shared/util.dart';
import 'base_stream.dart';
import 'binary_cmap.dart';
import 'core_utils.dart';
import 'parser.dart';
import 'primitives.dart';
import 'stream.dart' as pdf_stream;

const List<String> builtInCmaps = [
  // << Start unicode maps.
  "Adobe-GB1-UCS2", "Adobe-CNS1-UCS2", "Adobe-Japan1-UCS2", "Adobe-Korea1-UCS2",
  // >> End unicode maps.
  "78-EUC-H", "78-EUC-V", "78-H", "78-RKSJ-H", "78-RKSJ-V", "78-V", "78ms-RKSJ-H",
  "78ms-RKSJ-V", "83pv-RKSJ-H", "90ms-RKSJ-H", "90ms-RKSJ-V", "90msp-RKSJ-H",
  "90msp-RKSJ-V", "90pv-RKSJ-H", "90pv-RKSJ-V", "Add-H", "Add-RKSJ-H",
  "Add-RKSJ-V", "Add-V", "Adobe-CNS1-0", "Adobe-CNS1-1", "Adobe-CNS1-2",
  "Adobe-CNS1-3", "Adobe-CNS1-4", "Adobe-CNS1-5", "Adobe-CNS1-6", "Adobe-GB1-0",
  "Adobe-GB1-1", "Adobe-GB1-2", "Adobe-GB1-3", "Adobe-GB1-4", "Adobe-GB1-5",
  "Adobe-Japan1-0", "Adobe-Japan1-1", "Adobe-Japan1-2", "Adobe-Japan1-3",
  "Adobe-Japan1-4", "Adobe-Japan1-5", "Adobe-Japan1-6", "Adobe-Korea1-0",
  "Adobe-Korea1-1", "Adobe-Korea1-2", "B5-H", "B5-V", "B5pc-H", "B5pc-V",
  "CNS-EUC-H", "CNS-EUC-V", "CNS1-H", "CNS1-V", "CNS2-H", "CNS2-V", "ETHK-B5-H",
  "ETHK-B5-V", "ETen-B5-H", "ETen-B5-V", "ETenms-B5-H", "ETenms-B5-V", "EUC-H",
  "EUC-V", "Ext-H", "Ext-RKSJ-H", "Ext-RKSJ-V", "Ext-V", "GB-EUC-H", "GB-EUC-V",
  "GB-H", "GB-V", "GBK-EUC-H", "GBK-EUC-V", "GBK2K-H", "GBK2K-V", "GBKp-EUC-H",
  "GBKp-EUC-V", "GBT-EUC-H", "GBT-EUC-V", "GBT-H", "GBT-V", "GBTpc-EUC-H",
  "GBTpc-EUC-V", "GBpc-EUC-H", "GBpc-EUC-V", "H", "HKdla-B5-H", "HKdla-B5-V",
  "HKdlb-B5-H", "HKdlb-B5-V", "HKgccs-B5-H", "HKgccs-B5-V", "HKm314-B5-H",
  "HKm314-B5-V", "HKm471-B5-H", "HKm471-B5-V", "HKscs-B5-H", "HKscs-B5-V",
  "Hankaku", "Hiragana", "KSC-EUC-H", "KSC-EUC-V", "KSC-H", "KSC-Johab-H",
  "KSC-Johab-V", "KSC-V", "KSCms-UHC-H", "KSCms-UHC-HW-H", "KSCms-UHC-HW-V",
  "KSCms-UHC-V", "KSCpc-EUC-H", "KSCpc-EUC-V", "Katakana", "NWP-H", "NWP-V",
  "RKSJ-H", "RKSJ-V", "Roman", "UniCNS-UCS2-H", "UniCNS-UCS2-V", "UniCNS-UTF16-H",
  "UniCNS-UTF16-V", "UniCNS-UTF32-H", "UniCNS-UTF32-V", "UniCNS-UTF8-H",
  "UniCNS-UTF8-V", "UniGB-UCS2-H", "UniGB-UCS2-V", "UniGB-UTF16-H", "UniGB-UTF16-V",
  "UniGB-UTF32-H", "UniGB-UTF32-V", "UniGB-UTF8-H", "UniGB-UTF8-V", "UniJIS-UCS2-H",
  "UniJIS-UCS2-HW-H", "UniJIS-UCS2-HW-V", "UniJIS-UCS2-V", "UniJIS-UTF16-H",
  "UniJIS-UTF16-V", "UniJIS-UTF32-H", "UniJIS-UTF32-V", "UniJIS-UTF8-H",
  "UniJIS-UTF8-V", "UniJIS2004-UTF16-H", "UniJIS2004-UTF16-V", "UniJIS2004-UTF32-H",
  "UniJIS2004-UTF32-V", "UniJIS2004-UTF8-H", "UniJIS2004-UTF8-V",
  "UniJISPro-UCS2-HW-V", "UniJISPro-UCS2-V", "UniJISPro-UTF8-V",
  "UniJISX0213-UTF32-H", "UniJISX0213-UTF32-V", "UniJISX02132004-UTF32-H",
  "UniJISX02132004-UTF32-V", "UniKS-UCS2-H", "UniKS-UCS2-V", "UniKS-UTF16-H",
  "UniKS-UTF16-V", "UniKS-UTF32-H", "UniKS-UTF32-V", "UniKS-UTF8-H",
  "UniKS-UTF8-V", "V", "WP-Symbol"
];

// Heuristic to avoid hanging the worker-thread for CMap data with ridiculously
// large ranges, such as e.g. 0xFFFFFFFF (fixes issue11922_reduced.pdf).
const int _maxMapRange = (1 << 24) - 1; // 0xFFFFFF

class CharCodeOut {
  int charcode = 0;
  int length = 1;
}

class CMap {
  final List<List<int>> codespaceRanges;
  int numCodespaceRanges = 0;
  final Map<int, dynamic> _map = {}; // can contain int or String
  String name = "";
  bool vertical = false;
  CMap? useCMap;
  final bool builtInCMap;

  CMap({this.builtInCMap = false})
      : codespaceRanges = [<int>[], <int>[], <int>[], <int>[]];

  void addCodespaceRange(int n, int low, int high) {
    codespaceRanges[n - 1].addAll([low, high]);
    numCodespaceRanges++;
  }

  void mapCidRange(int low, int high, int dstLow) {
    if (high - low > _maxMapRange) {
      throw Exception("mapCidRange - ignoring data above MAX_MAP_RANGE.");
    }
    while (low <= high) {
      _map[low++] = dstLow++;
    }
  }

  void mapBfRange(int low, int high, String dstLow) {
    if (high - low > _maxMapRange) {
      throw Exception("mapBfRange - ignoring data above MAX_MAP_RANGE.");
    }
    final lastByte = dstLow.length - 1;
    while (low <= high) {
      _map[low++] = dstLow;
      final nextCharCode = dstLow.codeUnitAt(lastByte) + 1;
      if (nextCharCode > 0xff) {
        dstLow = dstLow.substring(0, lastByte - 1) +
            String.fromCharCode(dstLow.codeUnitAt(lastByte - 1) + 1) +
            "\x00";
        continue;
      }
      dstLow = dstLow.substring(0, lastByte) + String.fromCharCode(nextCharCode);
    }
  }

  void mapBfRangeToArray(int low, int high, List<dynamic> array) {
    if (high - low > _maxMapRange) {
      throw Exception("mapBfRangeToArray - ignoring data above MAX_MAP_RANGE.");
    }
    final ii = array.length;
    int i = 0;
    while (low <= high && i < ii) {
      _map[low] = array[i++];
      ++low;
    }
  }

  void mapOne(int src, dynamic dst) {
    _map[src] = dst;
  }

  dynamic lookup(int code) {
    return _map[code];
  }

  bool contains(int code) {
    return _map.containsKey(code);
  }

  void forEach(void Function(int key, dynamic value) callback) {
    _map.forEach(callback);
  }

  int charCodeOf(dynamic value) {
    for (final entry in _map.entries) {
      if (entry.value == value) {
        return entry.key;
      }
    }
    return -1;
  }

  Map<int, dynamic> getMap() {
    return _map;
  }

  void readCharCode(String str, int offset, CharCodeOut out) {
    int c = 0;
    for (int n = 0, nn = codespaceRanges.length; n < nn; n++) {
      if (offset + n >= str.length) break;
      c = ((c << 8) | str.codeUnitAt(offset + n)) & 0xFFFFFFFF;
      final codespaceRange = codespaceRanges[n];
      for (int k = 0, kk = codespaceRange.length; k < kk;) {
        final low = codespaceRange[k++];
        final high = codespaceRange[k++];
        if (c >= low && c <= high) {
          out.charcode = c;
          out.length = n + 1;
          return;
        }
      }
    }
    out.charcode = 0;
    out.length = 1;
  }

  int getCharCodeLength(int charCode) {
    for (int n = 0, nn = codespaceRanges.length; n < nn; n++) {
      final codespaceRange = codespaceRanges[n];
      for (int k = 0, kk = codespaceRange.length; k < kk;) {
        final low = codespaceRange[k++];
        final high = codespaceRange[k++];
        if (charCode >= low && charCode <= high) {
          return n + 1;
        }
      }
    }
    return 1;
  }

  int get length => _map.length;

  bool get isIdentityCMap {
    if (name != "Identity-H" && name != "Identity-V") {
      return false;
    }
    if (_map.length != 0x10000) {
      return false;
    }
    for (int i = 0; i < 0x10000; i++) {
      if (_map[i] != i) {
        return false;
      }
    }
    return true;
  }
}

class IdentityCMap extends CMap {
  IdentityCMap(bool vertical, int n) : super() {
    this.vertical = vertical;
    addCodespaceRange(n, 0, 0xffff);
  }

  @override
  void mapCidRange(int low, int high, int dstLow) {
    unreachable("should not call mapCidRange");
  }

  @override
  void mapBfRange(int low, int high, String dstLow) {
    unreachable("should not call mapBfRange");
  }

  @override
  void mapBfRangeToArray(int low, int high, List<dynamic> array) {
    unreachable("should not call mapBfRangeToArray");
  }

  @override
  void mapOne(int src, dynamic dst) {
    unreachable("should not call mapCidOne");
  }

  @override
  dynamic lookup(int code) {
    return code <= 0xffff ? code : null;
  }

  @override
  bool contains(int code) {
    return code <= 0xffff;
  }

  @override
  void forEach(void Function(int key, dynamic value) callback) {
    for (int i = 0; i <= 0xffff; i++) {
      callback(i, i);
    }
  }

  @override
  int charCodeOf(dynamic value) {
    if (value is int && value <= 0xffff) return value;
    return -1;
  }

  @override
  Map<int, dynamic> getMap() {
    final map = <int, dynamic>{};
    for (int i = 0; i <= 0xffff; i++) {
      map[i] = i;
    }
    return map;
  }

  @override
  int get length => 0x10000;

  @override
  bool get isIdentityCMap {
    unreachable("should not access .isIdentityCMap");
  }
}

int _strToInt(String str) {
  int a = 0;
  for (int i = 0; i < str.length; i++) {
    a = (a << 8) | str.codeUnitAt(i);
  }
  return a & 0xFFFFFFFF;
}

void _expectString(dynamic obj) {
  if (obj is! String) {
    throw FormatException("Malformed CMap: expected string.");
  }
}

void _expectInt(dynamic obj) {
  if (obj is! int) {
    throw FormatException("Malformed CMap: expected int.");
  }
}

void _parseBfChar(CMap cMap, Lexer lexer) {
  while (true) {
    dynamic obj = lexer.getObj();
    if (obj == eof) break;
    if (isCmd(obj, "endbfchar")) return;
    _expectString(obj);
    final src = _strToInt(obj as String);
    obj = lexer.getObj();
    _expectString(obj);
    final dst = obj;
    cMap.mapOne(src, dst);
  }
}

void _parseBfRange(CMap cMap, Lexer lexer) {
  while (true) {
    dynamic obj = lexer.getObj();
    if (obj == eof) break;
    if (isCmd(obj, "endbfrange")) return;
    _expectString(obj);
    final low = _strToInt(obj as String);
    obj = lexer.getObj();
    _expectString(obj);
    final high = _strToInt(obj as String);
    obj = lexer.getObj();
    
    if (obj is int || obj is String) {
      final String dstLow = obj is int ? String.fromCharCode(obj) : obj as String;
      cMap.mapBfRange(low, high, dstLow);
    } else if (isCmd(obj, "[")) {
      obj = lexer.getObj();
      final array = <dynamic>[];
      while (!isCmd(obj, "]") && obj != eof) {
        array.add(obj);
        obj = lexer.getObj();
      }
      cMap.mapBfRangeToArray(low, high, array);
    } else {
      break;
    }
  }
  throw FormatException("Invalid bf range.");
}

void _parseCidChar(CMap cMap, Lexer lexer) {
  while (true) {
    dynamic obj = lexer.getObj();
    if (obj == eof) break;
    if (isCmd(obj, "endcidchar")) return;
    _expectString(obj);
    final src = _strToInt(obj as String);
    obj = lexer.getObj();
    _expectInt(obj);
    final dst = obj as int;
    cMap.mapOne(src, dst);
  }
}

void _parseCidRange(CMap cMap, Lexer lexer) {
  while (true) {
    dynamic obj = lexer.getObj();
    if (obj == eof) break;
    if (isCmd(obj, "endcidrange")) return;
    _expectString(obj);
    final low = _strToInt(obj as String);
    obj = lexer.getObj();
    _expectString(obj);
    final high = _strToInt(obj as String);
    obj = lexer.getObj();
    _expectInt(obj);
    final dstLow = obj as int;
    cMap.mapCidRange(low, high, dstLow);
  }
}

void _parseCodespaceRange(CMap cMap, Lexer lexer) {
  while (true) {
    dynamic obj = lexer.getObj();
    if (obj == eof) break;
    if (isCmd(obj, "endcodespacerange")) return;
    if (obj is! String) break;
    final low = _strToInt(obj);
    obj = lexer.getObj();
    if (obj is! String) break;
    final high = _strToInt(obj);
    cMap.addCodespaceRange(obj.length, low, high);
  }
  throw FormatException("Invalid codespace range.");
}

void _parseWMode(CMap cMap, Lexer lexer) {
  final obj = lexer.getObj();
  if (obj is int) {
    cMap.vertical = obj != 0;
  }
}

void _parseCMapName(CMap cMap, Lexer lexer) {
  final obj = lexer.getObj();
  if (obj is Name) {
    cMap.name = obj.name;
  }
}

Future<CMap> _parseCMap(CMap cMap, Lexer lexer, Future<Map<String, dynamic>> Function(String) fetchBuiltInCMap, String? useCMap) async {
  dynamic previous;
  String? embeddedUseCMap;
  
  objLoop:
  while (true) {
    try {
      final obj = lexer.getObj();
      if (obj == eof) break;
      if (obj is Name) {
        if (obj.name == "WMode") {
          _parseWMode(cMap, lexer);
        } else if (obj.name == "CMapName") {
          _parseCMapName(cMap, lexer);
        }
        previous = obj;
      } else if (obj is Cmd) {
        switch (obj.cmd) {
          case "endcmap":
            break objLoop;
          case "usecmap":
            if (previous is Name) {
              embeddedUseCMap = previous.name;
            }
            break;
          case "begincodespacerange":
            _parseCodespaceRange(cMap, lexer);
            break;
          case "beginbfchar":
            _parseBfChar(cMap, lexer);
            break;
          case "begincidchar":
            _parseCidChar(cMap, lexer);
            break;
          case "beginbfrange":
            _parseBfRange(cMap, lexer);
            break;
          case "begincidrange":
            _parseCidRange(cMap, lexer);
            break;
        }
      }
    } catch (ex) {
      if (ex is MissingDataException) {
        rethrow;
      }
      print("Warning: Invalid cMap data: \$ex");
      continue;
    }
  }

  if (useCMap == null && embeddedUseCMap != null) {
    useCMap = embeddedUseCMap;
  }
  if (useCMap != null) {
    return _extendCMap(cMap, fetchBuiltInCMap, useCMap);
  }
  return cMap;
}

Future<CMap> _extendCMap(CMap cMap, Future<Map<String, dynamic>> Function(String) fetchBuiltInCMap, String useCMapName) async {
  cMap.useCMap = await _createBuiltInCMap(useCMapName, fetchBuiltInCMap);
  if (cMap.numCodespaceRanges == 0) {
    final useCodespaceRanges = cMap.useCMap!.codespaceRanges;
    for (int i = 0; i < useCodespaceRanges.length; i++) {
      cMap.codespaceRanges[i] = List<int>.from(useCodespaceRanges[i]);
    }
    cMap.numCodespaceRanges = cMap.useCMap!.numCodespaceRanges;
  }
  cMap.useCMap!.forEach((key, value) {
    if (!cMap.contains(key)) {
      cMap.mapOne(key, value);
    }
  });
  return cMap;
}

Future<CMap> _createBuiltInCMap(String name, Future<Map<String, dynamic>> Function(String)? fetchBuiltInCMap) async {
  if (name == "Identity-H") {
    return IdentityCMap(false, 2);
  } else if (name == "Identity-V") {
    return IdentityCMap(true, 2);
  }
  if (!builtInCmaps.contains(name)) {
    throw Exception("Unknown CMap name: \$name");
  }
  if (fetchBuiltInCMap == null) {
    throw Exception("Built-in CMap parameters are not provided.");
  }

  final cmapInfo = await fetchBuiltInCMap(name);
  final cMapData = cmapInfo['cMapData'];
  final bool isCompressed = cmapInfo['isCompressed'] == true;
  
  final cMap = CMap(builtInCMap: true);

  if (isCompressed) {
    return await BinaryCMapReader().process(
      cMapData,
      cMap,
      (String useCMapName) => _extendCMap(cMap, fetchBuiltInCMap, useCMapName)
    );
  }
  final lexer = Lexer(pdf_stream.Stream(cMapData));
  return _parseCMap(cMap, lexer, fetchBuiltInCMap, null);
}

class CMapFactory {
  static Future<CMap> create({
    required dynamic encoding, 
    required Future<Map<String, dynamic>> Function(String) fetchBuiltInCMap, 
    String? useCMap
  }) async {
    if (encoding is Name) {
      return _createBuiltInCMap(encoding.name, fetchBuiltInCMap);
    } else if (encoding is BaseStream) {
      // isAsync in dart translates differently, typically BaseStream has its own async loading
      if (encoding.isAsync) {
         throw UnimplementedError('encoding.isAsync not supported yet');
      }
      final parsedCMap = await _parseCMap(
        CMap(),
        Lexer(encoding),
        fetchBuiltInCMap,
        useCMap
      );

      if (parsedCMap.isIdentityCMap) {
        return _createBuiltInCMap(parsedCMap.name, fetchBuiltInCMap);
      }
      return parsedCMap;
    }
    throw Exception("Encoding required.");
  }
}
