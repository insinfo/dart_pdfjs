import 'dart:async';

import 'package:pdfjs/pdfjs_web.dart';
import 'package:web/web.dart' as web;

PDFDocumentProxy? _document;
var _pageNumber = 1;
var _scale = 1.0;
var _rotation = 0;
var _renderGeneration = 0;

T _element<T extends web.Element>(String selector) =>
    web.document.querySelector(selector) as T;

void main() {
  _element<web.HTMLFormElement>('#open-form').onSubmit.listen((event) {
    event.preventDefault();
    unawaited(_open(_element<web.HTMLInputElement>('#url').value));
  });
  _element<web.HTMLButtonElement>('#previous').onClick.listen((_) {
    if (_pageNumber > 1) {
      _pageNumber--;
      unawaited(_renderCurrentPage());
    }
  });
  _element<web.HTMLButtonElement>('#next').onClick.listen((_) {
    if (_pageNumber < (_document?.numPages ?? 0)) {
      _pageNumber++;
      unawaited(_renderCurrentPage());
    }
  });
  _element<web.HTMLInputElement>('#page-number').onChange.listen((_) {
    final requested = int.tryParse(
      _element<web.HTMLInputElement>('#page-number').value,
    );
    final count = _document?.numPages ?? 0;
    if (requested != null && requested >= 1 && requested <= count) {
      _pageNumber = requested;
      unawaited(_renderCurrentPage());
    } else {
      _syncControls();
    }
  });
  _element<web.HTMLButtonElement>('#zoom-out').onClick.listen((_) {
    _scale = (_scale / 1.2).clamp(0.25, 5.0);
    unawaited(_renderCurrentPage());
  });
  _element<web.HTMLButtonElement>('#zoom-in').onClick.listen((_) {
    _scale = (_scale * 1.2).clamp(0.25, 5.0);
    unawaited(_renderCurrentPage());
  });
  _element<web.HTMLButtonElement>('#rotate').onClick.listen((_) {
    _rotation = (_rotation + 90) % 360;
    unawaited(_renderCurrentPage());
  });

  unawaited(_open(_element<web.HTMLInputElement>('#url').value));
}

Future<void> _open(String source) async {
  if (source.trim().isEmpty) return;
  final generation = ++_renderGeneration;
  _showStatus('Carregando documento…');
  try {
    await _document?.destroy();
    final task = getDocument(Uri.parse(source.trim()));
    task.onProgress = (progress) {
      final loaded = progress['loaded'] ?? 0;
      final total = progress['total'] ?? 0;
      if (generation == _renderGeneration && total > 0) {
        _showStatus('Carregando… ${(loaded * 100 / total).round()}%');
      }
    };
    final document = await task.promise;
    if (generation != _renderGeneration) {
      await document.destroy();
      return;
    }
    _document = document;
    _pageNumber = 1;
    _scale = 1.0;
    _rotation = 0;
    await _renderCurrentPage();
  } catch (error) {
    if (generation == _renderGeneration) {
      _showStatus('Não foi possível abrir o PDF: $error', error: true);
    }
  }
}

Future<void> _renderCurrentPage() async {
  final document = _document;
  if (document == null) return;
  final generation = ++_renderGeneration;
  _showStatus('Renderizando página $_pageNumber…');
  try {
    final page = await document.getPage(_pageNumber);
    final viewport = page.getViewport(scale: _scale, rotation: _rotation);
    if (generation != _renderGeneration) return;
    final canvas = _element<web.HTMLCanvasElement>('#pdf-canvas')
      ..width = viewport.width.ceil()
      ..height = viewport.height.ceil();
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    await page
        .render(RenderParameters(canvasContext: context, viewport: viewport))
        .promise;
    if (generation != _renderGeneration) return;
    _element<web.HTMLElement>('#status').style.display = 'none';
    _element<web.HTMLElement>('#page').classList.add('visible');
    _syncControls();
  } catch (error) {
    if (generation == _renderGeneration) {
      _showStatus('Falha ao renderizar a página: $error', error: true);
    }
  }
}

void _showStatus(String message, {bool error = false}) {
  _element<web.HTMLElement>('#page').classList.remove('visible');
  final status = _element<web.HTMLElement>('#status');
  status
    ..textContent = message
    ..className = error ? 'error' : '';
  status.style.display = 'block';
}

void _syncControls() {
  final count = _document?.numPages ?? 0;
  _element<web.HTMLInputElement>('#page-number').value = '$_pageNumber';
  _element<web.HTMLElement>('#page-count').textContent = '$count';
  _element<web.HTMLOutputElement>('#zoom-value').textContent =
      '${(_scale * 100).round()}%';
  _element<web.HTMLButtonElement>('#previous').disabled = _pageNumber <= 1;
  _element<web.HTMLButtonElement>('#next').disabled = _pageNumber >= count;
}
