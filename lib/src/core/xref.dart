// Copyright 2021 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import '../shared/util.dart';
import 'primitives.dart';
import 'parser.dart';
import 'core_utils.dart';
import 'base_stream.dart';

class XRefEntry {
  int offset;
  int gen;
  bool free;
  bool uncompressed;

  XRefEntry({
    required this.offset,
    required this.gen,
    this.free = false,
    this.uncompressed = false,
  });
}

class XRefTableState {
  dynamic firstEntryNum;
  dynamic entryCount;
  int entryNum;
  int streamPos;
  dynamic parserBuf1;
  dynamic parserBuf2;

  XRefTableState({
    required this.entryNum,
    required this.streamPos,
    this.parserBuf1,
    this.parserBuf2,
  });
}

class XRefStreamState {
  List<dynamic> entryRanges;
  List<dynamic> byteWidths;
  int entryNum;
  int streamPos;

  XRefStreamState({
    required this.entryRanges,
    required this.byteWidths,
    required this.entryNum,
    required this.streamPos,
  });
}

class XRef {
  final BaseStream stream;
  final dynamic pdfManager;
  final List<XRefEntry?> entries = [];
  final Set<int> _xrefStms = {};
  final Map<int, dynamic> _cacheMap = {};
  final RefSet _pendingRefs = RefSet();
  int? _newPersistentRefNum;
  int? _newTemporaryRefNum;
  Map<int, dynamic>? _persistentRefsCache;

  List<int> startXRefQueue = [];
  Dict? topDict;
  Dict? trailer;
  dynamic encrypt;
  Dict? root;
  XRefTableState? tableState;
  XRefStreamState? streamState;
  bool _generationFallback = false;

  XRef(this.stream, this.pdfManager);

  void _setEntry(int index, XRefEntry entry) {
    if (index >= entries.length) {
      entries.length = index + 1;
    }
    entries[index] = entry;
  }

  Ref getNewPersistentRef(dynamic obj) {
    _newPersistentRefNum ??= (entries.isNotEmpty ? entries.length : 1);
    final num = _newPersistentRefNum!;
    _newPersistentRefNum = num + 1;
    _cacheMap[num] = obj;
    return Ref.get(num, 0);
  }

  Ref getNewTemporaryRef() {
    if (_newTemporaryRefNum == null) {
      _newTemporaryRefNum = entries.isNotEmpty ? entries.length : 1;
      if (_newPersistentRefNum != null) {
        _persistentRefsCache = {};
        for (int i = _newTemporaryRefNum!; i < _newPersistentRefNum!; i++) {
          _persistentRefsCache![i] = _cacheMap[i];
          _cacheMap.remove(i);
        }
      }
    }
    final num = _newTemporaryRefNum!;
    _newTemporaryRefNum = num + 1;
    return Ref.get(num, 0);
  }

  void resetNewTemporaryRef() {
    _newTemporaryRefNum = null;
    if (_persistentRefsCache != null) {
      for (final entry in _persistentRefsCache!.entries) {
        _cacheMap[entry.key] = entry.value;
      }
    }
    _persistentRefsCache = null;
  }

  void setStartXRef(int startXRef) {
    startXRefQueue = [startXRef];
  }

  void parse([bool recoveryMode = false]) {
    Dict? trailerDict;
    if (!recoveryMode) {
      trailerDict = readXRef();
    } else {
      warn("Indexing all PDF objects");
      trailerDict = indexObjects();
    }
    
    if (trailerDict == null) {
        throw XRefParseException();
    }
    
    trailerDict.assignXref(this);
    trailer = trailerDict;

    dynamic encryptDict;
    try {
      encryptDict = trailerDict.get("Encrypt");
    } catch (ex) {
      if (ex is MissingDataException) {
        rethrow;
      }
      warn('XRef.parse - Invalid "Encrypt" reference: "\$ex".');
    }

    if (encryptDict is Dict) {
      final ids = trailerDict.get("ID");
      // ignore: unused_local_variable
      final String fileId = (ids is List && ids.isNotEmpty) ? ids[0].toString() : "";
      encryptDict.suppressEncryption = true;
      // TODO: CipherTransformFactory instanciation
      // this.encrypt = CipherTransformFactory(encryptDict, fileId, pdfManager.password);
    }

    dynamic rootDict;
    try {
      rootDict = trailerDict.get("Root");
    } catch (ex) {
      if (ex is MissingDataException) {
        rethrow;
      }
      warn('XRef.parse - Invalid "Root" reference: "\$ex".');
    }

    if (rootDict is Dict) {
      try {
        final pages = rootDict.get("Pages");
        if (pages is Dict) {
          root = rootDict;
          return;
        }
      } catch (ex) {
        if (ex is MissingDataException) {
          rethrow;
        }
        warn('XRef.parse - Invalid "Pages" reference: "\$ex".');
      }
    }

    if (!recoveryMode) {
      throw XRefParseException();
    }
    throw FormatException("Invalid Root reference.");
  }

  Dict processXRefTable(Parser parser) {
    tableState ??= XRefTableState(
        entryNum: 0,
        streamPos: parser.lexer.stream.pos,
        parserBuf1: parser.buf1,
        parserBuf2: parser.buf2,
      );

    final obj = readXRefTable(parser);

    if (!isCmd(obj, "trailer")) {
      throw FormatException("Invalid XRef table: could not find trailer dictionary");
    }

    dynamic dict = parser.getObj();
    if (dict is! Dict && dict?.dict != null) {
      dict = dict.dict;
    }
    if (dict is! Dict) {
      throw FormatException("Invalid XRef table: could not parse trailer dictionary");
    }
    tableState = null;

    return dict;
  }

  dynamic readXRefTable(Parser parser) {
    final stream = parser.lexer.stream;
    final state = tableState!;
    stream.pos = state.streamPos;
    parser.buf1 = state.parserBuf1;
    parser.buf2 = state.parserBuf2;

    dynamic obj;

    while (true) {
      if (state.firstEntryNum == null || state.entryCount == null) {
        obj = parser.getObj();
        if (isCmd(obj, "trailer")) {
          break;
        }
        state.firstEntryNum = obj;
        state.entryCount = parser.getObj();
      }

      int first = state.firstEntryNum as int;
      final int count = state.entryCount as int;
      
      for (int i = state.entryNum; i < count; i++) {
        state.streamPos = stream.pos;
        state.entryNum = i;
        state.parserBuf1 = parser.buf1;
        state.parserBuf2 = parser.buf2;

        final offsetObj = parser.getObj();
        final genObj = parser.getObj();
        final typeObj = parser.getObj();

        bool free = false;
        bool uncompressed = false;

        if (typeObj is Cmd) {
          switch (typeObj.cmd) {
            case "f":
              free = true;
              break;
            case "n":
              uncompressed = true;
              break;
          }
        }

        if (offsetObj is! int || genObj is! int || !(free || uncompressed)) {
          throw FormatException("Invalid entry in XRef subsection: \$first, \$count");
        }

        if (i == 0 && free && first == 1) {
          first = 0;
        }

        final targetIndex = i + first;
        if (targetIndex >= entries.length || entries[targetIndex] == null) {
          _setEntry(targetIndex, XRefEntry(
            offset: offsetObj,
            gen: genObj,
            free: free,
            uncompressed: uncompressed,
          ));
        }
      }

      state.entryNum = 0;
      state.streamPos = stream.pos;
      state.parserBuf1 = parser.buf1;
      state.parserBuf2 = parser.buf2;
      state.firstEntryNum = null;
      state.entryCount = null;
    }

    if (entries.isNotEmpty && entries[0] != null && !entries[0]!.free) {
      throw FormatException("Invalid XRef table: unexpected first object");
    }
    return obj;
  }

  Dict processXRefStream(BaseStream stream) {
    if (streamState == null) {
      final dict = stream.dict as Dict;
      final byteWidths = dict.get("W") as List<dynamic>;
      final index = dict.get("Index");
      final List<dynamic> range = index is List ? index : [0, dict.get("Size")];

      streamState = XRefStreamState(
        entryRanges: range,
        byteWidths: byteWidths,
        entryNum: 0,
        streamPos: stream.pos,
      );
    }
    readXRefStream(stream);
    streamState = null;

    return stream.dict as Dict;
  }

  void readXRefStream(BaseStream stream) {
    final state = streamState!;
    stream.pos = state.streamPos;

    final typeFieldWidth = state.byteWidths[0] as int;
    final offsetFieldWidth = state.byteWidths[1] as int;
    final generationFieldWidth = state.byteWidths[2] as int;

    final entryRanges = state.entryRanges;
    while (entryRanges.isNotEmpty) {
      final int first = entryRanges[0] as int;
      final int n = entryRanges[1] as int;

      for (int i = state.entryNum; i < n; ++i) {
        state.entryNum = i;
        state.streamPos = stream.pos;

        int type = 0, offset = 0, generation = 0;
        for (int j = 0; j < typeFieldWidth; ++j) {
          final typeByte = stream.getByte();
          if (typeByte == -1) {
            throw FormatException("Invalid XRef byteWidths 'type'.");
          }
          type = (type << 8) | typeByte;
        }
        if (typeFieldWidth == 0) {
          type = 1;
        }
        for (int j = 0; j < offsetFieldWidth; ++j) {
          final offsetByte = stream.getByte();
          if (offsetByte == -1) {
            throw FormatException("Invalid XRef byteWidths 'offset'.");
          }
          offset = (offset << 8) | offsetByte;
        }
        for (int j = 0; j < generationFieldWidth; ++j) {
          final generationByte = stream.getByte();
          if (generationByte == -1) {
            throw FormatException("Invalid XRef byteWidths 'generation'.");
          }
          generation = (generation << 8) | generationByte;
        }

        bool free = false;
        bool uncompressed = false;
        switch (type) {
          case 0:
            free = true;
            break;
          case 1:
            uncompressed = true;
            break;
          case 2:
            break;
          default:
            throw FormatException("Invalid XRef entry type: \$type");
        }

        final targetIndex = first + i;
        if (targetIndex >= entries.length || entries[targetIndex] == null) {
          _setEntry(targetIndex, XRefEntry(
            offset: offset,
            gen: generation,
            free: free,
            uncompressed: uncompressed,
          ));
        }
      }

      state.entryNum = 0;
      state.streamPos = stream.pos;
      entryRanges.removeRange(0, 2);
    }
  }

  int _skipUntil(Uint8List data, int offset, List<int> what) {
    final length = what.length;
    final dataLength = data.length;
    int skipped = 0;
    while (offset < dataLength) {
      int i = 0;
      while (i < length && data[offset + i] == what[i]) {
        ++i;
      }
      if (i >= length) {
        break;
      }
      offset++;
      skipped++;
    }
    return skipped;
  }

  String _readToken(Uint8List data, int offset) {
    final sb = StringBuffer();
    int ch = data[offset];
    while (ch != 0x0a && ch != 0x0d && ch != 0x3c) { // LF, CR, '<'
      sb.writeCharCode(ch);
      if (++offset >= data.length) {
        break;
      }
      ch = data[offset];
    }
    return sb.toString();
  }

  Dict indexObjects() {
    const int TAB = 0x9, LF = 0xa, CR = 0xd, SPACE = 0x20;
    const int PERCENT = 0x25;

    final gEndobjRegExp = RegExp(r'\b(endobj|\d+\s+\d+\s+obj|xref|trailer\s*<<)\b');
    final gStartxrefRegExp = RegExp(r'\b(startxref|\d+\s+\d+\s+obj)\b');
    final objRegExp = RegExp(r'^(\d+)\s+(\d+)\s+obj\b');

    final trailerBytes = [116, 114, 97, 105, 108, 101, 114]; // trailer
    final startxrefBytes = [115, 116, 97, 114, 116, 120, 114, 101, 102]; // startxref
    final xrefBytes = [47, 88, 82, 101, 102]; // /XRef

    entries.clear();
    _cacheMap.clear();

    stream.pos = 0;
    final buffer = stream.getBytes();
    final bufferStr = bytesToString(buffer);
    final length = buffer.length;
    // stream.start in dart port: we assume 0 or basestream property
    int streamStart = 0;
    try { streamStart = (stream as dynamic).start ?? 0; } catch(_) {}
    
    int position = streamStart;
    final trailers = <int>[];
    final xrefStms = <int>[];

    while (position < length) {
      int ch = buffer[position];
      if (ch == TAB || ch == LF || ch == CR || ch == SPACE) {
        ++position;
        continue;
      }
      if (ch == PERCENT) {
        do {
          ++position;
          if (position >= length) break;
          ch = buffer[position];
        } while (ch != LF && ch != CR);
        continue;
      }
      
      final token = _readToken(buffer, position);
      final matchObj = objRegExp.firstMatch(token);

      if (token.startsWith("xref") && (token.length == 4 || RegExp(r'\s').hasMatch(token[4]))) {
        position += _skipUntil(buffer, position, trailerBytes);
        trailers.add(position);
        position += _skipUntil(buffer, position, startxrefBytes);
      } else if (matchObj != null) {
        final num = int.parse(matchObj.group(1)!);
        final gen = int.parse(matchObj.group(2)!);

        final startPos = position + token.length;
        int contentLength = 0;
        bool updateEntries = false;

        if (num >= entries.length || entries[num] == null) {
          updateEntries = true;
        } else if (entries[num]!.gen == gen) {
          try {
            final parser = Parser(lexer: Lexer(stream.makeSubStream(startPos)));
            parser.getObj();
            updateEntries = true;
          } catch (ex) {
            if (ex is ParserEOFException) {
               warn('indexObjects -- checking object ($token): "\$ex".');
            } else {
               updateEntries = true;
            }
          }
        }
        if (updateEntries) {
          _setEntry(num, XRefEntry(
            offset: position - streamStart,
            gen: gen,
            uncompressed: true,
          ));
        }

        final matchEnd = gEndobjRegExp.allMatches(bufferStr, startPos).firstOrNull;
        if (matchEnd != null) {
          final endPos = matchEnd.end;
          contentLength = endPos - position;
          if (matchEnd.group(1) != "endobj") {
             contentLength -= matchEnd.group(1)!.length + 1;
          }
        } else {
          contentLength = length - position;
        }
        
        if (position + contentLength > length) {
           contentLength = length - position;
        }
        final content = buffer.sublist(position, position + contentLength);
        final xrefTagOffset = _skipUntil(content, 0, xrefBytes);
        if (xrefTagOffset < contentLength && xrefTagOffset + 5 < content.length && content[xrefTagOffset + 5] < 64) {
          xrefStms.add(position - streamStart);
          _xrefStms.add(position - streamStart);
        }

        position += contentLength;
      } else if (token.startsWith("trailer") && (token.length == 7 || RegExp(r'\s').hasMatch(token[7]))) {
        trailers.add(position);
        final startPos = position + token.length;
        int contentLength;
        
        final matchStart = gStartxrefRegExp.allMatches(bufferStr, startPos).firstOrNull;
        if (matchStart != null) {
           final endPos = matchStart.end;
           contentLength = endPos - position;
           if (matchStart.group(1) != "startxref") {
              contentLength -= matchStart.group(1)!.length + 1;
           }
        } else {
          contentLength = length - position;
        }
        position += contentLength;
      } else {
        position += token.length + 1;
      }
    }

    for (final xrefStm in xrefStms) {
      startXRefQueue.add(xrefStm);
      readXRef(true);
    }

    final trailerDicts = <Dict>[];
    bool isEncrypted = false;
    for (final trailer in trailers) {
      stream.pos = trailer;
      final parser = Parser(
        lexer: Lexer(stream),
        xref: this,
        allowStreams: true,
        recoveryMode: true,
      );
      final obj = parser.getObj();
      if (!isCmd(obj, "trailer")) continue;

      final dict = parser.getObj();
      if (dict is! Dict) continue;
      
      trailerDicts.add(dict);
      if (dict.has("Encrypt")) {
        isEncrypted = true;
      }
    }

    dynamic trailerDict;
    dynamic trailerError;
    final dictsToTest = [...trailerDicts, "genFallback", ...trailerDicts];
    
    for (final dict in dictsToTest) {
      if (dict == "genFallback") {
        if (trailerError == null) break;
        _generationFallback = true;
        continue;
      }
      
      bool validPagesDict = false;
      try {
        final rootDict = (dict as Dict).get("Root");
        if (rootDict is! Dict) continue;
        
        final pagesDict = rootDict.get("Pages");
        if (pagesDict is! Dict) continue;
        
        final pagesCount = pagesDict.get("Count");
        if (pagesCount is int) {
          validPagesDict = true;
        }
      } catch (ex) {
        trailerError = ex;
        continue;
      }
      
      if (validPagesDict && (!isEncrypted || dict.has("Encrypt")) && dict.has("ID")) {
        return dict;
      }
      trailerDict = dict;
    }

    if (trailerDict != null) {
      return trailerDict as Dict;
    }
    if (topDict != null) {
      return topDict!;
    }

    if (trailerDicts.isEmpty) {
      for (int num = 0; num < entries.length; num++) {
        final entry = entries[num];
        if (entry == null) continue;
        final ref = Ref.get(num, entry.gen);
        dynamic obj;
        try {
          obj = fetch(ref);
        } catch (e) {
          continue;
        }
        if (obj is BaseStream) {
          obj = obj.dict;
        }
        if (obj is Dict && obj.has("Root")) {
          return obj;
        }
      }
    }

    throw FormatException("Invalid PDF structure.");
  }

  Dict? readXRef([bool recoveryMode = false]) {
    final streamStart = (stream as dynamic).start != null ? (stream as dynamic).start as int : 0;
    final startXRefParsedCache = <int>{};

    while (startXRefQueue.isNotEmpty) {
      try {
        final startXRef = startXRefQueue[0];

        if (startXRefParsedCache.contains(startXRef)) {
          warn("readXRef - skipping XRef table since it was already parsed.");
          startXRefQueue.removeAt(0);
          continue;
        }
        startXRefParsedCache.add(startXRef);

        stream.pos = startXRef + streamStart;

        final parser = Parser(
          lexer: Lexer(stream),
          xref: this,
          allowStreams: true,
        );
        dynamic obj = parser.getObj();
        Dict? dict;

        if (isCmd(obj, "xref")) {
          dict = processXRefTable(parser);
          topDict ??= dict;

          obj = dict.get("XRefStm");
          if (obj is int && !_xrefStms.contains(obj)) {
            _xrefStms.add(obj);
            startXRefQueue.add(obj);
          }
        } else if (obj is int) {
          if (parser.getObj() is! int || !isCmd(parser.getObj(), "obj") || (obj = parser.getObj()) is! BaseStream) {
            throw FormatException("Invalid XRef stream");
          }
          dict = processXRefStream(obj as BaseStream);
          topDict ??= dict;
        } else {
          throw FormatException("Invalid XRef stream header");
        }

        obj = dict.get("Prev");
        if (obj is int) {
          startXRefQueue.add(obj);
        } else if (obj is Ref) {
          startXRefQueue.add(obj.num);
        }
      } catch (e) {
        if (e is MissingDataException) rethrow;
        info("(while reading XRef): \$e");
      }
      if (startXRefQueue.isNotEmpty) {
        startXRefQueue.removeAt(0);
      }
    }

    if (topDict != null) {
      return topDict;
    }
    if (recoveryMode) {
      return null;
    }
    throw XRefParseException();
  }

  XRefEntry? getEntry(int i) {
    if (i >= entries.length) return null;
    final xrefEntry = entries[i];
    if (xrefEntry != null && !xrefEntry.free) { // offset is implicit in our class
      return xrefEntry;
    }
    return null;
  }

  dynamic fetchIfRef(dynamic obj, [bool suppressEncryption = false]) {
    if (obj is Ref) {
      return fetch(obj, suppressEncryption);
    }
    return obj;
  }

  dynamic fetch(Ref ref, [bool suppressEncryption = false]) {
    final num = ref.num;

    final cacheEntry = _cacheMap[num];
    if (cacheEntry != null) {
      if (cacheEntry is Dict && cacheEntry.objId == null) {
        cacheEntry.objId = ref.toString();
      }
      return cacheEntry;
    }
    
    dynamic xrefEntry = getEntry(num);

    if (xrefEntry == null) {
      return xrefEntry;
    }
    
    if (_pendingRefs.has(ref)) {
      _pendingRefs.remove(ref);
      warn("Ignoring circular reference: \$ref.");
      return circularRef;
    }
    _pendingRefs.put(ref);

    try {
      xrefEntry = xrefEntry.uncompressed
          ? fetchUncompressed(ref, xrefEntry, suppressEncryption)
          : fetchCompressed(ref, xrefEntry, suppressEncryption);
      _pendingRefs.remove(ref);
    } catch (ex) {
      _pendingRefs.remove(ref);
      rethrow;
    }
    
    if (xrefEntry is Dict) {
      xrefEntry.objId = ref.toString();
    } else if (xrefEntry is BaseStream) {
      if (xrefEntry.dict != null && xrefEntry.dict is Dict) {
        (xrefEntry.dict as Dict).objId = ref.toString();
      }
    }
    return xrefEntry;
  }

  dynamic fetchUncompressed(Ref ref, XRefEntry xrefEntry, [bool suppressEncryption = false]) {
    final gen = ref.gen;
    int num = ref.num;
    
    if (xrefEntry.gen != gen) {
      final msg = "Inconsistent generation in XRef: \$ref";
      if (_generationFallback && xrefEntry.gen < gen) {
        warn(msg);
        return fetchUncompressed(Ref.get(num, xrefEntry.gen), xrefEntry, suppressEncryption);
      }
      throw XRefEntryException(msg);
    }
    
    final streamStart = (stream as dynamic).start != null ? (stream as dynamic).start as int : 0;
    final subStream = stream.makeSubStream(xrefEntry.offset + streamStart);
    final parser = Parser(
      lexer: Lexer(subStream),
      xref: this,
      allowStreams: true,
    );
    
    final obj1 = parser.getObj();
    final obj2 = parser.getObj();
    final obj3 = parser.getObj();

    if (obj1 != num || obj2 != gen || obj3 is! Cmd) {
      throw XRefEntryException("Bad (uncompressed) XRef entry: \$ref");
    }
    if ((obj3 as Cmd).cmd != "obj") {
      if ((obj3).cmd.startsWith("obj")) {
        num = int.tryParse((obj3).cmd.substring(3)) ?? num;
        if (num != ref.num) {
          return num;
        }
      }
      throw XRefEntryException("Bad (uncompressed) XRef entry: \$ref");
    }
    
    dynamic parsedObj;
    if (encrypt != null && !suppressEncryption) {
      parsedObj = parser.getObj(encrypt.createCipherTransform(num, gen));
    } else {
      parsedObj = parser.getObj();
    }
    
    if (parsedObj is! BaseStream) {
      _cacheMap[num] = parsedObj;
    }
    return parsedObj;
  }

  dynamic fetchCompressed(Ref ref, XRefEntry xrefEntry, [bool suppressEncryption = false]) {
    final tableOffset = xrefEntry.offset;
    final objStmStream = fetch(Ref.get(tableOffset, 0));
    
    if (objStmStream is! BaseStream) {
      throw FormatException("bad ObjStm stream");
    }
    
    final first = (objStmStream.dict as Dict).get("First");
    final n = (objStmStream.dict as Dict).get("N");
    
    if (first is! int || n is! int) {
      throw FormatException("invalid first and n parameters for ObjStm stream");
    }
    
    Parser parser = Parser(
      lexer: Lexer(objStmStream),
      xref: this,
      allowStreams: true,
    );
    
    final nums = List<int>.filled(n, 0);
    final offsets = List<int>.filled(n, 0);
    
    for (int i = 0; i < n; ++i) {
      final numObj = parser.getObj();
      if (numObj is! int) {
        throw FormatException("invalid object number in the ObjStm stream: \$numObj");
      }
      final offsetObj = parser.getObj();
      if (offsetObj is! int) {
        throw FormatException("invalid object offset in the ObjStm stream: \$offsetObj");
      }
      nums[i] = numObj;
      
      final entry = getEntry(numObj);
      if (entry != null && entry.offset == tableOffset && entry.gen != i) {
        entry.gen = i;
      }
      offsets[i] = offsetObj;
    }

    final start = ((objStmStream as dynamic).start != null ? (objStmStream as dynamic).start as int : 0) + first;
    final parsedEntries = List<dynamic>.filled(n, null);
    
    for (int i = 0; i < n; ++i) {
      final length = i < n - 1 ? offsets[i + 1] - offsets[i] : null;
      if (length != null && length < 0) {
        throw FormatException("Invalid offset in the ObjStm stream.");
      }
      parser = Parser(
        lexer: Lexer(
          objStmStream.makeSubStream(start + offsets[i], length, objStmStream.dict)
        ),
        xref: this,
        allowStreams: true,
      );

      final obj = parser.getObj();
      parsedEntries[i] = obj;
      if (obj is BaseStream) continue;
      
      final num = nums[i];
      final entry = num < entries.length ? entries[num] : null;
      if (entry != null && entry.offset == tableOffset && entry.gen == i) {
        _cacheMap[num] = obj;
      }
    }
    
    final result = parsedEntries[xrefEntry.gen];
    if (result == null) {
      throw XRefEntryException("Bad (compressed) XRef entry: \$ref");
    }
    return result;
  }

  Future<dynamic> fetchIfRefAsync(dynamic obj, [bool suppressEncryption = false]) async {
    if (obj is Ref) {
      return fetchAsync(obj, suppressEncryption);
    }
    return obj;
  }

  Future<dynamic> fetchAsync(Ref ref, [bool suppressEncryption = false]) async {
    try {
      return fetch(ref, suppressEncryption);
    } catch (ex) {
      if (ex is! MissingDataException) {
        rethrow;
      }
      if (pdfManager != null && pdfManager.requestRange != null) {
        await pdfManager.requestRange((ex as dynamic).begin, (ex as dynamic).end);
        return fetchAsync(ref, suppressEncryption);
      } else {
        rethrow;
      }
    }
  }

  Dict? getCatalogObj() {
    return root;
  }
}
