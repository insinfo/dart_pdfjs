// Copyright 2012 Mozilla Foundation (original JS)
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

/// Entrada da tabela QE para o decodificador aritmético.
class _QeEntry {
  final int qe;
  final int nmps;
  final int nlps;
  final int switchFlag;
  const _QeEntry(this.qe, this.nmps, this.nlps, this.switchFlag);
}

// dart format off
// @formatter:off
// Table C-2
const List<_QeEntry> _qeTable = [
  _QeEntry(0x5601, 1, 1, 1),   _QeEntry(0x3401, 2, 6, 0),
  _QeEntry(0x1801, 3, 9, 0),   _QeEntry(0x0ac1, 4, 12, 0),
  _QeEntry(0x0521, 5, 29, 0),  _QeEntry(0x0221, 38, 33, 0),
  _QeEntry(0x5601, 7, 6, 1),   _QeEntry(0x5401, 8, 14, 0),
  _QeEntry(0x4801, 9, 14, 0),  _QeEntry(0x3801, 10, 14, 0),
  _QeEntry(0x3001, 11, 17, 0), _QeEntry(0x2401, 12, 18, 0),
  _QeEntry(0x1c01, 13, 20, 0), _QeEntry(0x1601, 29, 21, 0),
  _QeEntry(0x5601, 15, 14, 1), _QeEntry(0x5401, 16, 14, 0),
  _QeEntry(0x5101, 17, 15, 0), _QeEntry(0x4801, 18, 16, 0),
  _QeEntry(0x3801, 19, 17, 0), _QeEntry(0x3401, 20, 18, 0),
  _QeEntry(0x3001, 21, 19, 0), _QeEntry(0x2801, 22, 19, 0),
  _QeEntry(0x2401, 23, 20, 0), _QeEntry(0x2201, 24, 21, 0),
  _QeEntry(0x1c01, 25, 22, 0), _QeEntry(0x1801, 26, 23, 0),
  _QeEntry(0x1601, 27, 24, 0), _QeEntry(0x1401, 28, 25, 0),
  _QeEntry(0x1201, 29, 26, 0), _QeEntry(0x1101, 30, 27, 0),
  _QeEntry(0x0ac1, 31, 28, 0), _QeEntry(0x09c1, 32, 29, 0),
  _QeEntry(0x08a1, 33, 30, 0), _QeEntry(0x0521, 34, 31, 0),
  _QeEntry(0x0441, 35, 32, 0), _QeEntry(0x02a1, 36, 33, 0),
  _QeEntry(0x0221, 37, 34, 0), _QeEntry(0x0141, 38, 35, 0),
  _QeEntry(0x0111, 39, 36, 0), _QeEntry(0x0085, 40, 37, 0),
  _QeEntry(0x0049, 41, 38, 0), _QeEntry(0x0025, 42, 39, 0),
  _QeEntry(0x0015, 43, 40, 0), _QeEntry(0x0009, 44, 41, 0),
  _QeEntry(0x0005, 45, 42, 0), _QeEntry(0x0001, 45, 43, 0),
  _QeEntry(0x5601, 46, 46, 0),
];
// @formatter:on
// dart format on

/// Decodificador aritmético QM para JPEG2000 e JBIG2.
class ArithmeticDecoder {
  final Uint8List data;
  int bp;
  final int dataEnd;
  int chigh;
  int clow = 0;
  late int ct;
  int a = 0x8000;

  ArithmeticDecoder(this.data, int start, this.dataEnd) : bp = start, chigh = 0 {
    chigh = data[start];
    _byteIn();
    chigh = ((chigh << 7) & 0xffff) | ((clow >> 9) & 0x7f);
    clow = (clow << 7) & 0xffff;
    ct -= 7;
    a = 0x8000;
  }

  void _byteIn() {
    if (data[bp] == 0xff) {
      if (data[bp + 1] > 0x8f) {
        clow += 0xff00;
        ct = 8;
      } else {
        bp++;
        clow += data[bp] << 9;
        ct = 7;
      }
    } else {
      bp++;
      clow += bp < dataEnd ? data[bp] << 8 : 0xff00;
      ct = 8;
    }
    if (clow > 0xffff) {
      chigh += clow >> 16;
      clow &= 0xffff;
    }
  }

  /// Decodifica um bit usando o contexto em [contexts] na posição [pos].
  int readBit(Uint8List contexts, int pos) {
    int cxIndex = contexts[pos] >> 1;
    int cxMps = contexts[pos] & 1;
    final qeTableIcx = _qeTable[cxIndex];
    final qeIcx = qeTableIcx.qe;
    int d;
    int aVal = a - qeIcx;

    if (chigh < qeIcx) {
      if (aVal < qeIcx) {
        aVal = qeIcx;
        d = cxMps;
        cxIndex = qeTableIcx.nmps;
      } else {
        aVal = qeIcx;
        d = 1 ^ cxMps;
        if (qeTableIcx.switchFlag == 1) cxMps = d;
        cxIndex = qeTableIcx.nlps;
      }
    } else {
      chigh -= qeIcx;
      if ((aVal & 0x8000) != 0) {
        a = aVal;
        return cxMps;
      }
      if (aVal < qeIcx) {
        d = 1 ^ cxMps;
        if (qeTableIcx.switchFlag == 1) cxMps = d;
        cxIndex = qeTableIcx.nlps;
      } else {
        d = cxMps;
        cxIndex = qeTableIcx.nmps;
      }
    }

    // C.3.3 renormD
    do {
      if (ct == 0) _byteIn();
      aVal <<= 1;
      chigh = ((chigh << 1) & 0xffff) | ((clow >> 15) & 1);
      clow = (clow << 1) & 0xffff;
      ct--;
    } while ((aVal & 0x8000) == 0);
    a = aVal;

    contexts[pos] = (cxIndex << 1) | cxMps;
    return d;
  }
}
