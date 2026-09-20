import 'package:pdfjs/src/scripting_api/constants.dart';
import 'package:test/test.dart';

void main() {
  test('exposes PDF scripting constants', () {
    expect(Border.s, 'solid');
    expect(Cursor.delay, 2);
    expect(Display.noView, 3);
    expect(Font.HelvBI, 'Helvetica-BoldOblique');
    expect(Highlight.p, 'push');
    expect(Position.overlay, 6);
    expect(ScaleHow.anamorphic, 1);
    expect(ScaleWhen.tooSmall, 3);
    expect(Style.st, 'star');
    expect(Trans.glitterRD, 'GlitterRightDown');
    expect(ZoomType.fitV, 'FitVisibleWidth');
  });

  test('preserves messages and regular-expression source strings', () {
    expect(GlobalConstants.IDS_AM, 'am');
    expect(GlobalConstants.IDS_MONTH_INFO, contains('December[12]'));
    expect(GlobalConstants.RE_NUMBER_COMMIT_DOT_SEP,
        [r'[+-]?\d+(\.\d+)?', r'[+-]?\.\d+', r'[+-]?\d+\.']);
    expect(GlobalConstants.RE_PHONE_COMMIT, hasLength(4));
    expect(
        RegExp('^(?:${GlobalConstants.RE_ZIP_COMMIT.single})\$')
            .hasMatch('12345'),
        isTrue);
  });
}
