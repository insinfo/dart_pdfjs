// Copyright 2018 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'util.dart';

abstract class CallbackKind {
  static const int data = 1;
  static const int error = 2;
}

abstract class StreamKind {
  static const int cancel = 1;
  static const int cancelComplete = 2;
  static const int close = 3;
  static const int enqueue = 4;
  static const int error = 5;
  static const int pull = 6;
  static const int pullComplete = 7;
  static const int startComplete = 8;
}

Exception wrapReason(dynamic ex) {
  if (ex is AbortException ||
      ex is InvalidPDFException ||
      ex is PasswordException ||
      ex is ResponseException ||
      ex is UnknownErrorException) {
    return ex;
  }

  if (!(ex is Exception || ex is Error)) {
    return UnknownErrorException(ex.toString(), ex.toString());
  }

  // Se vier com o "name" de uma exception portável serializada:
  final name = (ex is FormatException) ? 'FormatException' : ex.runtimeType.toString();
  switch (name) {
    case 'AbortException':
      return AbortException(ex.toString());
    case 'InvalidPDFException':
      return InvalidPDFException(ex.toString());
    case 'PasswordException':
      return PasswordException(ex.toString(), 0); // TODO: pass code
    case 'ResponseException':
      return ResponseException(ex.toString(), 0, false);
    case 'UnknownErrorException':
      return UnknownErrorException(ex.toString(), ex.toString());
  }
  return UnknownErrorException(ex.toString(), ex.toString());
}

abstract class ComObj {
  void addEventListener(String type, Function(dynamic event) listener, {dynamic signal});
  void postMessage(dynamic data, [List<dynamic>? transfers]);
}

class MessageHandler {
  final String sourceName;
  final String targetName;
  final ComObj comObj;

  int _callbackId = 1;
  // ignore: unused_field
  int _streamId = 1;

  // ignore: unused_field
  final Map<int, dynamic> _streamSinks = {};
  // ignore: unused_field
  final Map<int, dynamic> _streamControllers = {};
  final Map<int, Completer<dynamic>> _callbackCapabilities = {};
  final Map<String, Function> _actionHandler = {};

  MessageHandler(this.sourceName, this.targetName, this.comObj) {
    comObj.addEventListener('message', _onMessage);
  }

  void _onMessage(dynamic event) {
    final data = event.data;
    if (data['targetName'] != sourceName) {
      return;
    }
    if (data['stream'] != null) {
      _processStreamMessage(data);
      return;
    }
    if (data['callback'] != null) {
      final callbackId = data['callbackId'] as int;
      final capability = _callbackCapabilities[callbackId];
      if (capability == null) {
        throw StateError('Cannot resolve callback \$callbackId');
      }
      _callbackCapabilities.remove(callbackId);

      if (data['callback'] == CallbackKind.data) {
        capability.complete(data['data']);
      } else if (data['callback'] == CallbackKind.error) {
        capability.completeError(wrapReason(data['reason']));
      } else {
        throw StateError('Unexpected callback case');
      }
      return;
    }

    final actionName = data['action'] as String;
    final action = _actionHandler[actionName];
    if (action == null) {
      throw StateError('Unknown action from worker: \$actionName');
    }

    if (data['callbackId'] != null) {
      final targetName = data['sourceName'];
      
      Future.microtask(() async {
        try {
          final result = await action(data['data']);
          comObj.postMessage({
            'sourceName': sourceName,
            'targetName': targetName,
            'callback': CallbackKind.data,
            'callbackId': data['callbackId'],
            'data': result,
          });
        } catch (reason) {
          comObj.postMessage({
            'sourceName': sourceName,
            'targetName': targetName,
            'callback': CallbackKind.error,
            'callbackId': data['callbackId'],
            'reason': wrapReason(reason).toString(),
          });
        }
      });
      return;
    }
    
    if (data['streamId'] != null) {
      _createStreamSink(data);
      return;
    }
    action(data['data']);
  }

  void on(String actionName, Function handler) {
    if (_actionHandler.containsKey(actionName)) {
      throw StateError('There is already an actionName called "\$actionName"');
    }
    _actionHandler[actionName] = handler;
  }

  void send(String actionName, dynamic data, [List<dynamic>? transfers]) {
    comObj.postMessage({
      'sourceName': sourceName,
      'targetName': targetName,
      'action': actionName,
      'data': data,
    }, transfers);
  }

  Future<dynamic> sendWithPromise(String actionName, dynamic data, [List<dynamic>? transfers]) {
    final callbackId = _callbackId++;
    final capability = Completer<dynamic>();
    _callbackCapabilities[callbackId] = capability;
    try {
      comObj.postMessage({
        'sourceName': sourceName,
        'targetName': targetName,
        'action': actionName,
        'callbackId': callbackId,
        'data': data,
      }, transfers);
    } catch (ex) {
      capability.completeError(ex);
    }
    return capability.future;
  }

  /// TODO: Implement full SendWithStream logic based on dart:async StreamController.
  Stream<dynamic> sendWithStream(String actionName, dynamic data, dynamic queueingStrategy, [List<dynamic>? transfers]) {
    unreachable('sendWithStream not fully ported yet.');
  }

  void _createStreamSink(dynamic data) {
    // TODO: implement StreamSink mappings
  }

  void _processStreamMessage(dynamic data) {
    // TODO: implement
  }

  void destroy() {
    // _messageAC?.abort();
  }
}
