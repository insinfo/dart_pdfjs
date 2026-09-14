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
- Complete Compact Font Format reader for headers, INDEX and DICT data,
  private dictionaries, charsets, encodings, FDSelect tables, Type 2
  charstrings, subroutines, widths, SEAC analysis, and CID font dictionaries.
- Reference-derived CFF parsing, malformed-input, compiler round-trip, charset,
  encoding, FDSelect, and Type 2 charstring tests.
- Public `getDocument` browser API with loading tasks, document/page proxies,
  viewport creation, rendering tasks, cancellation, cleanup, byte and URL
  loading, and a public `package:pdfjs/pdfjs.dart` entry point.
- Canvas 2D renderer for graphics state, transforms, paths, clipping, colors,
  text, blend modes, and RGB/RGBA/grayscale images.
- Functional content-stream evaluator producing operator lists for basic
  graphics, text, fonts, ExtGState, Form/Image XObjects, and inline images.
- End-to-end browser coverage that parses and paints a real one-page PDF and
  verifies the rendered Canvas pixels.
- Font translation for simple Type1/TrueType fonts and basic Type0 fonts,
  including standard encodings, Differences, widths, descriptors, embedded
  font streams, ToUnicode `bfchar`/`bfrange`, and display-ready glyph records.
- Image XObject and inline-image decoding through `PDFImage`, producing RGBA
  payloads for RGB, grayscale, CMYK, Decode arrays, SMask, color-key masks,
  and one-bit image masks.
- End-to-end browser coverage for parsing, decoding, and painting an embedded
  Image XObject from a real PDF.
- Canvas transparency groups with isolated off-screen compositing, alpha,
  blend modes, nested groups, annotation clipping, image-mask and image-repeat
  operators, and fill/stroke/invisible text rendering modes.
- Browser annotation layer for links, notes, popups, markup geometry, file
  attachments, and text/button/choice widgets synchronized with
  `AnnotationStorage`.
- Local worker document protocol with setup/factory injection, recovery/XFA
  loading, page/catalog/document actions, operator/text streaming entrypoints,
  task tracking, cleanup, and idempotent termination.

### Changed

- Expanded the pure Dart PDF.js port across shared, core, XFA, and display
  modules.
- Added lifecycle cleanup for bitmap resources held by `PDFObjects`.
- Added HTTP fetch streaming, range requests, cancellation, progress reporting,
  response metadata, and network-backend selection.
- Added the DOM text-layer rendering pipeline, including marked content,
  geometry, font layout, scaling, rotation updates, and cancellation.
- Increased coverage to 922 VM tests and 90 Chrome tests.

## [1.0.0] - 2026-09-14

- Initial development version of the PDF.js-to-Dart port.

[Unreleased]: https://github.com/insinfo/dart_pdfjs/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/insinfo/dart_pdfjs/releases/tag/v1.0.0
