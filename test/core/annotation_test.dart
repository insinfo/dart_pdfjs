// Copyright 2017 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:pdfjs/src/core/annotation.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/shared/util.dart';
import 'package:test/test.dart';

void main() {
  group('AnnotationFactory subtypes', () {
    test('creates Text', () {
      final dict = Dict()..set('Subtype', Name.get('Text'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'Text');
      expect(annotation, isA<TextAnnotation>());
      expect(annotation.annotationType, 1);
      expect(annotation.id, 'Text');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates Link', () {
      final dict = Dict()..set('Subtype', Name.get('Link'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'Link');
      expect(annotation, isA<LinkAnnotation>());
      expect(annotation.annotationType, 2);
      expect(annotation.id, 'Link');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates Popup', () {
      final dict = Dict()..set('Subtype', Name.get('Popup'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'Popup');
      expect(annotation, isA<PopupAnnotation>());
      expect(annotation.annotationType, 16);
      expect(annotation.id, 'Popup');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates FreeText', () {
      final dict = Dict()..set('Subtype', Name.get('FreeText'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'FreeText');
      expect(annotation, isA<FreeTextAnnotation>());
      expect(annotation.annotationType, 3);
      expect(annotation.id, 'FreeText');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates Line', () {
      final dict = Dict()..set('Subtype', Name.get('Line'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'Line');
      expect(annotation, isA<LineAnnotation>());
      expect(annotation.annotationType, 4);
      expect(annotation.id, 'Line');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates Square', () {
      final dict = Dict()..set('Subtype', Name.get('Square'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'Square');
      expect(annotation, isA<SquareAnnotation>());
      expect(annotation.annotationType, 5);
      expect(annotation.id, 'Square');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates Circle', () {
      final dict = Dict()..set('Subtype', Name.get('Circle'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'Circle');
      expect(annotation, isA<CircleAnnotation>());
      expect(annotation.annotationType, 6);
      expect(annotation.id, 'Circle');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates PolyLine', () {
      final dict = Dict()..set('Subtype', Name.get('PolyLine'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'PolyLine');
      expect(annotation, isA<PolylineAnnotation>());
      expect(annotation.annotationType, 8);
      expect(annotation.id, 'PolyLine');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates Polygon', () {
      final dict = Dict()..set('Subtype', Name.get('Polygon'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'Polygon');
      expect(annotation, isA<PolygonAnnotation>());
      expect(annotation.annotationType, 7);
      expect(annotation.id, 'Polygon');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates Ink', () {
      final dict = Dict()..set('Subtype', Name.get('Ink'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'Ink');
      expect(annotation, isA<InkAnnotation>());
      expect(annotation.annotationType, 15);
      expect(annotation.id, 'Ink');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates Highlight', () {
      final dict = Dict()..set('Subtype', Name.get('Highlight'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'Highlight');
      expect(annotation, isA<HighlightAnnotation>());
      expect(annotation.annotationType, 9);
      expect(annotation.id, 'Highlight');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates Underline', () {
      final dict = Dict()..set('Subtype', Name.get('Underline'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'Underline');
      expect(annotation, isA<UnderlineAnnotation>());
      expect(annotation.annotationType, 10);
      expect(annotation.id, 'Underline');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates Squiggly', () {
      final dict = Dict()..set('Subtype', Name.get('Squiggly'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'Squiggly');
      expect(annotation, isA<SquigglyAnnotation>());
      expect(annotation.annotationType, 11);
      expect(annotation.id, 'Squiggly');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates StrikeOut', () {
      final dict = Dict()..set('Subtype', Name.get('StrikeOut'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'StrikeOut');
      expect(annotation, isA<StrikeOutAnnotation>());
      expect(annotation.annotationType, 12);
      expect(annotation.id, 'StrikeOut');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates Stamp', () {
      final dict = Dict()..set('Subtype', Name.get('Stamp'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'Stamp');
      expect(annotation, isA<StampAnnotation>());
      expect(annotation.annotationType, 13);
      expect(annotation.id, 'Stamp');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });

    test('creates FileAttachment', () {
      final dict = Dict()..set('Subtype', Name.get('FileAttachment'));
      final annotation = AnnotationFactory.fromDict(dict, id: 'FileAttachment');
      expect(annotation, isA<FileAttachmentAnnotation>());
      expect(annotation.annotationType, 17);
      expect(annotation.id, 'FileAttachment');
      expect(annotation.rect, [0, 0, 0, 0]);
      expect(annotation.flags, 0);
    });
    test('creates text widget', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Widget'))
        ..set('FT', Name.get('Tx'));
      expect(AnnotationFactory.fromDict(dict, id: 'w'),
          isA<TextWidgetAnnotation>());
    });

    test('creates button widget', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Widget'))
        ..set('FT', Name.get('Btn'));
      expect(AnnotationFactory.fromDict(dict, id: 'w'),
          isA<ButtonWidgetAnnotation>());
    });

    test('creates choice widget', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Widget'))
        ..set('FT', Name.get('Ch'));
      expect(AnnotationFactory.fromDict(dict, id: 'w'),
          isA<ChoiceWidgetAnnotation>());
    });

    test('creates signature widget', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Widget'))
        ..set('FT', Name.get('Sig'));
      expect(AnnotationFactory.fromDict(dict, id: 'w'),
          isA<SignatureWidgetAnnotation>());
    });
  });

  group('rectangles and quad points', () {
    test('normalizes reversed rectangles', () {
      expect(normalizeRect([20, 40, 10, 5]), [10, 5, 20, 40]);
    });
    test('uses an empty rectangle for invalid data', () {
      expect(normalizeRect(null), [0, 0, 0, 0]);
      expect(normalizeRect([1, 2]), [0, 0, 0, 0]);
    });
    test('parses several quadrilaterals', () {
      final points = getQuadPoints(
          [0, 10, 10, 10, 0, 0, 10, 0, 10, 20, 20, 20, 10, 10, 20, 10],
          [0, 0, 20, 20]);
      expect(points, hasLength(2));
      expect(points.first.first, (x: 0, y: 10));
    });
    test('rejects points outside the annotation', () {
      expect(
          getQuadPoints([0, 10, 30, 10, 0, 0, 10, 0], [0, 0, 20, 20]), isEmpty);
    });
    test('rejects incomplete quadrilaterals', () {
      expect(getQuadPoints([0, 1, 2], [0, 0, 20, 20]), isEmpty);
    });
  });

  group('annotation visibility', () {
    test('visibility flag combination 0', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 0);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f0');
      expect(annotation.viewable, isTrue);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 1', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 1);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f1');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 2', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 2);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f2');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 3', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 3);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f3');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 4', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 4);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f4');
      expect(annotation.viewable, isTrue);
      expect(annotation.printable, isTrue);
    });

    test('visibility flag combination 5', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 5);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f5');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 6', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 6);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f6');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 7', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 7);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f7');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 8', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 8);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f8');
      expect(annotation.viewable, isTrue);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 9', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 9);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f9');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 10', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 10);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f10');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 11', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 11);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f11');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 12', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 12);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f12');
      expect(annotation.viewable, isTrue);
      expect(annotation.printable, isTrue);
    });

    test('visibility flag combination 13', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 13);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f13');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 14', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 14);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f14');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 15', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 15);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f15');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 16', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 16);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f16');
      expect(annotation.viewable, isTrue);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 17', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 17);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f17');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 18', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 18);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f18');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 19', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 19);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f19');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 20', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 20);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f20');
      expect(annotation.viewable, isTrue);
      expect(annotation.printable, isTrue);
    });

    test('visibility flag combination 21', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 21);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f21');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 22', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 22);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f22');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 23', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 23);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f23');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 24', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 24);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f24');
      expect(annotation.viewable, isTrue);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 25', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 25);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f25');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 26', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 26);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f26');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 27', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 27);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f27');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 28', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 28);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f28');
      expect(annotation.viewable, isTrue);
      expect(annotation.printable, isTrue);
    });

    test('visibility flag combination 29', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 29);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f29');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 30', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 30);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f30');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });

    test('visibility flag combination 31', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Square'))
        ..set('F', 31);
      final annotation = AnnotationFactory.fromDict(dict, id: 'f31');
      expect(annotation.viewable, isFalse);
      expect(annotation.printable, isFalse);
    });
  });

  group('border style', () {
    test('parses BS dictionaries', () {
      final bs = Dict()
        ..set('W', 4)
        ..set('S', Name.get('D'))
        ..set('D', [2, 1]);
      final style = AnnotationBorderStyle.fromDict(Dict()..set('BS', bs));
      expect(style.width, 4);
      expect(style.style, AnnotationBorderStyleType.dashed);
      expect(style.dashArray, [2, 1]);
    });
    test('parses legacy Border arrays', () {
      final style = AnnotationBorderStyle.fromDict(Dict()
        ..set('Border', [
          2,
          3,
          4,
          [1, 2]
        ]));
      expect(style.horizontalCornerRadius, 2);
      expect(style.verticalCornerRadius, 3);
      expect(style.width, 4);
    });
    test('rejects all-zero dash arrays', () {
      final style = AnnotationBorderStyle()..setDashArray([0, 0]);
      expect(style.width, 0);
      expect(style.dashArray, [3]);
    });
    test('maps every named border style', () {
      final expected = {'S': 1, 'D': 2, 'B': 3, 'I': 4, 'U': 5};
      for (final entry in expected.entries) {
        final style = AnnotationBorderStyle()..setStyle(Name.get(entry.key));
        expect(style.style, entry.value);
      }
    });
  });

  group('widget fields', () {
    test('collects hierarchical names', () {
      final root = Dict()..set('T', 'root');
      final child = Dict()
        ..set('T', 'child')
        ..set('Parent', root);
      final leaf = Dict()
        ..set('Subtype', Name.get('Widget'))
        ..set('FT', Name.get('Tx'))
        ..set('T', 'leaf')
        ..set('Parent', child);
      expect(
          (AnnotationFactory.fromDict(leaf, id: 'x') as WidgetAnnotation)
              .fieldName,
          'root.child.leaf');
    });
    test('derives text field properties', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Widget'))
        ..set('FT', Name.get('Tx'))
        ..set('Ff', AnnotationFieldFlag.multiline)
        ..set('MaxLen', 12);
      final value =
          AnnotationFactory.fromDict(dict, id: 'x') as TextWidgetAnnotation;
      expect(value.multiLine, isTrue);
      expect(value.maxLen, 12);
      expect(value.comb, isFalse);
    });
    test('derives button kinds', () {
      Dict button(int flags) => Dict()
        ..set('Subtype', Name.get('Widget'))
        ..set('FT', Name.get('Btn'))
        ..set('Ff', flags);
      expect(
          (AnnotationFactory.fromDict(button(0), id: 'c')
                  as ButtonWidgetAnnotation)
              .checkBox,
          isTrue);
      expect(
          (AnnotationFactory.fromDict(button(AnnotationFieldFlag.radio),
                  id: 'r') as ButtonWidgetAnnotation)
              .radioButton,
          isTrue);
      expect(
          (AnnotationFactory.fromDict(button(AnnotationFieldFlag.pushButton),
                  id: 'p') as ButtonWidgetAnnotation)
              .pushButton,
          isTrue);
    });
    test('normalizes choice options', () {
      final dict = Dict()
        ..set('Subtype', Name.get('Widget'))
        ..set('FT', Name.get('Ch'))
        ..set('Opt', [
          'One',
          ['export', 'Display']
        ]);
      final value =
          AnnotationFactory.fromDict(dict, id: 'x') as ChoiceWidgetAnnotation;
      expect(value.options, [
        {'exportValue': 'One', 'displayValue': 'One'},
        {'exportValue': 'export', 'displayValue': 'Display'}
      ]);
    });
  });

  group('annotation data', () {
    test('parses grayscale RGB and CMYK colors', () {
      Annotation color(List<num> c) =>
          Annotation(dict: Dict()..set('C', c), id: 'x', annotationType: 0);
      expect(color([.5]).color, [128, 128, 128]);
      expect(color([1, 0, .5]).color, [255, 0, 128]);
      expect(color([0, 1, 1, 0]).color, [255, 0, 0]);
    });
    test('serializes common fields', () {
      final dict = Dict()
        ..set('Rect', [1, 2, 3, 4])
        ..set('Contents', 'hello')
        ..set('M', 'date')
        ..set('T', 'title');
      final data = Annotation(dict: dict, id: 'a', annotationType: 9).toMap();
      expect(data['contents'], 'hello');
      expect(data['rect'], [1, 2, 3, 4]);
      expect(data['annotationType'], 9);
    });
    test('serializes new annotations', () async {
      final annotation = Annotation(dict: Dict(), id: 'a', annotationType: 1);
      final result = await AnnotationFactory.saveNewAnnotations(
          null,
          null,
          null,
          [
            annotation,
            {'id': 'b'}
          ],
          null,
          null);
      expect(result['annotations'], hasLength(2));
    });
  });
}
