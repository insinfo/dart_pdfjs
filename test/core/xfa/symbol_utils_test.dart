import 'package:pdfjs/src/core/xfa/symbol_utils.dart';
import 'package:test/test.dart';

void main() {
  test('XFA internal keys are stable and distinct', () {
    expect(identical($content, const Symbol('content')), isTrue);
    expect(identical($namespaceId, const Symbol('namespaceId')), isTrue);
    expect($appendChild, isNot($removeChild));
    expect($toHTML, isNot($toString));
  });
}
