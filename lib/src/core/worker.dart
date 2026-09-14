// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';

import '../core/pdf_manager.dart';

/// A task running in the worker context.
class WorkerTask {
  final String name;
  bool terminated = false;
  final Completer<void> _completer = Completer<void>();

  WorkerTask(this.name);

  Future<void> get finished => _completer.future;

  void finish() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  void terminate() {
    terminated = true;
  }

  void ensureNotTerminated() {
    if (terminated) {
      throw StateError('Worker task was terminated');
    }
  }
}

/// Handler for worker messages and PDF document operations.
class WorkerMessageHandler {
  /// Create a PDF document handler for the given parameters.
  static Future<Map<String, dynamic>> createDocumentHandler(
      Map<String, dynamic> docParams) async {
    final workTasks = <WorkerTask>{};

    void startWorkerTask(WorkerTask task) {
      workTasks.add(task);
    }

    void finishWorkerTask(WorkerTask task) {
      task.finish();
      workTasks.remove(task);
    }

    Future<Map<String, dynamic>> loadDocument(
        dynamic pdfManager, bool recoveryMode) async {
      await pdfManager.ensureDoc('checkHeader');
      await pdfManager.ensureDoc('parseStartXRef');
      await pdfManager.ensureDoc('parse', [recoveryMode]);
      await pdfManager.ensureDoc('checkFirstPage', [recoveryMode]);
      await pdfManager.ensureDoc('checkLastPage', [recoveryMode]);

      final isPureXfa = await pdfManager.ensureDoc('isPureXfa');
      if (isPureXfa == true) {
        final task = WorkerTask('loadXfaResources');
        startWorkerTask(task);
        await pdfManager.ensureDoc('loadXfaResources', [null, task]);
        finishWorkerTask(task);
      }

      final numPages = await pdfManager.ensureDoc('numPages');
      final fingerprints = await pdfManager.ensureDoc('fingerprints');

      final htmlForXfa = isPureXfa == true
          ? await pdfManager.ensureDoc('htmlForXfa')
          : null;

      return {
        'numPages': numPages,
        'fingerprints': fingerprints,
        'htmlForXfa': htmlForXfa,
      };
    }

    return {
      'loadDocument': loadDocument,
      'startWorkerTask': startWorkerTask,
      'finishWorkerTask': finishWorkerTask,
    };
  }

  /// Get PDF manager from document parameters.
  static Future<dynamic> getPdfManager(Map<String, dynamic> data) async {
    final source = data['source'] as Map<String, dynamic>?;
    if (source == null) {
      throw ArgumentError('No source provided');
    }

    final pdfData = source['data'];
    if (pdfData != null) {
      return LocalPdfManager(
        source: pdfData,
        docId: source['docId'] as String?,
        password: source['password'] as String?,
        evaluatorOptions:
            source['evaluatorOptions'] as Map<String, dynamic>? ?? const {},
      );
    }

    // Network PDF manager for URL-based loading
    return NetworkPdfManager(
      source: source['url'],
      length: source['length'] as int? ?? 0,
      rangeChunkSize: source['rangeChunkSize'] as int? ?? 65536,
      docId: source['docId'] as String?,
      password: source['password'] as String?,
      evaluatorOptions:
          source['evaluatorOptions'] as Map<String, dynamic>? ?? const {},
    );
  }
}
