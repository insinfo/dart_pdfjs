# Roteiro de Porte: pdf.js → em puro Dart para web usando pacote web (proibido dart:html)

> **Projeto:** pdfjs (Dart)  
> **Origem:** `referencia/pdf.js-master/src/` (Mozilla pdf.js)  
> **Destino:** `lib/src/`  
> **Data de Início:** 2026-04-23  

---

## 📋 Visão Geral

Porte completo da biblioteca **pdf.js** (Mozilla) para **Dart**, usando `dart:typed_data` para manipulação binária e exclusivamente o pacote `web` (com `dart:js_interop`) para interações DOM/navegador quando necessário. **O uso de `dart:html` é estritamente proibido** por estar depreciado. A estrutura de diretórios em Dart espelha a original JS.

---

## 🏗️ Estrutura de Diretórios

```
lib/src/
├── shared/            ← Utilitários compartilhados (util, math_clamp, etc.)
├── core/              ← Motor PDF (parser, primitives, streams, fonts, etc.)
│   ├── xfa/           ← Suporte XFA Forms
│   └── editor/        ← Editor de PDFs
├── display/           ← Camada de renderização (canvas, text_layer, etc.)
│   └── editor/        ← Editores visuais
└── scripting_api/     ← API de scripting JavaScript do PDF
```

---

## 📦 Fases do Porte

### Fase 1 — Fundação (shared/) ✅ CONCLUÍDA (100%)
> Base de tudo. Concluída com fidelidade e testes.

| # | Arquivo JS | Arquivo Dart | Status |
|---|-----------|-------------|--------|
| 1 | `shared/util.js` | `shared/util.dart` | ✅ |
| 2 | `shared/math_clamp.js` | `shared/math_clamp.dart` | ✅ |
| 3 | `shared/base_pdf_stream.js` | `shared/base_pdf_stream.dart` | ✅ |
| 4 | `shared/image_utils.js` | `shared/image_utils.dart` | ✅ |
| 5 | `shared/message_handler.js` | `shared/message_handler.dart` | ✅ |
| 6 | `shared/murmurhash3.js` | `shared/murmurhash3.dart` | ✅ |
| 7 | `shared/scripting_utils.js` | `shared/scripting_utils.dart` | ✅ |
| 8 | `shared/obj_bin_transform_utils.js` | `shared/obj_bin_transform_utils.dart` | ✅ |

### Fase 2 — Core Primitivas (core/ — base) ✅ CONCLUÍDA
> Estruturas fundamentais do PDF: primitivas, streams, parser, utils.

| # | Arquivo JS | Arquivo Dart | Status |
|---|-----------|-------------|--------|
| 1 | `core/primitives.js` | `core/primitives.dart` | ✅ |
| 2 | `core/base_stream.js` | `core/base_stream.dart` | ✅ |
| 3 | `core/stream.js` | `core/stream.dart` | ✅ |
| 4 | `core/decode_stream.js` | `core/decode_stream.dart` | ✅ |
| 5 | `core/core_utils.js` | `core/core_utils.dart` | ✅ |
| 6 | `core/parser.js` | `core/parser.dart` | ✅ |
| 7 | `core/xref.js` | `core/xref.dart` | ✅ |

### Fase 3 — Core Streams (filtros de compressão) ✅ CONCLUÍDA
> Decodificadores de streams do PDF.

| # | Arquivo JS | Arquivo Dart | Status |
|---|-----------|-------------|--------|
| 1 | `core/flate_stream.js` | `core/flate_stream.dart` | ✅ |
| 2 | `core/ascii_85_stream.js` | `core/ascii_85_stream.dart` | ✅ |
| 3 | `core/ascii_hex_stream.js` | `core/ascii_hex_stream.dart` | ✅ |
| 4 | `core/lzw_stream.js` | `core/lzw_stream.dart` | ✅ |
| 5 | `core/run_length_stream.js` | `core/run_length_stream.dart` | ✅ |
| 6 | `core/predictor_stream.js` | `core/predictor_stream.dart` | ✅ |
| 7 | `core/ccitt_stream.js` | `core/ccitt_stream.dart` | ✅ |
| 8 | `core/ccitt.js` | `core/ccitt.dart` | ✅ |
| 9 | `core/jbig2_stream.js` | `core/jbig2_stream.dart` | ✅ |
| 10 | `core/jbig2.js` | `core/jbig2.dart` | ✅ |
| 11 | `core/jpeg_stream.js` | `core/jpeg_stream.dart` | ✅ |
| 12 | `core/jpg.js` | `core/jpg.dart` | ✅ |
| 13 | `core/jpx_stream.js` | `core/jpx_stream.dart` | ✅ |
| 14 | `core/jpx.js` | `core/jpx.dart` | ✅ |
| 15 | `core/brotli_stream.js` | `core/brotli_stream.dart` | ✅ (Stubs) |
| 16 | `core/decrypt_stream.js` | `core/decrypt_stream.dart` | ✅ |

### Fase 4 — Core Criptografia & Hashing

| # | Arquivo JS | Arquivo Dart | Status |
|---|-----------|-------------|--------|
| 1 | `core/crypto.js` | `core/crypto.dart` | ✅ |
| 2 | `core/calculate_md5.js` | `core/calculate_md5.dart` | ✅ |
| 3 | `core/calculate_sha256.js` | `core/calculate_sha256.dart` | ✅ |
| 4 | `core/calculate_sha_other.js` | `core/calculate_sha_other.dart` | ✅ |
| 5 | `core/arithmetic_decoder.js` | `core/arithmetic_decoder.dart` | ✅ |

### Fase 5 — Core Fontes

| # | Arquivo JS | Arquivo Dart | Complexidade |
|---|-----------|-------------|-------------|
| 1 | `core/encodings.js` | `core/encodings.dart` | ✅ |
| 2 | `core/fonts_utils.js` | `core/fonts_utils.dart` | ✅ |
| 3 | `core/fonts.js` | `core/fonts.dart` | 🔄 Parcial: helpers, detecção, mapas, tabelas OpenType/TTC, `checkAndRepair` inicial, `Glyph`, `Font` texto/export, `ErrorFont` |
| 4 | `core/cff_parser.js` | `core/cff_parser.dart` | ✅ |
| 5 | `core/cff_font.js` | `core/cff_font.dart` | ✅ |
| 6 | `core/type1_font.js` | `core/type1_font.dart` | ✅ |
| 7 | `core/type1_parser.js` | `core/type1_parser.dart` | ✅ |
| 8 | `core/font_renderer.js` | `core/font_renderer.dart` | ✅ |
| 9 | `core/font_substitutions.js` | `core/font_substitutions.dart` | ✅ |
| 10 | `core/glyf.js` | `core/glyf.dart` | ✅ |
| 11 | `core/glyphlist.js` | `core/glyphlist.dart` | ✅ |
| 12 | `core/charsets.js` | `core/charsets.dart` | ✅ |
| 13 | `core/standard_fonts.js` | `core/standard_fonts.dart` | ✅ |
| 14 | `core/metrics.js` | `core/metrics.dart` | ✅ |
| 15 | `core/unicode.js` | `core/unicode.dart` | ✅ |
| 16 | `core/cmap.js` | `core/cmap.dart` | ✅ |
| 17 | `core/binary_cmap.js` | `core/binary_cmap.dart` | ✅ |
| 18 | `core/to_unicode_map.js` | `core/to_unicode_map.dart` | ✅ |
| 19 | `core/opentype_file_builder.js` | `core/opentype_file_builder.dart` | ✅ |
| 20-24 | `core/*_factors.js`, `core/liberationsans_widths.js` | `core/*_factors.dart`, `core/font_metrics.dart` | ✅ |
| 25 | `core/xfa_fonts.js` | `core/xfa_fonts.dart` | ✅ |

### Fase 6 — Core Rendering & Document

| # | Arquivo JS | Arquivo Dart | Complexidade |
|---|-----------|-------------|-------------|
| 1 | `core/colorspace.js` | `core/colorspace.dart` | ✅ Completo (DeviceGray, DeviceRGB, DeviceRGBA, DeviceCMYK, Indexed, Alternate, CalGray, CalRGB, Lab) |
| 2 | `core/pattern.js` | `core/pattern.dart` | ✅ (Shadings Radial, Axial, FunctionBased, Meshes Types 4-7, Tiling) |
| 3 | `core/writer.js` | `core/writer.dart` | ✅ (Escrita de objetos, streams, dicts, arrays, XRef table/stream, XFA, incremental updates) |
| 4 | `core/pdf_manager.js` | `core/pdf_manager.dart` | ✅ (BasePdfManager, LocalPdfManager, NetworkPdfManager com retry) |
| 5 | `core/operator_list.js` | `core/operator_list.dart` | ✅ (OperatorList, CheckedOperatorList, QueueOptimizer com autômato afim) |
| 6 | `core/image_resizer.js` | `core/image_resizer.dart` | ✅ (Thresholds, codificador BMP puro Dart 1/24/32bpp, subamostragem) |
| 7 | `core/image.js` | `core/image.dart` | ✅ (PDFImage, decodificação de cores/máscaras, extração bpc, RGBA) |
| 8 | `core/document.js` | `core/document.dart` | ✅ (Page, PDFDocument, geometria, ciclo de vida, fingerprints, versioning) |
| 9 | `core/evaluator.js` | `core/evaluator.dart` | 🔄 (caminho funcional para operadores, texto, recursos, Form/Image XObjects e ExtGState) |
| 10 | `core/catalog.js` | `core/catalog.dart` | ✅ Completo |
| 11 | `core/annotation.js` | `core/annotation.dart` | 🔄 (AnnotationFactory estruturado) |
| 12 | `display/obj_bin_transform_display.js` | `display/obj_bin_transform_display.dart` | ✅ Deserialização binária display |


### Fase 7 — Core Utilitários Secundários (~16 arquivos) 🟡

| # | Arquivo JS | Arquivo Dart | Status |
|---|-----------|-------------|--------|
| 1 | `core/xml_parser.js` | `core/xml_parser.dart` | ✅ |
| 2 | `core/metadata_parser.js` | `core/metadata_parser.dart` | ✅ |
| 3 | `core/dataset_reader.js` | `core/dataset_reader.dart` | ✅ |
| 4 | `core/cleanup_helper.js` | `core/cleanup_helper.dart` | ✅ |
| 5 | `core/colorspace_utils.js` | `core/colorspace_utils.dart` | ✅ |
| 6 | `core/bidi.js` | `core/bidi.dart` | ✅ |
| 7 | `core/intersector.js` | `core/intersector.dart` | ✅ |
| 8 | `core/image_utils.js` | `core/image_utils.dart` | ✅ |
| 9 | `core/chunked_stream.js` | `core/chunked_stream.dart` | ✅ |
| 10 | `core/function.js` | `core/function.dart` | ✅ |
| 11 | `core/internal_viewer_utils.js` | `core/internal_viewer_utils.dart` | ✅ |
| 12 | `core/postscript/lexer.js` | `core/postscript/lexer.dart` | ✅ |
| 13-16 | Restante | `core/*.dart` | 🟡 |

### Fase 8 — Core XFA (27 arquivos) ⏳ Diferido

### Fase 9 — Display (~35 arquivos) 🟡

O caminho `getDocument → getPage → OperatorList → CanvasGraphics` já renderiza
PDFs no Canvas 2D do navegador, incluindo fontes simples traduzidas,
Image XObjects/inline images, grupos de transparência, máscaras e uma camada
visual de annotations/widgets, CMaps CID, métricas verticais, patterns,
shadings, soft masks e transporte progressivo/por ranges. Permanece em
evolução a orquestração de worker web dedicado e recursos PDF mais raros.

### Fase 10 — Scripting API (18 arquivos) ⏳ Diferido

### Fase 11 — Pontos de Entrada (barrel exports)

---

## 🔧 Padrões de Conversão JS → Dart

### Execução segura dos testes

Use `./tool/run_tests.ps1` no lugar de executar `dart test` diretamente. O
script remove os artefatos `dart_test.kernel.*` de `%TEMP%` no bloco `finally`
e limpa o cache local `.dart_tool/test` antes de cada execução.

```powershell
# Suíte Dart/VM
./tool/run_tests.ps1

# Teste que exige DOM/Chrome
./tool/run_tests.ps1 test/display/canvas_factory_test.dart -p chrome
```

| JavaScript | Dart |
|-----------|------|
| `class X { #private }` | `class X { dynamic _private; }` |
| `const obj = { a: 1 }` | `abstract class` com constantes estáticas |
| `Uint8Array` | `Uint8List` (de `dart:typed_data`) |
| `Float32Array` | `Float32List` |
| `ArrayBuffer` | `ByteBuffer` |
| `null ?? value` | `value ?? defaultValue` |
| `Symbol('X')` | Sentinela: `static final x = Object()` |
| `Object.create(null)` | `<String, dynamic>{}` |
| `Promise / async` | `Future / async` |
| `typeof x === 'undefined'` | `x == null` |
| `for...of` | `for (var x in iterable)` |
| `import/export` | `import/export` Dart |
| `throw new Error(msg)` | `throw Exception(msg)` ou classes custom |
| `console.warn` | `print('Warning: ...')` |
| `Math.min/max` | `import 'dart:math'; min()/max()` |
| `str.replaceAll(regex, fn)` | `str.replaceAllMapped(RegExp(...), fn)` |
| `crypto.randomUUID()` | Gerar com `Random.secure()` |
| `globalThis.pdfjsLib` | Não necessário — usar exports Dart |
| `PDFJSDev.test(...)` | Remover — constantes de build JS |
| `window / document / DOM` | **Pacote `web` e `dart:js_interop` (PROIBIDO usar `dart:html` depreciado)** |

---

## 📐 Regras do Porte

1. **Fidelidade funcional** — cada classe/função = mesmo comportamento.
2. **Tipagem forte** — tipos explícitos sempre que possível.
3. **Sem `dynamic` desnecessário** — preferir genéricos e tipos concretos.
4. **Documentação** — comentários do original preservados/traduzidos.
5. **Remover código JS-específico** — `PDFJSDev`, polyfills.
6. **Streams binários** — usar `Uint8List` e `ByteData`.
7. **Proibição de `dart:html`** — `dart:html` está oficialmente descontinuado/depreciado no Dart moderno. Toda integração web/navegador DEVE usar exclusivamente `package:web` e `dart:js_interop`.

---

## 📊 Estimativa de Escopo

| Módulo | Arquivos JS | Complexidade |
|--------|------------|-------------|
| shared/ | 8 | 🟡 Média |
| core/ (base) | ~85 | 🔴 Alta |
| core/xfa/ | 27 | 🔴 Alta (diferido) |
| display/ | ~35 | 🟡 Média |
| scripting_api/ | 18 | 🟡 Média (diferido) |
| **Total** | **~173** | - |

---

## 📈 Status Atual do Porte (2026-09-13)

- **Fase 1 (`shared/`):** 100% concluída com testes.
- **Fase 2 (`core/` infraestrutura de streams):** 100% concluída com testes.
- **Fase 3 (`core/` parsing e primitivas):** 100% concluída com testes.
- **Fase 4 (`core/` decodificadores e streams de filtros):** 100% concluída com testes (inclui JPEG 2000 / JPX puro Dart).
- **Fase 5 (`core/` fontes e métricas):** ~95% concluída (`font_renderer.dart`, tabelas de fatores de fontes `calibri`, `helvetica`, `myriadpro`, `segoeui`, `liberationsans_widths`, `xfa_fonts.dart`).
- **Fase 6 (`core/` renderização e documento):** `colorspace.dart` 100% completo; `pattern.dart` 100% completo; `writer.dart` 100% concluído; `pdf_manager.dart` 100% concluído; `operator_list.dart` 100% concluído; `image_resizer.dart` 100% concluído; `image.dart` (`PDFImage`) 100% concluído; `document.dart` (`Page`, `PDFDocument`) 100% concluído; `evaluator.dart` já gera listas funcionais para PDFs simples e `annotation.dart` permanece parcial.
- **Fase 7 (`core/` utilitários centrais):** `bidi.dart`, `intersector.dart`, `image_utils.dart`, `chunked_stream.dart`, `function.dart`, `default_appearance.dart`, `evaluator_preprocessor.dart`, `internal_viewer_utils.dart`, `postscript/lexer.dart` 100% concluídos.
- **Fase 9 (`display/`):** API pública, `CanvasGraphics`, grupos de transparência, máscaras e annotation layer funcional concluídos, além de factories DOM, objetos, imagens/texto XFA, transporte Fetch, seleção de backend e `text_layer.dart`; soft masks completos e recursos avançados permanecem em andamento.
- **Testes Unitários:** **1.074 testes passando (973 VM + 101 Chrome, 100% sucesso)**.
- **Análise Estática (`dart analyze`):** **0 issues**.
