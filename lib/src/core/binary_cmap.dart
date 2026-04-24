// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'stream.dart' as pdf_stream;
// import 'cmap.dart'; // TODO: Typed CMap when available

int _hexToInt(Uint8List a, int size) {
  int n = 0;
  for (int i = 0; i <= size; i++) {
    n = (n << 8) | a[i];
  }
  return n & 0xFFFFFFFF; // Ensure unsigned 32-bit
}

String _hexToStr(Uint8List a, int size) {
  // This code is hot.
  if (size == 1) {
    return String.fromCharCode(a[0]) + String.fromCharCode(a[1]);
  }
  if (size == 3) {
    return String.fromCharCodes([a[0], a[1], a[2], a[3]]);
  }
  return String.fromCharCodes(a.sublist(0, size + 1));
}

void _addHex(Uint8List a, Uint8List b, int size) {
  int c = 0;
  for (int i = size; i >= 0; i--) {
    c += a[i] + b[i];
    a[i] = c & 255;
    c >>= 8;
  }
}

void _incHex(Uint8List a, int size) {
  int c = 1;
  for (int i = size; i >= 0 && c > 0; i--) {
    c += a[i];
    a[i] = c & 255;
    c >>= 8;
  }
}

const int _maxNumSize = 16;
const int _maxEncodedNumSize = 19; // ceil(MAX_NUM_SIZE * 7 / 8)

class BinaryCMapStream extends pdf_stream.Stream {
  final Uint8List tmpBuf = Uint8List(_maxEncodedNumSize);

  BinaryCMapStream(Uint8List data) : super(data, 0, data.length, null);

  int readNumber() {
    int n = 0;
    bool last;
    do {
      final b = getByte();
      if (b < 0) {
        throw FormatException('unexpected EOF in bcmap');
      }
      last = (b & 0x80) == 0;
      n = (n << 7) | (b & 0x7f);
    } while (!last);
    return n;
  }

  int readSigned() {
    final n = readNumber();
    return (n & 1) != 0 ? ~(n >>> 1) : n >>> 1;
  }

  void readHex(Uint8List numList, int size) {
    final bytes = getBytes(size + 1);
    numList.setRange(0, size + 1, bytes);
  }

  void readHexNumber(Uint8List numList, int size) {
    bool last;
    final stack = tmpBuf;
    int sp = 0;
    do {
      final b = getByte();
      if (b < 0) {
        throw FormatException('unexpected EOF in bcmap');
      }
      last = (b & 0x80) == 0;
      stack[sp++] = b & 0x7f;
    } while (!last);
    
    int i = size, buffer = 0, bufferSize = 0;
    while (i >= 0) {
      while (bufferSize < 8 && sp > 0) {
        buffer |= stack[--sp] << bufferSize;
        bufferSize += 7;
      }
      numList[i] = buffer & 255;
      i--;
      buffer >>= 8;
      bufferSize -= 8;
    }
  }

  void readHexSigned(Uint8List numList, int size) {
    readHexNumber(numList, size);
    final sign = (numList[size] & 1) != 0 ? 255 : 0;
    int c = 0;
    for (int i = 0; i <= size; i++) {
      c = ((c & 1) << 8) | numList[i];
      numList[i] = (c >> 1) ^ sign;
    }
  }

  String readString() {
    final len = readNumber();
    final buf = List<int>.filled(len, 0);
    for (int i = 0; i < len; i++) {
      buf[i] = readNumber();
    }
    return String.fromCharCodes(buf);
  }
}

class BinaryCMapReader {
  Future<dynamic> process(Uint8List data, dynamic cMap, Future<dynamic> Function(String) extend) async {
    final stream = BinaryCMapStream(data);
    final header = stream.getByte();
    cMap.vertical = (header & 1) != 0;

    String? useCMap;
    final start = Uint8List(_maxNumSize);
    final end = Uint8List(_maxNumSize);
    final char = Uint8List(_maxNumSize);
    final charCode = Uint8List(_maxNumSize);
    final tmp = Uint8List(_maxNumSize);
    int code;

    int b;
    while ((b = stream.getByte()) >= 0) {
      final type = b >> 5;
      if (type == 7) {
        // metadata, e.g. comment or usecmap
        switch (b & 0x1f) {
          case 0:
            stream.readString(); // skipping comment
            break;
          case 1:
            useCMap = stream.readString();
            break;
        }
        continue;
      }
      final sequence = (b & 0x10) != 0;
      final dataSize = b & 15;

      if (dataSize + 1 > _maxNumSize) {
        throw Exception("BinaryCMapReader.process: Invalid dataSize.");
      }

      const ucs2DataSize = 1;
      final subitemsCount = stream.readNumber();
      switch (type) {
        case 0: // codespacerange
          stream.readHex(start, dataSize);
          stream.readHexNumber(end, dataSize);
          _addHex(end, start, dataSize);
          cMap.addCodespaceRange(
            dataSize + 1,
            _hexToInt(start, dataSize),
            _hexToInt(end, dataSize)
          );
          for (int i = 1; i < subitemsCount; i++) {
            _incHex(end, dataSize);
            stream.readHexNumber(start, dataSize);
            _addHex(start, end, dataSize);
            stream.readHexNumber(end, dataSize);
            _addHex(end, start, dataSize);
            cMap.addCodespaceRange(
              dataSize + 1,
              _hexToInt(start, dataSize),
              _hexToInt(end, dataSize)
            );
          }
          break;
        case 1: // notdefrange
          stream.readHex(start, dataSize);
          stream.readHexNumber(end, dataSize);
          _addHex(end, start, dataSize);
          stream.readNumber(); // code
          // undefined range, skipping
          for (int i = 1; i < subitemsCount; i++) {
            _incHex(end, dataSize);
            stream.readHexNumber(start, dataSize);
            _addHex(start, end, dataSize);
            stream.readHexNumber(end, dataSize);
            _addHex(end, start, dataSize);
            stream.readNumber(); // code
            // nop
          }
          break;
        case 2: // cidchar
          stream.readHex(char, dataSize);
          code = stream.readNumber();
          cMap.mapOne(_hexToInt(char, dataSize), code);
          for (int i = 1; i < subitemsCount; i++) {
            _incHex(char, dataSize);
            if (!sequence) {
              stream.readHexNumber(tmp, dataSize);
              _addHex(char, tmp, dataSize);
            }
            code = stream.readSigned() + (code + 1);
            cMap.mapOne(_hexToInt(char, dataSize), code);
          }
          break;
        case 3: // cidrange
          stream.readHex(start, dataSize);
          stream.readHexNumber(end, dataSize);
          _addHex(end, start, dataSize);
          code = stream.readNumber();
          cMap.mapCidRange(
            _hexToInt(start, dataSize),
            _hexToInt(end, dataSize),
            code
          );
          for (int i = 1; i < subitemsCount; i++) {
            _incHex(end, dataSize);
            if (!sequence) {
              stream.readHexNumber(start, dataSize);
              _addHex(start, end, dataSize);
            } else {
              start.setAll(0, end);
            }
            stream.readHexNumber(end, dataSize);
            _addHex(end, start, dataSize);
            code = stream.readNumber();
            cMap.mapCidRange(
              _hexToInt(start, dataSize),
              _hexToInt(end, dataSize),
              code
            );
          }
          break;
        case 4: // bfchar
          stream.readHex(char, ucs2DataSize);
          stream.readHex(charCode, dataSize);
          cMap.mapOne(
            _hexToInt(char, ucs2DataSize),
            _hexToStr(charCode, dataSize)
          );
          for (int i = 1; i < subitemsCount; i++) {
            _incHex(char, ucs2DataSize);
            if (!sequence) {
              stream.readHexNumber(tmp, ucs2DataSize);
              _addHex(char, tmp, ucs2DataSize);
            }
            _incHex(charCode, dataSize);
            stream.readHexSigned(tmp, dataSize);
            _addHex(charCode, tmp, dataSize);
            cMap.mapOne(
              _hexToInt(char, ucs2DataSize),
              _hexToStr(charCode, dataSize)
            );
          }
          break;
        case 5: // bfrange
          stream.readHex(start, ucs2DataSize);
          stream.readHexNumber(end, ucs2DataSize);
          _addHex(end, start, ucs2DataSize);
          stream.readHex(charCode, dataSize);
          cMap.mapBfRange(
            _hexToInt(start, ucs2DataSize),
            _hexToInt(end, ucs2DataSize),
            _hexToStr(charCode, dataSize)
          );
          for (int i = 1; i < subitemsCount; i++) {
            _incHex(end, ucs2DataSize);
            if (!sequence) {
              stream.readHexNumber(start, ucs2DataSize);
              _addHex(start, end, ucs2DataSize);
            } else {
              start.setAll(0, end);
            }
            stream.readHexNumber(end, ucs2DataSize);
            _addHex(end, start, ucs2DataSize);
            stream.readHex(charCode, dataSize);
            cMap.mapBfRange(
              _hexToInt(start, ucs2DataSize),
              _hexToInt(end, ucs2DataSize),
              _hexToStr(charCode, dataSize)
            );
          }
          break;
        default:
          throw Exception('BinaryCMapReader.process - unknown type: \$type');
      }
    }

    if (useCMap != null) {
      return extend(useCMap);
    }
    return cMap;
  }
}
