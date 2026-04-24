import 'dart:typed_data';

import '../shared/util.dart';
import 'base_stream.dart';
import 'primitives.dart';

dynamic _pickPlatformItem(dynamic dict) {
  if (dict is Dict) {
    // Look for the filename in this order: UF, F, Unix, Mac, DOS
    for (final key in const ['UF', 'F', 'Unix', 'Mac', 'DOS']) {
      if (dict.has(key)) {
        return dict.get(key);
      }
    }
  }
  return null;
}

/// "A PDF file can refer to the contents of another file by using a File
/// Specification (PDF 1.1)", see the spec (7.11) for more details.
/// NOTE: Only embedded files are supported (as part of the attachments support)
/// TODO: support the 'URL' file system (with caching if !/V), portable
/// collections attributes and related files (/RF)
class FileSpec {
  bool _contentAvailable = false;
  Dict? root;
  dynamic fs;

  FileSpec(dynamic root, {bool skipContent = false}) {
    if (root is! Dict) {
      return;
    }
    this.root = root;
    if (root.has('FS')) {
      fs = root.get('FS');
    }
    if (root.has('RF')) {
      warn('Related file specifications are not supported');
    }
    if (!skipContent) {
      if (root.has('EF')) {
        _contentAvailable = true;
      } else {
        warn('Non-embedded file specifications are not supported');
      }
    }
  }

  String get filename {
    final item = _pickPlatformItem(root);
    if (item != null && item is String) {
      // NOTE: The following replacement order is INTENTIONAL, regardless of
      //       what some static code analysers (e.g. CodeQL) may claim.
      return stringToPDFString(item, keepEscapeSequence: true)
          .replaceAll('\\\\', '\\')
          .replaceAll('\\/', '/')
          .replaceAll('\\', '/');
    }
    return '';
  }

  Uint8List? get content {
    if (!_contentAvailable) {
      return null;
    }
    final ef = _pickPlatformItem(root?.get('EF'));

    if (ef is BaseStream) {
      return ef.getBytes();
    }
    warn('Embedded file specification points to non-existing/invalid content');
    return null;
  }

  String get description {
    final desc = root?.get('Desc');
    if (desc != null && desc is String) {
      return stringToPDFString(desc);
    }
    return '';
  }

  Map<String, dynamic> get serializable {
    final fn = filename;
    final stripped = stripPath(fn);
    return {
      'rawFilename': fn,
      'filename': stripped.isNotEmpty ? stripped : 'unnamed',
      'content': content,
      'description': description,
    };
  }
}
