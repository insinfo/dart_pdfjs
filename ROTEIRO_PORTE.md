# Roteiro de Porte: pdf.js → em puro Dart para web usando dart:html ou pacote web

> **Projeto:** pdfjs (Dart)  
> **Origem:** `referencia/pdf.js-master/src/` (Mozilla pdf.js)  
> **Destino:** `lib/src/`  
> **Data de Início:** 2026-04-23  

---

## 📋 Visão Geral

Porte completo da biblioteca **pdf.js** (Mozilla) para **Dart **, usando `dart:typed_data` para manipulação binária e o pacote `web` ou dart:html para interações DOM quando necessário. A estrutura de diretórios em Dart espelha a original JS.

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

### Fase 1 — Fundação (shared/) ✅ PRIORIDADE MÁXIMA
> Base de tudo. Sem isso nada compila.

| # | Arquivo JS | Arquivo Dart | Status |
|---|-----------|-------------|--------|
| 1 | `shared/util.js` | `shared/util.dart` | 🔄 Portar |
| 2 | `shared/math_clamp.js` | `shared/math_clamp.dart` | ✅ |
| 3 | `shared/base_pdf_stream.js` | `shared/base_pdf_stream.dart` | ✅ |
| 4 | `shared/image_utils.js` | `shared/image_utils.dart` | ✅ |
| 5 | `shared/message_handler.js` | `shared/message_handler.dart` | ✅ (Stubs) |
| 6 | `shared/murmurhash3.js` | `shared/murmurhash3.dart` | ✅ |
| 7 | `shared/scripting_utils.js` | `shared/scripting_utils.dart` | ⏳ Diferido |
| 8 | `shared/obj_bin_transform_utils.js` | `shared/obj_bin_transform_utils.dart` | ⏳ Diferido |

### Fase 2 — Core Primitivas (core/ — base)
> Estruturas fundamentais do PDF: primitivas, streams, parser.

| # | Arquivo JS | Arquivo Dart | Status |
|---|-----------|-------------|--------|
| 1 | `core/primitives.js` | `core/primitives.dart` | ✅ |
| 2 | `core/base_stream.js` | `core/base_stream.dart` | ✅ |
| 3 | `core/stream.js` | `core/stream.dart` | ✅ |
| 4 | `core/decode_stream.js` | `core/decode_stream.dart` | ✅ |
| 5 | `core/core_utils.js` | `core/core_utils.dart` | 🔄 Stubs |
| 6 | `core/parser.js` | `core/parser.dart` | ✅ |
| 7 | `core/xref.js` | `core/xref.dart` | ✅ |

### Fase 3 — Core Streams (filtros de compressão)
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
| 10 | `core/jbig2.js` | `core/jbig2.dart` | 🔄 Stubs |
| 11 | `core/jpeg_stream.js` | `core/jpeg_stream.dart` | ✅ |
| 12 | `core/jpg.js` | `core/jpg.dart` | 🔄 Stubs |
| 13 | `core/jpx_stream.js` | `core/jpx_stream.dart` | ✅ |
| 14 | `core/jpx.js` | `core/jpx.dart` | 🔄 Stubs |
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
| 3 | `core/fonts.js` | `core/fonts.dart` | 🔴 (122KB) |
| 4 | `core/cff_parser.js` | `core/cff_parser.dart` | ✅ |
| 5 | `core/cff_font.js` | `core/cff_font.dart` | ✅ |
| 6 | `core/type1_font.js` | `core/type1_font.dart` | ✅ |
| 7 | `core/type1_parser.js` | `core/type1_parser.dart` | ✅ |
| 8 | `core/font_renderer.js` | `core/font_renderer.dart` | 🟡 |
| 9 | `core/font_substitutions.js` | `core/font_substitutions.dart` | 🟡 |
| 10 | `core/glyf.js` | `core/glyf.dart` | 🟡 |
| 11 | `core/glyphlist.js` | `core/glyphlist.dart` | ✅ |
| 12 | `core/charsets.js` | `core/charsets.dart` | ✅ |
| 13 | `core/standard_fonts.js` | `core/standard_fonts.dart` | ✅ |
| 14 | `core/metrics.js` | `core/metrics.dart` | ✅ |
| 15 | `core/unicode.js` | `core/unicode.dart` | ✅ |
| 16 | `core/cmap.js` | `core/cmap.dart` | ✅ |
| 17 | `core/binary_cmap.js` | `core/binary_cmap.dart` | ✅ |
| 18 | `core/to_unicode_map.js` | `core/to_unicode_map.dart` | ✅ |
| 19 | `core/opentype_file_builder.js` | `core/opentype_file_builder.dart` | 🟡 |
| 20-24 | `core/*_factors.js`, `core/liberationsans_widths.js` | `core/*_factors.dart` | 🟢 (dados) |

### Fase 6 — Core Rendering & Document

| # | Arquivo JS | Arquivo Dart | Complexidade |
|---|-----------|-------------|-------------|
| 1 | `core/colorspace.js` | `core/colorspace.dart` | 🟡 |
| 2 | `core/evaluator.js` | `core/evaluator.dart` | 🔴 (176KB!) |
| 3 | `core/document.js` | `core/document.dart` | 🔴 (61KB) |
| 4 | `core/catalog.js` | `core/catalog.dart` | 🔴 (56KB) |
| 5 | `core/annotation.js` | `core/annotation.dart` | 🔴 (157KB!) |
| 6-18 | Restante | `core/*.dart` | 🟡 |

### Fase 7 — Core Utilitários Secundários (~14 arquivos) 🟡

### Fase 8 — Core XFA (27 arquivos) ⏳ Diferido

### Fase 9 — Display (~35 arquivos) 🟡

### Fase 10 — Scripting API (18 arquivos) ⏳ Diferido

### Fase 11 — Pontos de Entrada (barrel exports)

---

## 🔧 Padrões de Conversão JS → Dart

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

---

## 📐 Regras do Porte

1. **Fidelidade funcional** — cada classe/função = mesmo comportamento.
2. **Tipagem forte** — tipos explícitos sempre que possível.
3. **Sem `dynamic` desnecessário** — preferir genéricos e tipos concretos.
4. **Documentação** — comentários do original preservados/traduzidos.
5. **Remover código JS-específico** — `PDFJSDev`, polyfills.
6. **Streams binários** — usar `Uint8List` e `ByteData`.

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

## ▶️ Início Imediato

**Fases 1 e 2 começam AGORA** com:
1. `shared/math_clamp.dart`
2. `shared/util.dart`
3. `core/primitives.dart`
4. `core/base_stream.dart`
5. `core/stream.dart`
6. `core/core_utils.dart`
