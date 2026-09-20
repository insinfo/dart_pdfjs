// Copyright 2017 Mozilla Foundation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:convert';
import 'event_utils.dart';
import 'pdf_history_environment_stub.dart'
    if (dart.library.js_interop) 'pdf_history_environment_web.dart' as platform;
import 'pdf_link_service.dart';
import 'ui_utils.dart' show isValidRotation, parseQueryString;

const int hashChangeTimeoutMilliseconds = 1000;
const int positionUpdatedThreshold = 50;
const int updateViewareaTimeoutMilliseconds = 1000;

typedef HistoryEventCanceler = void Function();

/// Browser operations required by [PDFHistory].
///
/// Keeping these operations behind a narrow interface makes the complete
/// history state machine usable in browser builds and deterministic in tests.
abstract interface class PDFHistoryEnvironment {
  Map<String, dynamic>? get state;
  String get hash;
  String get href;
  String get protocol;
  bool get wasReloaded;

  void replaceState(Map<String, dynamic> state, String? url);
  void pushState(Map<String, dynamic> state, String? url);
  void back();
  void forward();

  HistoryEventCanceler onPopState(
    void Function(Map<String, dynamic>? state) listener,
  );
  HistoryEventCanceler onPageHide(void Function() listener);
  Future<void> waitForHashChange(Duration timeout);
}

/// Current viewport details carried by the viewer's `updateviewarea` event.
final class PDFHistoryLocation {
  const PDFHistoryLocation({
    required this.pdfOpenParams,
    required this.pageNumber,
    required this.rotation,
  });

  final String pdfOpenParams;
  final int pageNumber;
  final int rotation;
}

/// Maintains PDF destinations in the browser session history.
///
/// This is a direct port of `web/pdf_history.js`. It deliberately owns the
/// throttling and temporary-entry behavior because those details prevent the
/// browser Back button from being flooded while the user scrolls.
final class PDFHistory implements PDFLinkHistory {
  PDFHistory({
    required this.linkService,
    required this.eventBus,
    PDFHistoryEnvironment? environment,
    this.hashChangeTimeout =
        const Duration(milliseconds: hashChangeTimeoutMilliseconds),
    this.updateViewareaTimeout =
        const Duration(milliseconds: updateViewareaTimeoutMilliseconds),
  }) : environment = environment ?? platform.createPDFHistoryEnvironment() {
    eventBus.internalOn('pagesinit', _pagesInitListener);
  }

  final PDFLinkService linkService;
  final EventBus eventBus;
  final PDFHistoryEnvironment environment;
  final Duration hashChangeTimeout;
  final Duration updateViewareaTimeout;

  bool _initialized = false;
  String _fingerprint = '';
  bool _updateUrl = false;
  bool _isPagesLoaded = false;
  bool _popStateInProgress = false;
  int _blockHashChange = 0;
  String _currentHash = '';
  int _numPositionUpdates = 0;
  int _uid = 0;
  int _maxUid = 0;
  Map<String, dynamic>? _destination;
  Map<String, dynamic>? _position;
  Timer? _updateViewareaTimer;
  String? _initialBookmark;
  int? _initialRotation;
  EventBusListener? _updateViewareaListener;
  HistoryEventCanceler? _cancelPopState;
  HistoryEventCanceler? _cancelPageHide;

  bool get initialized => _initialized;
  bool get popStateInProgress =>
      _initialized && (_popStateInProgress || _blockHashChange > 0);
  String? get initialBookmark => _initialized ? _initialBookmark : null;
  int? get initialRotation => _initialized ? _initialRotation : null;

  void _pagesInitListener(Object? _) {
    _isPagesLoaded = false;
    eventBus.internalOn('pagesloaded', (Object? event) {
      final count = _readInt(event, 'pagesCount') ?? 0;
      _isPagesLoaded = count != 0;
    }, once: true);
  }

  /// Initializes history for [fingerprint], reusing a valid browser entry or
  /// the current URL hash when possible.
  void initialize({
    required String fingerprint,
    bool resetHistory = false,
    bool updateUrl = false,
  }) {
    if (fingerprint.isEmpty) return;
    if (_initialized) reset();

    final reInitialized =
        _fingerprint.isNotEmpty && _fingerprint != fingerprint;
    _fingerprint = fingerprint;
    _updateUrl = updateUrl;
    _initialized = true;
    _bindEvents();

    final state = environment.state;
    _popStateInProgress = false;
    _blockHashChange = 0;
    _currentHash = environment.hash;
    _numPositionUpdates = 0;
    _uid = _maxUid = 0;
    _destination = null;
    _position = null;

    if (!_isValidState(state, checkReload: true) || resetHistory) {
      final parsed = _parseCurrentHash(checkNamedDest: true);
      if ((parsed['hash'] as String).isEmpty || reInitialized || resetHistory) {
        _pushOrReplaceState(null, forceReplace: true);
      } else {
        _pushOrReplaceState(parsed, forceReplace: true);
      }
      return;
    }

    final destination = _asStringMap(state!['destination'])!;
    _updateInternalState(destination, state['uid'] as int,
        removeTemporary: true);
    final rotation = destination['rotation'];
    if (rotation is int) _initialRotation = rotation;
    if (destination['dest'] is List) {
      _initialBookmark = jsonEncode(destination['dest']);
      _destination!['page'] = null;
    } else if (destination['hash'] is String) {
      _initialBookmark = destination['hash'] as String;
    } else if (destination['page'] is int) {
      _initialBookmark = 'page=${destination['page']}';
    }
  }

  /// Stops updates and detaches listeners. The final viewport is preserved if
  /// the current browser entry is empty or temporary.
  void reset() {
    if (_initialized) {
      _pageHide();
      _initialized = false;
      _unbindEvents();
    }
    _updateViewareaTimer?.cancel();
    _updateViewareaTimer = null;
    _initialBookmark = null;
    _initialRotation = null;
  }

  @override
  void pushDestination({
    String? namedDestination,
    required List<dynamic> explicitDestination,
    required int pageNumber,
  }) {
    push(
      namedDest: namedDestination,
      explicitDest: explicitDestination,
      pageNumber: pageNumber,
    );
  }

  void push({
    String? namedDest,
    required List<dynamic> explicitDest,
    required int? pageNumber,
  }) {
    if (!_initialized) return;
    if (!_isValidPage(pageNumber)) {
      if (pageNumber != null || _destination != null) return;
    }
    final hash = namedDest ?? jsonEncode(explicitDest);
    if (hash.isEmpty) return;

    var forceReplace = false;
    final current = _destination;
    if (current != null &&
        (isDestHashesEqual(current['hash'], hash) ||
            isDestArraysEqual(current['dest'], explicitDest))) {
      if (current['page'] != null) return;
      forceReplace = true;
    }
    if (_popStateInProgress && !forceReplace) return;
    _pushOrReplaceState(<String, dynamic>{
      'dest': List<dynamic>.from(explicitDest),
      'hash': hash,
      'page': pageNumber,
      'rotation': linkService.rotation,
    }, forceReplace: forceReplace);
    _deferPopStateReset();
  }

  @override
  void pushPage(int pageNumber) {
    if (!_initialized || !_isValidPage(pageNumber)) return;
    if (_destination?['page'] == pageNumber || _popStateInProgress) return;
    _pushOrReplaceState(<String, dynamic>{
      'dest': null,
      'hash': 'page=$pageNumber',
      'page': pageNumber,
      'rotation': linkService.rotation,
    });
    _deferPopStateReset();
  }

  void _deferPopStateReset() {
    if (_popStateInProgress) return;
    _popStateInProgress = true;
    Future<void>.microtask(() => _popStateInProgress = false);
  }

  @override
  void pushCurrentPosition() {
    if (_initialized && !_popStateInProgress) _tryPushCurrentPosition();
  }

  @override
  void back() {
    if (!_initialized || _popStateInProgress) return;
    final state = environment.state;
    if (_isValidState(state) && (state!['uid'] as int) > 0) {
      environment.back();
    }
  }

  @override
  void forward() {
    if (!_initialized || _popStateInProgress) return;
    final state = environment.state;
    if (_isValidState(state) && (state!['uid'] as int) < _maxUid) {
      environment.forward();
    }
  }

  void _pushOrReplaceState(
    Map<String, dynamic>? destination, {
    bool forceReplace = false,
  }) {
    final shouldReplace = forceReplace || _destination == null;
    final newState = <String, dynamic>{
      'fingerprint': _fingerprint,
      'uid': shouldReplace ? _uid : _uid + 1,
      'destination':
          destination == null ? null : Map<String, dynamic>.from(destination),
    };
    _updateInternalState(destination, newState['uid'] as int);

    String? newUrl;
    final hash = destination?['hash'];
    if (_updateUrl && hash is String && environment.protocol != 'file:') {
      newUrl = updateUrlHash(environment.href, hash);
    }
    if (shouldReplace) {
      environment.replaceState(newState, newUrl);
    } else {
      environment.pushState(newState, newUrl);
    }
  }

  void _tryPushCurrentPosition({bool temporary = false}) {
    if (_position == null) return;
    final position = Map<String, dynamic>.from(_position!);
    if (temporary) position['temporary'] = true;
    final destination = _destination;
    if (destination == null) {
      _pushOrReplaceState(position);
      return;
    }
    if (destination['temporary'] == true) {
      _pushOrReplaceState(position, forceReplace: true);
      return;
    }
    if (destination['hash'] == position['hash']) return;
    if (destination['page'] == null &&
        _numPositionUpdates <= positionUpdatedThreshold) {
      return;
    }

    var forceReplace = false;
    final destinationPage = destination['page'];
    final first = position['first'];
    final page = position['page'];
    if (destinationPage is int &&
        first is int &&
        page is int &&
        destinationPage >= first &&
        destinationPage <= page) {
      if (destination.containsKey('dest') || destination['first'] == null) {
        return;
      }
      forceReplace = true;
    }
    _pushOrReplaceState(position, forceReplace: forceReplace);
  }

  bool _isValidPage(Object? value) =>
      value is int && value > 0 && value <= linkService.pagesCount;

  bool _isValidState(
    Map<String, dynamic>? state, {
    bool checkReload = false,
  }) {
    if (state == null) return false;
    if (state['fingerprint'] != _fingerprint) {
      if (!checkReload ||
          state['fingerprint'] is! String ||
          (state['fingerprint'] as String).length != _fingerprint.length ||
          !environment.wasReloaded) {
        return false;
      }
    }
    final uid = state['uid'];
    if (uid is! int || uid < 0) return false;
    return _asStringMap(state['destination']) != null;
  }

  void _updateInternalState(
    Map<String, dynamic>? destination,
    int uid, {
    bool removeTemporary = false,
  }) {
    _updateViewareaTimer?.cancel();
    _updateViewareaTimer = null;
    if (removeTemporary) destination?.remove('temporary');
    _destination = destination;
    _uid = uid;
    if (uid > _maxUid) _maxUid = uid;
    _numPositionUpdates = 0;
  }

  Map<String, dynamic> _parseCurrentHash({bool checkNamedDest = false}) {
    final rawHash = environment.hash;
    final hash = _legacyUnescape(
      rawHash.startsWith('#') ? rawHash.substring(1) : rawHash,
    );
    final parameters = parseQueryString(hash);
    final namedDest = parameters['nameddest'] ?? '';
    int? page = int.tryParse(parameters['page'] ?? '');
    if (!_isValidPage(page) || (checkNamedDest && namedDest.isNotEmpty)) {
      page = null;
    }
    return <String, dynamic>{
      'hash': hash,
      'page': page,
      'rotation': linkService.rotation,
    };
  }

  void _updateViewarea(Object? event) {
    _updateViewareaTimer?.cancel();
    _updateViewareaTimer = null;
    final location = _readLocation(event);
    if (location == null) return;
    _position = <String, dynamic>{
      'hash': location.pdfOpenParams.startsWith('#')
          ? location.pdfOpenParams.substring(1)
          : location.pdfOpenParams,
      'page': linkService.page,
      'first': location.pageNumber,
      'rotation': location.rotation,
    };
    if (_popStateInProgress) return;
    if (_isPagesLoaded &&
        _destination != null &&
        _destination!['page'] == null) {
      _numPositionUpdates++;
    }
    if (updateViewareaTimeout <= Duration.zero) return;
    _updateViewareaTimer = Timer(updateViewareaTimeout, () {
      if (!_popStateInProgress) _tryPushCurrentPosition(temporary: true);
      _updateViewareaTimer = null;
    });
  }

  void _popState(Map<String, dynamic>? state) {
    final newHash = environment.hash;
    final hashChanged = _currentHash != newHash;
    _currentHash = newHash;
    if (state == null) {
      _uid++;
      _pushOrReplaceState(_parseCurrentHash(), forceReplace: true);
      return;
    }
    if (!_isValidState(state)) return;
    _popStateInProgress = true;
    if (hashChanged) {
      _blockHashChange++;
      environment.waitForHashChange(hashChangeTimeout).whenComplete(() {
        if (_blockHashChange > 0) _blockHashChange--;
      });
    }

    final destination = _asStringMap(state['destination'])!;
    _updateInternalState(destination, state['uid'] as int,
        removeTemporary: true);
    final rotation = destination['rotation'];
    if (isValidRotation(rotation)) linkService.rotation = rotation as int;
    final explicitDestination = destination['dest'];
    if (explicitDestination is List) {
      unawaited(
        linkService.goToDestination(List<dynamic>.from(explicitDestination)),
      );
    } else if (destination['hash'] is String) {
      linkService.setHash(destination['hash'] as String);
    } else if (destination['page'] is int) {
      linkService.page = destination['page'] as int;
    }
    Future<void>.microtask(() => _popStateInProgress = false);
  }

  void _pageHide() {
    if (_destination == null || _destination!['temporary'] == true) {
      _tryPushCurrentPosition();
    }
  }

  void _bindEvents() {
    if (_updateViewareaListener != null) return;
    _updateViewareaListener = _updateViewarea;
    eventBus.internalOn('updateviewarea', _updateViewareaListener!);
    _cancelPopState = environment.onPopState(_popState);
    _cancelPageHide = environment.onPageHide(_pageHide);
  }

  void _unbindEvents() {
    final listener = _updateViewareaListener;
    if (listener != null) eventBus.internalOff('updateviewarea', listener);
    _updateViewareaListener = null;
    _cancelPopState?.call();
    _cancelPopState = null;
    _cancelPageHide?.call();
    _cancelPageHide = null;
  }
}

PDFHistoryLocation? _readLocation(Object? event) {
  Object? value = event;
  if (event is Map) value = event['location'];
  if (value is PDFHistoryLocation) return value;
  if (value is Map) {
    final params = value['pdfOpenParams'];
    final page = value['pageNumber'];
    final rotation = value['rotation'];
    if (params is String && page is int && rotation is int) {
      return PDFHistoryLocation(
        pdfOpenParams: params,
        pageNumber: page,
        rotation: rotation,
      );
    }
  }
  return null;
}

int? _readInt(Object? event, String key) {
  if (event is Map && event[key] is int) return event[key] as int;
  return null;
}

Map<String, dynamic>? _asStringMap(Object? value) {
  if (value is! Map) return null;
  return value.map((key, value) => MapEntry(key.toString(), value));
}

/// Compares destination hashes, including a `nameddest` open parameter.
bool isDestHashesEqual(Object? destinationHash, Object? pushedHash) {
  if (destinationHash is! String || pushedHash is! String) return false;
  if (destinationHash == pushedHash) return true;
  return parseQueryString(destinationHash)['nameddest'] == pushedHash;
}

/// Performs PDF.js' destination-array comparison.
///
/// Nested arrays are intentionally rejected; destination entries may be
/// primitives or plain dictionaries, whose key order is irrelevant.
bool isDestArraysEqual(Object? firstDestination, Object? secondDestination) {
  if (firstDestination is! List || secondDestination is! List) return false;
  if (firstDestination.length != secondDestination.length) return false;
  for (var index = 0; index < firstDestination.length; index++) {
    if (!_isDestinationEntryEqual(
      firstDestination[index],
      secondDestination[index],
    )) {
      return false;
    }
  }
  return true;
}

bool _isDestinationEntryEqual(Object? first, Object? second) {
  if (first is List || second is List) return false;
  if (first is Map && second is Map) {
    if (first.length != second.length) return false;
    for (final entry in first.entries) {
      if (!second.containsKey(entry.key) ||
          !_isDestinationEntryEqual(entry.value, second[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (first.runtimeType != second.runtimeType) return false;
  if (first is double && second is double && first.isNaN && second.isNaN) {
    return true;
  }
  return first == second;
}

/// Replaces the fragment of [url], preserving the behavior of PDF.js'
/// `updateUrlHash` utility.
String updateUrlHash(String url, String hash) {
  final fragmentStart = url.indexOf('#');
  final base = fragmentStart < 0 ? url : url.substring(0, fragmentStart);
  return '$base#$hash';
}

String _legacyUnescape(String value) {
  return value.replaceAllMapped(RegExp(r'%u([0-9a-fA-F]{4})|%([0-9a-fA-F]{2})'),
      (match) {
    final digits = match.group(1) ?? match.group(2)!;
    return String.fromCharCode(int.parse(digits, radix: 16));
  });
}
