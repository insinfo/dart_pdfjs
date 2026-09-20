// Copyright 2025 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.
// Ported from pdf.js/web/autolinker.js.

import 'package:pdfjs/src/shared/util.dart';
import 'package:web/web.dart' as web;

import 'pdf_find_controller.dart';
import 'text_highlighter.dart';

final class DetectedLink {
  const DetectedLink({
    required this.url,
    required this.index,
    required this.length,
  });

  final String url;
  final int index;
  final int length;
}

/// Page geometry required to turn detected text URLs into PDF annotations.
abstract interface class AutolinkPageView {
  TextHighlighter get textHighlighter;
  web.HTMLDivElement get textLayerDiv;
  List<double> getPagePoint(double x, double y);
}

/// Finds URL/e-mail text and derives annotation rectangles from the text layer.
abstract final class Autolinker {
  static int _nextId = 0;

  static final RegExp _candidate = RegExp(
    r'''(?:https?://|mailto:|www\.)[^\s<>]+|[\p{L}\p{M}\p{N}.!#$%&'*+/=?^_`{|}~-]+@[\p{L}\p{M}\p{N}-]+(?:\.[\p{L}\p{M}\p{N}-]+)+''',
    multiLine: true,
    unicode: true,
    caseSensitive: false,
  );
  static final RegExp _numericTld = RegExp(r'\.\d+$');
  static final RegExp _trailingPunctuation = RegExp(r'''[.,;:!?"'’”)>\]}]+$''');

  static List<DetectedLink> findLinks(String text) {
    final normalized = normalizeFindText(text, ignoreDashEol: true);
    final links = <DetectedLink>[];
    for (final match in _candidate.allMatches(normalized.text)) {
      var visible = match.group(0)!;
      visible = visible.replaceFirst(_trailingPunctuation, '');
      if (visible.isEmpty) continue;

      final (originalIndex, originalLength) =
          normalized.originalRange(match.start, visible.length);
      final originalVisible = text.substring(
        originalIndex,
        (originalIndex + originalLength).clamp(0, text.length),
      );

      String raw;
      if (visible.startsWith(RegExp(r'https?://', caseSensitive: false)) ||
          visible.toLowerCase().startsWith('www.')) {
        raw = originalVisible;
      } else if (visible.toLowerCase().startsWith('mailto:')) {
        raw = originalVisible;
      } else {
        final at = originalVisible.lastIndexOf('@');
        if (at <= 0) continue;
        final domain = originalVisible.substring(at + 1);
        if (!_isValidDomain(domain) || _numericTld.hasMatch(domain)) continue;
        raw = 'mailto:$originalVisible';
      }
      final uri = createValidAbsoluteUrl(raw, null, true);
      if (uri == null) continue;
      links.add(DetectedLink(
        url: uri.toString(),
        index: originalIndex,
        length: originalLength,
      ));
    }
    return links;
  }

  static bool _isValidDomain(String domain) {
    if (!domain.contains('.') ||
        domain.startsWith('.') ||
        domain.endsWith('.')) {
      return false;
    }
    return domain.split('.').every((label) =>
        label.isNotEmpty &&
        !label.startsWith('-') &&
        !label.endsWith('-') &&
        RegExp(r'^[\p{L}\p{M}\p{N}-]+$', unicode: true).hasMatch(label));
  }

  static List<Map<String, dynamic>> processLinks(AutolinkPageView pageView) {
    final highlighter = pageView.textHighlighter;
    final texts = highlighter.textContentItemsStr;
    if (texts == null || highlighter.textDivs == null) return const [];
    return findLinks(texts.join('\n'))
        .map((link) => _createLinkAnnotation(link, pageView, _nextId++))
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static Map<String, dynamic>? _createLinkAnnotation(
    DetectedLink link,
    AutolinkPageView pageView,
    int id,
  ) {
    final highlighter = pageView.textHighlighter;
    final converted = highlighter.convertMatches([link.index], [link.length]);
    if (converted.isEmpty) return null;
    final match = converted.single;
    final nodes = highlighter.textDivs!;
    final start = textPosition(nodes[match.begin.divIndex], match.begin.offset);
    final end = textPosition(nodes[match.end.divIndex], match.end.offset);
    final range = web.document.createRange()
      ..setStart(start.$1, start.$2)
      ..setEnd(end.$1, end.$2);
    final position = calculateLinkPosition(range, pageView);
    if (position == null) return null;
    return <String, dynamic>{
      'id': 'inferred_link_$id',
      'unsafeUrl': link.url,
      'url': link.url,
      'annotationType': AnnotationType.link,
      'rotation': 0,
      ...position,
      'borderStyle': null,
    };
  }

  static (web.Text, int) textPosition(web.Node container, int offset) {
    web.Node current = container;
    var remaining = offset;
    while (true) {
      if (current is web.Text) {
        final length = (current.textContent ?? '').length;
        if (remaining <= length) return (current, remaining);
        remaining -= length;
      } else if (current.firstChild != null) {
        current = current.firstChild!;
        continue;
      }
      while (current.nextSibling == null && current != container) {
        current = current.parentNode!;
      }
      if (current == container) break;
      current = current.nextSibling!;
    }
    throw RangeError.range(
        offset, 0, container.textContent?.length ?? 0, 'offset');
  }

  static Map<String, List<num>>? calculateLinkPosition(
    web.Range range,
    AutolinkPageView pageView,
  ) {
    final domRects = range.getClientRects();
    if (domRects.length == 0) return null;
    if (domRects.length == 1) {
      final domRect = domRects.item(0);
      if (domRect == null) return null;
      final rect = _domRectToPdf(domRect, pageView);
      return rect == null ? null : {'rect': rect};
    }
    final rect = <num>[
      double.infinity,
      double.infinity,
      double.negativeInfinity,
      double.negativeInfinity,
    ];
    final quadPoints = <num>[];
    for (var index = 0; index < domRects.length; index++) {
      final domRect = domRects.item(index);
      if (domRect == null) continue;
      final normalized = _domRectToPdf(domRect, pageView);
      if (normalized == null) continue;
      quadPoints.addAll([
        normalized[0],
        normalized[3],
        normalized[2],
        normalized[3],
        normalized[0],
        normalized[1],
        normalized[2],
        normalized[1],
      ]);
      Util.rectBoundingBox(
        normalized[0],
        normalized[1],
        normalized[2],
        normalized[3],
        rect,
      );
    }
    return quadPoints.isEmpty ? null : {'quadPoints': quadPoints, 'rect': rect};
  }

  static List<double>? _domRectToPdf(
    web.DOMRect rect,
    AutolinkPageView pageView,
  ) {
    if (rect.width == 0 || rect.height == 0) return null;
    final pageBox = pageView.textLayerDiv.getBoundingClientRect();
    final bottomLeft = pageView.getPagePoint(
      rect.left - pageBox.left,
      rect.top - pageBox.top,
    );
    final topRight = pageView.getPagePoint(
      rect.left - pageBox.left + rect.width,
      rect.top - pageBox.top + rect.height,
    );
    return Util.normalizeRect([
      bottomLeft[0],
      bottomLeft[1],
      topRight[0],
      topRight[1],
    ]);
  }
}
