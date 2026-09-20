import 'package:pdfjs/src/scripting_api/pdf_object.dart';
import 'package:test/test.dart';

void main() {
  test('PDFObject initializes host state and isolated expandos', () {
    Map<String, dynamic>? sent;
    void sender(Map<String, dynamic> message) => sent = message;

    final object = PDFObject(<String, dynamic>{'id': 'field', 'send': sender});
    final other = PDFObject();
    expect(object.id, 'field');
    object.send!(<String, dynamic>{'value': 1});
    expect(sent, <String, dynamic>{'value': 1});
    object.expandos['custom'] = 42;
    expect(other.expandos, isEmpty);
  });

  test('PDFObject ignores values that are not send callbacks', () {
    expect(PDFObject(<String, dynamic>{'send': false}).send, isNull);
  });
}
