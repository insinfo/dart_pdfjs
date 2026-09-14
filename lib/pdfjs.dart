// Copyright 2026. Apache License 2.0.

/// Public browser API for loading and rendering PDF documents.
library;

export 'src/display/api.dart';
export 'src/display/annotation_storage.dart' show AnnotationStorage;
export 'src/display/display_utils.dart'
    show PageViewport, RenderingCancelledException;
export 'src/display/transport_stream.dart'
    show PDFDataRangeTransport, PDFDataTransportStream;
