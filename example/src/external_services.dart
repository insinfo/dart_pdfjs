// Copyright 2024 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'l10n.dart';

/// Host integration points used by the generic PDF viewer.
///
/// Embedders override only the services they support. Notification hooks are
/// no-ops by default, while factories throw to expose missing capabilities.
abstract class BaseExternalServices {
  void updateFindControlState(Map<String, dynamic> data) {}

  void updateFindMatchesCount(Map<String, dynamic> data) {}

  void initPassiveLoading() {}

  void reportTelemetry(Map<String, dynamic> data) {}

  void reportText({required String text, required int requestId}) {}

  Future<L10n> createL10n() {
    throw UnsupportedError('Not implemented: createL10n');
  }

  Object createScripting() {
    throw UnsupportedError('Not implemented: createScripting');
  }

  Object createSignatureStorage() {
    throw UnsupportedError('Not implemented: createSignatureStorage');
  }

  void updateEditorStates(Map<String, dynamic> data) {
    throw UnsupportedError('Not implemented: updateEditorStates');
  }

  void dispatchGlobalEvent(Map<String, dynamic> event) {}
}
