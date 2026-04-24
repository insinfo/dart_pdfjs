import 'package:test/test.dart';

import 'package:pdfjs/src/shared/message_handler.dart';

class MockComObj extends ComObj {
  Function(dynamic)? onMessage;
  dynamic lastMessage;

  @override
  void addEventListener(String type, Function(dynamic) listener, {dynamic signal}) {
    if (type == 'message') {
      onMessage = listener;
    }
  }

  @override
  void postMessage(dynamic data, [List<dynamic>? transfers]) {
    lastMessage = data;
    // Simulate loopback or assert directly
  }
}

class EventMock {
  final dynamic data;
  EventMock(this.data);
}

void main() {
  group('MessageHandler', () {
    test('Can register an action and send', () {
      final comObj = MockComObj();
      final handler = MessageHandler('source', 'target', comObj);

      handler.send('someAction', {'foo': 'bar'});
      expect(comObj.lastMessage, isNotNull);
      expect(comObj.lastMessage['action'], equals('someAction'));
      expect(comObj.lastMessage['data']['foo'], equals('bar'));
    });

    test('Can receive messages', () {
      final comObj = MockComObj();
      final handler = MessageHandler('source', 'target', comObj);

      bool actionCalled = false;
      handler.on('myAction', (data) {
        actionCalled = true;
        expect(data, equals(123));
      });

      // trigger from outside
      comObj.onMessage!(EventMock({
        'targetName': 'source',
        'action': 'myAction',
        'data': 123
      }));

      expect(actionCalled, isTrue);
    });
  });
}
