import 'dart:io';

void main() {
  final jsFiles = [
    'calibri_factors.js',
    'helvetica_factors.js',
    'myriadpro_factors.js',
    'segoeui_factors.js',
    'liberationsans_widths.js',
  ];

  final refDir = Directory('referencia/pdf.js-master/src/core');
  final outDir = Directory('lib/src/core');

  for (final filename in jsFiles) {
    final jsFile = File('${refDir.path}/$filename');
    if (!jsFile.existsSync()) {
      print('File not found: ${jsFile.path}');
      continue;
    }
    final dartFilename = filename.replaceAll('.js', '.dart');
    final outFile = File('${outDir.path}/$dartFilename');
    print('Converting $filename to $dartFilename...');

    final content = jsFile.readAsStringSync();
    // Converter const X = [...] para const List<double> ou const List<int> ou const Map etc.
    // Também converter metrics = { lineHeight: 1.2, lineGap: 0.2 } para Map ou class.
    // Vamos fazer um parser regex / estruturado.
    final dartCode = convertJsToDart(filename, content);
    outFile.writeAsStringSync(dartCode);
    print('Wrote ${outFile.lengthSync()} bytes to ${outFile.path}');
  }
}

String convertJsToDart(String filename, String content) {
  final buffer = StringBuffer();
  buffer.writeln('// Converted from pdf.js $filename\n');
  
  if (filename.contains('factors')) {
    buffer.writeln("import 'font_metrics.dart';\n");
  }


  // Remove licensing header if desired, or keep notice
  // Find all `const <Name> = <Value>;`
  final regExp = RegExp(r'const\s+([A-Za-z0-9_]+)\s*=\s*([^;]+);', multiLine: true);
  final matches = regExp.allMatches(content);

  for (final m in matches) {
    final name = m.group(1)!;
    var value = m.group(2)!.trim();

    if (name.endsWith('Metrics')) {
      // { lineHeight: 1.2207, lineGap: 0.2207 }
      final lhMatch = RegExp(r'lineHeight:\s*([0-9.]+)').firstMatch(value);
      final lgMatch = RegExp(r'lineGap:\s*([0-9.]+)').firstMatch(value);
      if (lhMatch != null && lgMatch != null) {
        final lh = lhMatch.group(1);
        final lg = lgMatch.group(1);
        buffer.writeln('const FontMetrics $name = FontMetrics(lineHeight: $lh, lineGap: $lg);\n');
      }
    } else if (name.endsWith('Factors')) {
      // List<double>
      // Ensure double literals if integers or floats
      buffer.writeln('const List<double> $name = $value;\n');
    } else if (name.endsWith('Widths')) {
      // List<int> or List<num>
      buffer.writeln('const List<int> $name = $value;\n');
    } else if (name.endsWith('Mapping')) {
      // List<int>
      buffer.writeln('const List<int> $name = $value;\n');
    } else {
      buffer.writeln('const $name = $value;\n');
    }
  }

  return buffer.toString();
}
