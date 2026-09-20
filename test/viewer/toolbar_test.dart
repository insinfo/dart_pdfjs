@TestOn('browser')
library;

import 'package:pdfjs/src/shared/util.dart' show AnnotationEditorType;
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../example/src/event_utils.dart';
import '../../example/src/toolbar.dart';

void main() {
  late web.HTMLDivElement host;
  late ToolbarOptions options;
  late EventBus bus;
  late Toolbar toolbar;

  web.HTMLButtonElement button(String id) =>
      web.document.createElement('button') as web.HTMLButtonElement..id = id;
  web.HTMLElement panel() =>
      web.document.createElement('div') as web.HTMLElement;

  setUp(() {
    host = web.document.createElement('div') as web.HTMLDivElement;
    final select =
        web.document.createElement('select') as web.HTMLSelectElement;
    web.HTMLOptionElement option(String value) =>
        web.document.createElement('option') as web.HTMLOptionElement
          ..value = value;
    final automatic = option('auto');
    final pageWidth = option('page-width');
    final custom = option('custom');
    select
      ..append(automatic)
      ..append(pageWidth)
      ..append(custom);
    options = ToolbarOptions(
      container: host,
      numPages: web.document.createElement('span') as web.HTMLElement,
      pageNumber: web.document.createElement('input') as web.HTMLInputElement,
      scaleSelect: select,
      customScaleOption: custom,
      previous: button('previous'),
      next: button('next'),
      zoomIn: button('zoomIn'),
      zoomOut: button('zoomOut'),
      print: button('print'),
      download: button('download'),
      editorCommentButton: button('comment'),
      editorCommentParamsToolbar: panel(),
      editorFreeTextButton: button('freeText'),
      editorFreeTextParamsToolbar: panel(),
      editorHighlightButton: button('highlight'),
      editorHighlightParamsToolbar: panel(),
      editorInkButton: button('ink'),
      editorInkParamsToolbar: panel(),
      editorStampButton: button('stamp'),
      editorStampParamsToolbar: panel(),
      editorSignatureButton: button('signature'),
      editorSignatureParamsToolbar: panel(),
    );
    for (final element in [
      options.numPages,
      options.pageNumber,
      options.scaleSelect,
      options.previous,
      options.next,
      options.zoomIn,
      options.zoomOut,
      options.print,
      options.download,
      options.editorCommentButton,
      options.editorFreeTextButton,
      options.editorHighlightButton,
      options.editorInkButton,
      options.editorStampButton,
      options.editorSignatureButton,
    ]) {
      host.append(element);
    }
    web.document.body!.append(host);
    bus = EventBus();
    toolbar = Toolbar(options, bus, toolbarDensity: 1);
  });

  tearDown(() => host.remove());

  test('reset establishes upstream initial state and toolbar density', () {
    expect(toolbar.pageNumber, 0);
    expect(toolbar.pagesCount, 0);
    expect(options.previous.disabled, isTrue);
    expect(options.next.disabled, isTrue);
    expect(options.pageNumber.value, '0');
    expect(options.pageNumber.max, '0');
    expect(options.numPages.getAttribute('data-l10n-id'), 'pdfjs-of-pages');
    expect(web.document.documentElement!.getAttribute('data-toolbar-density'),
        'compact');
    expect(options.editorInkButton.disabled, isTrue);
  });

  test('page count, labels and page navigation state stay synchronized', () {
    toolbar.setPagesCount(12, false);
    toolbar.setPageNumber(1);
    expect(options.pageNumber.type, 'number');
    expect(options.pageNumber.max, '12');
    expect(options.previous.disabled, isTrue);
    expect(options.next.disabled, isFalse);
    toolbar.setPageNumber(12);
    expect(options.next.disabled, isTrue);

    toolbar.setPagesCount(20, true);
    toolbar.setPageNumber(3, 'iii');
    expect(options.pageNumber.type, 'text');
    expect(options.pageNumber.value, 'iii');
    expect(
        options.numPages.getAttribute('data-l10n-id'), 'pdfjs-page-of-pages');
    expect(options.numPages.getAttribute('data-l10n-args'),
        contains('"pageNumber":3'));
  });

  test('scale state selects predefined and custom values', () {
    toolbar.setPageScale('page-width', 1.2);
    expect(options.scaleSelect.value, 'page-width');
    toolbar.setPageScale(null, 1.23456);
    expect(options.customScaleOption.selected, isTrue);
    expect(options.customScaleOption.getAttribute('data-l10n-args'),
        contains('123.46'));
    toolbar.setPageScale('tiny', 0.1);
    expect(options.zoomOut.disabled, isTrue);
    toolbar.setPageScale('huge', 25);
    expect(options.zoomIn.disabled, isTrue);
  });

  test('buttons dispatch source, keyboard flag and telemetry', () {
    final events = <Map>[];
    final telemetry = <Map>[];
    bus
      ..on('previouspage', (data) => events.add(data as Map))
      ..on('reporttelemetry', (data) => telemetry.add(data as Map));
    options.previous.dispatchEvent(web.MouseEvent('click'));
    options.editorStampButton.dispatchEvent(web.MouseEvent('click'));
    expect(events.single['source'], same(toolbar));
    expect(events.single['isFromKeyboard'], isTrue);
    expect(telemetry.single['details']['data']['action'],
        'pdfjs.image.icon_click');
  });

  test('page number and scale controls dispatch changed values', () {
    final pages = <Map>[];
    final scales = <Map>[];
    bus
      ..on('pagenumberchanged', (data) => pages.add(data as Map))
      ..on('scalechanged', (data) => scales.add(data as Map));
    options.pageNumber.value = '7';
    options.pageNumber.dispatchEvent(web.Event('change'));
    options.scaleSelect.value = 'page-width';
    options.scaleSelect.dispatchEvent(web.Event('change'));
    expect(pages.single['value'], '7');
    expect(scales.single['value'], 'page-width');
    options.scaleSelect.value = 'custom';
    options.scaleSelect.dispatchEvent(web.Event('change'));
    expect(scales, hasLength(1));
  });

  test('editor events update expanded state and dispatch modes', () {
    bus.dispatch('annotationeditormodechanged',
        {'mode': AnnotationEditorType.highlight});
    expect(options.editorHighlightButton.classList.contains('toggled'), isTrue);
    expect(options.editorHighlightButton.getAttribute('aria-expanded'), 'true');
    expect(options.editorInkButton.classList.contains('toggled'), isFalse);
    expect(options.editorHighlightButton.disabled, isFalse);

    final modes = <int>[];
    bus.on('switchannotationeditormode',
        (data) => modes.add((data as Map)['mode'] as int));
    options.editorHighlightButton.click();
    options.editorInkButton.click();
    expect(modes, [AnnotationEditorType.none, AnnotationEditorType.ink]);
  });

  test('loading, pagesedited, density and show-editor events are observed', () {
    toolbar.updateLoadingIndicatorState(true);
    expect(options.pageNumber.classList.contains('loading'), isTrue);
    bus.dispatch('pagesedited', {
      'pagesMapper': {'pagesNumber': 8}
    });
    expect(toolbar.pagesCount, 8);
    bus.dispatch('toolbardensity', {'value': 2});
    expect(web.document.documentElement!.getAttribute('data-toolbar-density'),
        'touch');
    final modes = <int>[];
    bus.on('switchannotationeditormode',
        (data) => modes.add((data as Map)['mode'] as int));
    bus.dispatch(
        'annotationeditormodechanged', {'mode': AnnotationEditorType.none});
    bus.dispatch(
        'showannotationeditorui', {'mode': AnnotationEditorType.highlight});
    expect(modes, [AnnotationEditorType.highlight]);
  });
}
