@TestOn('browser')
library;

import 'package:pdfjs/src/shared/util.dart' show AnnotationEditorParamsType;
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/annotation_editor_params.dart';
import '../../example/src/event_utils.dart';

void main() {
  late web.HTMLDivElement host;
  late web.HTMLInputElement freeTextSize;
  late web.HTMLInputElement freeTextColor;
  late web.HTMLInputElement inkColor;
  late web.HTMLInputElement inkThickness;
  late web.HTMLInputElement inkOpacity;
  late web.HTMLButtonElement stampAddImage;
  late web.HTMLInputElement highlightThickness;
  late web.HTMLButtonElement highlightShowAll;
  late web.HTMLButtonElement signatureAdd;
  late EventBus eventBus;
  late AnnotationEditorParams controller;

  web.HTMLInputElement input(String type) {
    final element = web.document.createElement('input') as web.HTMLInputElement;
    element.type = type;
    host.append(element);
    return element;
  }

  web.HTMLButtonElement button() {
    final element =
        web.document.createElement('button') as web.HTMLButtonElement;
    host.append(element);
    return element;
  }

  setUp(() {
    host = web.document.createElement('div') as web.HTMLDivElement;
    web.document.body!.append(host);
    freeTextSize = input('number');
    freeTextColor = input('color');
    inkColor = input('color');
    inkThickness = input('number');
    inkOpacity = input('number');
    stampAddImage = button();
    highlightThickness = input('number');
    highlightShowAll = button()..setAttribute('aria-pressed', 'false');
    signatureAdd = button();
    eventBus = EventBus();
    controller = AnnotationEditorParams(
      AnnotationEditorParamsOptions(
        editorFreeTextFontSize: freeTextSize,
        editorFreeTextColor: freeTextColor,
        editorInkColor: inkColor,
        editorInkThickness: inkThickness,
        editorInkOpacity: inkOpacity,
        editorStampAddImage: stampAddImage,
        editorFreeHighlightThickness: highlightThickness,
        editorHighlightShowAll: highlightShowAll,
        editorSignatureAddSignature: signatureAdd,
      ),
      eventBus,
    );
  });

  tearDown(() {
    controller.destroy();
    host.remove();
  });

  test('dispatches numeric and color input parameters', () {
    final events = <Map<Object?, Object?>>[];
    eventBus.on('switchannotationeditorparams', (event) {
      events.add(event! as Map<Object?, Object?>);
    });

    freeTextSize
      ..value = '17'
      ..dispatchEvent(web.Event('input'));
    freeTextColor
      ..value = '#123456'
      ..dispatchEvent(web.Event('input'));
    inkColor
      ..value = '#abcdef'
      ..dispatchEvent(web.Event('input'));
    inkThickness
      ..value = '4'
      ..dispatchEvent(web.Event('input'));
    inkOpacity
      ..value = '63'
      ..dispatchEvent(web.Event('input'));
    highlightThickness
      ..value = '12'
      ..dispatchEvent(web.Event('input'));

    expect(
      events.map((event) => event['type']),
      [
        AnnotationEditorParamsType.freetextSize,
        AnnotationEditorParamsType.freetextColor,
        AnnotationEditorParamsType.inkColor,
        AnnotationEditorParamsType.inkThickness,
        AnnotationEditorParamsType.inkOpacity,
        AnnotationEditorParamsType.highlightThickness,
      ],
    );
    expect(events.map((event) => event['value']), [
      17,
      '#123456',
      '#abcdef',
      4,
      63,
      12,
    ]);
    expect(
        events.every((event) => identical(event['source'], controller)), true);
  });

  test('create buttons dispatch create and stamp telemetry', () {
    final params = <Map<Object?, Object?>>[];
    final telemetry = <Map<Object?, Object?>>[];
    eventBus.on('switchannotationeditorparams', (event) {
      params.add(event! as Map<Object?, Object?>);
    });
    eventBus.on('reporttelemetry', (event) {
      telemetry.add(event! as Map<Object?, Object?>);
    });

    stampAddImage.click();
    signatureAdd.click();

    expect(params, hasLength(2));
    expect(
      params.map((event) => event['type']),
      everyElement(AnnotationEditorParamsType.create),
    );
    expect(params.map((event) => event['value']), everyElement(isNull));
    expect(telemetry, hasLength(1));
    expect(telemetry.single['details'], {
      'type': 'editing',
      'data': {'action': 'pdfjs.image.add_image_click'},
    });
  });

  test('show-all button toggles aria state and parameter value', () {
    final values = <Object?>[];
    eventBus.on('switchannotationeditorparams', (event) {
      values.add((event! as Map<Object?, Object?>)['value']);
    });

    highlightShowAll.click();
    expect(highlightShowAll.getAttribute('aria-pressed'), 'true');
    highlightShowAll.click();
    expect(highlightShowAll.getAttribute('aria-pressed'), 'false');
    expect(values, [true, false]);
  });

  test('applies editor parameter updates to controls', () {
    eventBus.dispatch('annotationeditorparamschanged', {
      'details': <Object?>[
        [AnnotationEditorParamsType.freetextSize, 21],
        [AnnotationEditorParamsType.freetextColor, '#010203'],
        [AnnotationEditorParamsType.inkColor, '#040506'],
        [AnnotationEditorParamsType.inkThickness, 7],
        [AnnotationEditorParamsType.inkOpacity, 42],
        [AnnotationEditorParamsType.highlightThickness, 9],
        [AnnotationEditorParamsType.highlightFree, false],
        [AnnotationEditorParamsType.highlightShowAll, true],
      ],
    });

    expect(freeTextSize.value, '21');
    expect(freeTextColor.value, '#010203');
    expect(inkColor.value, '#040506');
    expect(inkThickness.value, '7');
    expect(inkOpacity.value, '42');
    expect(highlightThickness.value, '9');
    expect(highlightThickness.disabled, true);
    expect(highlightShowAll.getAttribute('aria-pressed'), 'true');
  });

  test('forwards highlight color updates to the main picker', () {
    final events = <Map<Object?, Object?>>[];
    eventBus.on('mainhighlightcolorpickerupdatecolor', (event) {
      events.add(event! as Map<Object?, Object?>);
    });

    eventBus.dispatch('annotationeditorparamschanged', {
      'details': <Object?>[
        [AnnotationEditorParamsType.highlightColor, '#fedcba'],
      ],
    });

    expect(events, hasLength(1));
    expect(events.single['value'], '#fedcba');
    expect(events.single['source'], same(controller));
  });

  test('accepts map entries and ignores malformed updates', () {
    eventBus.dispatch('annotationeditorparamschanged', {
      'details': <Object?>[
        const MapEntry<Object?, Object?>(
          AnnotationEditorParamsType.highlightFree,
          true,
        ),
        const <Object?>['missing-value'],
        'invalid',
      ],
    });

    expect(highlightThickness.disabled, false);
  });

  test('destroy is idempotent and detaches DOM and bus listeners', () {
    final params = <Object?>[];
    eventBus.on('switchannotationeditorparams', params.add);

    controller.destroy();
    controller.destroy();
    freeTextSize
      ..value = '99'
      ..dispatchEvent(web.Event('input'));
    highlightShowAll.click();
    eventBus.dispatch('annotationeditorparamschanged', {
      'details': <Object?>[
        [AnnotationEditorParamsType.freetextSize, 55],
      ],
    });

    expect(params, isEmpty);
    expect(freeTextSize.value, '99');
    expect(highlightShowAll.getAttribute('aria-pressed'), 'false');
  });
}
