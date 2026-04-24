// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'primitives.dart';
import 'core_utils.dart';
import 'base_stream.dart';
import 'stream.dart' as pdf_stream;
import 'ascii_85_stream.dart';
import 'ascii_hex_stream.dart';
import 'brotli_stream.dart';
import 'ccitt_stream.dart';
import 'flate_stream.dart';
import 'jbig2_stream.dart';
import 'jpeg_stream.dart';
import 'jpx_stream.dart';
import 'lzw_stream.dart';
import 'predictor_stream.dart';
import 'run_length_stream.dart';

const int _maxLengthToCache = 1000;

String _getInlineImageCacheKey(List<int> bytes) {
  final strBuf = <int>[];
  final ii = bytes.length;
  int i = 0;
  while (i < ii - 1) {
    strBuf.add((bytes[i++] << 8) | bytes[i++]);
  }
  if (i < ii) {
    strBuf.add(bytes[i]);
  }
  return "\${ii}_\${String.fromCharCodes(strBuf)}";
}

const List<int> specialChars = [
  1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, // 0x
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 1x
  1, 0, 0, 0, 0, 2, 0, 0, 2, 2, 0, 0, 0, 0, 0, 2, // 2x
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0, // 3x
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 4x
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0, 0, // 5x
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 6x
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0, 0, // 7x
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 8x
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // 9x
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // ax
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // bx
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // cx
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // dx
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, // ex
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0  // fx
];

int _toHexDigit(int ch) {
  if (ch >= 0x30 && ch <= 0x39) return ch & 0x0f;
  if ((ch >= 0x41 && ch <= 0x46) || (ch >= 0x61 && ch <= 0x66)) {
    return (ch & 0x0f) + 9;
  }
  return -1;
}

class Lexer {
  final BaseStream stream;
  final Map<String, dynamic>? knownCommands;
  int currentChar = -1;
  final List<String> strBuf = [];
  int _hexStringNumWarn = 0;
  int beginInlineImagePos = -1;

  Lexer(this.stream, [this.knownCommands]) {
    nextChar();
  }

  int nextChar() {
    return (currentChar = stream.getByte());
  }

  int peekChar() {
    return stream.peekByte();
  }

  dynamic getNumber() {
    int ch = currentChar;
    int divideBy = 0;
    int sign = 1;

    if (ch == 0x2d) { // '-'
      sign = -1;
      ch = nextChar();
      if (ch == 0x2d) {
        ch = nextChar();
      }
    } else if (ch == 0x2b) { // '+'
      ch = nextChar();
    }

    if (ch == 0x0a || ch == 0x0d) { // LF or CR
      do {
        ch = nextChar();
      } while (ch == 0x0a || ch == 0x0d);
    }

    if (ch == 0x2e) { // '.'
      divideBy = 10;
      ch = nextChar();
    }

    if (ch < 0x30 || ch > 0x39) {
      final msg = "Invalid number: \${String.fromCharCode(ch)} (charCode $ch)";
      if (isSpace(ch) || ch == 0x28 || ch == 0x3c || ch == -1) {
        return 0;
      }
      throw FormatException(msg);
    }

    num baseValue = ch - 0x30;
    while ((ch = nextChar()) >= 0) {
      if (ch >= 0x30 && ch <= 0x39) {
        final currentDigit = ch - 0x30;
        if (divideBy != 0) {
          divideBy *= 10;
        }
        baseValue = baseValue * 10 + currentDigit;
      } else if (ch == 0x2e) {
        if (divideBy == 0) {
          divideBy = 1;
        } else {
          break;
        }
      } else if (ch == 0x2d) { // '-'
        // ignore minus
      } else {
        break;
      }
    }

    if (divideBy != 0) {
      baseValue /= divideBy;
    }
    return sign * baseValue;
  }

  String getString() {
    int numParen = 1;
    bool done = false;
    strBuf.clear();

    int ch = nextChar();
    while (true) {
      bool charBuffered = false;
      switch (ch) {
        case -1:
          done = true;
          break;
        case 0x28: // '('
          ++numParen;
          strBuf.add("(");
          break;
        case 0x29: // ')'
          if (--numParen == 0) {
            nextChar();
            done = true;
          } else {
            strBuf.add(")");
          }
          break;
        case 0x5c: // '\\'
          ch = nextChar();
          switch (ch) {
            case -1:
              done = true;
              break;
            case 0x6e: strBuf.add("\\n"); break;
            case 0x72: strBuf.add("\\r"); break;
            case 0x74: strBuf.add("\\t"); break;
            case 0x62: strBuf.add("\\b"); break;
            case 0x66: strBuf.add("\\f"); break;
            case 0x5c:
            case 0x28:
            case 0x29:
              strBuf.add(String.fromCharCode(ch));
              break;
            case 0x30: case 0x31: case 0x32: case 0x33:
            case 0x34: case 0x35: case 0x36: case 0x37:
              int x = ch & 0x0f;
              ch = nextChar();
              charBuffered = true;
              if (ch >= 0x30 && ch <= 0x37) {
                x = (x << 3) + (ch & 0x0f);
                ch = nextChar();
                if (ch >= 0x30 && ch <= 0x37) {
                  charBuffered = false;
                  x = (x << 3) + (ch & 0x0f);
                }
              }
              strBuf.add(String.fromCharCode(x));
              break;
            case 0x0d:
              if (peekChar() == 0x0a) {
                nextChar();
              }
              break;
            case 0x0a:
              break;
            default:
              strBuf.add(String.fromCharCode(ch));
              break;
          }
          break;
        default:
          strBuf.add(String.fromCharCode(ch));
          break;
      }
      if (done) break;
      if (!charBuffered) ch = nextChar();
    }
    return strBuf.join("");
  }

  Name getName() {
    int ch;
    strBuf.clear();

    while ((ch = nextChar()) >= 0 && (ch >= specialChars.length || specialChars[ch] == 0)) {
      if (ch == 0x23) { // '#'
        ch = nextChar();
        if (ch < specialChars.length && specialChars[ch] != 0) {
          strBuf.add("#");
          break;
        }
        final x = _toHexDigit(ch);
        if (x != -1) {
          final previousCh = ch;
          ch = nextChar();
          final x2 = _toHexDigit(ch);
          if (x2 == -1) {
            strBuf.add("#");
            strBuf.add(String.fromCharCode(previousCh));
            if (ch < specialChars.length && specialChars[ch] != 0) break;
            strBuf.add(String.fromCharCode(ch));
            continue;
          }
          strBuf.add(String.fromCharCode((x << 4) | x2));
        } else {
          strBuf.add("#");
          strBuf.add(String.fromCharCode(ch));
        }
      } else {
        strBuf.add(String.fromCharCode(ch));
      }
    }
    return Name.get(strBuf.join(""));
  }

  void _hexStringWarn(int ch) {
    const int maxWarn = 5;
    if (_hexStringNumWarn++ == maxWarn) {
      return;
    }
    if (_hexStringNumWarn > maxWarn) return;
  }

  String getHexString() {
    strBuf.clear();
    int ch = currentChar;
    int firstDigit = -1, digit = -1;
    _hexStringNumWarn = 0;

    while (true) {
      if (ch < 0) {
        break;
      } else if (ch == 0x3e) { // '>'
        nextChar();
        break;
      } else if (ch < specialChars.length && specialChars[ch] == 1) {
        ch = nextChar();
        continue;
      } else {
        digit = _toHexDigit(ch);
        if (digit == -1) {
          _hexStringWarn(ch);
        } else if (firstDigit == -1) {
          firstDigit = digit;
        } else {
          strBuf.add(String.fromCharCode((firstDigit << 4) | digit));
          firstDigit = -1;
        }
        ch = nextChar();
      }
    }

    if (firstDigit != -1) {
      strBuf.add(String.fromCharCode(firstDigit << 4));
    }
    return strBuf.join("");
  }

  dynamic getObj() {
    bool comment = false;
    int ch = currentChar;

    while (true) {
      if (ch < 0) return eof;
      if (comment) {
        if (ch == 0x0a || ch == 0x0d) {
          comment = false;
        }
      } else if (ch == 0x25) { // '%'
        comment = true;
      } else if (ch >= specialChars.length || specialChars[ch] != 1) {
        break;
      }
      ch = nextChar();
    }

    switch (ch) {
      case 0x30: case 0x31: case 0x32: case 0x33: case 0x34:
      case 0x35: case 0x36: case 0x37: case 0x38: case 0x39:
      case 0x2b: case 0x2d: case 0x2e:
        return getNumber();
      case 0x28: return getString();
      case 0x2f: return getName();
      case 0x5b: // '['
        nextChar(); return Cmd.get("[");
      case 0x5d: // ']'
        nextChar(); return Cmd.get("]");
      case 0x3c: // '<'
        ch = nextChar();
        if (ch == 0x3c) {
          nextChar(); return Cmd.get("<<");
        }
        return getHexString();
      case 0x3e: // '>'
        ch = nextChar();
        if (ch == 0x3e) {
          nextChar(); return Cmd.get(">>");
        }
        return Cmd.get(">");
      case 0x7b: // '{'
        nextChar(); return Cmd.get("{");
      case 0x7d: // '}'
        nextChar(); return Cmd.get("}");
      case 0x29: // ')'
        nextChar();
        throw FormatException("Illegal character: $ch");
    }

    String str = String.fromCharCode(ch);
    if (ch < 0x20 || ch > 0x7f) {
      final nextCh = peekChar();
      if (nextCh >= 0x20 && nextCh <= 0x7f) {
        nextChar();
        return Cmd.get(str);
      }
    }

    bool knownCommandFound = knownCommands != null && knownCommands![str] != null;
    while ((ch = nextChar()) >= 0 && (ch >= specialChars.length || specialChars[ch] == 0)) {
      final possibleCommand = str + String.fromCharCode(ch);
      if (knownCommandFound && knownCommands![possibleCommand] == null) {
        break;
      }
      if (str.length == 128) {
        throw FormatException("Command token too long: \${str.length}");
      }
      str = possibleCommand;
      knownCommandFound = knownCommands != null && knownCommands![str] != null;
    }

    if (str == "true") return true;
    if (str == "false") return false;
    if (str == "null") return null;

    if (str == "BI") {
      beginInlineImagePos = stream.pos;
    }
    return Cmd.get(str);
  }

  void skipToNextLine() {
    int ch = currentChar;
    while (ch >= 0) {
      if (ch == 0x0d) {
        ch = nextChar();
        if (ch == 0x0a) {
          nextChar();
        }
        break;
      } else if (ch == 0x0a) {
        nextChar();
        break;
      }
      ch = nextChar();
    }
  }
}

class Parser {
  final Lexer lexer;
  final dynamic xref;
  final bool allowStreams;
  final bool recoveryMode;
  
  final Map<String, dynamic> imageCache = {};
  
  dynamic buf1;
  dynamic buf2;

  Parser({
    required this.lexer,
    this.xref,
    this.allowStreams = false,
    this.recoveryMode = false,
  }) {
    refill();
  }

  void refill() {
    buf1 = lexer.getObj();
    buf2 = lexer.getObj();
  }

  void shift() {
    if (buf2 is Cmd && (buf2 as Cmd).cmd == "ID") {
      buf1 = buf2;
      buf2 = null;
    } else {
      buf1 = buf2;
      buf2 = lexer.getObj();
    }
  }

  bool tryShift() {
    try {
      shift();
      return true;
    } catch (e) {
      if (e is MissingDataException) {
        rethrow;
      }
      return false;
    }
  }

  dynamic getObj([dynamic cipherTransform]) {
    final curBuf1 = buf1;
    shift();

    if (curBuf1 is Cmd) {
      switch (curBuf1.cmd) {
        case "BI":
          return makeInlineImage(cipherTransform);
        case "[":
          final array = <dynamic>[];
          while (!isCmd(buf1, "]") && buf1 != eof) {
            array.add(getObj(cipherTransform));
          }
          if (buf1 == eof) {
            if (recoveryMode) return array;
            throw ParserEOFException("End of file inside array.");
          }
          shift();
          return array;
        case "<<":
          final dict = Dict(xref);
          while (!isCmd(buf1, ">>") && buf1 != eof) {
            if (buf1 is! Name) {
              shift();
              continue;
            }
            final key = (buf1 as Name).name;
            shift();
            if (buf1 == eof) break;
            dict.set(key, getObj(cipherTransform));
          }
          if (buf1 == eof) {
            if (recoveryMode) return dict;
            throw ParserEOFException("End of file inside dictionary.");
          }

          if (isCmd(buf2, "stream")) {
            return allowStreams ? makeStream(dict, cipherTransform) : dict;
          }
          shift();
          return dict;
        default:
          return curBuf1;
      }
    }

    if (curBuf1 is int) {
      if (buf1 is int && isCmd(buf2, "R")) {
        final ref = Ref.get(curBuf1, buf1 as int);
        shift();
        shift();
        return ref;
      }
      return curBuf1;
    }
    
    if (curBuf1 is num) {
       return curBuf1;
    }

    if (curBuf1 is String) {
      if (cipherTransform != null) {
        return cipherTransform.decryptString(curBuf1);
      }
      return curBuf1;
    }

    return curBuf1;
  }

  int findDefaultInlineStreamEnd(BaseStream stream) {
    const int E = 0x45, I = 0x49, space = 0x20, lf = 0x0a, cr = 0x0d, nul = 0x00;
    final knownCommands = lexer.knownCommands;
    final startPos = stream.pos;
    final int n = 15;
    int state = 0, ch;
    int? maybeEIPos;

    while ((ch = stream.getByte()) != -1) {
      if (state == 0) {
        state = ch == E ? 1 : 0;
      } else if (state == 1) {
        state = ch == I ? 2 : 0;
      } else {
        if (ch == space || ch == lf || ch == cr) {
          maybeEIPos = stream.pos;
          final followingBytes = stream.peekBytes(n);
          final ii = followingBytes.length;
          if (ii == 0) break;
          
          for (int i = 0; i < ii; i++) {
            ch = followingBytes[i];
            if (ch == nul && (i + 1 < ii && followingBytes[i + 1] != nul)) {
              continue;
            }
            if (ch != lf && ch != cr && (ch < space || ch > 0x7f)) {
              state = 0;
              break;
            }
          }
          if (state != 2) continue;
          
          if (knownCommands == null) continue;
          
          final tmpLexer = Lexer(pdf_stream.Stream(stream.peekBytes(5 * n)), knownCommands);
          int numArgs = 0;
          
          while (true) {
            final nextObj = tmpLexer.getObj();
            if (nextObj == eof) {
              state = 0;
              break;
            }
            if (nextObj is Cmd) {
              final knownCommand = knownCommands[nextObj.cmd];
              if (knownCommand == null) {
                state = 0;
                break;
              } else {
                final int reqArgs = knownCommand['numArgs'] ?? 0;
                final bool variableArgs = knownCommand['variableArgs'] ?? false;
                if (variableArgs ? numArgs <= reqArgs : numArgs == reqArgs) {
                  break;
                }
              }
              numArgs = 0;
              continue;
            }
            numArgs++;
          }
          if (state == 2) break;
        } else {
          state = 0;
        }
      }
    }
    
    if (ch == -1) {
      if (maybeEIPos != null) {
        stream.skip(-(stream.pos - maybeEIPos));
      }
    }
    
    int endOffset = 4;
    stream.skip(-endOffset);
    ch = stream.peekByte();
    stream.skip(endOffset);
    
    if (!isSpace(ch)) {
      endOffset--;
    }
    return stream.pos - endOffset - startPos;
  }

  int findDCTDecodeInlineStreamEnd(BaseStream stream) {
    final startPos = stream.pos;
    bool foundEOI = false;
    int b;
    int markerLength;
    
    while ((b = stream.getByte()) != -1) {
      if (b != 0xff) continue;
      
      final nextByte = stream.getByte();
      switch (nextByte) {
        case 0x00: break;
        case 0xff: stream.skip(-1); break;
        case 0xd9: foundEOI = true; break;
        case 0xc0: case 0xc1: case 0xc2: case 0xc3:
        case 0xc5: case 0xc6: case 0xc7: case 0xc9:
        case 0xca: case 0xcb: case 0xcd: case 0xce:
        case 0xcf: case 0xc4: case 0xcc: case 0xda:
        case 0xdb: case 0xdc: case 0xdd: case 0xde:
        case 0xdf: case 0xe0: case 0xe1: case 0xe2:
        case 0xe3: case 0xe4: case 0xe5: case 0xe6:
        case 0xe7: case 0xe8: case 0xe9: case 0xea:
        case 0xeb: case 0xec: case 0xed: case 0xee:
        case 0xef: case 0xfe:
          markerLength = stream.getUint16();
          if (markerLength > 2) {
            stream.skip(markerLength - 2);
          } else {
            stream.skip(-2);
          }
          break;
      }
      if (foundEOI) break;
    }
    final length = stream.pos - startPos;
    if (b == -1) {
      stream.skip(-length);
      return findDefaultInlineStreamEnd(stream);
    }
    inlineStreamSkipEI(stream);
    return length;
  }

  int findASCII85DecodeInlineStreamEnd(BaseStream stream) {
    const int TILDE = 0x7e, GT = 0x3e;
    final startPos = stream.pos;
    int ch;
    while ((ch = stream.getByte()) != -1) {
      if (ch == TILDE) {
        final tildePos = stream.pos;
        ch = stream.peekByte();
        while (isSpace(ch)) {
          stream.skip(1);
          ch = stream.peekByte();
        }
        if (ch == GT) {
          stream.skip(1);
          break;
        }
        if (stream.pos > tildePos) {
          final maybeEI = stream.peekBytes(2);
          if (maybeEI.length >= 2 && maybeEI[0] == 0x45 && maybeEI[1] == 0x49) {
            break;
          }
        }
      }
    }
    final length = stream.pos - startPos;
    if (ch == -1) {
      stream.skip(-length);
      return findDefaultInlineStreamEnd(stream);
    }
    inlineStreamSkipEI(stream);
    return length;
  }

  int findASCIIHexDecodeInlineStreamEnd(BaseStream stream) {
    const int GT = 0x3e;
    final startPos = stream.pos;
    int ch;
    while ((ch = stream.getByte()) != -1) {
      if (ch == GT) break;
    }
    final length = stream.pos - startPos;
    if (ch == -1) {
      stream.skip(-length);
      return findDefaultInlineStreamEnd(stream);
    }
    inlineStreamSkipEI(stream);
    return length;
  }

  void inlineStreamSkipEI(BaseStream stream) {
    const int E = 0x45, I = 0x49;
    int state = 0, ch;
    while ((ch = stream.getByte()) != -1) {
      if (state == 0) {
        state = ch == E ? 1 : 0;
      } else if (state == 1) {
        state = ch == I ? 2 : 0;
      } else if (state == 2) {
        break;
      }
    }
  }

  dynamic makeInlineImage([dynamic cipherTransform]) {
    final stream = lexer.stream;
    final dictMap = <String, dynamic>{};
    int dictLength = 0;

    while (!isCmd(buf1, "ID") && buf1 != eof) {
      if (buf1 is! Name) throw FormatException("Dictionary key must be a name");
      final key = (buf1 as Name).name;
      shift();
      if (buf1 == eof) break;
      dictMap[key] = getObj(cipherTransform);
    }
    
    if (lexer.beginInlineImagePos != -1) {
      dictLength = stream.pos - lexer.beginInlineImagePos;
    }

    dynamic filter = xref != null ? xref.fetchIfRef(dictMap["F"] ?? dictMap["Filter"]) : (dictMap["F"] ?? dictMap["Filter"]);
    String? filterName;
    if (filter is Name) {
      filterName = filter.name;
    } else if (filter is List) {
      final filterZero = xref != null ? xref.fetchIfRef(filter[0]) : filter[0];
      if (filterZero is Name) filterName = filterZero.name;
    }

    final startPos = stream.pos;
    int length;
    switch (filterName) {
      case "DCT":
      case "DCTDecode":
        length = findDCTDecodeInlineStreamEnd(stream);
        break;
      case "A85":
      case "ASCII85Decode":
        length = findASCII85DecodeInlineStreamEnd(stream);
        break;
      case "AHx":
      case "ASCIIHexDecode":
        length = findASCIIHexDecodeInlineStreamEnd(stream);
        break;
      default:
        length = findDefaultInlineStreamEnd(stream);
    }

    String? cacheKey;
    if (length < _maxLengthToCache && dictLength > 0) {
      final initialStreamPos = stream.pos;
      stream.pos = lexer.beginInlineImagePos;
      cacheKey = _getInlineImageCacheKey(stream.getBytes(dictLength + length).toList());
      stream.pos = initialStreamPos;

      final cacheEntry = imageCache[cacheKey];
      if (cacheEntry != null) {
        buf2 = Cmd.get("EI");
        shift();
        cacheEntry.reset();
        return cacheEntry;
      }
    }

    final dict = Dict(xref);
    for (final entry in dictMap.entries) {
      dict.set(entry.key, entry.value);
    }

    BaseStream imageStream = stream.makeSubStream(startPos, length, dict);
    if (cipherTransform != null) {
      imageStream = cipherTransform.createStream(imageStream, length);
    }

    imageStream = filterStream(imageStream, dict, length);
    imageStream.dict = dict;
    if (cacheKey != null) {
      // Dart Streams don't dynamically get cacheKey field, so if needed, add logic into BaseStream.
      imageCache[cacheKey] = imageStream;
    }

    buf2 = Cmd.get("EI");
    shift();

    return imageStream;
  }

  int _findStreamLength(int startPos) {
    final stream = lexer.stream;
    stream.pos = startPos;
    const int SCAN_BLOCK_LENGTH = 2048;
    final int signatureLength = 9; // "endstream".length
    final END_SIGNATURE = [0x65, 0x6e, 0x64];
    final endLength = END_SIGNATURE.length;
    final PARTIAL_SIGNATURE = [
      [0x73, 0x74, 0x72, 0x65, 0x61, 0x6d], // stream
      [0x73, 0x74, 0x65, 0x61, 0x6d], // steam
      [0x73, 0x74, 0x72, 0x65, 0x61], // strea
    ];
    final normalLength = signatureLength - endLength;

    while (stream.pos < stream.end) {
      final scanBytes = stream.peekBytes(SCAN_BLOCK_LENGTH);
      final scanLength = scanBytes.length - signatureLength;
      if (scanLength <= 0) break;
      
      int pos = 0;
      while (pos < scanLength) {
        int j = 0;
        while (j < endLength && scanBytes[pos + j] == END_SIGNATURE[j]) {
          j++;
        }
        if (j >= endLength) {
          bool found = false;
          for (final part in PARTIAL_SIGNATURE) {
            final partLen = part.length;
            int k = 0;
            while (k < partLen && scanBytes[pos + j + k] == part[k]) {
              k++;
            }
            if (k >= normalLength) {
              found = true;
              break;
            }
            if (k >= partLen) {
              final lastByte = scanBytes[pos + j + k];
              if (isSpace(lastByte)) {
                found = true;
              }
              break;
            }
          }
          if (found) {
            stream.pos += pos;
            return stream.pos - startPos;
          }
        }
        pos++;
      }
      stream.pos += scanLength;
    }
    return -1;
  }

  BaseStream makeStream(Dict dict, [dynamic cipherTransform]) {
    BaseStream stream = lexer.stream;
    lexer.skipToNextLine();
    final startPos = stream.pos - 1;

    dynamic lengthObj = dict.get("Length");
    int length = lengthObj is int ? lengthObj : 0;

    stream.pos = startPos + length;
    lexer.nextChar();

    if (tryShift() && isCmd(buf2, "endstream")) {
      shift();
    } else {
      length = _findStreamLength(startPos);
      if (length < 0) throw FormatException("Missing endstream command.");
      lexer.nextChar();
      shift();
      shift();
    }
    shift();

    stream = stream.makeSubStream(startPos, length, dict);
    if (cipherTransform != null) {
      stream = cipherTransform.createStream(stream, length);
    }
    stream = filterStream(stream, dict, length);
    stream.dict = dict;
    return stream;
  }

  BaseStream filterStream(BaseStream stream, Dict dict, int length) {
    dynamic filter = dict.get("F", "Filter");
    dynamic params = dict.get("DP", "DecodeParms");

    if (filter is Name) {
      return makeFilter(stream, filter.name, length, params);
    }
    
    int? maybeLength = length;
    if (filter is List) {
      final filterArray = filter;
      final paramsArray = params is List ? params : null;
      for (int i = 0; i < filterArray.length; i++) {
        filter = xref != null ? xref.fetchIfRef(filterArray[i]) : filterArray[i];
        if (filter is! Name) throw FormatException("Bad filter name \$filter");
        
        dynamic p;
        if (paramsArray != null && i < paramsArray.length) {
          p = xref != null ? xref.fetchIfRef(paramsArray[i]) : paramsArray[i];
        }
        stream = makeFilter(stream, filter.name, maybeLength, p);
        maybeLength = null;
      }
    }
    return stream;
  }

  BaseStream makeFilter(BaseStream stream, String name, int? maybeLength, dynamic params) {
    if (maybeLength == 0) {
      return pdf_stream.NullStream();
    }
    try {
      switch (name) {
        case "Fl":
        case "FlateDecode":
          if (params != null) {
            return PredictorStream(FlateStream(stream, maybeLength), maybeLength, params);
          }
          return FlateStream(stream, maybeLength);
        case "LZW":
        case "LZWDecode":
          int earlyChange = 1;
          if (params != null) {
            if (params is Dict && params.has("EarlyChange")) {
              earlyChange = params.get("EarlyChange");
            }
            return PredictorStream(LZWStream(stream, maybeLength, earlyChange), maybeLength, params);
          }
          return LZWStream(stream, maybeLength, earlyChange);
        case "DCT":
        case "DCTDecode":
          return JpegStream(stream, maybeLength, params);
        case "JPX":
        case "JPXDecode":
          return JpxStream(stream, maybeLength, params);
        case "A85":
        case "ASCII85Decode":
          return Ascii85Stream(stream, maybeLength);
        case "AHx":
        case "ASCIIHexDecode":
          return AsciiHexStream(stream, maybeLength);
        case "CCF":
        case "CCITTFaxDecode":
          return CCITTFaxStream(stream, maybeLength, params);
        case "RL":
        case "RunLengthDecode":
          return RunLengthStream(stream, maybeLength);
        case "JBIG2Decode":
          return Jbig2Stream(stream, maybeLength, params);
        case "BrotliDecode":
          return BrotliStream(stream, maybeLength);
      }
      return stream;
    } catch (ex) {
      if (ex is MissingDataException) {
        rethrow;
      }
      return pdf_stream.NullStream();
    }
  }
}

class Linearization {
  static Map<String, dynamic>? create(BaseStream stream) {
    int getInt(Dict linDict, String name, [bool allowZeroValue = false]) {
      final obj = linDict.get(name);
      if (obj is int && (allowZeroValue ? obj >= 0 : obj > 0)) {
        return obj;
      }
      throw FormatException('The "$name" parameter in the linearization dictionary is invalid.');
    }

    List<dynamic> getHints(Dict linDict) {
      final hints = linDict.get("H");
      if (hints is List && (hints.length == 2 || hints.length == 4)) {
        for (int i = 0; i < hints.length; i++) {
          final hint = hints[i];
          if (!(hint is int && hint > 0)) {
            throw FormatException("Hint ($i) in the linearization dictionary is invalid.");
          }
        }
        return hints;
      }
      throw FormatException("Hint array in the linearization dictionary is invalid.");
    }

    final parser = Parser(lexer: Lexer(stream));
    final obj1 = parser.getObj();
    final obj2 = parser.getObj();
    final obj3 = parser.getObj();
    final linDict = parser.getObj();
    
    if (!(obj1 is int && obj2 is int && isCmd(obj3, "obj") && linDict is Dict)) {
      return null;
    }
    
    final obj = linDict.get("Linearized");
    if (!(obj is num && obj > 0)) return null;

    final length = getInt(linDict, "L");
    if (length != stream.length) {
      throw FormatException('The "L" parameter in the linearization dictionary does not equal the stream length.');
    }

    return {
      'length': length,
      'hints': getHints(linDict),
      'objectNumberFirst': getInt(linDict, "O"),
      'endFirst': getInt(linDict, "E"),
      'numPages': getInt(linDict, "N"),
      'mainXRefEntriesOffset': getInt(linDict, "T"),
      'pageFirst': linDict.has("P") ? getInt(linDict, "P", true) : 0,
    };
  }
}
