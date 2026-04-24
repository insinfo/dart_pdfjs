import 'package:pdfjs/src/shared/util.dart';

const bool SEAC_ANALYSIS_ENABLED = false;

// Stub for now. Will be fully implemented when porting fonts_utils.js
Map<int, int> type1FontGlyphMapping(dynamic properties, dynamic builtInEncoding, List<String> glyphNames) {
  final charCodeToGlyphId = <int, int>{};
  
  // Implementation will go here later
  warn("type1FontGlyphMapping not fully implemented yet");
  
  return charCodeToGlyphId;
}
