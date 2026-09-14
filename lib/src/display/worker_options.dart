// Copyright 2018 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

class GlobalWorkerOptions {
  static dynamic _port;
  static String _src = '';

  static dynamic get workerPort => _port;
  static set workerPort(dynamic val) {
    _port = val;
  }

  static String get workerSrc => _src;
  static set workerSrc(String val) {
    _src = val;
  }
}
