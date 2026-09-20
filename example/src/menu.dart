// Copyright 2025 Mozilla Foundation
// Licensed under the Apache License, Version 2.0.

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Keyboard-accessible popup menu used by viewer management controls.
final class Menu {
  Menu(this.menu, this.triggeringButton, [List<web.HTMLElement>? items])
      : menuItems = items ?? _queryButtons(menu) {
    _setUpMenu();
  }

  final web.HTMLElement menu;
  final web.HTMLElement triggeringButton;
  final List<web.HTMLElement> menuItems;
  final web.AbortController _menuController = web.AbortController();
  web.AbortController? _openController;
  int _lastIndex = -1;
  bool _destroyed = false;

  bool get isOpen => _openController != null;

  void open() {
    if (_destroyed || isOpen) return;
    triggeringButton.setAttribute('aria-expanded', 'true');
    final controller = _openController = web.AbortController();
    final signal = controller.signal;
    web.window.addEventListener(
        'pointerdown',
        ((web.Event event) {
          final target = event.target;
          if (target is web.Node &&
              !triggeringButton.contains(target) &&
              !menu.contains(target)) {
            close();
          }
        }).toJS,
        web.AddEventListenerOptions(signal: signal));
    web.window.addEventListener('blur', ((web.Event _) => close()).toJS,
        web.AddEventListenerOptions(signal: signal));
    menu.addEventListener('focusout', _onFocusOut.toJS,
        web.AddEventListenerOptions(signal: signal));
  }

  void close() {
    final controller = _openController;
    if (controller == null) return;
    triggeringButton.setAttribute('aria-expanded', 'false');
    controller.abort();
    _openController = null;
    if (menu.contains(web.document.activeElement)) {
      Timer.run(() {
        if (!menu.contains(web.document.activeElement)) {
          triggeringButton.focus();
        }
      });
    }
    _lastIndex = -1;
  }

  void destroy() {
    if (_destroyed) return;
    close();
    _menuController.abort();
    _destroyed = true;
  }

  void _onFocusOut(web.Event rawEvent) {
    final event = rawEvent as web.FocusEvent;
    final related = event.relatedTarget;
    if (related is! web.Node ||
        (!triggeringButton.contains(related) && !menu.contains(related))) {
      close();
    }
  }

  void _setUpMenu() {
    final signal = _menuController.signal;
    triggeringButton.addEventListener(
        'click',
        ((web.Event _) {
          isOpen ? close() : open();
        }).toJS,
        web.AddEventListenerOptions(signal: signal));
    triggeringButton.addEventListener('focusout', _onFocusOut.toJS,
        web.AddEventListenerOptions(signal: signal));
    menu.addEventListener(
        'keydown',
        ((web.Event rawEvent) {
          final event = rawEvent as web.KeyboardEvent;
          switch (event.key) {
            case 'Escape':
              close();
            case 'ArrowDown':
              _goToNextItem(event.target, true);
            case 'ArrowUp':
              _goToNextItem(event.target, false);
            case 'Home':
              _firstEnabled()?.focus();
            case 'End':
              _lastEnabled()?.focus();
            default:
              final key = event.key;
              if (RegExp(r'^\p{L}$', unicode: true).hasMatch(key)) {
                final character = key.toLowerCase();
                _goToNextItem(
                    event.target,
                    true,
                    (item) => (item.textContent ?? '')
                        .trim()
                        .toLowerCase()
                        .startsWith(character));
              } else {
                return;
              }
          }
          _stopEvent(event);
        }).toJS,
        web.AddEventListenerOptions(signal: signal, capture: true));
    menu.addEventListener(
        'contextmenu',
        ((web.Event event) {
          event.preventDefault();
        }).toJS,
        web.AddEventListenerOptions(signal: signal));
    menu.addEventListener('click', ((web.Event _) => close()).toJS,
        web.AddEventListenerOptions(signal: signal, capture: true));
    triggeringButton.addEventListener(
        'keydown',
        ((web.Event rawEvent) {
          final event = rawEvent as web.KeyboardEvent;
          switch (event.key) {
            case ' ':
            case 'Enter':
            case 'ArrowDown':
            case 'Home':
              _stopEvent(event);
              open();
              _firstEnabled()?.focus();
            case 'ArrowUp':
            case 'End':
              _stopEvent(event);
              open();
              _lastEnabled()?.focus();
            case 'Escape':
              close();
              _stopEvent(event);
          }
        }).toJS,
        web.AddEventListenerOptions(signal: signal));
  }

  web.HTMLElement? _firstEnabled() {
    for (final item in menuItems) {
      if (_isEnabled(item)) return item;
    }
    return null;
  }

  web.HTMLElement? _lastEnabled() {
    for (final item in menuItems.reversed) {
      if (_isEnabled(item)) return item;
    }
    return null;
  }

  bool _isEnabled(web.HTMLElement item) =>
      !(item is web.HTMLButtonElement && item.disabled) &&
      !item.classList.contains('hidden');

  void _goToNextItem(web.EventTarget? target, bool forward,
      [bool Function(web.HTMLElement item)? check]) {
    if (menuItems.isEmpty) return;
    var index = _lastIndex == -1
        ? menuItems.indexWhere((item) => identical(item, target))
        : _lastIndex;
    if (index < 0) index = forward ? -1 : 0;
    final increment = forward ? 1 : menuItems.length - 1;
    for (var count = 0; count < menuItems.length; count++) {
      index = (index + increment) % menuItems.length;
      final item = menuItems[index];
      if (_isEnabled(item) && (check?.call(item) ?? true)) {
        item.focus();
        _lastIndex = index;
        return;
      }
    }
  }

  static void _stopEvent(web.Event event) {
    event
      ..preventDefault()
      ..stopPropagation();
  }

  static List<web.HTMLElement> _queryButtons(web.HTMLElement menu) {
    final nodes = menu.querySelectorAll('button');
    final result = <web.HTMLElement>[];
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes.item(index);
      if (node is web.HTMLElement) result.add(node);
    }
    return result;
  }
}
