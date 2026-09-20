// Copyright 2016 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'event_utils.dart';
import 'l10n.dart';
import 'menu.dart';
import 'sidebar.dart';
import 'ui_utils.dart';

const String _sidebarWidthVariable = '--viewsManager-width';
const String _resizingClass = 'viewsManagerResizing';
const String _notificationClass = 'pdfSidebarNotification';

final class ViewsManagerElements {
  const ViewsManagerElements({
    required this.outerContainer,
    required this.sidebarContainer,
    required this.toggleButton,
    required this.resizer,
    required this.thumbnailButton,
    required this.outlineButton,
    required this.attachmentsButton,
    required this.layersButton,
    required this.thumbnailsView,
    required this.outlinesView,
    required this.attachmentsView,
    required this.layersView,
    required this.addFileButton,
    required this.currentOutlineButton,
    required this.selectorButton,
    required this.selectorOptions,
    required this.headerLabel,
    required this.status,
  });

  final web.HTMLDivElement outerContainer;
  final web.HTMLElement sidebarContainer;
  final web.HTMLButtonElement toggleButton;
  final web.HTMLElement resizer;
  final web.HTMLButtonElement thumbnailButton;
  final web.HTMLButtonElement outlineButton;
  final web.HTMLButtonElement attachmentsButton;
  final web.HTMLButtonElement layersButton;
  final web.HTMLElement thumbnailsView;
  final web.HTMLElement outlinesView;
  final web.HTMLElement attachmentsView;
  final web.HTMLElement layersView;
  final web.HTMLButtonElement addFileButton;
  final web.HTMLButtonElement currentOutlineButton;
  final web.HTMLButtonElement selectorButton;
  final web.HTMLElement selectorOptions;
  final web.HTMLElement headerLabel;
  final web.HTMLElement status;
}

typedef ViewsManagerMenuFactory = Object Function(
  web.HTMLElement options,
  web.HTMLButtonElement selector,
  List<web.HTMLButtonElement> buttons,
);

class ViewsManager extends Sidebar {
  ViewsManager({
    required this.elements,
    required this.eventBus,
    required L10n l10n,
    bool enableMerge = false,
    bool enableSplitMerge = false,
    web.AbortSignal? globalAbortSignal,
    ViewsManagerMenuFactory? menuFactory,
  })  : _enableMerge = enableMerge,
        _enableSplitMerge = enableSplitMerge,
        _hasAnimations =
            !web.window.matchMedia('(prefers-reduced-motion: reduce)').matches,
        super(
          SidebarElements(
            sidebar: elements.sidebarContainer,
            resizer: elements.resizer,
            toggleButton: elements.toggleButton,
          ),
          ltr: l10n.getDirection() == 'ltr',
          isResizerOnTheLeft: false,
          globalAbortSignal: globalAbortSignal,
        ) {
    elements.status.hidden = (!enableSplitMerge).toJS;
    elements.addFileButton.hidden = (!enableMerge).toJS;
    final menuItems = <web.HTMLButtonElement>[
      elements.thumbnailButton,
      elements.outlineButton,
      elements.attachmentsButton,
      elements.layersButton,
    ];
    menu = menuFactory?.call(
          elements.selectorOptions,
          elements.selectorButton,
          menuItems,
        ) ??
        Menu(elements.selectorOptions, elements.selectorButton, menuItems);
    _addEventListeners();
  }

  static const Map<String, String> _descriptions = {
    'pagesTitle': 'pdfjs-views-manager-pages-title',
    'outlinesTitle': 'pdfjs-views-manager-outlines-title1',
    'attachmentsTitle': 'pdfjs-views-manager-attachments-title',
    'layersTitle': 'pdfjs-views-manager-layers-title1',
    'notificationButton': 'pdfjs-toggle-views-manager-notification-button',
    'toggleButton': 'pdfjs-toggle-views-manager-button1',
  };

  final ViewsManagerElements elements;
  final EventBus eventBus;
  final bool _enableMerge;
  final bool _enableSplitMerge;
  final bool _hasAnimations;
  Object? menu;

  int active = SidebarView.thumbs;
  bool isInitialViewSet = false;
  bool isInitialEventDispatched = false;
  void Function()? onToggled;
  void Function()? onUpdateThumbnails;

  int get visibleView => isOpen ? active : SidebarView.none;

  @override
  void destroy() {
    final currentMenu = menu;
    if (currentMenu is Menu) currentMenu.destroy();
    menu = null;
    super.destroy();
  }

  void reset() {
    isInitialViewSet = false;
    isInitialEventDispatched = false;
    _hideUINotification(reset: true);
    switchView(SidebarView.thumbs);
    elements.outlineButton.disabled = false;
    elements.attachmentsButton.disabled = false;
    elements.layersButton.disabled = false;
    elements.currentOutlineButton.disabled = true;
  }

  void setInitialView([int view = SidebarView.none]) {
    if (isInitialViewSet) return;
    isInitialViewSet = true;
    if (view == SidebarView.none || view == SidebarView.unknown) {
      _dispatchEvent();
      return;
    }
    switchView(view, forceOpen: true);
    if (!isInitialEventDispatched) _dispatchEvent();
  }

  void switchView(int view, {bool forceOpen = false}) {
    final changed = view != active;
    var forceRendering = false;
    String? title;
    switch (view) {
      case SidebarView.none:
        if (isOpen) close();
        return;
      case SidebarView.thumbs:
        title = 'pagesTitle';
        forceRendering = isOpen && changed;
      case SidebarView.outline:
        if (elements.outlineButton.disabled) return;
        title = 'outlinesTitle';
      case SidebarView.attachments:
        if (elements.attachmentsButton.disabled) return;
        title = 'attachmentsTitle';
      case SidebarView.layers:
        if (elements.layersButton.disabled) return;
        title = 'layersTitle';
      default:
        return;
    }
    elements.status.hidden =
        (!_enableSplitMerge || view != SidebarView.thumbs).toJS;
    elements.addFileButton.hidden =
        (!_enableMerge || view != SidebarView.thumbs).toJS;
    elements.currentOutlineButton.hidden = (view != SidebarView.outline).toJS;
    elements.headerLabel
        .setAttribute('data-l10n-id', _descriptions[title] ?? '');
    active = view;
    toggleSelectedBtn(elements.thumbnailButton, view == SidebarView.thumbs,
        elements.thumbnailsView);
    toggleSelectedBtn(elements.outlineButton, view == SidebarView.outline,
        elements.outlinesView);
    toggleSelectedBtn(elements.attachmentsButton,
        view == SidebarView.attachments, elements.attachmentsView);
    toggleSelectedBtn(
        elements.layersButton, view == SidebarView.layers, elements.layersView);
    if (forceOpen && !isOpen) {
      open();
      return;
    }
    if (forceRendering) {
      onUpdateThumbnails?.call();
      onToggled?.call();
    }
    if (changed) _dispatchEvent();
  }

  void open() {
    if (isOpen) return;
    setOpenState(true);
    onResizing(width);
    toggleExpandedBtn(elements.toggleButton, true);
    switchView(active);
    if (_hasAnimations) {
      scheduleMicrotask(() => elements.outerContainer.classList
        ..add('viewsManagerMoving')
        ..add('viewsManagerOpen'));
    } else {
      elements.outerContainer.classList.add('viewsManagerOpen');
      eventBus.dispatch('resize', {'source': this});
    }
    if (active == SidebarView.thumbs) onUpdateThumbnails?.call();
    onToggled?.call();
    _dispatchEvent();
    _hideUINotification();
  }

  void close([web.UIEvent? event]) {
    if (!isOpen) return;
    setOpenState(false);
    toggleExpandedBtn(elements.toggleButton, false);
    elements.outerContainer.classList
      ..add('viewsManagerMoving')
      ..remove('viewsManagerOpen');
    onToggled?.call();
    _dispatchEvent();
    if ((event?.detail ?? 0) > 0) elements.toggleButton.blur();
  }

  @override
  void toggle([bool? visibility]) {
    final target = visibility ?? !isOpen;
    if (target) {
      open();
    } else {
      close();
    }
  }

  void _dispatchEvent() {
    if (isInitialViewSet) isInitialEventDispatched = true;
    eventBus.dispatch('sidebarviewchanged', {
      'source': this,
      'view': visibleView,
    });
  }

  void _showUINotification() {
    elements.toggleButton.setAttribute(
      'data-l10n-id',
      _descriptions['notificationButton']!,
    );
    if (!isOpen) elements.toggleButton.classList.add(_notificationClass);
  }

  void _hideUINotification({bool reset = false}) {
    if (isOpen || reset)
      elements.toggleButton.classList.remove(_notificationClass);
    if (reset) {
      elements.toggleButton.setAttribute(
        'data-l10n-id',
        _descriptions['toggleButton']!,
      );
    }
  }

  void _treeLoaded(int count, web.HTMLButtonElement button, int view) {
    button.disabled = count == 0;
    if (count > 0) {
      _showUINotification();
    } else if (active == view) {
      switchView(SidebarView.thumbs);
    }
  }

  static Object? _value(Object? data, String key) =>
      data is Map<Object?, Object?> ? data[key] : null;

  void _addEventListeners() {
    if (_hasAnimations) {
      elements.sidebarContainer.addEventListener(
          'transitionend',
          ((web.Event event) {
            if (identical(event.target, elements.sidebarContainer)) {
              elements.outerContainer.classList.remove('viewsManagerMoving');
              eventBus.dispatch('resize', {'source': this});
            }
          }).toJS);
    }
    elements.headerLabel.addEventListener(
        'dblclick',
        ((web.Event _) {
          if (active == SidebarView.outline) {
            eventBus.dispatch('toggleoutlinetree', {'source': this});
          } else if (active == SidebarView.layers) {
            eventBus.dispatch('resetlayers', {'source': this});
          }
        }).toJS);
    elements.thumbnailButton.addEventListener(
        'click', ((web.Event _) => switchView(SidebarView.thumbs)).toJS);
    elements.outlineButton.addEventListener(
        'click', ((web.Event _) => switchView(SidebarView.outline)).toJS);
    elements.attachmentsButton.addEventListener(
        'click', ((web.Event _) => switchView(SidebarView.attachments)).toJS);
    elements.layersButton.addEventListener(
        'click', ((web.Event _) => switchView(SidebarView.layers)).toJS);
    elements.currentOutlineButton.addEventListener(
        'click',
        ((web.Event _) {
          eventBus.dispatch('currentoutlineitem', {'source': this});
        }).toJS);
    eventBus.internalOn('outlineloaded', (data) {
      final count = (_value(data, 'outlineCount') as num?)?.toInt() ?? 0;
      _treeLoaded(count, elements.outlineButton, SidebarView.outline);
      final future = _value(data, 'currentOutlineItemPromise');
      if (future is Future<bool>) {
        future.then((enabled) {
          if (isInitialViewSet)
            elements.currentOutlineButton.disabled = !enabled;
        });
      }
    });
    eventBus.internalOn(
        'attachmentsloaded',
        (data) => _treeLoaded(
            (_value(data, 'attachmentsCount') as num?)?.toInt() ?? 0,
            elements.attachmentsButton,
            SidebarView.attachments));
    eventBus.internalOn(
        'layersloaded',
        (data) => _treeLoaded(
            (_value(data, 'layersCount') as num?)?.toInt() ?? 0,
            elements.layersButton,
            SidebarView.layers));
    eventBus.internalOn('presentationmodechanged', (data) {
      if (_value(data, 'state') == PresentationModeState.normal &&
          visibleView == SidebarView.thumbs) {
        onUpdateThumbnails?.call();
      }
    });
  }

  @override
  void onStartResizing() =>
      elements.outerContainer.classList.add(_resizingClass);

  @override
  void onStopResizing() {
    eventBus.dispatch('resize', {'source': this});
    elements.outerContainer.classList.remove(_resizingClass);
  }

  @override
  void onResizing(double newWidth) =>
      docStyle.setProperty(_sidebarWidthVariable, '${newWidth}px');
}
