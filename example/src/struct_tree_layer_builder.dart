// Copyright 2021 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.
// Ported from pdf.js/web/struct_tree_layer_builder.js.

import 'dart:js_interop';

import 'package:pdfjs/src/display/display_utils.dart';
import 'package:web/web.dart' as web;

import 'layer_page_adapter.dart';
import 'ui_utils.dart';

const _mathMlNamespace = 'http://www.w3.org/1998/Math/MathML';
const _roles = <String, String?>{
  'Document': null,
  'DocumentFragment': null,
  'Part': 'group',
  'Sect': 'group',
  'Div': 'group',
  'Aside': 'note',
  'NonStruct': 'none',
  'P': null,
  'H': 'heading',
  'Title': null,
  'FENote': 'note',
  'Sub': 'group',
  'Lbl': null,
  'Span': null,
  'Em': null,
  'Strong': null,
  'Link': 'link',
  'Annot': 'note',
  'Form': 'form',
  'Ruby': null,
  'RB': null,
  'RT': null,
  'RP': null,
  'Warichu': null,
  'WT': null,
  'WP': null,
  'L': 'list',
  'LI': 'listitem',
  'LBody': null,
  'Table': 'table',
  'TR': 'row',
  'TH': 'columnheader',
  'TD': 'cell',
  'THead': 'rowgroup',
  'TBody': 'rowgroup',
  'TFoot': null,
  'Caption': null,
  'Figure': 'figure',
  'Formula': null,
  'Artifact': null,
};

const _mathElements = <String>{
  'math',
  'merror',
  'mfrac',
  'mi',
  'mmultiscripts',
  'mn',
  'mo',
  'mover',
  'mpadded',
  'mprescripts',
  'mroot',
  'mrow',
  'ms',
  'mspace',
  'msqrt',
  'mstyle',
  'msub',
  'msubsup',
  'msup',
  'mtable',
  'mtd',
  'mtext',
  'mtr',
  'munder',
  'munderover',
  'semantics',
};

/// Builds an accessibility tree for a tagged PDF page.
final class StructTreeLayerBuilder {
  StructTreeLayerBuilder(this.pdfPage, this.rawDims)
      : _treeSource = pdfPage.getStructTree();

  final LayerPage pdfPage;
  final RawDims? rawDims;
  Future<Map<String, dynamic>?>? _treeSource;
  Future<web.Element?>? _treePromise;
  web.Element? _treeDom;
  final Map<String, Map<String, String>> _elementAttributes = {};
  Map<String, web.HTMLSpanElement>? _elementsToAdd;
  List<String>? _elementsToHide;
  List<(web.Element, List<String>)>? _elementsToSteal;

  web.Element? get treeDom => _treeDom;

  Future<web.Element?> render() {
    final existing = _treePromise;
    if (existing != null) return existing;
    return _treePromise = _renderOnce();
  }

  Future<web.Element?> _renderOnce() async {
    final source = _treeSource;
    _treeSource = null;
    final tree = source == null ? null : await source;
    _treeDom = _walk(tree, const []);
    _treeDom?.classList.add('structTree');
    return _treeDom;
  }

  Future<Map<String, String>?> getAriaAttributes(String annotationId) async {
    try {
      await render();
      final value = _elementAttributes[annotationId];
      return value == null ? null : Map.unmodifiable(value);
    } catch (_) {
      return null;
    }
  }

  void hide() {
    final tree = _treeDom;
    if (tree is web.HTMLElement && !tree.hasAttribute('hidden')) {
      tree.setAttribute('hidden', '');
    }
  }

  void show() {
    final tree = _treeDom;
    if (tree is web.HTMLElement && tree.hasAttribute('hidden')) {
      tree.removeAttribute('hidden');
    }
  }

  void updateTextLayer() {
    final add = _elementsToAdd;
    if (add != null) {
      for (final entry in add.entries) {
        web.document.getElementById(entry.key)?.append(entry.value);
      }
      add.clear();
      _elementsToAdd = null;
    }
    final hide = _elementsToHide;
    if (hide != null) {
      for (final id in hide) {
        web.document.getElementById(id)?.setAttribute('aria-hidden', 'true');
      }
      _elementsToHide = null;
    }
    final steal = _elementsToSteal;
    if (steal != null) {
      for (final (element, ids) in steal) {
        final content = StringBuffer();
        for (final id in ids) {
          final textElement = web.document.getElementById(id);
          if (textElement == null) continue;
          content.write((textElement.textContent ?? '').trim());
          textElement.setAttribute('aria-hidden', 'true');
        }
        if (content.isNotEmpty) element.textContent = content.toString();
      }
      _elementsToSteal = null;
    }
  }

  void _setAttributes(Map<String, dynamic> node, web.Element element) {
    final alt = node['alt'];
    if (alt != null) {
      final label = removeNullCharacters(alt.toString());
      var assignedToAnnotation = false;
      for (final child in _children(node)) {
        if (child['type'] == 'annotation' && child['id'] != null) {
          (_elementAttributes[child['id'].toString()] ??= {})['aria-label'] =
              label;
          assignedToAnnotation = true;
        }
      }
      if (!assignedToAnnotation) element.setAttribute('aria-label', label);
    }
    if (node['id'] != null) {
      element.setAttribute('aria-owns', node['id'].toString());
    }
    if (node['lang'] != null) {
      element.setAttribute(
        'lang',
        removeNullCharacters(node['lang'].toString(), replaceInvisible: true),
      );
    }
  }

  bool _addImageInTextLayer(
    Map<String, dynamic> node,
    web.Element element,
  ) {
    final dims = rawDims;
    final alt = node['alt'];
    final bbox = node['bbox'];
    final children = _children(node);
    final child = children.isEmpty ? null : children.first;
    if (dims == null ||
        alt == null ||
        bbox is! List ||
        bbox.length < 4 ||
        child?['type'] != 'content' ||
        child?['id'] == null) {
      return false;
    }
    final id = child!['id'].toString();
    element.setAttribute('aria-owns', id);
    final image = web.document.createElement('span') as web.HTMLSpanElement;
    (_elementsToAdd ??= {})[id] = image;
    image
      ..setAttribute('role', 'img')
      ..setAttribute('aria-label', removeNullCharacters(alt.toString()));
    final values = bbox.cast<num>();
    const calc = 'calc(var(--total-scale-factor) * ';
    image.style
      ..width = '$calc${values[2] - values[0]}px)'
      ..height = '$calc${values[3] - values[1]}px)'
      ..left = '$calc${values[0] - dims.pageX}px)'
      ..top = '$calc${dims.pageHeight - values[3] + dims.pageY}px)';
    return true;
  }

  web.Element? _walk(
    Map<String, dynamic>? node,
    List<Map<String, dynamic>> parents,
  ) {
    if (node == null) return null;
    final role = node['role']?.toString();
    web.Element element;
    var visitChildren = true;
    if (role != null && _mathElements.contains(role)) {
      element = web.document.createElementNS(_mathMlNamespace, role);
      final ids = <String>[];
      (_elementsToSteal ??= []).add((element, ids));
      for (final child in _children(node)) {
        if (child['type'] == 'content' && child['id'] != null) {
          ids.add(child['id'].toString());
        }
      }
    } else {
      element = web.document.createElement('span');
    }

    if (role != null) {
      final heading = RegExp(r'^H(\d+)$').firstMatch(role);
      if (heading != null) {
        element
          ..setAttribute('role', 'heading')
          ..setAttribute('aria-level', heading.group(1)!);
      } else {
        var htmlRole = _roles[role];
        if (role == 'TH' &&
            parents.isNotEmpty &&
            parents.last['role'] == 'TR' &&
            parents.length > 1 &&
            parents[parents.length - 2]['role'] == 'TBody') {
          htmlRole = 'rowheader';
        }
        if (htmlRole != null) element.setAttribute('role', htmlRole);
      }
      if (role == 'Figure' && _addImageInTextLayer(node, element)) {
        _setAttributes(node, element);
        return element;
      }
      if (role == 'Formula') {
        final mathMl = node['mathML']?.toString();
        if (mathMl != null && mathMl.isNotEmpty) {
          final sanitized = _parseSafeMathMl(mathMl);
          if (sanitized != null) {
            visitChildren = false;
            element.append(sanitized);
            _collectIds(node, _elementsToHide ??= []);
          }
        } else {
          final children = _children(node);
          if (children.length == 1 && children.first['role'] != 'math') {
            element = web.document.createElementNS(_mathMlNamespace, 'math');
          }
        }
      }
    }

    _setAttributes(node, element);
    final children = _children(node);
    if (children.length == 1 && children.first['id'] != null) {
      _setAttributes(children.first, element);
    } else if (visitChildren) {
      final nextParents = [...parents, node];
      for (final child in children) {
        final rendered = _walk(child, nextParents);
        if (rendered != null) element.append(rendered);
      }
    }
    return element;
  }

  web.Element? _parseSafeMathMl(String source) {
    final parser = web.DOMParser();
    final document = parser.parseFromString(source.toJS, 'application/xml');
    final root = document.documentElement;
    if (root == null || !_mathElements.contains(root.localName)) return null;
    return _copySafeMathNode(root);
  }

  web.Element _copySafeMathNode(web.Element source) {
    final copy =
        web.document.createElementNS(_mathMlNamespace, source.localName);
    const allowed = <String>{
      'dir',
      'displaystyle',
      'mathbackground',
      'mathcolor',
      'mathsize',
      'scriptlevel',
      'encoding',
      'display',
      'linethickness',
      'intent',
      'arg',
      'form',
      'fence',
      'separator',
      'lspace',
      'rspace',
      'stretchy',
      'symmetric',
      'maxsize',
      'minsize',
      'largeop',
      'movablelimits',
      'width',
      'height',
      'depth',
      'voffset',
      'accent',
      'accentunder',
      'columnspan',
      'rowspan',
    };
    for (final name in allowed) {
      final value = source.getAttribute(name);
      if (value != null) copy.setAttribute(name, value);
    }
    for (var i = 0; i < source.childNodes.length; i++) {
      final child = source.childNodes.item(i);
      if (child is web.Text) {
        copy.append(web.document.createTextNode(child.data));
      } else if (child is web.Element &&
          _mathElements.contains(child.localName)) {
        copy.append(_copySafeMathNode(child));
      }
    }
    return copy;
  }

  static List<Map<String, dynamic>> _children(Map<String, dynamic> node) {
    final raw = node['children'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  static void _collectIds(Map<String, dynamic> node, List<String> target) {
    if (node['id'] != null) target.add(node['id'].toString());
    for (final child in _children(node)) {
      _collectIds(child, target);
    }
  }
}
