class PDFManager {
  final Map<String, dynamic> evaluatorOptions;
  final String docBaseUrl;

  PDFManager({
    this.evaluatorOptions = const {},
    this.docBaseUrl = '',
  });

  Future<dynamic> ensureCatalog(String prop) async {
    return null;
  }

  Future<dynamic> getPage(int pageIndex) async {
    return null;
  }
}
