// Copyright 2025 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'colorspace.dart';

class IccColorSpace extends ColorSpace {
  static bool _useWasm = true;
  static String? _wasmUrl;

  IccColorSpace(Uint8List iccProfile, String name, int numComps)
      : super(name, numComps) {
    if (!IccColorSpace.isUsable) {
      throw UnsupportedError('No ICC color space support');
    }
  }

  @override
  int getOutputLength(int inputLength, [int alpha01 = 0]) {
    return ((inputLength / numComps!) * (3 + alpha01)).toInt();
  }

  static void setOptions(Map<String, dynamic> options) {
    if (options['useWorkerFetch'] == false) {
      _useWasm = false;
      return;
    }
    _useWasm = options['useWasm'] == true;
    _wasmUrl = options['wasmUrl'] as String?;
  }

  static bool get isUsable => _useWasm && _wasmUrl != null;
}

class CmykICCBasedCS extends IccColorSpace {
  static String? _iccUrl;

  CmykICCBasedCS() : super(Uint8List(0), 'DeviceCMYK', 4);

  static void setOptions(Map<String, dynamic> options) {
    _iccUrl = options['iccUrl'] as String?;
  }

  static bool get isUsable => IccColorSpace.isUsable && _iccUrl != null;
}
