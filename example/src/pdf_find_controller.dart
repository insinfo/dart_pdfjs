// Copyright 2012 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:async';
import 'dart:math' as math;

import 'event_utils.dart';
import 'pdf_find_utils.dart';

/// State values emitted by the PDF.js find controller.
enum FindState { found, notFound, wrapped, pending }

/// A match in normalized page text.
final class FindMatch {
  const FindMatch(this.index, this.length);

  final int index;
  final int length;

  @override
  bool operator ==(Object other) =>
      other is FindMatch && index == other.index && length == other.length;

  @override
  int get hashCode => Object.hash(index, length);
}

/// Selection exposed to text-layer builders.
final class FindSelection {
  const FindSelection({required this.pageIndex, required this.matchIndex});

  final int pageIndex;
  final int matchIndex;

  int get pageIdx => pageIndex;
  int get matchIdx => matchIndex;
}

/// Count shown in the find bar.
final class FindMatchesCount {
  const FindMatchesCount({required this.current, required this.total});

  final int current;
  final int total;

  Map<String, int> toMap() => {'current': current, 'total': total};
}

/// Typed representation of the payload sent with a `find` event.
final class FindParameters {
  const FindParameters({
    this.source,
    this.type = '',
    this.query = '',
    this.caseSensitive = false,
    this.entireWord = false,
    this.findPrevious = false,
    this.matchDiacritics = false,
    this.highlightAll = false,
  });

  factory FindParameters.from(Object? value) {
    if (value is FindParameters) return value;
    if (value is! Map) return const FindParameters();
    return FindParameters(
      source: value['source'],
      type: value['type'] as String? ?? '',
      query: value['query'] ?? '',
      caseSensitive: value['caseSensitive'] == true,
      entireWord: value['entireWord'] == true,
      findPrevious: value['findPrevious'] == true,
      matchDiacritics: value['matchDiacritics'] == true,
      highlightAll: value['highlightAll'] == true,
    );
  }

  final Object? source;
  final String type;
  final Object query;
  final bool caseSensitive;
  final bool entireWord;
  final bool findPrevious;
  final bool matchDiacritics;
  final bool highlightAll;
}

/// Result of normalizing searchable text and retaining highlight positions.
final class NormalizedText {
  const NormalizedText({
    required this.text,
    required this.normalizedToOriginal,
    required this.originalLengths,
    required this.hasDiacritics,
  });

  final String text;
  final List<int> normalizedToOriginal;
  final List<int> originalLengths;
  final bool hasDiacritics;

  /// Converts a normalized match back to a range in the source string.
  (int, int) originalRange(int position, int length) {
    if (length <= 0 || normalizedToOriginal.isEmpty) return (position, length);
    final first = position.clamp(0, normalizedToOriginal.length - 1);
    final last = (position + length - 1).clamp(
      first,
      normalizedToOriginal.length - 1,
    );
    var start = normalizedToOriginal[first];
    var end = start + originalLengths[first];
    for (var i = first + 1; i <= last; i++) {
      start = math.min(start, normalizedToOriginal[i]);
      end = math.max(end, normalizedToOriginal[i] + originalLengths[i]);
    }
    return (start, end - start);
  }
}

const _charactersToNormalize = <int, String>{
  0x2010: '-',
  0x2011: '-',
  0x2018: "'",
  0x2019: "'",
  0x201a: "'",
  0x201b: "'",
  0x201c: '"',
  0x201d: '"',
  0x201e: '"',
  0x201f: '"',
  0x00bc: '1/4',
  0x00bd: '1/2',
  0x00be: '3/4',
  0x00a0: ' ',
  0xfb00: 'ff',
  0xfb01: 'fi',
  0xfb02: 'fl',
  0xfb03: 'ffi',
  0xfb04: 'ffl',
  0xfb05: 'st',
  0xfb06: 'st',
  // Arabic presentation forms used by embedded CID fonts.
  0xfe80: '\u0621',
  0xfe81: '\u0622', 0xfe82: '\u0622',
  0xfe83: '\u0623', 0xfe84: '\u0623',
  0xfe85: '\u0624', 0xfe86: '\u0624',
  0xfe87: '\u0625', 0xfe88: '\u0625',
  0xfe89: '\u0626', 0xfe8a: '\u0626', 0xfe8b: '\u0626', 0xfe8c: '\u0626',
  0xfe8d: '\u0627', 0xfe8e: '\u0627',
  0xfe8f: '\u0628', 0xfe90: '\u0628', 0xfe91: '\u0628', 0xfe92: '\u0628',
  0xfe93: '\u0629', 0xfe94: '\u0629',
  0xfe95: '\u062a', 0xfe96: '\u062a', 0xfe97: '\u062a', 0xfe98: '\u062a',
  0xfe99: '\u062b', 0xfe9a: '\u062b', 0xfe9b: '\u062b', 0xfe9c: '\u062b',
  0xfe9d: '\u062c', 0xfe9e: '\u062c', 0xfe9f: '\u062c', 0xfea0: '\u062c',
  0xfea1: '\u062d', 0xfea2: '\u062d', 0xfea3: '\u062d', 0xfea4: '\u062d',
  0xfea5: '\u062e', 0xfea6: '\u062e', 0xfea7: '\u062e', 0xfea8: '\u062e',
  0xfea9: '\u062f', 0xfeaa: '\u062f',
  0xfeab: '\u0630', 0xfeac: '\u0630',
  0xfead: '\u0631', 0xfeae: '\u0631',
  0xfeaf: '\u0632', 0xfeb0: '\u0632',
  0xfeb1: '\u0633', 0xfeb2: '\u0633', 0xfeb3: '\u0633', 0xfeb4: '\u0633',
  0xfeb5: '\u0634', 0xfeb6: '\u0634', 0xfeb7: '\u0634', 0xfeb8: '\u0634',
  0xfeb9: '\u0635', 0xfeba: '\u0635', 0xfebb: '\u0635', 0xfebc: '\u0635',
  0xfebd: '\u0636', 0xfebe: '\u0636', 0xfebf: '\u0636', 0xfec0: '\u0636',
  0xfec1: '\u0637', 0xfec2: '\u0637', 0xfec3: '\u0637', 0xfec4: '\u0637',
  0xfec5: '\u0638', 0xfec6: '\u0638', 0xfec7: '\u0638', 0xfec8: '\u0638',
  0xfec9: '\u0639', 0xfeca: '\u0639', 0xfecb: '\u0639', 0xfecc: '\u0639',
  0xfecd: '\u063a', 0xfece: '\u063a', 0xfecf: '\u063a', 0xfed0: '\u063a',
  0xfed1: '\u0641', 0xfed2: '\u0641', 0xfed3: '\u0641', 0xfed4: '\u0641',
  0xfed5: '\u0642', 0xfed6: '\u0642', 0xfed7: '\u0642', 0xfed8: '\u0642',
  0xfed9: '\u0643', 0xfeda: '\u0643', 0xfedb: '\u0643', 0xfedc: '\u0643',
  0xfedd: '\u0644', 0xfede: '\u0644', 0xfedf: '\u0644', 0xfee0: '\u0644',
  0xfee1: '\u0645', 0xfee2: '\u0645', 0xfee3: '\u0645', 0xfee4: '\u0645',
  0xfee5: '\u0646', 0xfee6: '\u0646', 0xfee7: '\u0646', 0xfee8: '\u0646',
  0xfee9: '\u0647', 0xfeea: '\u0647', 0xfeeb: '\u0647', 0xfeec: '\u0647',
  0xfeed: '\u0648', 0xfeee: '\u0648',
  0xfeef: '\u0649', 0xfef0: '\u0649',
  0xfef1: '\u064a', 0xfef2: '\u064a', 0xfef3: '\u064a', 0xfef4: '\u064a',
};

// Canonical decompositions needed by the Latin scripts most often found in
// PDF text. Hangul is handled algorithmically below.
const _latinDecomposition = <int, String>{
  0x00c0: 'A\u0300',
  0x00c1: 'A\u0301',
  0x00c2: 'A\u0302',
  0x00c3: 'A\u0303',
  0x00c4: 'A\u0308',
  0x00c5: 'A\u030a',
  0x00c7: 'C\u0327',
  0x00c8: 'E\u0300',
  0x00c9: 'E\u0301',
  0x00ca: 'E\u0302',
  0x00cb: 'E\u0308',
  0x00cc: 'I\u0300',
  0x00cd: 'I\u0301',
  0x00ce: 'I\u0302',
  0x00cf: 'I\u0308',
  0x00d1: 'N\u0303',
  0x00d2: 'O\u0300',
  0x00d3: 'O\u0301',
  0x00d4: 'O\u0302',
  0x00d5: 'O\u0303',
  0x00d6: 'O\u0308',
  0x00d9: 'U\u0300',
  0x00da: 'U\u0301',
  0x00db: 'U\u0302',
  0x00dc: 'U\u0308',
  0x00dd: 'Y\u0301',
  0x00e0: 'a\u0300',
  0x00e1: 'a\u0301',
  0x00e2: 'a\u0302',
  0x00e3: 'a\u0303',
  0x00e4: 'a\u0308',
  0x00e5: 'a\u030a',
  0x00e7: 'c\u0327',
  0x00e8: 'e\u0300',
  0x00e9: 'e\u0301',
  0x00ea: 'e\u0302',
  0x00eb: 'e\u0308',
  0x00ec: 'i\u0300',
  0x00ed: 'i\u0301',
  0x00ee: 'i\u0302',
  0x00ef: 'i\u0308',
  0x00f1: 'n\u0303',
  0x00f2: 'o\u0300',
  0x00f3: 'o\u0301',
  0x00f4: 'o\u0302',
  0x00f5: 'o\u0303',
  0x00f6: 'o\u0308',
  0x00f9: 'u\u0300',
  0x00fa: 'u\u0301',
  0x00fb: 'u\u0302',
  0x00fc: 'u\u0308',
  0x00fd: 'y\u0301',
  0x00ff: 'y\u0308',
  0x0100: 'A\u0304',
  0x0101: 'a\u0304',
  0x0102: 'A\u0306',
  0x0103: 'a\u0306',
  0x0104: 'A\u0328',
  0x0105: 'a\u0328',
  0x0106: 'C\u0301',
  0x0107: 'c\u0301',
  0x0108: 'C\u0302',
  0x0109: 'c\u0302',
  0x010a: 'C\u0307',
  0x010b: 'c\u0307',
  0x010c: 'C\u030c',
  0x010d: 'c\u030c',
  0x010e: 'D\u030c',
  0x010f: 'd\u030c',
  0x0112: 'E\u0304',
  0x0113: 'e\u0304',
  0x0116: 'E\u0307',
  0x0117: 'e\u0307',
  0x0118: 'E\u0328',
  0x0119: 'e\u0328',
  0x011a: 'E\u030c',
  0x011b: 'e\u030c',
  0x0128: 'I\u0303',
  0x0129: 'i\u0303',
  0x012a: 'I\u0304',
  0x012b: 'i\u0304',
  0x0139: 'L\u0301',
  0x013a: 'l\u0301',
  0x0143: 'N\u0301',
  0x0144: 'n\u0301',
  0x0147: 'N\u030c',
  0x0148: 'n\u030c',
  0x014c: 'O\u0304',
  0x014d: 'o\u0304',
  0x0154: 'R\u0301',
  0x0155: 'r\u0301',
  0x0158: 'R\u030c',
  0x0159: 'r\u030c',
  0x015a: 'S\u0301',
  0x015b: 's\u0301',
  0x015e: 'S\u0327',
  0x015f: 's\u0327',
  0x0160: 'S\u030c',
  0x0161: 's\u030c',
  0x0164: 'T\u030c',
  0x0165: 't\u030c',
  0x0168: 'U\u0303',
  0x0169: 'u\u0303',
  0x016a: 'U\u0304',
  0x016b: 'u\u0304',
  0x016e: 'U\u030a',
  0x016f: 'u\u030a',
  0x0178: 'Y\u0308',
  0x0179: 'Z\u0301',
  0x017a: 'z\u0301',
  0x017b: 'Z\u0307',
  0x017c: 'z\u0307',
  0x017d: 'Z\u030c',
  0x017e: 'z\u030c',
};

String _decomposeRune(int rune) {
  final direct = _charactersToNormalize[rune] ?? _latinDecomposition[rune];
  if (direct != null) return direct;
  if (rune >= 0xff01 && rune <= 0xff5e) {
    return String.fromCharCode(rune - 0xfee0);
  }
  // Unicode Hangul canonical decomposition (UAX #15).
  if (rune >= 0xac00 && rune <= 0xd7a3) {
    const sBase = 0xac00, lBase = 0x1100, vBase = 0x1161, tBase = 0x11a7;
    const vCount = 21, tCount = 28, nCount = vCount * tCount;
    final sIndex = rune - sBase;
    final result = <int>[
      lBase + sIndex ~/ nCount,
      vBase + (sIndex % nCount) ~/ tCount,
    ];
    final tIndex = sIndex % tCount;
    if (tIndex != 0) result.add(tBase + tIndex);
    return String.fromCharCodes(result);
  }
  return String.fromCharCode(rune);
}

bool _isLetter(int rune) {
  if (rune >= 0x30 && rune <= 0x39) return false;
  final type = getCharacterType(rune);
  return type != CharacterType.space && type != CharacterType.punctuation;
}

/// Normalizes page/query text following the PDF.js search rules.
NormalizedText normalizeFindText(
  String source, {
  bool ignoreDashEol = false,
}) {
  final runes = source.runes.toList(growable: false);
  final runeOffsets = <int>[];
  var utf16Offset = 0;
  for (final rune in runes) {
    runeOffsets.add(utf16Offset);
    utf16Offset += rune > 0xffff ? 2 : 1;
  }

  final output = StringBuffer();
  final origins = <int>[];
  final lengths = <int>[];
  var hasDiacritics = false;

  void emit(String value, int origin, int originalLength) {
    output.write(value);
    for (var i = 0; i < value.length; i++) {
      origins.add(origin);
      lengths.add(originalLength);
    }
  }

  for (var i = 0; i < runes.length; i++) {
    final rune = runes[i];
    final origin = runeOffsets[i];
    final originalLength = rune > 0xffff ? 2 : 1;
    if (rune == 0x0d && i + 1 < runes.length && runes[i + 1] == 0x0a) {
      continue;
    }
    if (rune == 0x0a) {
      final previous = i > 0 ? runes[i - 1] : null;
      final next = i + 1 < runes.length ? runes[i + 1] : null;
      if (previous == 0x2d) {
        // The dash has already been emitted. Remove it only for a probable
        // word split, matching `Ll-\nLl` and `Lu-\nL` in PDF.js.
        final beforeDash = i > 1 ? runes[i - 2] : null;
        if (!ignoreDashEol &&
            beforeDash != null &&
            next != null &&
            _isLetter(beforeDash) &&
            _isLetter(next)) {
          final text = output.toString();
          if (text.isNotEmpty) {
            output.clear();
            output.write(text.substring(0, text.length - 1));
            origins.removeLast();
            lengths.removeLast();
          }
        }
        continue;
      }
      if (previous != null && isCjk(previous)) continue;
      emit(' ', origin, originalLength);
      continue;
    }

    final replacement = _decomposeRune(rune);
    for (final decomposed in replacement.runes) {
      if (isCombiningMark(decomposed)) hasDiacritics = true;
    }
    emit(replacement, origin, originalLength);
  }
  return NormalizedText(
    text: output.toString(),
    normalizedToOriginal: List<int>.unmodifiable(origins),
    originalLengths: List<int>.unmodifiable(lengths),
    hasDiacritics: hasDiacritics,
  );
}

final class _SearchText {
  const _SearchText(this.text, this.toNormalized);
  final String text;
  final List<int> toNormalized;
}

_SearchText _withoutDiacritics(String source) {
  final output = StringBuffer();
  final map = <int>[];
  var offset = 0;
  for (final rune in source.runes) {
    final width = rune > 0xffff ? 2 : 1;
    if (!isCombiningMark(rune) || isDiacriticException(rune)) {
      final value = String.fromCharCode(rune);
      output.write(value);
      for (var i = 0; i < value.length; i++) map.add(offset);
    }
    offset += width;
  }
  return _SearchText(output.toString(), map);
}

abstract interface class FindScrollableElement {
  void scrollIntoView({String block = 'start', String inline = 'center'});
}

/// Port of PDF.js' `PDFFindController`.
class PDFFindController {
  PDFFindController({
    required dynamic linkService,
    required EventBus eventBus,
    bool updateMatchesCountOnProgress = true,
    Duration findDelay = const Duration(milliseconds: 250),
  })  : _linkService = linkService,
        _eventBus = eventBus,
        _updateMatchesCountOnProgress = updateMatchesCountOnProgress,
        _findDelay = findDelay {
    _reset();
    eventBus.internalOn('find', _onFind);
    eventBus.internalOn('findbarclose', _onFindBarClose);
    eventBus.internalOn('pagesedited', _onPagesEdited);
  }

  final dynamic _linkService;
  final EventBus _eventBus;
  final bool _updateMatchesCountOnProgress;
  final Duration _findDelay;

  bool Function(int pageNumber)? onIsPageVisible;
  dynamic _pdfDocument;
  FindParameters? _state;
  bool _highlightMatches = false;
  bool _scrollMatches = false;
  bool _dirtyMatch = false;
  Timer? _findTimeout;
  late Completer<void> _firstPage;
  List<List<int>?> _pageMatches = [];
  List<List<int>?> _pageMatchesLength = [];
  List<NormalizedText?> _pageData = [];
  List<Future<void>> _extractTextPromises = [];
  final Set<int> _pendingFindMatches = {};
  int _selectedPage = -1;
  int _selectedMatch = -1;
  int? _offsetPage;
  int? _offsetMatch;
  bool _offsetWrapped = false;
  int? _resumePageIndex;
  int? _pagesToSearch;
  int _matchesCountTotal = 0;
  int _visitedPagesCount = 0;
  String? _rawQuery;
  String? _normalizedQuery;
  Map<int, (Future<void>, NormalizedText?)>? _copiedPageData;
  (List<Future<void>>, List<NormalizedText?>)? _savedPageData;

  bool get highlightMatches => _highlightMatches;
  List<List<int>?> get pageMatches => List.unmodifiable(_pageMatches);
  List<List<int>?> get pageMatchesLength =>
      List.unmodifiable(_pageMatchesLength);
  FindSelection get selected => FindSelection(
        pageIndex: _selectedPage,
        matchIndex: _selectedMatch,
      );
  FindParameters? get state => _state;

  void setDocument(dynamic pdfDocument) {
    if (_pdfDocument != null) _reset();
    if (pdfDocument == null) return;
    _pdfDocument = pdfDocument;
    if (!_firstPage.isCompleted) _firstPage.complete();
  }

  void scrollMatchIntoView({
    FindScrollableElement? element,
    int pageIndex = -1,
    int matchIndex = -1,
  }) {
    if (!_scrollMatches || element == null) return;
    if (matchIndex != _selectedMatch || pageIndex != _selectedPage) return;
    _scrollMatches = false;
    element.scrollIntoView();
  }

  void _reset() {
    _highlightMatches = false;
    _scrollMatches = false;
    _pdfDocument = null;
    _pageMatches = [];
    _pageMatchesLength = [];
    _pageData = [];
    _extractTextPromises = [];
    _pendingFindMatches.clear();
    _selectedPage = _selectedMatch = -1;
    _offsetPage = _offsetMatch = null;
    _offsetWrapped = false;
    _resumePageIndex = null;
    _pagesToSearch = null;
    _matchesCountTotal = _visitedPagesCount = 0;
    _state = null;
    _dirtyMatch = false;
    _rawQuery = _normalizedQuery = null;
    _copiedPageData = null;
    _savedPageData = null;
    _findTimeout?.cancel();
    _findTimeout = null;
    _firstPage = Completer<void>();
  }

  void _onFind(Object? event) {
    if (event == null) return;
    final nextState = FindParameters.from(event);
    final documentAtDispatch = _pdfDocument;
    if (_state == null || _shouldDirtyMatch(nextState)) _dirtyMatch = true;
    _state = nextState;
    if (nextState.type != 'highlightallchange') {
      _updateUiState(FindState.pending);
    }
    _firstPage.future.then((_) {
      if (_pdfDocument == null ||
          (documentAtDispatch != null && documentAtDispatch != _pdfDocument)) {
        return;
      }
      _extractText();
      final findbarClosed = !_highlightMatches;
      final pendingTimeout = _findTimeout != null;
      _findTimeout?.cancel();
      _findTimeout = null;
      switch (nextState.type) {
        case '':
          _findTimeout = Timer(_findDelay, () {
            _nextMatch();
            _findTimeout = null;
          });
        case 'highlightallchange':
          if (pendingTimeout) {
            _nextMatch();
          } else {
            _highlightMatches = true;
          }
          _updateAllPages();
        case 'again':
          _nextMatch();
          if (findbarClosed && nextState.highlightAll) _updateAllPages();
        default:
          _nextMatch();
      }
    });
  }

  bool _shouldDirtyMatch(FindParameters next) {
    final previous = _state!;
    if (!_sameQuery(next.query, previous.query)) return true;
    if (next.type == 'highlightallchange') return false;
    if (next.type == 'again') {
      final pageNumber = _selectedPage + 1;
      final count = _linkService.pagesCount as int;
      final current = _linkService.page as int;
      return pageNumber >= 1 &&
          pageNumber <= count &&
          pageNumber != current &&
          !(onIsPageVisible?.call(pageNumber) ?? true);
    }
    return true;
  }

  bool _sameQuery(Object a, Object b) {
    if (a is String && b is String) return a == b;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    return false;
  }

  Object get _query {
    final query = _state?.query ?? '';
    if (query is String) {
      if (_rawQuery != query) {
        _rawQuery = query;
        _normalizedQuery = normalizeFindText(query).text;
      }
      return _normalizedQuery!;
    }
    if (query is List) {
      return query
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .map((value) => normalizeFindText(value).text)
          .toList();
    }
    return '';
  }

  List<FindMatch> match(Object query, String pageContent, int pageIndex) {
    final state = _state ?? const FindParameters();
    final pageSearch = state.matchDiacritics
        ? _SearchText(pageContent, List.generate(pageContent.length, (i) => i))
        : _withoutDiacritics(pageContent);
    final terms = query is String
        ? <String>[query]
        : (query as List).whereType<String>().toList()
      ..sort((a, b) => b.compareTo(a));
    final matches = <FindMatch>[];
    for (var term in terms) {
      if (!state.matchDiacritics) term = _withoutDiacritics(term).text;
      if (term.isEmpty) continue;
      final pattern = _queryPattern(term);
      final regexp = RegExp(pattern, caseSensitive: state.caseSensitive);
      for (final result in regexp.allMatches(pageSearch.text)) {
        if (result.end == result.start) continue;
        final normalizedStart = pageSearch.toNormalized[result.start];
        final normalizedEnd = pageSearch.toNormalized[result.end - 1] + 1;
        if (state.entireWord &&
            !_isEntireWord(pageContent, normalizedStart,
                normalizedEnd - normalizedStart)) {
          continue;
        }
        matches
            .add(FindMatch(normalizedStart, normalizedEnd - normalizedStart));
      }
    }
    matches.sort((a, b) {
      final byIndex = a.index.compareTo(b.index);
      return byIndex != 0 ? byIndex : b.length.compareTo(a.length);
    });
    // Alternation in JS reports only the longest term at a position.
    final unique = <FindMatch>[];
    for (final item in matches) {
      if (unique.any((accepted) =>
          item.index < accepted.index + accepted.length &&
          item.index + item.length > accepted.index)) {
        continue;
      }
      unique.add(item);
    }
    return unique;
  }

  String _queryPattern(String query) {
    final output = StringBuffer();
    var index = 0;
    while (index < query.length) {
      // Read the rune at this UTF-16 position without depending on characters.
      final current = query.codeUnitAt(index);
      final width = current >= 0xd800 && current <= 0xdbff ? 2 : 1;
      final actualRune = width == 2
          ? 0x10000 +
              ((current - 0xd800) << 10) +
              (query.codeUnitAt(index + 1) - 0xdc00)
          : current;
      if (_isWhitespace(actualRune)) {
        while (index + width < query.length &&
            _isWhitespace(query.codeUnitAt(index + width))) {
          index += width;
        }
        output.write(r'[ ]+');
      } else {
        final value = String.fromCharCode(actualRune);
        final escaped = RegExp.escape(value);
        if (getCharacterType(actualRune) == CharacterType.punctuation) {
          if (index > 0) output.write(r'[ ]*');
          output.write(escaped);
          if (index + width < query.length) output.write(r'[ ]*');
        } else {
          output.write(escaped);
        }
      }
      index += width;
    }
    var result = output.toString();
    if (result.endsWith(r'[ ]*')) {
      result = result.substring(0, result.length - 5);
    }
    return result;
  }

  bool _isWhitespace(int rune) =>
      rune == 0x20 || rune == 0x09 || rune == 0x0a || rune == 0x0d;

  bool _isEntireWord(String content, int start, int length) {
    int? previous;
    for (var i = start - 1; i >= 0; i--) {
      final rune = content.codeUnitAt(i);
      if (!isCombiningMark(rune)) {
        previous = rune;
        break;
      }
    }
    if (previous != null &&
        start < content.length &&
        getCharacterType(previous) ==
            getCharacterType(content.codeUnitAt(start))) {
      return false;
    }
    int? next;
    for (var i = start + length; i < content.length; i++) {
      final rune = content.codeUnitAt(i);
      if (!isCombiningMark(rune)) {
        next = rune;
        break;
      }
    }
    if (next != null &&
        start + length > 0 &&
        getCharacterType(next) ==
            getCharacterType(content.codeUnitAt(start + length - 1))) {
      return false;
    }
    return true;
  }

  void _extractText() {
    if (_extractTextPromises.isNotEmpty) return;
    final count = _linkService.pagesCount as int;
    _pageData = List<NormalizedText?>.filled(count, null);
    var deferred = Future<void>.value();
    final document = _pdfDocument;
    for (var index = 0; index < count; index++) {
      final completer = Completer<void>();
      _extractTextPromises.add(completer.future);
      final pageIndex = index;
      deferred = deferred.then((_) async {
        if (document != _pdfDocument) {
          completer.complete();
          return;
        }
        try {
          final dynamic page = await document.getPage(pageIndex + 1);
          final dynamic textContent = await page.getTextContent();
          final buffer = StringBuffer();
          final dynamic rawItems =
              textContent is Map ? textContent['items'] : textContent.items;
          for (final dynamic item in rawItems as Iterable) {
            final String text = item is Map
                ? (item['str'] as String? ?? '')
                : item.str as String;
            final bool hasEol =
                item is Map ? item['hasEOL'] == true : item.hasEOL == true;
            buffer.write(text);
            if (hasEol) buffer.write('\n');
          }
          _pageData[pageIndex] = normalizeFindText(buffer.toString());
        } catch (_) {
          _pageData[pageIndex] = normalizeFindText('');
        } finally {
          completer.complete();
        }
      });
    }
  }

  void _calculateMatch(int pageIndex) {
    if (_state == null) return;
    final query = _query;
    if ((query is String && query.isEmpty) ||
        (query is List && query.isEmpty)) {
      return;
    }
    final data = _pageData[pageIndex]!;
    final found = match(query, data.text, pageIndex);
    final positions = <int>[];
    final lengths = <int>[];
    for (final item in found) {
      final range = data.originalRange(item.index, item.length);
      if (range.$2 > 0) {
        positions.add(range.$1);
        lengths.add(range.$2);
      }
    }
    _ensurePageSlot(_pageMatches, pageIndex);
    _ensurePageSlot(_pageMatchesLength, pageIndex);
    _pageMatches[pageIndex] = positions;
    _pageMatchesLength[pageIndex] = lengths;
    if (_state!.highlightAll) _updatePage(pageIndex);
    if (_resumePageIndex == pageIndex) {
      _resumePageIndex = null;
      _nextPageMatch();
    }
    _matchesCountTotal += positions.length;
    if (_updateMatchesCountOnProgress) {
      if (positions.isNotEmpty) _updateUiResultsCount();
    } else if (++_visitedPagesCount == (_linkService.pagesCount as int)) {
      _updateUiResultsCount();
    }
  }

  void _ensurePageSlot(List<List<int>?> list, int index) {
    while (list.length <= index) list.add(null);
  }

  void _nextMatch() {
    final state = _state;
    if (state == null) return;
    final previous = state.findPrevious;
    final currentPage = (_linkService.page as int) - 1;
    final count = _linkService.pagesCount as int;
    _highlightMatches = true;
    if (_dirtyMatch) {
      _dirtyMatch = false;
      _selectedPage = _selectedMatch = -1;
      _offsetPage = currentPage;
      _offsetMatch = null;
      _offsetWrapped = false;
      _resumePageIndex = null;
      _pageMatches = [];
      _pageMatchesLength = [];
      _visitedPagesCount = _matchesCountTotal = 0;
      _updateAllPages();
      for (var i = 0; i < count; i++) {
        if (!_pendingFindMatches.add(i)) continue;
        _extractTextPromises[i].then((_) {
          _pendingFindMatches.remove(i);
          _calculateMatch(i);
        });
      }
    }
    final query = _query;
    if ((query is String && query.isEmpty) ||
        (query is List && query.isEmpty)) {
      _updateUiState(FindState.found);
      return;
    }
    if (_resumePageIndex != null) return;
    _pagesToSearch = count;
    if (_offsetMatch != null) {
      final matches = _pageMatches[_offsetPage!] ?? const <int>[];
      if ((!previous && _offsetMatch! + 1 < matches.length) ||
          (previous && _offsetMatch! > 0)) {
        _offsetMatch = previous ? _offsetMatch! - 1 : _offsetMatch! + 1;
        _updateMatch(true);
        return;
      }
      _advanceOffsetPage(previous);
    }
    _nextPageMatch();
  }

  void _nextPageMatch() {
    while (true) {
      final page = _offsetPage!;
      final matches = page < _pageMatches.length ? _pageMatches[page] : null;
      if (matches == null) {
        _resumePageIndex = page;
        return;
      }
      if (_matchesReady(matches)) return;
    }
  }

  bool _matchesReady(List<int> matches) {
    final previous = _state!.findPrevious;
    if (matches.isNotEmpty) {
      _offsetMatch = previous ? matches.length - 1 : 0;
      _updateMatch(true);
      return true;
    }
    _advanceOffsetPage(previous);
    if (_offsetWrapped) {
      _offsetMatch = null;
      if (_pagesToSearch! < 0) {
        _updateMatch(false);
        return true;
      }
    }
    return false;
  }

  void _advanceOffsetPage(bool previous) {
    final count = _linkService.pagesCount as int;
    _offsetPage = _offsetPage! + (previous ? -1 : 1);
    _offsetMatch = null;
    _pagesToSearch = _pagesToSearch! - 1;
    if (_offsetPage! >= count || _offsetPage! < 0) {
      _offsetPage = previous ? count - 1 : 0;
      _offsetWrapped = true;
    }
  }

  void _updateMatch([bool found = false]) {
    var result = FindState.notFound;
    final wrapped = _offsetWrapped;
    _offsetWrapped = false;
    if (found) {
      final previousPage = _selectedPage;
      _selectedPage = _offsetPage!;
      _selectedMatch = _offsetMatch!;
      result = wrapped ? FindState.wrapped : FindState.found;
      if (previousPage != -1 && previousPage != _selectedPage) {
        _updatePage(previousPage);
      }
    }
    _updateUiState(result, _state!.findPrevious);
    if (_selectedPage != -1) {
      _scrollMatches = true;
      _updatePage(_selectedPage);
    }
  }

  void _updatePage(int index) {
    if (_scrollMatches && _selectedPage == index) {
      _linkService.page = index + 1;
    }
    _eventBus.dispatch('updatetextlayermatches', {
      'source': this,
      'pageIndex': index,
    });
  }

  void _updateAllPages() => _eventBus.dispatch('updatetextlayermatches', {
        'source': this,
        'pageIndex': -1,
      });

  FindMatchesCount _requestMatchesCount() {
    var current = 0;
    var total = _matchesCountTotal;
    if (_selectedMatch != -1) {
      for (var i = 0; i < _selectedPage; i++) {
        current += i < _pageMatches.length ? _pageMatches[i]?.length ?? 0 : 0;
      }
      current += _selectedMatch + 1;
    }
    if (current < 1 || current > total) current = total = 0;
    return FindMatchesCount(current: current, total: total);
  }

  void _updateUiResultsCount() {
    _eventBus.dispatch('updatefindmatchescount', {
      'source': this,
      'matchesCount': _requestMatchesCount().toMap(),
    });
  }

  void _updateUiState(FindState findState, [bool previous = false]) {
    if (!_updateMatchesCountOnProgress &&
        (_visitedPagesCount != (_linkService.pagesCount as int) ||
            findState == FindState.pending)) {
      return;
    }
    _eventBus.dispatch('updatefindcontrolstate', {
      'source': this,
      'state': findState,
      'previous': previous,
      'entireWord': _state?.entireWord,
      'matchesCount': _requestMatchesCount().toMap(),
      'rawQuery': _state?.query,
    });
  }

  void _onFindBarClose(Object? event) {
    final document = _pdfDocument;
    _firstPage.future.then((_) {
      if (_pdfDocument == null ||
          (document != null && document != _pdfDocument)) return;
      _findTimeout?.cancel();
      _findTimeout = null;
      if (_resumePageIndex != null) {
        _resumePageIndex = null;
        _dirtyMatch = true;
      }
      _updateUiState(FindState.found);
      _highlightMatches = false;
      _updateAllPages();
    });
  }

  void _onPagesEdited(Object? event) {
    if (_extractTextPromises.isEmpty || event is! Map) return;
    final type = event['type'];
    final numbers =
        (event['pageNumbers'] as Iterable?)?.cast<int>() ?? const <int>[];
    if (type == 'copy') {
      _copiedPageData = {
        for (final pageNumber in numbers)
          pageNumber: (
            _extractTextPromises[pageNumber - 1],
            _pageData[pageNumber - 1],
          ),
      };
      return;
    }
    if (type == 'cancelCopy') {
      _copiedPageData = null;
      return;
    }
    if (type == 'delete') {
      _savedPageData = (_extractTextPromises, _pageData);
    }
    if (type == 'cancelDelete') {
      final saved = _savedPageData;
      if (saved != null) {
        _extractTextPromises = saved.$1;
        _pageData = saved.$2;
      }
      return;
    }
    if (type == 'cleanSavedData') {
      _savedPageData = null;
      return;
    }
    _findTimeout?.cancel();
    _findTimeout = null;
    _resumePageIndex = null;
    _dirtyMatch = true;
    final previousPromises = _extractTextPromises;
    final previousData = _pageData;
    final mapper = event['pagesMapper'];
    final remappedPromises = <Future<void>>[];
    final remappedData = <NormalizedText?>[];
    if (mapper != null) {
      final pageCount = mapper.pagesNumber as int;
      for (var pageNumber = 1; pageNumber <= pageCount; pageNumber++) {
        final previousPage = mapper.getPrevPageNumber(pageNumber) as int;
        if (previousPage < 0) {
          final copied = _copiedPageData?[-previousPage];
          remappedPromises.add(copied?.$1 ?? Future<void>.value());
          remappedData.add(copied?.$2 ?? normalizeFindText(''));
        } else {
          final index = previousPage - 1;
          remappedPromises.add(index >= 0 && index < previousPromises.length
              ? previousPromises[index]
              : Future<void>.value());
          remappedData.add(index >= 0 && index < previousData.length
              ? previousData[index]
              : normalizeFindText(''));
        }
      }
    }
    _extractTextPromises = remappedPromises;
    _pageData = remappedData;
    _pendingFindMatches.clear();
    if (_extractTextPromises.isEmpty) _extractText();
    if (_state != null) _nextMatch();
  }
}
