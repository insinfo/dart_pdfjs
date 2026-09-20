import 'pdf_history.dart';

/// Default-environment fallback for non-web compilation targets.
PDFHistoryEnvironment createPDFHistoryEnvironment() =>
    throw UnsupportedError('PDFHistory requires a browser environment.');
