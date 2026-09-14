// Copyright 2021 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

class XFAFactory {
  final dynamic data;
  XFAFactory(this.data);

  bool isValid() => false;
  dynamic getPages() => null;
  int getNumPages() => 0;
  List<num>? getBoundingBox(int pageIndex) => null;
  void setImages(dynamic images) {}
  List<String>? setFonts(List<dynamic> fonts) => null;
  void appendFonts(List<dynamic> fonts, Set<String> reallyMissingFonts) {}
  dynamic serializeData(dynamic annotationStorage) => null;
}
