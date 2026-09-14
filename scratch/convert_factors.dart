import 'dart:io';

void main() {
  final factorFiles = [
    'calibri_factors',
    'helvetica_factors',
    'myriadpro_factors',
    'segoeui_factors',
  ];

  for (final name in factorFiles) {
    final jsPath = 'referencia/pdf.js-master/src/core/$name.js';
    final dartPath = 'lib/src/core/$name.dart';
    var content = File(jsPath).readAsStringSync();

    // Replace js export with empty
    content = content.replaceAll(RegExp(r'export\s*\{[^}]*\};?', multiLine: true), '');

    // Replace metrics objects: const FooMetrics = { lineHeight: 1.2207, lineGap: 0.2207 };
    content = content.replaceAllMapped(
      RegExp(r'const\s+(\w+Metrics)\s*=\s*\{\s*lineHeight:\s*([\d.]+),\s*lineGap:\s*([\d.]+)\s*\};'),
      (m) => 'const Map<String, double> ${m[1]} = {\'lineHeight\': ${m[2]}, \'lineGap\': ${m[3]}};\n',
    );

    // Replace factor arrays: const FooFactors = [ ... ]; -> const List<double> FooFactors = [ ... ];
    content = content.replaceAllMapped(
      RegExp(r'const\s+(\w+Factors)\s*=\s*\['),
      (m) => 'const List<double> ${m[1]} = [',
    );

    // Ensure all numbers in factors array are doubles (e.g., 1 -> 1.0)
    // Actually in Dart, int literals in double contexts in const List<double> are automatically treated as double in Dart 2.1+!
    
    File(dartPath).writeAsStringSync(content);
    print('Converted $dartPath');
  }

  // Convert liberationsans_widths.js
  {
    final jsPath = 'referencia/pdf.js-master/src/core/liberationsans_widths.js';
    final dartPath = 'lib/src/core/liberationsans_widths.dart';
    var content = File(jsPath).readAsStringSync();

    content = content.replaceAll(RegExp(r'export\s*\{[^}]*\};?', multiLine: true), '');

    content = content.replaceAllMapped(
      RegExp(r'const\s+(\w+Widths)\s*=\s*\['),
      (m) => 'const List<int> ${m[1]} = [',
    );

    content = content.replaceAllMapped(
      RegExp(r'const\s+(\w+Mapping)\s*=\s*\['),
      (m) => 'const List<int> ${m[1]} = [',
    );

    File(dartPath).writeAsStringSync(content);
    print('Converted $dartPath');
  }

  print('All factors and widths converted successfully!');
}
