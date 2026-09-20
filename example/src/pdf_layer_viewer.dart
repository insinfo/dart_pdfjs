// Copyright 2020 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:async';
import 'dart:js_interop';

import 'package:pdfjs/src/display/optional_content_config.dart';
import 'package:web/web.dart' as web;

import 'base_tree_viewer.dart';

abstract interface class LayerViewerDocument {
  Future<OptionalContentConfig> getOptionalContentConfig({String intent});
}

final class _VisibilityEntry {
  _VisibilityEntry(this.input, this.visible);
  final web.HTMLInputElement input;
  bool visible;
}

/// Tree viewer for PDF optional-content groups (layers).
class PDFLayerViewer extends BaseTreeViewer {
  PDFLayerViewer({
    required super.container,
    required super.eventBus,
    required super.l10n,
  }) {
    eventBus.internalOn('optionalcontentconfigchanged', (data) {
      final promise = data is Map ? data['promise'] : null;
      unawaited(_updateLayers(
        promise is Future<OptionalContentConfig> ? promise : null,
      ));
    });
    eventBus.internalOn('resetlayers', (_) => unawaited(_updateLayers()));
    eventBus.internalOn('togglelayerstree', (_) => _toggleAll());
  }

  OptionalContentConfig? _optionalContentConfig;
  LayerViewerDocument? _document;
  Map<String, _VisibilityEntry>? _optionalContentVisibility;

  @override
  void reset() {
    super.reset();
    _optionalContentConfig = null;
    _document = null;
    _optionalContentVisibility?.clear();
    _optionalContentVisibility = null;
  }

  @override
  void dispatchLoadedEvent(int count) {
    eventBus.dispatch('layersloaded', {'source': this, 'layersCount': count});
  }

  @override
  void bindLink(web.HTMLAnchorElement element, Map<String, dynamic> item) {
    final groupId = item['groupId'] as String;
    final input = item['input'] as web.HTMLInputElement;
    void setVisibility() {
      final visible = input.checked;
      _optionalContentConfig!.setVisibility(groupId, visible);
      final cached = _optionalContentVisibility?[groupId];
      if (cached != null) cached.visible = visible;
      eventBus.dispatch('optionalcontentconfig', {
        'source': this,
        'promise': Future<OptionalContentConfig>.value(
          _optionalContentConfig!,
        ),
      });
    }

    element.addEventListener(
        'click',
        ((web.Event event) {
          if (identical(event.target, input)) {
            setVisibility();
            return;
          }
          if (!identical(event.target, element)) return;
          input.checked = !input.checked;
          setVisibility();
          event.preventDefault();
        }).toJS);
  }

  void _setNestedName(web.HTMLAnchorElement element, Object? name) {
    if (name is String) {
      element.textContent = normalizeTextContent(name);
      return;
    }
    element.setAttribute('data-l10n-id', 'pdfjs-additional-layers');
    element.style.fontStyle = 'italic';
    unawaited(l10n.translateOnce(element));
  }

  void _toggleAll() {
    if (_optionalContentConfig != null) toggleAllTreeItems();
  }

  void render({
    required OptionalContentConfig? optionalContentConfig,
    required LayerViewerDocument? pdfDocument,
  }) {
    if (_optionalContentConfig != null) reset();
    _optionalContentConfig = optionalContentConfig;
    _document = pdfDocument;
    this.pdfDocument = pdfDocument;
    final groups = optionalContentConfig?.getOrder();
    if (groups == null) {
      dispatchLoadedEvent(0);
      return;
    }
    _optionalContentVisibility = {};
    final fragment = web.document.createDocumentFragment();
    final queue = <({web.Node parent, List<dynamic> groups})>[
      (parent: fragment, groups: groups),
    ];
    var count = 0;
    var nested = false;
    while (queue.isNotEmpty) {
      final level = queue.removeAt(0);
      for (final raw in level.groups) {
        final div = web.document.createElement('div') as web.HTMLDivElement
          ..className = 'treeItem';
        final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
        div.append(anchor);
        if (raw is Map) {
          nested = true;
          final name = raw['name'];
          addToggleButton(div, hidden: name == null);
          _setNestedName(anchor, name);
          final items = web.document.createElement('div') as web.HTMLDivElement
            ..className = 'treeItems';
          div.append(items);
          final order = raw['order'];
          queue.add((
            parent: items,
            groups: order is List ? List<dynamic>.from(order) : <dynamic>[],
          ));
        } else {
          final id = raw.toString();
          final group = optionalContentConfig!.getGroup(id);
          if (group == null) continue;
          final label =
              web.document.createElement('label') as web.HTMLLabelElement;
          final input =
              web.document.createElement('input') as web.HTMLInputElement
                ..type = 'checkbox'
                ..checked = group.visible;
          label
            ..append(input)
            ..append(
                web.document.createTextNode(normalizeTextContent(group.name)));
          bindLink(anchor, {'groupId': id, 'input': input});
          _optionalContentVisibility![id] =
              _VisibilityEntry(input, input.checked);
          anchor.append(label);
          count++;
        }
        level.parent.appendChild(div);
      }
    }
    finishRendering(fragment, count, hasAnyNesting: nested);
  }

  Future<void> _updateLayers([Future<OptionalContentConfig>? promise]) async {
    if (_optionalContentConfig == null) return;
    final document = _document;
    if (document == null) return;
    final config =
        await (promise ?? document.getOptionalContentConfig(intent: 'display'));
    if (!identical(document, _document)) return;
    if (promise != null) {
      for (final entry in _optionalContentVisibility!.entries) {
        final group = config.getGroup(entry.key);
        final cached = entry.value;
        if (group != null && cached.visible != group.visible) {
          cached.visible = !cached.visible;
          cached.input.checked = cached.visible;
        }
      }
      return;
    }
    eventBus.dispatch('optionalcontentconfig', {
      'source': this,
      'promise': Future<OptionalContentConfig>.value(config),
    });
    render(optionalContentConfig: config, pdfDocument: _document);
  }
}
