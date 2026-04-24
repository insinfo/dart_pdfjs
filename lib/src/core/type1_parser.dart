// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import 'encodings.dart';
import 'core_utils.dart';
import 'stream.dart';
import '../shared/util.dart';
import 'base_stream.dart';

const bool HINTING_ENABLED = false;

const Map<String, List<int>> COMMAND_MAP = {
  "hstem": [1],
  "vstem": [3],
  "vmoveto": [4],
  "rlineto": [5],
  "hlineto": [6],
  "vlineto": [7],
  "rrcurveto": [8],
  "callsubr": [10],
  "flex": [12, 35],
  "drop": [12, 18],
  "endchar": [14],
  "rmoveto": [21],
  "hmoveto": [22],
  "vhcurveto": [30],
  "hvcurveto": [31],
};

class Type1CharString {
  double width = 0;
  double lsb = 0;
  bool flexing = false;
  List<int> output = [];
  List<dynamic> stack = [];
  List<dynamic>? seac;

  bool convert(Uint8List encoded, List<Uint8List> subrs, bool seacAnalysisEnabled) {
    final count = encoded.length;
    bool error = false;
    double wx, sbx;
    int subrNumber;
    
    for (int i = 0; i < count; i++) {
      int value = encoded[i];
      if (value < 32) {
        if (value == 12) {
          value = (value << 8) + encoded[++i];
        }
        switch (value) {
          case 1: // hstem
            if (!HINTING_ENABLED) {
              stack.clear();
              break;
            }
            error = executeCommand(2, COMMAND_MAP["hstem"]!);
            break;
          case 3: // vstem
            if (!HINTING_ENABLED) {
              stack.clear();
              break;
            }
            error = executeCommand(2, COMMAND_MAP["vstem"]!);
            break;
          case 4: // vmoveto
            if (flexing) {
              if (stack.isEmpty) {
                error = true;
                break;
              }
              final dy = stack.removeLast();
              stack.addAll([0, dy]);
              break;
            }
            error = executeCommand(1, COMMAND_MAP["vmoveto"]!);
            break;
          case 5: // rlineto
            error = executeCommand(2, COMMAND_MAP["rlineto"]!);
            break;
          case 6: // hlineto
            error = executeCommand(1, COMMAND_MAP["hlineto"]!);
            break;
          case 7: // vlineto
            error = executeCommand(1, COMMAND_MAP["vlineto"]!);
            break;
          case 8: // rrcurveto
            error = executeCommand(6, COMMAND_MAP["rrcurveto"]!);
            break;
          case 9: // closepath
            stack.clear();
            break;
          case 10: // callsubr
            if (stack.isEmpty) {
              error = true;
              break;
            }
            subrNumber = (stack.removeLast() as num).toInt();
            if (subrNumber < 0 || subrNumber >= subrs.length) { // equivalent to !subrs[subrNumber]
              error = true;
              break;
            }
            error = convert(subrs[subrNumber], subrs, seacAnalysisEnabled);
            break;
          case 11: // return
            return error;
          case 13: // hsbw
            if (stack.length < 2) {
              error = true;
              break;
            }
            wx = (stack.removeLast() as num).toDouble();
            sbx = (stack.removeLast() as num).toDouble();
            lsb = sbx;
            width = wx;
            stack.addAll([wx, sbx]);
            error = executeCommand(2, COMMAND_MAP["hmoveto"]!);
            break;
          case 14: // endchar
            output.add(COMMAND_MAP["endchar"]![0]);
            break;
          case 21: // rmoveto
            if (flexing) break;
            error = executeCommand(2, COMMAND_MAP["rmoveto"]!);
            break;
          case 22: // hmoveto
            if (flexing) {
              stack.add(0);
              break;
            }
            error = executeCommand(1, COMMAND_MAP["hmoveto"]!);
            break;
          case 30: // vhcurveto
            error = executeCommand(4, COMMAND_MAP["vhcurveto"]!);
            break;
          case 31: // hvcurveto
            error = executeCommand(4, COMMAND_MAP["hvcurveto"]!);
            break;
          case const ((12 << 8) + 0): // dotsection
            stack.clear();
            break;
          case const ((12 << 8) + 1): // vstem3
            if (!HINTING_ENABLED) {
              stack.clear();
              break;
            }
            error = executeCommand(2, COMMAND_MAP["vstem"]!);
            break;
          case const ((12 << 8) + 2): // hstem3
            if (!HINTING_ENABLED) {
              stack.clear();
              break;
            }
            error = executeCommand(2, COMMAND_MAP["hstem"]!);
            break;
          case const ((12 << 8) + 6): // seac
            if (seacAnalysisEnabled) {
              final asb = stack[stack.length - 5];
              final spliced = stack.sublist(stack.length - 4);
              stack.length -= 4;
              seac = spliced;
              seac![0] += lsb - asb;
              error = executeCommand(0, COMMAND_MAP["endchar"]!);
            } else {
              error = executeCommand(4, COMMAND_MAP["endchar"]!);
            }
            break;
          case const ((12 << 8) + 7): // sbw
            if (stack.length < 4) {
              error = true;
              break;
            }
            stack.removeLast(); // wy
            wx = (stack.removeLast() as num).toDouble();
            final sby = stack.removeLast();
            sbx = (stack.removeLast() as num).toDouble();
            lsb = sbx;
            width = wx;
            stack.addAll([wx, sbx, sby]);
            error = executeCommand(3, COMMAND_MAP["rmoveto"]!);
            break;
          case const ((12 << 8) + 12): // div
            if (stack.length < 2) {
              error = true;
              break;
            }
            final num2 = stack.removeLast();
            final num1 = stack.removeLast();
            stack.add(num1 / num2);
            break;
          case const ((12 << 8) + 16): // callothersubr
            if (stack.length < 2) {
              error = true;
              break;
            }
            subrNumber = (stack.removeLast() as num).toInt();
            final numArgs = (stack.removeLast() as num).toInt();
            if (subrNumber == 0 && numArgs == 3) {
              final flexArgs = stack.sublist(stack.length - 17);
              stack.length -= 17;
              stack.addAll([
                flexArgs[2] + flexArgs[0], // bcp1x + rpx
                flexArgs[3] + flexArgs[1], // bcp1y + rpy
                flexArgs[4], // bcp2x
                flexArgs[5], // bcp2y
                flexArgs[6], // p2x
                flexArgs[7], // p2y
                flexArgs[8], // bcp3x
                flexArgs[9], // bcp3y
                flexArgs[10], // bcp4x
                flexArgs[11], // bcp4y
                flexArgs[12], // p3x
                flexArgs[13], // p3y
                flexArgs[14] // flexDepth
              ]);
              error = executeCommand(13, COMMAND_MAP["flex"]!, true);
              flexing = false;
              stack.addAll([flexArgs[15], flexArgs[16]]);
            } else if (subrNumber == 1 && numArgs == 0) {
              flexing = true;
            }
            break;
          case const ((12 << 8) + 17): // pop
            break;
          case const ((12 << 8) + 33): // setcurrentpoint
            stack.clear();
            break;
          default:
            warn('Unknown type 1 charstring command of "\$value"');
            break;
        }
        if (error) break;
        continue;
      } else if (value <= 246) {
        value -= 139;
      } else if (value <= 250) {
        value = (value - 247) * 256 + encoded[++i] + 108;
      } else if (value <= 254) {
        value = -((value - 251) * 256) - encoded[++i] - 108;
      } else {
        value = ((encoded[++i] & 0xff) << 24) |
                ((encoded[++i] & 0xff) << 16) |
                ((encoded[++i] & 0xff) << 8) |
                ((encoded[++i] & 0xff) << 0);
      }
      stack.add(value);
    }
    return error;
  }

  bool executeCommand(int howManyArgs, List<int> command, [bool keepStack = false]) {
    final stackLength = stack.length;
    if (howManyArgs > stackLength) {
      return true;
    }
    final start = stackLength - howManyArgs;
    for (int i = start; i < stackLength; i++) {
      dynamic val = stack[i];
      if (val is int) {
        output.addAll([28, (val >> 8) & 0xff, val & 0xff]);
      } else {
        int v = (65536 * val).toInt();
        output.addAll([
          255,
          (v >> 24) & 0xff,
          (v >> 16) & 0xff,
          (v >> 8) & 0xff,
          v & 0xff
        ]);
      }
    }
    output.addAll(command);
    if (keepStack) {
      stack.removeRange(start, stackLength);
    } else {
      stack.clear();
    }
    return false;
  }
}

const int EEXEC_ENCRYPT_KEY = 55665;
const int CHAR_STRS_ENCRYPT_KEY = 4330;

bool isHexDigit(int code) {
  return (code >= 48 && code <= 57) || // '0'-'9'
         (code >= 65 && code <= 70) || // 'A'-'F'
         (code >= 97 && code <= 102);  // 'a'-'f'
}

Uint8List decrypt(Uint8List data, int key, int discardNumber) {
  if (discardNumber >= data.length) {
    return Uint8List(0);
  }
  const int c1 = 52845, c2 = 22719;
  int r = key;
  for (int i = 0; i < discardNumber; i++) {
    r = ((data[i] + r) * c1 + c2) & 0xffff;
  }
  final count = data.length - discardNumber;
  final decrypted = Uint8List(count);
  for (int i = discardNumber, j = 0; j < count; i++, j++) {
    final value = data[i];
    decrypted[j] = value ^ (r >> 8);
    r = ((value + r) * c1 + c2) & 0xffff;
  }
  return decrypted;
}

Uint8List decryptAscii(Uint8List data, int key, int discardNumber) {
  const int c1 = 52845, c2 = 22719;
  int r = key;
  final count = data.length;
  final maybeLength = count >>> 1;
  final decrypted = Uint8List(maybeLength);
  int j = 0;
  for (int i = 0; i < count; i++) {
    final digit1 = data[i];
    if (!isHexDigit(digit1)) {
      continue;
    }
    i++;
    int digit2 = 0; // initialize
    while (i < count && !isHexDigit((digit2 = data[i]))) {
      i++;
    }
    if (i < count) {
      final value = int.parse(String.fromCharCodes([digit1, digit2]), radix: 16);
      decrypted[j++] = value ^ (r >> 8);
      r = ((value + r) * c1 + c2) & 0xffff;
    }
  }
  return decrypted.sublist(discardNumber, j);
}

bool isSpecial(int c) {
  return c == 0x2f || // '/'
         c == 0x5b || // '['
         c == 0x5d || // ']'
         c == 0x7b || // '{'
         c == 0x7d || // '}'
         c == 0x28 || // '('
         c == 0x29;   // ')'
}

class Type1Parser {
  late BaseStream stream;
  int currentChar = -1;
  bool seacAnalysisEnabled;

  Type1Parser(BaseStream s, bool encrypted, this.seacAnalysisEnabled) {
    if (encrypted) {
      final data = s.getBytes();
      final isBinary = !(
        (isHexDigit(data[0]) || isSpace(data[0])) &&
        isHexDigit(data[1]) &&
        isHexDigit(data[2]) &&
        isHexDigit(data[3]) &&
        isHexDigit(data[4]) &&
        isHexDigit(data[5]) &&
        isHexDigit(data[6]) &&
        isHexDigit(data[7])
      );
      stream = Stream(
        isBinary ? decrypt(data, EEXEC_ENCRYPT_KEY, 4) : decryptAscii(data, EEXEC_ENCRYPT_KEY, 4)
      );
    } else {
      stream = s;
    }
    nextChar();
  }

  List<double> readNumberArray() {
    getToken(); // read '[' or '{'
    final array = <double>[];
    while (true) {
      final token = getToken();
      if (token == null || token == "]" || token == "}") {
        break;
      }
      array.add(double.tryParse(token) ?? 0.0);
    }
    return array;
  }

  double readNumber() {
    final token = getToken();
    return double.tryParse(token ?? "0") ?? 0.0;
  }

  int readInt() {
    final token = getToken();
    return int.tryParse(token ?? "0") ?? 0;
  }

  int readBoolean() {
    final token = getToken();
    return token == "true" ? 1 : 0;
  }

  int nextChar() {
    return (currentChar = stream.getByte());
  }

  int prevChar() {
    stream.skip(-2);
    return (currentChar = stream.getByte());
  }

  String? getToken() {
    bool comment = false;
    int ch = currentChar;
    while (true) {
      if (ch == -1) {
        return null;
      }
      if (comment) {
        if (ch == 0x0a || ch == 0x0d) {
          comment = false;
        }
      } else if (ch == 0x25) { // '%'
        comment = true;
      } else if (!isSpace(ch)) {
        break;
      }
      ch = nextChar();
    }
    if (isSpecial(ch)) {
      nextChar();
      return String.fromCharCode(ch);
    }
    final sb = StringBuffer();
    do {
      sb.writeCharCode(ch);
      ch = nextChar();
    } while (ch >= 0 && !isSpace(ch) && !isSpecial(ch));
    return sb.toString();
  }

  Uint8List readCharStrings(Uint8List bytes, dynamic lenIV) {
    if (lenIV == -1) {
      return bytes;
    }
    return decrypt(bytes, CHAR_STRS_ENCRYPT_KEY, lenIV as int);
  }

  Map<String, dynamic> extractFontProgram(dynamic properties) {
    final subrs = <Uint8List>[];
    final charstrings = <Map<String, dynamic>>[];
    final privateData = <String, dynamic>{"lenIV": 4};
    final program = <String, dynamic>{
      "subrs": <Uint8List>[],
      "charstrings": <Map<String, dynamic>>[],
      "properties": {
        "privateData": privateData,
      },
    };
    String? token;
    int length;
    Uint8List data;
    dynamic lenIV;

    while ((token = getToken()) != null) {
      if (token != "/") continue;
      token = getToken();
      if (token == null) break;
      
      switch (token) {
        case "CharStrings":
          getToken();
          getToken();
          getToken();
          getToken();
          while (true) {
            token = getToken();
            if (token == null || token == "end") break;
            if (token != "/") continue;
            
            final glyph = getToken()!;
            length = readInt();
            getToken();
            data = length > 0 ? stream.getBytes(length) : Uint8List(0);
            lenIV = privateData["lenIV"];
            final encoded = readCharStrings(data, lenIV);
            nextChar();
            token = getToken();
            if (token == "noaccess") {
              getToken();
            } else if (token == "/") {
              prevChar();
            }
            charstrings.add({"glyph": glyph, "encoded": encoded});
          }
          break;
        case "Subrs":
          readInt();
          getToken();
          while (getToken() == "dup") {
            final index = readInt();
            length = readInt();
            getToken();
            data = length > 0 ? stream.getBytes(length) : Uint8List(0);
            lenIV = privateData["lenIV"];
            final encoded = readCharStrings(data, lenIV);
            nextChar();
            token = getToken();
            if (token == "noaccess") {
              getToken();
            }
            if (index >= subrs.length) {
              subrs.length = index + 1;
            }
            subrs[index] = encoded;
          }
          break;
        case "BlueValues":
        case "OtherBlues":
        case "FamilyBlues":
        case "FamilyOtherBlues":
          final blueArray = readNumberArray();
          if (blueArray.isNotEmpty && blueArray.length % 2 == 0 && HINTING_ENABLED) {
            privateData[token] = blueArray;
          }
          break;
        case "StemSnapH":
        case "StemSnapV":
          privateData[token] = readNumberArray();
          break;
        case "StdHW":
        case "StdVW":
          final array = readNumberArray();
          if (array.isNotEmpty) {
            privateData[token] = array[0];
          }
          break;
        case "BlueShift":
        case "lenIV":
        case "BlueFuzz":
        case "BlueScale":
        case "LanguageGroup":
          privateData[token] = readNumber();
          break;
        case "ExpansionFactor":
          final val = readNumber();
          privateData[token] = val == 0 ? 0.06 : val;
          break;
        case "ForceBold":
          privateData[token] = readBoolean();
          break;
      }
    }

    final outCharstrings = program["charstrings"] as List<Map<String, dynamic>>;
    for (final charDef in charstrings) {
      final glyph = charDef["glyph"];
      final encoded = charDef["encoded"];
      
      final charString = Type1CharString();
      final error = charString.convert(encoded, subrs, seacAnalysisEnabled);
      List<int> output = charString.output;
      if (error) {
        output = [14];
      }
      final charStringObject = <String, dynamic>{
        "glyphName": glyph,
        "charstring": output,
        "width": charString.width,
        "lsb": charString.lsb,
        "seac": charString.seac,
      };
      
      if (glyph == ".notdef") {
        outCharstrings.insert(0, charStringObject);
      } else {
        outCharstrings.add(charStringObject);
      }
      
      if (properties != null && properties.builtInEncoding != null) {
        final List<dynamic> builtIn = properties.builtInEncoding;
        final index = builtIn.indexOf(glyph);
        if (index > -1 && 
            properties.widths[index] == null && 
            index >= properties.firstChar && 
            index <= properties.lastChar) {
          properties.widths[index] = charString.width;
        }
      }
    }

    // copy subrs
    program["subrs"] = subrs;
    return program;
  }

  void extractFontHeader(dynamic properties) {
    String? token;
    while ((token = getToken()) != null) {
      if (token != "/") continue;
      token = getToken();
      if (token == null) break;
      
      switch (token) {
        case "FontMatrix":
          properties.fontMatrix = readNumberArray();
          break;
        case "Encoding":
          final encodingArg = getToken();
          dynamic encoding;
          if (encodingArg != null && !RegExp(r'^\d+$').hasMatch(encodingArg)) {
            encoding = getEncoding(encodingArg);
          } else if (encodingArg != null) {
            encoding = <String?>[];
            final size = int.parse(encodingArg);
            getToken(); // array
            for (int j = 0; j < size; j++) {
              token = getToken();
              while (token != "dup" && token != "def") {
                token = getToken();
                if (token == null) return;
              }
              if (token == "def") break;
              
              final index = readInt();
              getToken(); // '/'
              final glyph = getToken();
              if (index >= encoding.length) {
                encoding.length = index + 1;
              }
              encoding[index] = glyph;
              getToken(); // put
            }
          }
          properties.builtInEncoding = encoding;
          break;
        case "FontBBox":
          final fontBBox = readNumberArray();
          if (fontBBox.length >= 4) {
            properties.ascent = fontBBox[3] > fontBBox[1] ? fontBBox[3] : fontBBox[1];
            properties.descent = fontBBox[1] < fontBBox[3] ? fontBBox[1] : fontBBox[3];
            properties.ascentScaled = true;
          }
          break;
      }
    }
  }
}
