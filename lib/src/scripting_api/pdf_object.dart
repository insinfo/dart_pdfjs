// Copyright 2020 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

/// Callback used by scripting objects to send a message to their host.
typedef ScriptingSend = void Function(Map<String, dynamic> message);

/// Common state shared by the objects exposed to PDF JavaScript.
class PDFObject {
  PDFObject([Map<String, dynamic> data = const {}])
      : send = data['send'] is ScriptingSend
            ? data['send'] as ScriptingSend
            : null,
        id = data['id'];

  /// User-defined properties attached through the scripting proxy.
  final Map<String, dynamic> expandos = <String, dynamic>{};

  final ScriptingSend? send;
  final Object? id;
}
