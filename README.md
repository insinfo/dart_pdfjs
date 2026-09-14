# pdfjs for Dart

A work-in-progress, pure Dart port of [Mozilla PDF.js](https://github.com/mozilla/pdf.js).
The project targets web applications and uses `package:web` with
`dart:js_interop`; deprecated `dart:html` APIs are intentionally not used.

> This package is under active development. Core parsing, streams, filters,
> fonts, image decoding, document structures, and part of the display layer
> have been ported. The stable public barrel API is not available yet.

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
folder after every run and clears `.dart_tool/test` before the next run.

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
