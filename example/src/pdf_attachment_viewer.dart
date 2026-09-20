// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'base_tree_viewer.dart';
import 'event_utils.dart';

/// Renders document-level and FileAttachment annotation attachments.
class PDFAttachmentViewer extends BaseTreeViewer {
  PDFAttachmentViewer({
    required super.container,
    required super.eventBus,
    required super.l10n,
    required this.downloadManager,
    this.emptyDispatchDelay = const Duration(seconds: 1),
  }) {
    _renderedCompleter = Completer<void>();
    eventBus.internalOn('fileattachmentannotation', _appendAttachment);
  }

  final ViewerDownloadManager downloadManager;

  /// Injectable to keep tests fast; production retains upstream's one second.
  final Duration emptyDispatchDelay;

  Map<String, Map<String, dynamic>>? _attachments;
  late Completer<void> _renderedCompleter;
  bool _pendingDispatchEvent = false;

  @override
  void reset({bool keepRenderedCapability = false}) {
    super.reset();
    _attachments = null;
    if (!keepRenderedCapability) _renderedCompleter = Completer<void>();
    _pendingDispatchEvent = false;
  }

  @override
  void dispatchLoadedEvent(int count) {
    unawaited(_dispatchAttachmentEvent(count));
  }

  Future<void> _dispatchAttachmentEvent(int count) async {
    if (!_renderedCompleter.isCompleted) _renderedCompleter.complete();
    if (count == 0 && !_pendingDispatchEvent) {
      _pendingDispatchEvent = true;
      await waitOnEventOrTimeout(
        target: eventBus,
        name: 'annotationlayerrendered',
        delay: emptyDispatchDelay,
      );
      if (!_pendingDispatchEvent) return;
    }
    _pendingDispatchEvent = false;
    eventBus.dispatch('attachmentsloaded', <String, Object?>{
      'source': this,
      'attachmentsCount': count,
    });
  }

  @override
  void bindLink(web.HTMLAnchorElement element, Map<String, dynamic> item) {
    final description = item['description'];
    if (description != null && description.toString().isNotEmpty) {
      element.title = description.toString();
    }
    element.onclick = ((web.MouseEvent event) {
      event.preventDefault();
      downloadManager.openOrDownloadData(
        item['content'],
        item['filename']?.toString() ?? '',
      );
    }).toJS;
  }

  void render({
    required Map<String, dynamic>? attachments,
    bool keepRenderedCapability = false,
  }) {
    if (_attachments != null) {
      reset(keepRenderedCapability: keepRenderedCapability);
    }
    _attachments = attachments?.map(
      (name, value) => MapEntry(
        name,
        value is Map
            ? Map<String, dynamic>.from(value)
            : <String, dynamic>{'filename': name, 'content': value},
      ),
    );
    if (_attachments == null || _attachments!.isEmpty) {
      dispatchLoadedEvent(0);
      return;
    }

    final fragment = web.document.createDocumentFragment();
    final list = web.document.createElement('ul') as web.HTMLUListElement;
    fragment.append(list);
    var count = 0;
    for (final item in _attachments!.values) {
      final listItem = web.document.createElement('li') as web.HTMLLIElement;
      list.append(listItem);
      final link = web.document.createElement('a') as web.HTMLAnchorElement;
      listItem.append(link);
      bindLink(link, item);
      link.textContent = normalizeTextContent(item['filename']);
      count++;
    }
    finishRendering(fragment, count);
  }

  void _appendAttachment(Object? event) {
    final item = _attachmentFromEvent(event);
    if (item == null) return;
    final renderedFuture = _renderedCompleter.future;
    unawaited(renderedFuture.then((_) {
      if (!identical(renderedFuture, _renderedCompleter.future)) return;
      final attachments = Map<String, Map<String, dynamic>>.from(
        _attachments ?? const <String, Map<String, dynamic>>{},
      );
      final filename = item['filename']?.toString() ?? '';
      if (attachments.containsKey(filename) ||
          attachments.values.any(
            (attachment) => attachment['filename']?.toString() == filename,
          )) {
        return;
      }
      attachments[filename] = item;
      render(
        attachments: attachments.cast<String, dynamic>(),
        keepRenderedCapability: true,
      );
    }));
  }
}

Map<String, dynamic>? _attachmentFromEvent(Object? event) {
  if (event is! Map) return null;
  final map = Map<String, dynamic>.from(event);
  final nested = map['attachment'];
  if (nested is Map) return Map<String, dynamic>.from(nested);
  return map.containsKey('filename') ? map : null;
}
