// Copyright 2012 Mozilla Foundation
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
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

const String defaultScaleValue = 'auto';
const double defaultScale = 1.0;
const double defaultScaleDelta = 1.1;
const double minScale = 0.1;
const double maxScale = 25.0;
const double unknownScale = 0;
const double maxAutoScale = 1.25;
const int scrollbarPadding = 40;
const int verticalPadding = 5;

abstract final class PresentationModeState {
  static const int unknown = 0;
  static const int normal = 1;
  static const int changing = 2;
  static const int fullscreen = 3;
}

abstract final class SidebarView {
  static const int unknown = -1;
  static const int none = 0;
  static const int thumbs = 1;
  static const int outline = 2;
  static const int attachments = 3;
  static const int layers = 4;
}

abstract final class TextLayerMode {
  static const int disable = 0;
  static const int enable = 1;
  static const int enablePermissions = 2;
}

abstract final class ScrollMode {
  static const int unknown = -1;
  static const int vertical = 0;
  static const int horizontal = 1;
  static const int wrapped = 2;
  static const int page = 3;
}

abstract final class SpreadMode {
  static const int unknown = -1;
  static const int none = 0;
  static const int odd = 1;
  static const int even = 2;
}

abstract final class CursorTool {
  static const int select = 0;
  static const int hand = 1;
  static const int zoom = 2;
}

final RegExp autoPrintRegExp = RegExp(r'\bprint\s*\(');
final RegExp _invisibleCharsRegExp = RegExp(r'[\x00-\x1f]');

/// Scrolls [element] into view of its first scrollable offset parent.
void scrollIntoView(
  web.HTMLElement element, {
  num? left,
  num? top,
}) {
  var parent = element.offsetParent as web.HTMLElement?;
  if (parent == null) {
    return;
  }
  var offsetY = element.offsetTop + element.clientTop;
  var offsetX = element.offsetLeft + element.clientLeft;
  while (parent!.clientHeight == parent.scrollHeight &&
      parent.clientWidth == parent.scrollWidth) {
    offsetY += parent.offsetTop;
    offsetX += parent.offsetLeft;
    parent = parent.offsetParent as web.HTMLElement?;
    if (parent == null) return;
  }
  if (top != null) offsetY += top.round();
  if (left != null) {
    offsetX += left.round();
    parent.scrollLeft = offsetX;
  }
  parent.scrollTop = offsetY;
}

final class ScrollState {
  ScrollState({
    required this.lastX,
    required this.lastY,
    required this.eventHandler,
  });

  bool right = true;
  bool down = true;
  double lastX;
  double lastY;
  final JSFunction eventHandler;
}

/// Monitors scrolling, debouncing notifications to an animation frame.
ScrollState watchScroll(
  web.HTMLElement viewAreaElement,
  void Function(ScrollState state) callback, {
  web.AbortSignal? abortSignal,
}) {
  int? animationFrame;
  late final ScrollState state;
  late final JSFunction handler;
  handler = ((web.Event event) {
    if (animationFrame != null) return;
    animationFrame = web.window.requestAnimationFrame(((num _) {
      animationFrame = null;
      final currentX = viewAreaElement.scrollLeft;
      if (currentX != state.lastX) state.right = currentX > state.lastX;
      state.lastX = currentX;
      final currentY = viewAreaElement.scrollTop;
      if (currentY != state.lastY) state.down = currentY > state.lastY;
      state.lastY = currentY;
      callback(state);
    }).toJS);
  }).toJS;
  state = ScrollState(
    lastX: viewAreaElement.scrollLeft,
    lastY: viewAreaElement.scrollTop,
    eventHandler: handler,
  );
  final options = abortSignal == null
      ? web.AddEventListenerOptions(capture: true)
      : web.AddEventListenerOptions(capture: true, signal: abortSignal);
  viewAreaElement.addEventListener('scroll', handler, options);
  if (abortSignal != null) {
    abortSignal.addEventListener(
      'abort',
      ((web.Event _) {
        final frame = animationFrame;
        if (frame != null) web.window.cancelAnimationFrame(frame);
      }).toJS,
      web.AddEventListenerOptions(once: true),
    );
  }
  return state;
}

Map<String, String> parseQueryString(String query) {
  final result = <String, String>{};
  final source = query.startsWith('?') ? query.substring(1) : query;
  if (source.isEmpty) return result;
  for (final part in source.split('&')) {
    final separator = part.indexOf('=');
    final key = separator < 0 ? part : part.substring(0, separator);
    final value = separator < 0 ? '' : part.substring(separator + 1);
    result[Uri.decodeQueryComponent(key).toLowerCase()] =
        Uri.decodeQueryComponent(value);
  }
  return result;
}

String removeNullCharacters(String value, {bool replaceInvisible = false}) {
  if (!_invisibleCharsRegExp.hasMatch(value)) return value;
  if (replaceInvisible) {
    return value.replaceAllMapped(
      _invisibleCharsRegExp,
      (match) => match.group(0) == '\x00' ? '' : ' ',
    );
  }
  return value.replaceAll('\x00', '');
}

int binarySearchFirstItem<T>(
  List<T> items,
  bool Function(T item) condition, [
  int start = 0,
]) {
  var minIndex = start;
  var maxIndex = items.length - 1;
  if (maxIndex < 0 || !condition(items[maxIndex])) return items.length;
  if (condition(items[minIndex])) return minIndex;
  while (minIndex < maxIndex) {
    final currentIndex = (minIndex + maxIndex) >> 1;
    if (condition(items[currentIndex])) {
      maxIndex = currentIndex;
    } else {
      minIndex = currentIndex + 1;
    }
  }
  return minIndex;
}

List<int> approximateFraction(num x) {
  if (x.floor() == x) return <int>[x.toInt(), 1];
  final inverse = 1 / x;
  const limit = 8;
  if (inverse > limit) return const <int>[1, limit];
  if (inverse.floor() == inverse) return <int>[1, inverse.toInt()];
  final target = x > 1 ? inverse : x;
  var a = 0, b = 1, c = 1, d = 1;
  while (true) {
    final p = a + c, q = b + d;
    if (q > limit) break;
    if (target <= p / q) {
      c = p;
      d = q;
    } else {
      a = p;
      b = q;
    }
  }
  if (target - a / b < c / d - target) {
    return target == x ? <int>[a, b] : <int>[b, a];
  }
  return target == x ? <int>[c, d] : <int>[d, c];
}

num floorToDivide(num x, num divisor) => x - x % divisor;

final class PageSize {
  const PageSize({required this.width, required this.height});
  final double width;
  final double height;
}

PageSize getPageSizeInches({
  required List<num> view,
  required num userUnit,
  required int rotate,
}) {
  final width = ((view[2] - view[0]) / 72) * userUnit;
  final height = ((view[3] - view[1]) / 72) * userUnit;
  return rotate % 180 != 0
      ? PageSize(width: height.toDouble(), height: width.toDouble())
      : PageSize(width: width.toDouble(), height: height.toDouble());
}

/// Geometry used by visibility calculations. DOM elements can be adapted with
/// [DomElementGeometry], while tests and non-DOM callers can provide values.
abstract interface class ElementGeometry {
  num get offsetLeft;
  num get offsetTop;
  num get clientLeft;
  num get clientTop;
  num get clientWidth;
  num get clientHeight;
}

final class DomElementGeometry implements ElementGeometry {
  const DomElementGeometry(this.element);
  final web.HTMLElement element;
  @override
  num get offsetLeft => element.offsetLeft;
  @override
  num get offsetTop => element.offsetTop;
  @override
  int get clientLeft => element.clientLeft;
  @override
  int get clientTop => element.clientTop;
  @override
  int get clientWidth => element.clientWidth;
  @override
  int get clientHeight => element.clientHeight;
}

final class ViewportGeometry {
  const ViewportGeometry({
    required this.scrollTop,
    required this.scrollLeft,
    required this.clientHeight,
    required this.clientWidth,
  });
  factory ViewportGeometry.fromElement(web.HTMLElement element) =>
      ViewportGeometry(
        scrollTop: element.scrollTop,
        scrollLeft: element.scrollLeft,
        clientHeight: element.clientHeight,
        clientWidth: element.clientWidth,
      );
  final num scrollTop;
  final num scrollLeft;
  final int clientHeight;
  final int clientWidth;
}

final class ViewerElement<T> {
  const ViewerElement({required this.id, required this.div, this.data});
  final int id;
  final ElementGeometry div;
  final T? data;
}

final class VisibleArea {
  const VisibleArea({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });
  final num minX;
  final num minY;
  final num maxX;
  final num maxY;
}

final class VisibleElement<T> {
  const VisibleElement({
    required this.id,
    required this.x,
    required this.y,
    required this.view,
    required this.percent,
    required this.widthPercent,
    this.visibleArea,
  });
  final int id;
  final num x;
  final num y;
  final ViewerElement<T> view;
  final int percent;
  final int widthPercent;
  final VisibleArea? visibleArea;
}

final class VisibleElements<T> {
  const VisibleElements({
    required this.first,
    required this.last,
    required this.views,
    required this.ids,
  });
  final VisibleElement<T>? first;
  final VisibleElement<T>? last;
  final List<VisibleElement<T>> views;
  final Set<int> ids;
}

int backtrackBeforeAllVisibleElements<T>(
  int index,
  List<ViewerElement<T>> views,
  num top,
) {
  if (index < 2) return index;
  var element = views[index].div;
  var pageTop = element.offsetTop + element.clientTop;
  if (pageTop >= top) {
    element = views[index - 1].div;
    pageTop = element.offsetTop + element.clientTop;
  }
  for (var i = index - 2; i >= 0; --i) {
    element = views[i].div;
    if (element.offsetTop + element.clientTop + element.clientHeight <=
        pageTop) {
      break;
    }
    index = i;
  }
  return index;
}

VisibleElements<T> getVisibleElements<T>({
  required ViewportGeometry scrollElement,
  required List<ViewerElement<T>> views,
  bool sortByVisibility = false,
  bool horizontal = false,
  bool rtl = false,
}) {
  final top = scrollElement.scrollTop;
  final bottom = top + scrollElement.clientHeight;
  final left = scrollElement.scrollLeft;
  final right = left + scrollElement.clientWidth;

  bool bottomAfterTop(ViewerElement<T> view) {
    final element = view.div;
    return element.offsetTop + element.clientTop + element.clientHeight > top;
  }

  bool nextHorizontally(ViewerElement<T> view) {
    final element = view.div;
    final elementLeft = element.offsetLeft + element.clientLeft;
    final elementRight = elementLeft + element.clientWidth;
    return rtl ? elementLeft < right : elementRight > left;
  }

  final visible = <VisibleElement<T>>[];
  final ids = <int>{};
  var firstIndex = binarySearchFirstItem(
    views,
    horizontal ? nextHorizontally : bottomAfterTop,
  );
  if (firstIndex > 0 && firstIndex < views.length && !horizontal) {
    firstIndex = backtrackBeforeAllVisibleElements(firstIndex, views, top);
  }
  var lastEdge = horizontal ? right : -1;
  for (var i = firstIndex; i < views.length; i++) {
    final view = views[i];
    final element = view.div;
    final currentX = element.offsetLeft + element.clientLeft;
    final currentY = element.offsetTop + element.clientTop;
    final viewWidth = element.clientWidth;
    final viewHeight = element.clientHeight;
    final viewRight = currentX + viewWidth;
    final viewBottom = currentY + viewHeight;
    if (lastEdge == -1) {
      if (viewBottom >= bottom) lastEdge = viewBottom;
    } else if ((horizontal ? currentX : currentY) > lastEdge) {
      break;
    }
    if (viewBottom <= top ||
        currentY >= bottom ||
        viewRight <= left ||
        currentX >= right) {
      continue;
    }
    final minY = math.max(0, top - currentY);
    final minX = math.max(0, left - currentX);
    final hiddenHeight = minY + math.max(0, viewBottom - bottom);
    final hiddenWidth = minX + math.max(0, viewRight - right);
    final fractionHeight = (viewHeight - hiddenHeight) / viewHeight;
    final fractionWidth = (viewWidth - hiddenWidth) / viewWidth;
    final percent = (fractionHeight * fractionWidth * 100).truncate();
    visible.add(
      VisibleElement<T>(
        id: view.id,
        x: currentX,
        y: currentY,
        view: view,
        percent: percent,
        widthPercent: (fractionWidth * 100).truncate(),
        visibleArea: percent == 100
            ? null
            : VisibleArea(
                minX: minX,
                minY: minY,
                maxX: math.min(viewRight, right) - currentX,
                maxY: math.min(viewBottom, bottom) - currentY,
              ),
      ),
    );
    ids.add(view.id);
  }
  final first = visible.isEmpty ? null : visible.first;
  final last = visible.isEmpty ? null : visible.last;
  if (sortByVisibility) {
    visible.sort((a, b) {
      final percentage = a.percent - b.percent;
      return percentage != 0 ? -percentage : a.id - b.id;
    });
  }
  return VisibleElements(first: first, last: last, views: visible, ids: ids);
}

double normalizeWheelEventDirection(web.WheelEvent event) {
  var delta =
      math.sqrt(event.deltaX * event.deltaX + event.deltaY * event.deltaY);
  final angle = math.atan2(event.deltaY, event.deltaX);
  if (-0.25 * math.pi < angle && angle < 0.75 * math.pi) delta = -delta;
  return delta;
}

double normalizeWheelEventDelta(web.WheelEvent event) {
  var delta = normalizeWheelEventDirection(event);
  const mousePixelsPerLine = 30;
  const mouseLinesPerPage = 30;
  if (event.deltaMode == web.WheelEvent.DOM_DELTA_PIXEL) {
    delta /= mousePixelsPerLine * mouseLinesPerPage;
  } else if (event.deltaMode == web.WheelEvent.DOM_DELTA_LINE) {
    delta /= mouseLinesPerPage;
  }
  return delta;
}

bool isValidRotation(Object? angle) =>
    angle is int && angle.isFinite && angle % 90 == 0;

bool isValidScrollMode(Object? mode) =>
    mode is int && mode >= ScrollMode.vertical && mode <= ScrollMode.page;

bool isValidSpreadMode(Object? mode) =>
    mode is int && mode >= SpreadMode.none && mode <= SpreadMode.even;

bool isPortraitOrientation(PageSize size) => size.width <= size.height;

final Future<void> animationStarted = Future<void>.delayed(Duration.zero, () {
  final completer = Completer<void>();
  web.window.requestAnimationFrame(((num _) => completer.complete()).toJS);
  return completer.future;
});

web.CSSStyleDeclaration get docStyle =>
    (web.document.documentElement! as web.HTMLElement).style;

final class ProgressBar {
  ProgressBar(web.HTMLElement bar)
      : _classList = bar.classList,
        _style = bar.style;
  final web.DOMTokenList _classList;
  final web.CSSStyleDeclaration _style;
  Timer? _disableAutoFetchTimeout;
  double _percent = 0;
  bool _visible = true;

  double get percent => _percent;
  set percent(num value) {
    _percent = value.toDouble();
    if (_percent.isNaN) {
      _classList.add('indeterminate');
      return;
    }
    _classList.remove('indeterminate');
    _style.setProperty('--progressBar-percent', '$_percent%');
  }

  void setWidth(web.HTMLElement? viewer) {
    if (viewer == null) return;
    final container = viewer.parentNode;
    if (container is! web.HTMLElement) return;
    final width = container.offsetWidth - viewer.offsetWidth;
    if (width > 0) {
      _style.setProperty('--progressBar-end-offset', '${width}px');
    }
  }

  void setDisableAutoFetch([Duration delay = const Duration(seconds: 5)]) {
    if (_percent == 100 || _percent.isNaN) return;
    _disableAutoFetchTimeout?.cancel();
    show();
    _disableAutoFetchTimeout = Timer(delay, () {
      _disableAutoFetchTimeout = null;
      hide();
    });
  }

  void hide() {
    if (!_visible) return;
    _visible = false;
    _classList.add('hidden');
  }

  void show() {
    if (_visible) return;
    _visible = true;
    _classList.remove('hidden');
  }
}

web.Element? getActiveOrFocusedElement() {
  var current =
      web.document.activeElement ?? web.document.querySelector(':focus');
  while (current?.shadowRoot != null) {
    final root = current!.shadowRoot!;
    current = root.activeElement ?? root.querySelector(':focus');
  }
  return current;
}

final class ViewerModes {
  const ViewerModes({required this.scrollMode, required this.spreadMode});
  final int scrollMode;
  final int spreadMode;
}

ViewerModes apiPageLayoutToViewerModes(String? layout) {
  var scrollMode = ScrollMode.vertical;
  var spreadMode = SpreadMode.none;
  switch (layout) {
    case 'SinglePage':
      scrollMode = ScrollMode.page;
    case 'OneColumn':
      break;
    case 'TwoPageLeft':
      scrollMode = ScrollMode.page;
      spreadMode = SpreadMode.odd;
    case 'TwoColumnLeft':
      spreadMode = SpreadMode.odd;
    case 'TwoPageRight':
      scrollMode = ScrollMode.page;
      spreadMode = SpreadMode.even;
    case 'TwoColumnRight':
      spreadMode = SpreadMode.even;
  }
  return ViewerModes(scrollMode: scrollMode, spreadMode: spreadMode);
}

int apiPageModeToSidebarView(String? mode) => switch (mode) {
      'UseThumbs' => SidebarView.thumbs,
      'UseOutlines' => SidebarView.outline,
      'UseAttachments' => SidebarView.attachments,
      'UseOC' => SidebarView.layers,
      _ => SidebarView.none,
    };

void toggleCheckedBtn(web.HTMLElement button, bool toggle,
    [web.HTMLElement? view]) {
  button.classList.toggle('toggled', toggle);
  button.setAttribute('aria-checked', '$toggle');
  view?.classList.toggle('hidden', !toggle);
}

void toggleSelectedBtn(web.HTMLElement button, bool toggle,
    [web.HTMLElement? view]) {
  button.classList.toggle('selected', toggle);
  button.setAttribute('aria-selected', '$toggle');
  view?.classList.toggle('hidden', !toggle);
}

void toggleExpandedBtn(web.HTMLElement button, bool toggle,
    [web.HTMLElement? view]) {
  button.classList.toggle('toggled', toggle);
  button.setAttribute('aria-expanded', '$toggle');
  view?.classList.toggle('hidden', !toggle);
}

/// Dart doubles already use the f64 behavior of Chromium/Safari CSS calc.
double calcRound(num value) => value.toDouble();
