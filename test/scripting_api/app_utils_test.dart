import 'package:pdfjs/src/scripting_api/app_utils.dart';
import 'package:test/test.dart';

void main() {
  test('exposes viewer and activation constants', () {
    expect(viewerType, 'PDF.js');
    expect(viewerVariation, 'Full');
    expect(viewerVersion, 21.00720099);
    expect(formsVersion, 21.00720099);
    expect(userActivationCallbackId, 0);
    expect(userActivationMaxTimeValidity, 5000);
  });

  test('serializeError returns the scripting command payload', () {
    final trace = StackTrace.fromString('trace');
    expect(serializeError(ArgumentError('bad'), trace), {
      'command': 'error',
      'value': 'Invalid argument(s): bad\ntrace',
    });
  });

  test('collection factories return fresh, correctly typed collections', () {
    final firstList = makeArr<int>();
    final secondList = makeArr<int>();
    firstList.add(1);
    expect(secondList, isEmpty);

    final firstMap = makeMap<String, int>();
    final secondMap = makeMap<String, int>();
    firstMap['one'] = 1;
    expect(secondMap, isEmpty);
  });
}
