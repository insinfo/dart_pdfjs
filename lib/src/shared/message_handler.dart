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

  final name = ex is Map
      ? ex['name']?.toString()
      : (ex is FormatException)
          ? 'FormatException'
          : ex.runtimeType.toString();
  final message = ex is Map ? ex['message']?.toString() ?? '' : ex.toString();
  switch (name) {
    case 'AbortException':
      return AbortException(message);
    case 'InvalidPDFException':
      return InvalidPDFException(message);
    case 'PasswordException':
      return PasswordException(
          message, ex is Map && ex['code'] is int ? ex['code'] as int : 0);
    case 'ResponseException':
      return ResponseException(
        message,
        ex is Map && ex['status'] is int ? ex['status'] as int : 0,
        ex is Map && ex['missing'] is bool ? ex['missing'] as bool : false,
      );
    case 'UnknownErrorException':
      return UnknownErrorException(
        message,
        ex is Map ? ex['details']?.toString() ?? message : ex.toString(),
      );
  }
  return UnknownErrorException(ex.toString(), ex.toString());
}

abstract class ComObj {
  void addEventListener(String type, Function(dynamic event) listener,
      {dynamic signal});
  void postMessage(dynamic data, [List<dynamic>? transfers]);
}

class MessageHandler {
  final String sourceName;
  final String targetName;
  final ComObj comObj;

  int _callbackId = 1;
  int _streamId = 1;

  final Map<int, _MessageStreamSink> _streamSinks = {};
  final Map<int, _MessageStreamController> _streamControllers = {};
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
        throw StateError('Cannot resolve callback $callbackId');
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
      throw StateError('Unknown action from worker: $actionName');
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
      throw StateError('There is already an actionName called "$actionName"');
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

  Future<dynamic> sendWithPromise(String actionName, dynamic data,
      [List<dynamic>? transfers]) {
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

  Stream<dynamic> sendWithStream(
      String actionName, dynamic data, dynamic queueingStrategy,
      [List<dynamic>? transfers]) {
    final streamId = _streamId++;
    final startCompleter = Completer<void>();
    final holder = _MessageStreamController(startCall: startCompleter);
    late final StreamController<dynamic> controller;

    controller = StreamController<dynamic>(
      onListen: () {
        holder.controller = controller;
        _streamControllers[streamId] = holder;
        comObj.postMessage({
          'sourceName': sourceName,
          'targetName': targetName,
          'action': actionName,
          'streamId': streamId,
          'data': data,
          'desiredSize': _desiredSize(queueingStrategy),
        }, transfers);
      },
      onResume: () {
        final streamController = _streamControllers[streamId];
        if (streamController == null || streamController.isClosed) {
          return;
        }
        final pullCompleter = Completer<void>();
        streamController.pullCall = pullCompleter;
        comObj.postMessage({
          'sourceName': sourceName,
          'targetName': targetName,
          'stream': StreamKind.pull,
          'streamId': streamId,
          'desiredSize': _desiredSize(queueingStrategy),
        });
      },
      onCancel: () {
        final streamController = _streamControllers[streamId];
        if (streamController == null || streamController.isClosed) {
          return null;
        }
        final cancelCompleter = Completer<void>();
        streamController.cancelCall = cancelCompleter;
        streamController.isClosed = true;
        comObj.postMessage({
          'sourceName': sourceName,
          'targetName': targetName,
          'stream': StreamKind.cancel,
          'streamId': streamId,
          'reason': {
            'name': 'AbortException',
            'message': 'Stream cancelled.',
          },
        });
        return cancelCompleter.future;
      },
    );

    startCompleter.future.catchError(controller.addError);
    return controller.stream;
  }

  void _createStreamSink(dynamic data) {
    final streamId = data['streamId'] as int;
    final targetName = data['sourceName'];
    final action = _actionHandler[data['action']];
    if (action == null) {
      throw StateError('Unknown action from worker: ${data['action']}');
    }

    final sink = _MessageStreamSink(
      onEnqueue: (chunk, size, transfers) {
        comObj.postMessage({
          'sourceName': sourceName,
          'targetName': targetName,
          'stream': StreamKind.enqueue,
          'streamId': streamId,
          'chunk': chunk,
        }, transfers);
      },
      onClose: () {
        comObj.postMessage({
          'sourceName': sourceName,
          'targetName': targetName,
          'stream': StreamKind.close,
          'streamId': streamId,
        });
        _streamSinks.remove(streamId);
      },
      onError: (reason) {
        comObj.postMessage({
          'sourceName': sourceName,
          'targetName': targetName,
          'stream': StreamKind.error,
          'streamId': streamId,
          'reason': _serializeReason(wrapReason(reason)),
        });
      },
      desiredSize: data['desiredSize'] is num
          ? (data['desiredSize'] as num).toDouble()
          : 1,
    );
    _streamSinks[streamId] = sink;

    Future.microtask(() async {
      try {
        await action(data['data'], sink);
        comObj.postMessage({
          'sourceName': sourceName,
          'targetName': targetName,
          'stream': StreamKind.startComplete,
          'streamId': streamId,
          'success': true,
        });
      } catch (reason) {
        comObj.postMessage({
          'sourceName': sourceName,
          'targetName': targetName,
          'stream': StreamKind.startComplete,
          'streamId': streamId,
          'reason': _serializeReason(wrapReason(reason)),
        });
      }
    });
  }

  void _processStreamMessage(dynamic data) {
    final streamId = data['streamId'] as int;
    final targetName = data['sourceName'];
    final streamController = _streamControllers[streamId];
    final streamSink = _streamSinks[streamId];

    switch (data['stream']) {
      case StreamKind.startComplete:
        if (data['success'] == true) {
          streamController?.startCall.complete();
        } else {
          streamController?.startCall.completeError(wrapReason(data['reason']));
        }
        break;
      case StreamKind.pullComplete:
        final completer = streamController?.pullCall;
        if (completer == null) {
          break;
        }
        if (data['success'] == true) {
          completer.complete();
        } else {
          completer.completeError(wrapReason(data['reason']));
        }
        streamController!.pullCall = null;
        break;
      case StreamKind.pull:
        if (streamSink == null) {
          comObj.postMessage({
            'sourceName': sourceName,
            'targetName': targetName,
            'stream': StreamKind.pullComplete,
            'streamId': streamId,
            'success': true,
          });
          break;
        }
        if (data['desiredSize'] is num) {
          streamSink.desiredSize = (data['desiredSize'] as num).toDouble();
        }
        Future.microtask(() async {
          try {
            await streamSink.onPull?.call();
            comObj.postMessage({
              'sourceName': sourceName,
              'targetName': targetName,
              'stream': StreamKind.pullComplete,
              'streamId': streamId,
              'success': true,
            });
          } catch (reason) {
            comObj.postMessage({
              'sourceName': sourceName,
              'targetName': targetName,
              'stream': StreamKind.pullComplete,
              'streamId': streamId,
              'reason': _serializeReason(wrapReason(reason)),
            });
          }
        });
        break;
      case StreamKind.enqueue:
        if (streamController == null || streamController.isClosed) {
          break;
        }
        streamController.controller?.add(data['chunk']);
        break;
      case StreamKind.close:
        if (streamController == null || streamController.isClosed) {
          break;
        }
        streamController.isClosed = true;
        streamController.controller?.close();
        _deleteStreamController(streamId);
        break;
      case StreamKind.error:
        if (streamController == null) {
          break;
        }
        streamController.controller?.addError(wrapReason(data['reason']));
        _deleteStreamController(streamId);
        break;
      case StreamKind.cancelComplete:
        final completer = streamController?.cancelCall;
        if (completer == null) {
          break;
        }
        if (data['success'] == true) {
          completer.complete();
        } else {
          completer.completeError(wrapReason(data['reason']));
        }
        _deleteStreamController(streamId);
        break;
      case StreamKind.cancel:
        if (streamSink == null) {
          break;
        }
        final reason = wrapReason(data['reason']);
        Future.microtask(() async {
          try {
            await streamSink.onCancel?.call(reason);
            comObj.postMessage({
              'sourceName': sourceName,
              'targetName': targetName,
              'stream': StreamKind.cancelComplete,
              'streamId': streamId,
              'success': true,
            });
          } catch (cancelReason) {
            comObj.postMessage({
              'sourceName': sourceName,
              'targetName': targetName,
              'stream': StreamKind.cancelComplete,
              'streamId': streamId,
              'reason': _serializeReason(wrapReason(cancelReason)),
            });
          }
        });
        streamSink.isCancelled = true;
        _streamSinks.remove(streamId);
        break;
      default:
        throw StateError('Unexpected stream case');
    }
  }

  void _deleteStreamController(int streamId) {
    _streamControllers.remove(streamId);
  }

  void destroy() {
    // _messageAC?.abort();
    _streamSinks.clear();
    _streamControllers.clear();
    _callbackCapabilities.clear();
  }
}

double _desiredSize(dynamic queueingStrategy) {
  if (queueingStrategy is Map && queueingStrategy['highWaterMark'] is num) {
    return (queueingStrategy['highWaterMark'] as num).toDouble();
  }
  return 1;
}

Map<String, dynamic> _serializeReason(Exception reason) {
  if (reason is AbortException) {
    return {'name': 'AbortException', 'message': reason.message};
  }
  if (reason is InvalidPDFException) {
    return {'name': 'InvalidPDFException', 'message': reason.message};
  }
  if (reason is PasswordException) {
    return {
      'name': 'PasswordException',
      'message': reason.message,
      'code': reason.code,
    };
  }
  if (reason is ResponseException) {
    return {
      'name': 'ResponseException',
      'message': reason.message,
      'status': reason.status,
      'missing': reason.missing,
    };
  }
  if (reason is UnknownErrorException) {
    return {
      'name': 'UnknownErrorException',
      'message': reason.message,
      'details': reason.details,
    };
  }
  return {
    'name': 'UnknownErrorException',
    'message': reason.toString(),
    'details': reason.toString(),
  };
}

class _MessageStreamController {
  _MessageStreamController({required this.startCall});

  StreamController<dynamic>? controller;
  final Completer<void> startCall;
  Completer<void>? pullCall;
  Completer<void>? cancelCall;
  bool isClosed = false;
}

class _MessageStreamSink {
  _MessageStreamSink({
    required void Function(dynamic chunk, double size, List<dynamic>? transfers)
        onEnqueue,
    required void Function() onClose,
    required void Function(dynamic reason) onError,
    required this.desiredSize,
  })  : _onEnqueue = onEnqueue,
        _onClose = onClose,
        _onError = onError;

  final void Function(dynamic chunk, double size, List<dynamic>? transfers)
      _onEnqueue;
  final void Function() _onClose;
  final void Function(dynamic reason) _onError;
  FutureOr<void> Function()? onPull;
  FutureOr<void> Function(dynamic reason)? onCancel;
  bool isCancelled = false;
  double desiredSize;

  void enqueue(dynamic chunk, {double size = 1, List<dynamic>? transfers}) {
    if (isCancelled) {
      return;
    }
    desiredSize -= size;
    _onEnqueue(chunk, size, transfers);
  }

  void close() {
    if (isCancelled) {
      return;
    }
    isCancelled = true;
    _onClose();
  }

  void error(dynamic reason) {
    if (isCancelled) {
      return;
    }
    isCancelled = true;
    _onError(reason);
  }
}
