# Viewer de exemplo

Este diretório é o destino do porte incremental de `referencia/pdf.js-master/web`.
A base atual abre PDFs por URL e oferece navegação, zoom e rotação.

Compile e sirva a raiz do repositório:

```powershell
dart compile js example/main.dart -o example/main.dart.js
dart run shelf_static --help
```

Qualquer servidor HTTP estático pode ser usado. Abra `/example/` no navegador;
servir a raiz mantém acessível o PDF de demonstração em `referencia/`.
