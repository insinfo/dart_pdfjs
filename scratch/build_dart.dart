import 'dart:convert';
import 'dart:io';

void convertStandardFonts() {
  final jsonStr = File('scratch/standard_fonts.json').readAsStringSync();
  final data = jsonDecode(jsonStr);
  
  final out = StringBuffer();
  out.writeln('// Copyright 2015 Mozilla Foundation');
  out.writeln('// Ported to Dart, 2026. Apache License 2.0.');
  out.writeln();
  out.writeln('// Preserve formatting');
  out.writeln('// dart format width=5000');
  out.writeln();
  
  void writeMapStringString(String name, Map map) {
    out.writeln('const Map<String, String> $name = {');
    map.forEach((k, v) {
      out.writeln('  \'$k\': \'$v\',');
    });
    out.writeln('};');
    out.writeln();
  }

  void writeMapStringBool(String name, Map map) {
    out.writeln('const Map<String, bool> $name = {');
    map.forEach((k, v) {
      out.writeln('  \'$k\': $v,');
    });
    out.writeln('};');
    out.writeln();
  }

  void writeMapIntInt(String name, Map map) {
    out.writeln('const Map<int, int> $name = {');
    map.forEach((k, v) {
      out.writeln('  $k: $v,');
    });
    out.writeln('};');
    out.writeln();
  }

  writeMapStringString('_stdFontMap', data['getStdFontMap']);
  writeMapStringString('_fontNameToFileMap', data['getFontNameToFileMap']);
  writeMapStringString('_nonStdFontMap', data['getNonStdFontMap']);
  writeMapStringBool('_serifFonts', data['getSerifFonts']);
  writeMapStringBool('_symbolsFonts', data['getSymbolsFonts']);
  writeMapIntInt('_glyphMapForStandardFonts', data['getGlyphMapForStandardFonts']);
  
  out.writeln('Map<String, String> getStdFontMap() => _stdFontMap;');
  out.writeln('Map<String, String> getFontNameToFileMap() => _fontNameToFileMap;');
  out.writeln('Map<String, String> getNonStdFontMap() => _nonStdFontMap;');
  out.writeln('Map<String, bool> getSerifFonts() => _serifFonts;');
  out.writeln('Map<String, bool> getSymbolsFonts() => _symbolsFonts;');
  out.writeln('Map<int, int> getGlyphMapForStandardFonts() => _glyphMapForStandardFonts;');

  File('lib/src/core/standard_fonts.dart').writeAsStringSync(out.toString());
}

void convertMetrics() {
  final jsonStr = File('scratch/metrics.json').readAsStringSync();
  final data = jsonDecode(jsonStr);
  final metrics = data['getMetrics'] as Map;
  
  final out = StringBuffer();
  out.writeln('// Copyright 2012 Mozilla Foundation');
  out.writeln('// Ported to Dart, 2026. Apache License 2.0.');
  out.writeln();
  out.writeln('// Preserve formatting');
  out.writeln('// dart format width=5000');
  out.writeln();
  out.writeln('const Map<String, dynamic> _metrics = {');
  metrics.forEach((k, v) {
    if (v is int) {
      out.writeln('  \'$k\': $v,');
    } else if (v is Map) {
      out.writeln('  \'$k\': <String, int>{');
      v.forEach((vk, vv) {
        out.writeln('    \'$vk\': $vv,');
      });
      out.writeln('  },');
    }
  });
  out.writeln('};');
  out.writeln();
  out.writeln('Map<String, dynamic> getMetrics() => _metrics;');
  
  File('lib/src/core/metrics.dart').writeAsStringSync(out.toString());
}

void main() {
  convertStandardFonts();
  convertMetrics();
  print('Convertido para dart!');
}
