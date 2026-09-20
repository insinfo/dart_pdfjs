# pdfjs for Dart

A work-in-progress, pure Dart port of [Mozilla PDF.js](https://github.com/mozilla/pdf.js).
The project targets web applications and uses `package:web` with
`dart:js_interop`; deprecated `dart:html` APIs are intentionally not used.

> This package is under active development. Simple PDF documents can be loaded
> and rendered to a browser Canvas. Simple Type1/TrueType/Type0 fonts and
> common PDF image color spaces and masks are supported. The Canvas backend
> includes isolated transparency groups and image masks, and a browser
> annotation layer covers common links, markup, popups, and form widgets.
> CID CMaps and vertical metrics, Alpha/Luminosity soft masks, axial/radial
> shadings, tiling patterns, and application-provided progressive/range data
> transports are supported. Dedicated browser-worker orchestration remains in
> development.

## Render a PDF in the browser

```dart
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:pdfjs/pdfjs.dart';
import 'package:web/web.dart' as web;

Future<void> renderFirstPage(Uint8List pdfBytes) async {
  final document = await getDocument(pdfBytes).promise;
  final page = await document.getPage(1);
  final viewport = page.getViewport(scale: 1.5);

  final canvas = web.document.querySelector('#pdf') as web.HTMLCanvasElement
    ..width = viewport.width.ceil()
    ..height = viewport.height.ceil();
  final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;

  await page
      .render(RenderParameters(
        canvasContext: context,
        viewport: viewport,
      ))
      .promise;
}
```

URLs can also be loaded directly in browser builds with
`getDocument('https://example.com/document.pdf')`, subject to normal CORS
rules.

Applications with their own networking layer can subclass
`PDFDataRangeTransport`, feed progressive/range bytes through its `onData*`
methods, and consume them with `PDFDataTransportStream`.

## Requirements

- Dart SDK 3.6 or newer
- Chrome for DOM-specific tests
- PowerShell 7 (`pwsh`) for the safe test runner

## Development

Install dependencies and analyze the project:

```powershell
dart pub get
dart analyze
```

Always use the project test runner instead of invoking `dart test` directly.
It removes the large `dart_test.kernel.*` directories left in the system temp
folder after every run, clears `.dart_tool/test` before the next run, and on
Windows terminates browser/compiler descendants left by that invocation. Runs
time out after 15 minutes by default; set `PDFJS_TEST_TIMEOUT_MINUTES` to a
smaller positive value on resource-constrained machines.

```powershell
# VM suite
./tool/run_tests.ps1

# DOM/Chrome suites
./tool/run_tests.ps1 test/display/canvas_factory_test.dart `
  test/display/svg_factory_test.dart `
  test/display/binary_data_factory_test.dart `
  test/display/text_layer_images_test.dart `
  test/display/fetch_stream_test.dart `
  test/display/network_test.dart `
  test/display/text_layer_test.dart `
  test/display/touch_manager_test.dart -p chrome
```

The detailed porting status and conversion rules are tracked in
[ROTEIRO_PORTE.md](ROTEIRO_PORTE.md).

## Source and attribution

The reference implementation is Mozilla PDF.js. Ported files retain their
original Mozilla copyright notices where applicable. This project is licensed
under the Apache License 2.0; see [LICENSE](LICENSE).
