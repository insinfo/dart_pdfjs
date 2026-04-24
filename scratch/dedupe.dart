import 'dart:io';

void main() {
  var file = File('lib/src/core/glyphlist.dart');
  var lines = file.readAsLinesSync();
  var seen = <String>{};
  var newLines = <String>[];
  for (var line in lines) {
    var m = RegExp(r"^\s*'([^']+)'").firstMatch(line);
    if (m != null) {
      if (seen.contains(m.group(1))) continue;
      seen.add(m.group(1)!);
    }
    newLines.add(line);
  }
  file.writeAsStringSync(newLines.join('\n') + '\n');
}
