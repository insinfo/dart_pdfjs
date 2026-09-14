# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- GitHub Actions CI for static analysis, VM tests, and Chrome tests.
- Safe PowerShell test runner that removes generated Dart test artifacts.
- Project README, license, package metadata, and porting roadmap.
- DOM canvas, SVG, binary-data factory, text-layer image, and text-layer
  rendering implementations and tests.
- Touch gesture management with pinch thresholds, stable touch ordering,
  callback lifecycle, DOM listener cleanup, and browser coverage.
- Non-streaming network transport with complete-document reads, byte ranges,
  progress reporting, cancellation, and response metadata.
- Reference-derived XMP metadata coverage for scalar values, RDF collections,
  malformed input repair, raw data, and entity-expansion safety.
- PostScript Type 4 AST, parser, safe stack interpreter, expression-tree
  conversion, constant simplification, and reference-derived operator tests.
- Reference cryptographic vectors for MD5, SHA-2, RC4, AES, and PDF 1.7/2.0
  password validation and key derivation, plus explicit cipher key validation.
- Annotation factory and data models for markup, links, popups, text, geometry,
  ink, attachments, and AcroForm text/button/choice/signature widgets.
- Annotation geometry, border, color, visibility, field hierarchy, option,
  serialization, and subtype coverage derived from PDF.js tests.
- Structure-tree RoleMap resolution with cycle/depth protection and exhaustive
  child-position, alias, malformed-map, and structure-kind coverage.
- Native JPEG pipeline covering sequential/progressive DCT, Huffman and
  arithmetic entropy coding, lossless scans, sampling, IDCT and color output.
- JPEG probing, frame/process validation, arithmetic-state tests, and a bridge
  from the existing PDF `JpegStream` API with RGB/RGBA resizing.

### Changed

- Expanded the pure Dart PDF.js port across shared, core, XFA, and display
  modules.
- Added lifecycle cleanup for bitmap resources held by `PDFObjects`.
- Added HTTP fetch streaming, range requests, cancellation, progress reporting,
  response metadata, and network-backend selection.
- Added the DOM text-layer rendering pipeline, including marked content,
  geometry, font layout, scaling, rotation updates, and cancellation.
- Increased coverage to 728 VM tests and 41 Chrome tests.

## [1.0.0] - 2026-09-14

- Initial development version of the PDF.js-to-Dart port.

[Unreleased]: https://github.com/insinfo/dart_pdfjs/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/insinfo/dart_pdfjs/releases/tag/v1.0.0
