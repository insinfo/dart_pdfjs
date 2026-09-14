// Copyright 2012 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../shared/math_clamp.dart';
import 'base_stream.dart';
import 'core_utils.dart';
import 'stream.dart';

class ChunkedStream extends Stream {
  ChunkedStream(
    int length,
    this.chunkSize,
    this.manager,
  )   : numChunks = (length / chunkSize).ceil(),
        super(
          Uint8List(length),
          0,
          length,
          null,
        );

  ChunkedStream.withBytes(
    Uint8List existingBytes,
    this.chunkSize,
    this.manager, [
    int? startPos,
    int? length,
    dynamic dict,
  ])  : numChunks = (existingBytes.length / chunkSize).ceil(),
        super(
          existingBytes,
          startPos ?? 0,
          length ?? existingBytes.length,
          dict,
        );

  final int chunkSize;
  final int numChunks;
  final dynamic manager;

  int progressiveDataLength = 0;
  int _lastSuccessfulEnsureByteChunk = -1;
  final Set<int> _loadedChunks = <int>{};

  List<int> getMissingChunks() {
    final chunks = <int>[];
    for (var chunk = 0; chunk < numChunks; ++chunk) {
      if (!_loadedChunks.contains(chunk)) {
        chunks.add(chunk);
      }
    }
    return chunks;
  }

  int get numChunksLoaded => _loadedChunks.length;

  bool get isDataLoaded => numChunksLoaded == numChunks;

  void onReceiveData(int begin, Uint8List chunk) {
    if (begin % chunkSize != 0) {
      throw FormatException('Bad begin offset: $begin');
    }

    final end = begin + chunk.lengthInBytes;
    if (end % chunkSize != 0 && end != bytes.length) {
      throw FormatException('Bad end offset: $end');
    }

    bytes.setRange(begin, end, chunk);
    final beginChunk = (begin / chunkSize).floor();
    final endChunk = ((end - 1) / chunkSize).floor() + 1;

    for (var curChunk = beginChunk; curChunk < endChunk; ++curChunk) {
      _loadedChunks.add(curChunk);
    }
  }

  void onReceiveProgressiveData(Uint8List data) {
    var position = progressiveDataLength;
    final beginChunk = (position / chunkSize).floor();

    bytes.setRange(position, position + data.lengthInBytes, data);
    position += data.lengthInBytes;
    progressiveDataLength = position;
    final endChunk =
        position >= end ? numChunks : (position / chunkSize).floor();

    for (var curChunk = beginChunk; curChunk < endChunk; ++curChunk) {
      _loadedChunks.add(curChunk);
    }
  }

  void ensureByte(int targetPos) {
    if (targetPos < progressiveDataLength) {
      return;
    }

    final chunk = (targetPos / chunkSize).floor();
    if (chunk >= numChunks) {
      return;
    }
    if (chunk == _lastSuccessfulEnsureByteChunk) {
      return;
    }

    if (!_loadedChunks.contains(chunk)) {
      throw MissingDataException(targetPos, targetPos + 1);
    }
    _lastSuccessfulEnsureByteChunk = chunk;
  }

  void ensureRange(int begin, int targetEnd) {
    if (begin >= targetEnd) {
      return;
    }
    if (targetEnd <= progressiveDataLength) {
      return;
    }

    final beginChunk = (begin / chunkSize).floor();
    if (beginChunk >= numChunks) {
      return;
    }
    final endChunk = math.min(
      ((targetEnd - 1) / chunkSize).floor() + 1,
      numChunks,
    );
    for (var chunk = beginChunk; chunk < endChunk; ++chunk) {
      if (!_loadedChunks.contains(chunk)) {
        throw MissingDataException(begin, targetEnd);
      }
    }
  }

  int? nextEmptyChunk(int beginChunk) {
    for (var i = 0; i < numChunks; ++i) {
      final chunk = (beginChunk + i) % numChunks;
      if (!_loadedChunks.contains(chunk)) {
        return chunk;
      }
    }
    return null;
  }

  bool hasChunk(int chunk) => _loadedChunks.contains(chunk);

  @override
  int getByte() {
    if (pos >= end) {
      return -1;
    }
    if (pos >= progressiveDataLength) {
      ensureByte(pos);
    }
    return bytes[pos++];
  }

  @override
  Uint8List getBytes([int? length]) {
    final strEnd = end;

    if (length == null || length == 0) {
      if (strEnd > progressiveDataLength) {
        ensureRange(pos, strEnd);
      }
      final result = bytes.sublist(pos, strEnd);
      pos = strEnd;
      return result;
    }

    var targetEnd = pos + length;
    if (targetEnd > strEnd) {
      targetEnd = strEnd;
    }
    if (targetEnd > progressiveDataLength) {
      ensureRange(pos, targetEnd);
    }

    final result = bytes.sublist(pos, targetEnd);
    pos = targetEnd;
    return result;
  }

  @override
  Uint8List getByteRange(int begin, int targetEnd) {
    var b = begin < 0 ? 0 : begin;
    var e = targetEnd > end ? end : targetEnd;
    if (e > progressiveDataLength) {
      ensureRange(b, e);
    }
    return bytes.sublist(b, e);
  }

  @override
  BaseStream makeSubStream(int start, [int? length, dynamic dict]) {
    final len = length ?? (end - start);
    if (length != null && length > 0) {
      if (start + len > progressiveDataLength) {
        ensureRange(start, start + len);
      }
    } else if (start >= progressiveDataLength) {
      ensureByte(start);
    }

    return ChunkedStreamSubstream(
      this,
      start,
      len,
      dict,
    );
  }

  @override
  List<BaseStream> getBaseStreams() => [this];
}

class ChunkedStreamSubstream extends ChunkedStream {
  ChunkedStreamSubstream(
    this.parent,
    int subStart,
    int subLength,
    dynamic dict,
  ) : super.withBytes(
          parent.bytes,
          parent.chunkSize,
          parent.manager,
          subStart,
          subLength,
          dict,
        ) {
    pos = start = subStart;
    end = subStart + subLength;
  }

  final ChunkedStream parent;

  @override
  int get progressiveDataLength => parent.progressiveDataLength;

  @override
  bool hasChunk(int chunk) => parent.hasChunk(chunk);

  @override
  int get numChunksLoaded => parent.numChunksLoaded;

  @override
  void ensureByte(int targetPos) => parent.ensureByte(targetPos);

  @override
  void ensureRange(int begin, int targetEnd) =>
      parent.ensureRange(begin, targetEnd);

  @override
  List<int> getMissingChunks() {
    final cSize = chunkSize;
    final beginChunk = (start / cSize).floor();
    final endChunk = ((end - 1) / cSize).floor() + 1;
    final missing = <int>[];
    for (var chunk = beginChunk; chunk < endChunk; ++chunk) {
      if (!parent.hasChunk(chunk)) {
        missing.add(chunk);
      }
    }
    return missing;
  }

  @override
  bool get isDataLoaded {
    if (parent.numChunksLoaded == parent.numChunks) {
      return true;
    }
    return getMissingChunks().isEmpty;
  }
}

class ChunkedStreamManager {
  ChunkedStreamManager(this.pdfStream, {
    required int length,
    required int rangeChunkSize,
    bool disableAutoFetch = false,
    dynamic msgHandler,
  })  : this.length = length,
        chunkSize = rangeChunkSize,
        this.disableAutoFetch = disableAutoFetch,
        this.msgHandler = msgHandler {
    stream = ChunkedStream(length, chunkSize, this);
  }

  final dynamic pdfStream;
  final int length;
  final int chunkSize;
  final bool disableAutoFetch;
  final dynamic msgHandler;

  late final ChunkedStream stream;
  bool aborted = false;
  int currRequestId = 0;

  final Map<int, Set<int>> _chunksNeededByRequest = <int, Set<int>>{};
  final Completer<ChunkedStream> _loadedStreamCompleter =
      Completer<ChunkedStream>();
  final Map<int, Completer<void>> _promisesByRequest =
      <int, Completer<void>>{};
  final Map<int, List<int>> _requestsByChunk = <int, List<int>>{};

  Future<ChunkedStream> requestAllChunks([bool noFetch = false]) {
    if (!noFetch) {
      final missingChunks = stream.getMissingChunks();
      _requestChunks(missingChunks);
    }
    return _loadedStreamCompleter.future;
  }

  Future<void> _requestChunks(List<int> chunks) {
    final requestId = currRequestId++;
    final chunksNeeded = <int>{};
    _chunksNeededByRequest[requestId] = chunksNeeded;

    for (final chunk in chunks) {
      if (!stream.hasChunk(chunk)) {
        chunksNeeded.add(chunk);
      }
    }

    if (chunksNeeded.isEmpty) {
      return Future<void>.value();
    }

    final completer = Completer<void>();
    _promisesByRequest[requestId] = completer;

    final chunksToRequest = <int>[];
    for (final chunk in chunksNeeded) {
      var requestIds = _requestsByChunk[chunk];
      if (requestIds == null) {
        requestIds = <int>[];
        _requestsByChunk[chunk] = requestIds;
        chunksToRequest.add(chunk);
      }
      requestIds.add(requestId);
    }

    if (chunksToRequest.isNotEmpty) {
      final groupedChunks = groupChunks(chunksToRequest);
      for (final grouped in groupedChunks) {
        final begin = grouped.beginChunk * chunkSize;
        final targetEnd = math.min(grouped.endChunk * chunkSize, length);
        sendRequest(begin, targetEnd).catchError((Object error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        });
      }
    }

    return completer.future.catchError((Object error) {
      if (aborted) return;
      throw error;
    });
  }

  ChunkedStream getStream() => stream;

  Future<void> requestRange(int begin, int end) {
    final targetEnd = math.min(end, length);
    final beginChunk = getBeginChunk(begin);
    final endChunk = getEndChunk(targetEnd);

    final chunks = <int>[];
    for (var chunk = beginChunk; chunk < endChunk; ++chunk) {
      chunks.add(chunk);
    }
    return _requestChunks(chunks);
  }

  List<({int beginChunk, int endChunk})> groupChunks(List<int> chunks) {
    final grouped = <({int beginChunk, int endChunk})>[];
    var beginChunk = -1;
    var prevChunk = -1;

    for (var i = 0; i < chunks.length; ++i) {
      final chunk = chunks[i];
      if (beginChunk < 0) {
        beginChunk = chunk;
      }
      if (prevChunk >= 0 && prevChunk + 1 != chunk) {
        grouped.add((beginChunk: beginChunk, endChunk: prevChunk + 1));
        beginChunk = chunk;
      }
      if (i + 1 == chunks.length) {
        grouped.add((beginChunk: beginChunk, endChunk: chunk + 1));
      }
      prevChunk = chunk;
    }
    return grouped;
  }

  int getBeginChunk(int begin) => (begin / chunkSize).floor();
  int getEndChunk(int end) => ((end - 1) / chunkSize).floor() + 1;

  Future<void> sendRequest(int begin, int end) async {
    final dynamic rangeReader = pdfStream?.getRangeReader(begin, end);
    if (rangeReader == null) return;

    final chunks = <Uint8List>[];
    while (true) {
      final dynamic result = await rangeReader.read();
      if (aborted) return;
      if (result.done == true) break;
      if (result.value is Uint8List) {
        chunks.add(result.value as Uint8List);
      } else if (result.value is ByteBuffer) {
        chunks.add(Uint8List.view(result.value as ByteBuffer));
      }
    }

    if (chunks.isEmpty && disableAutoFetch) return;

    final totalLen = chunks.fold<int>(0, (sum, c) => sum + c.lengthInBytes);
    final data = Uint8List(totalLen);
    var offset = 0;
    for (final c in chunks) {
      data.setRange(offset, offset + c.lengthInBytes, c);
      offset += c.lengthInBytes;
    }

    onReceiveData(chunk: data, begin: begin);
  }

  void onReceiveData({required Uint8List chunk, int? begin}) {
    final isProgressive = begin == null;
    final b = isProgressive ? stream.progressiveDataLength : begin;
    final end = b + chunk.lengthInBytes;

    final beginChunk = (b / chunkSize).floor();
    final endChunk =
        end < length ? (end / chunkSize).floor() : (end / chunkSize).ceil();

    if (isProgressive) {
      stream.onReceiveProgressiveData(chunk);
    } else {
      stream.onReceiveData(b, chunk);
    }

    if (stream.isDataLoaded && !_loadedStreamCompleter.isCompleted) {
      _loadedStreamCompleter.complete(stream);
    }

    final loadedRequests = <int>[];
    for (var curChunk = beginChunk; curChunk < endChunk; ++curChunk) {
      final requestIds = _requestsByChunk.remove(curChunk);
      if (requestIds == null) continue;

      for (final requestId in requestIds) {
        final needed = _chunksNeededByRequest[requestId];
        if (needed != null) {
          needed.remove(curChunk);
          if (needed.isEmpty) {
            loadedRequests.add(requestId);
          }
        }
      }
    }

    for (final reqId in loadedRequests) {
      final comp = _promisesByRequest.remove(reqId);
      if (comp != null && !comp.isCompleted) {
        comp.complete();
      }
    }

    if (msgHandler != null) {
      try {
        msgHandler.send('DocProgress', <String, dynamic>{
          'loaded': mathClamp(
            stream.numChunksLoaded * chunkSize,
            stream.progressiveDataLength,
            length,
          ),
          'total': length,
        });
      } catch (_) {}
    }
  }

  void abort(dynamic reason) {
    aborted = true;
    try {
      pdfStream?.cancelAllRequests(reason);
    } catch (_) {}
    for (final comp in _promisesByRequest.values) {
      if (!comp.isCompleted) {
        comp.completeError(reason ?? Exception('Stream aborted'));
      }
    }
  }
}
