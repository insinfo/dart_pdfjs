// Copyright 2020 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';

import '../shared/util.dart';
import 'base_stream.dart';
import 'calculate_md5.dart';
import 'core_utils.dart';
import 'crypto.dart';
import 'primitives.dart';
import 'stream.dart';
import 'xml_parser.dart';
import 'xref.dart';

class XRefInfo {
  final Ref newRef;
  final int? startXRef;
  final List<dynamic>? fileIds;
  final Ref? rootRef;
  final Ref? infoRef;
  final Ref? encryptRef;
  final String? filename;
  final Map<dynamic, dynamic>? infoMap;
  final int? time;

  XRefInfo({
    required this.newRef,
    this.startXRef,
    this.fileIds,
    this.rootRef,
    this.infoRef,
    this.encryptRef,
    this.filename,
    this.infoMap,
    this.time,
  });

  factory XRefInfo.from(dynamic info) {
    if (info is XRefInfo) {
      return info;
    }
    if (info is Map) {
      return XRefInfo(
        newRef: info['newRef'] as Ref,
        startXRef: info['startXRef'] as int?,
        fileIds: info['fileIds'] as List<dynamic>?,
        rootRef: info['rootRef'] as Ref?,
        infoRef: info['infoRef'] as Ref?,
        encryptRef: info['encryptRef'] as Ref?,
        filename: info['filename'] as String?,
        infoMap: (info['infoMap'] is Map)
            ? info['infoMap'] as Map<dynamic, dynamic>
            : null,
        time: info['time'] as int?,
      );
    }
    throw ArgumentError('Invalid xrefInfo: $info');
  }
}

class _NewRefEntry {
  final Ref ref;
  final dynamic data;
  final Ref? objStreamRef;
  final int? index;

  _NewRefEntry({
    required this.ref,
    this.data,
    this.objStreamRef,
    this.index,
  });
}

/// Optional hook for flate compressing stream data in web or native runtimes.
typedef StreamCompressor = Future<Uint8List?> Function(Uint8List bytes);
StreamCompressor? customStreamCompressor;

String _formatNumber(num value) {
  if (value == 0) {
    return '0';
  }
  var str = value.toStringAsFixed(10);
  str = str.replaceFirst(RegExp(r'\.?0+$'), '');
  if (str == '-0' || str.isEmpty) {
    return '0';
  }
  return str;
}

Future<void> writeObject(
  Ref ref,
  dynamic obj,
  List<String> buffer, [
  dynamic encryptOptions,
]) async {
  dynamic encrypt;
  Ref? encryptRef;
  if (encryptOptions is Map) {
    encrypt = encryptOptions['encrypt'];
    encryptRef = encryptOptions['encryptRef'] as Ref?;
  } else if (encryptOptions is XRef) {
    encrypt = encryptOptions.encrypt;
    encryptRef = encryptOptions.encryptRef;
  }

  // Avoid encrypting the encrypt dictionary itself.
  final CipherTransform? transform = (encrypt != null && encryptRef != ref)
      ? (encrypt.createCipherTransform(ref.num, ref.gen) as CipherTransform?)
      : null;

  buffer.add('${ref.num} ${ref.gen} obj\n');
  await writeValue(obj, buffer, transform);
  buffer.add('\nendobj\n');
}

Future<void> writeDict(
  Dict dict,
  List<String> buffer, [
  CipherTransform? transform,
]) async {
  buffer.add('<<');
  for (final entry in dict.getRawEntries()) {
    buffer.add(' /${escapePDFName(entry.key)} ');
    await writeValue(entry.value, buffer, transform);
  }
  buffer.add('>>');
}

Future<void> writeStream(
  BaseStream stream,
  List<String> buffer, [
  CipherTransform? transform,
]) async {
  var origStream = stream.getOriginalStream();
  origStream.reset();
  var bytes = origStream.getBytes();
  final dict = origStream.dict ?? Dict(null);

  final dynamic filter = await dict.getAsync('Filter');
  final dynamic params = await dict.getAsync('DecodeParms');

  dynamic filterZero = filter;
  if (filter is List && filter.isNotEmpty) {
    filterZero = dict.xref != null
        ? await dict.xref.fetchIfRefAsync(filter[0])
        : filter[0];
  }
  final isFilterZeroFlateDecode = isName(filterZero, 'FlateDecode');

  // If the string is too small there is no real benefit in compressing it.
  const minLengthForCompressing = 256;

  if (bytes.length >= minLengthForCompressing && !isFilterZeroFlateDecode) {
    if (customStreamCompressor != null) {
      try {
        final compressed = await customStreamCompressor!(bytes);
        if (compressed != null) {
          bytes = compressed;
          dynamic newFilter;
          dynamic newParams;
          if (filter == null) {
            newFilter = Name.get('FlateDecode');
          } else if (!isFilterZeroFlateDecode) {
            newFilter = filter is List
                ? [Name.get('FlateDecode'), ...filter]
                : [Name.get('FlateDecode'), filter];
            if (params != null) {
              newParams = params is List
                  ? [null, ...params]
                  : [null, params];
            }
          }
          if (newFilter != null) {
            dict.set('Filter', newFilter);
          }
          if (newParams != null) {
            dict.set('DecodeParms', newParams);
          }
        }
      } catch (ex) {
        info('writeStream - cannot compress data: "$ex".');
      }
    }
  }

  var string = bytesToString(bytes);
  if (transform != null) {
    string = transform.encryptString(string);
  }

  dict.set('Length', string.length);
  await writeDict(dict, buffer, transform);
  buffer.add(' stream\n');
  buffer.add(string);
  buffer.add('\nendstream');
}

Future<void> writeArray(
  List<dynamic> array,
  List<String> buffer, [
  CipherTransform? transform,
]) async {
  buffer.add('[');
  for (var i = 0, ii = array.length; i < ii; i++) {
    await writeValue(array[i], buffer, transform);
    if (i < ii - 1) {
      buffer.add(' ');
    }
  }
  buffer.add(']');
}

Future<void> writeValue(
  dynamic value,
  List<String> buffer, [
  CipherTransform? transform,
]) async {
  if (value is Name) {
    buffer.add('/${escapePDFName(value.name)}');
  } else if (value is Ref) {
    buffer.add('${value.num} ${value.gen} R');
  } else if (value is List) {
    await writeArray(value, buffer, transform);
  } else if (value is String) {
    var str = value;
    if (transform != null) {
      str = transform.encryptString(str);
    }
    buffer.add('(${escapeString(str)})');
  } else if (value is num) {
    buffer.add(_formatNumber(value));
  } else if (value is bool) {
    buffer.add(value.toString());
  } else if (value is Dict) {
    await writeDict(value, buffer, transform);
  } else if (value is BaseStream) {
    await writeStream(value, buffer, transform);
  } else if (value == null) {
    buffer.add('null');
  } else {
    warn('Unhandled value in writer: ${value.runtimeType}, please file a bug.');
  }
}

int writeInt(int number, int size, int offset, Uint8List buffer) {
  for (var i = size + offset - 1; i > offset - 1; i--) {
    buffer[i] = number & 0xff;
    number >>= 8;
  }
  return offset + size;
}

int writeString(String string, int offset, Uint8List buffer) {
  final ii = string.length;
  for (var i = 0; i < ii; i++) {
    buffer[offset + i] = string.codeUnitAt(i) & 0xff;
  }
  return offset + ii;
}

String computeMD5(int filesize, XRefInfo xrefInfo) {
  final time = xrefInfo.time ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
  final filename = xrefInfo.filename ?? '';
  final md5Buffer = <String>[
    time.toString(),
    filename,
    filesize.toString(),
  ];
  if (xrefInfo.infoMap != null) {
    for (final val in xrefInfo.infoMap!.values) {
      md5Buffer.add(val.toString());
    }
  }

  var md5BufferLen = 0;
  for (final str in md5Buffer) {
    md5BufferLen += str.length;
  }

  final array = Uint8List(md5BufferLen);
  var offset = 0;
  for (final str in md5Buffer) {
    offset = writeString(str, offset, array);
  }
  return bytesToString(calculateMD5(array, 0, array.length));
}

String writeXFADataForAcroform(String str, RefSetCache changes) {
  final xml = SimpleXMLParser(hasAttributes: true).parseFromString(str);
  if (xml == null) {
    return str;
  }

  for (final change in changes.values) {
    if (change is! Map) {
      continue;
    }
    final dynamic xfa = change['xfa'];
    if (xfa == null || xfa is! Map) {
      continue;
    }
    final dynamic path = xfa['path'];
    final dynamic value = xfa['value'];
    if (path == null || path is! String) {
      continue;
    }
    final nodePath = parseXFAPath(path);
    var node = xml.documentElement.searchNode(nodePath, 0);
    if (node == null && nodePath.length > 1) {
      node = xml.documentElement.searchNode([nodePath.last], 0);
    }
    if (node != null) {
      node.childNodes = value is List
          ? value.map((val) => SimpleDOMNode('value', val.toString())).toList()
          : [SimpleDOMNode('#text', value?.toString() ?? '')];
    } else {
      warn('Node not found for path: $path');
    }
  }
  final buffer = <String>[];
  xml.documentElement.dump(buffer);
  return buffer.join('');
}

void updateAcroform({
  dynamic xref,
  Dict? acroForm,
  Ref? acroFormRef,
  bool hasXfa = false,
  bool hasXfaDatasetsEntry = false,
  Ref? xfaDatasetsRef,
  bool needAppearances = false,
  required RefSetCache changes,
}) {
  if (hasXfa && !hasXfaDatasetsEntry && xfaDatasetsRef == null) {
    warn('XFA - Cannot save it');
  }

  if (!needAppearances && (!hasXfa || xfaDatasetsRef == null || hasXfaDatasetsEntry)) {
    return;
  }

  if (acroForm == null || acroFormRef == null) {
    return;
  }

  final dict = acroForm.clone();

  if (hasXfa && !hasXfaDatasetsEntry) {
    final rawXfa = acroForm.get('XFA');
    final List<dynamic> newXfa = rawXfa is List ? List<dynamic>.from(rawXfa) : <dynamic>[];
    newXfa.insert(2, 'datasets');
    newXfa.insert(3, xfaDatasetsRef);
    dict.set('XFA', newXfa);
  }

  if (needAppearances) {
    dict.set('NeedAppearances', true);
  }

  changes.put(acroFormRef, {
    'data': dict,
  });
}

void updateXFA({
  String? xfaData,
  Ref? xfaDatasetsRef,
  required RefSetCache changes,
  dynamic xref,
}) {
  if (xfaDatasetsRef == null) {
    return;
  }
  if (xfaData == null) {
    final dynamic datasets = xref != null ? (xref as dynamic).fetchIfRef(xfaDatasetsRef) : null;
    final String str = datasets is BaseStream
        ? datasets.getString()
        : (datasets != null ? datasets.toString() : '');
    xfaData = writeXFADataForAcroform(str, changes);
  }
  final xfaDataStream = StringStream(xfaData);
  xfaDataStream.dict = Dict(xref is XRef ? xref : null);
  xfaDataStream.dict!.setIfName('Type', 'EmbeddedFile');

  changes.put(xfaDatasetsRef, {
    'data': xfaDataStream,
  });
}

List<int> getIndexes(List<_NewRefEntry> newRefs) {
  final indexes = <int>[];
  for (final entry in newRefs) {
    final ref = entry.ref;
    if (indexes.length >= 2 &&
        ref.num == indexes[indexes.length - 2] + indexes[indexes.length - 1]) {
      indexes[indexes.length - 1] += 1;
    } else {
      indexes.add(ref.num);
      indexes.add(1);
    }
  }
  return indexes;
}

void computeIDs(int baseOffset, XRefInfo xrefInfo, Dict newXref) {
  if (xrefInfo.fileIds != null && xrefInfo.fileIds!.isNotEmpty) {
    final md5 = computeMD5(baseOffset, xrefInfo);
    newXref.set('ID', [xrefInfo.fileIds![0] ?? md5, md5]);
  }
}

Dict getTrailerDict(
  XRefInfo xrefInfo,
  RefSetCache changes,
  bool useXrefStream,
) {
  final newXref = Dict(null);
  newXref.setIfDefined('Prev', xrefInfo.startXRef);
  final refForXrefTable = xrefInfo.newRef;
  if (useXrefStream) {
    changes.put(refForXrefTable, {'data': ''});
    newXref.set('Size', refForXrefTable.num + 1);
    newXref.setIfName('Type', 'XRef');
  } else {
    newXref.set('Size', refForXrefTable.num);
  }
  newXref.setIfDefined('Root', xrefInfo.rootRef);
  newXref.setIfDefined('Info', xrefInfo.infoRef);
  newXref.setIfDefined('Encrypt', xrefInfo.encryptRef);

  return newXref;
}

Future<List<_NewRefEntry>> writeChanges(
  RefSetCache changes,
  dynamic xref, [
  List<String>? buffer,
]) async {
  buffer ??= <String>[];
  final newRefs = <_NewRefEntry>[];

  for (final item in changes.items()) {
    final ref = item[0] as Ref;
    final changeVal = item[1];
    dynamic data;
    Ref? objStreamRef;
    int? index;

    if (changeVal is Map) {
      data = changeVal['data'];
      objStreamRef = changeVal['objStreamRef'] as Ref?;
      index = changeVal['index'] as int?;
    } else {
      data = changeVal;
    }

    if (objStreamRef != null) {
      newRefs.add(_NewRefEntry(
        ref: ref,
        data: data,
        objStreamRef: objStreamRef,
        index: index,
      ));
      continue;
    }

    if (data == null || data is String) {
      newRefs.add(_NewRefEntry(ref: ref, data: data));
      continue;
    }

    await writeObject(ref, data, buffer, xref);
    newRefs.add(_NewRefEntry(ref: ref, data: buffer.join('')));
    buffer.clear();
  }

  newRefs.sort((a, b) => a.ref.num.compareTo(b.ref.num));
  return newRefs;
}

Future<void> getXRefTable(
  XRefInfo xrefInfo,
  int baseOffset,
  List<_NewRefEntry> newRefs,
  Dict newXref,
  List<String> buffer,
) async {
  buffer.add('xref\n');
  final indexes = getIndexes(newRefs);
  var indexesPosition = 0;

  for (final entry in newRefs) {
    final ref = entry.ref;
    final data = entry.data;

    if (indexesPosition < indexes.length && ref.num == indexes[indexesPosition]) {
      buffer.add('${indexes[indexesPosition]} ${indexes[indexesPosition + 1]}\n');
      indexesPosition += 2;
    }

    // The EOL is \r\n to make sure that every entry is exactly 20 bytes long.
    if (data != null) {
      final offsetStr = baseOffset.toString().padLeft(10, '0');
      final genStr = (ref.gen & 0xffff).toString().padLeft(5, '0');
      buffer.add('$offsetStr $genStr n\r\n');
      baseOffset += (data as String).length;
    } else {
      final genStr = ((ref.gen + 1) & 0xffff).toString().padLeft(5, '0');
      buffer.add('0000000000 $genStr f\r\n');
    }
  }

  computeIDs(baseOffset, xrefInfo, newXref);
  buffer.add('trailer\n');
  await writeDict(newXref, buffer, null);
  buffer.add('\nstartxref\n${baseOffset}\n%%EOF\n');
}

Future<void> getXRefStreamTable(
  XRefInfo xrefInfo,
  int baseOffset,
  List<_NewRefEntry> newRefs,
  Dict newXref,
  List<String> buffer,
) async {
  final xrefTableData = <List<int>>[];
  var maxOffset = 0;
  var maxGen = 0;

  for (final entry in newRefs) {
    final ref = entry.ref;
    final data = entry.data;
    final objStreamRef = entry.objStreamRef;
    final index = entry.index;

    int gen;
    if (baseOffset > maxOffset) {
      maxOffset = baseOffset;
    }

    if (objStreamRef != null) {
      gen = index ?? 0;
      xrefTableData.add([2, objStreamRef.num, gen]);
    } else if (data != null) {
      gen = ref.gen.clamp(0, 0xffff);
      xrefTableData.add([1, baseOffset, gen]);
      baseOffset += (data as String).length;
    } else {
      gen = (ref.gen + 1).clamp(0, 0xffff);
      xrefTableData.add([0, 0, gen]);
    }
    if (gen > maxGen) {
      maxGen = gen;
    }
  }

  newXref.set('Index', getIndexes(newRefs));
  final offsetSize = getSizeInBytes(maxOffset);
  final maxGenSize = getSizeInBytes(maxGen);
  final sizes = [1, offsetSize, maxGenSize];
  newXref.set('W', sizes);
  computeIDs(baseOffset, xrefInfo, newXref);

  final structSize = sizes[0] + sizes[1] + sizes[2];
  final data = Uint8List(structSize * xrefTableData.length);
  final stream = Stream(data);
  stream.dict = newXref;

  var offset = 0;
  for (final entry in xrefTableData) {
    final type = entry[0];
    final objOffset = entry[1];
    final gen = entry[2];
    offset = writeInt(type, sizes[0], offset, data);
    offset = writeInt(objOffset, sizes[1], offset, data);
    offset = writeInt(gen, sizes[2], offset, data);
  }

  await writeObject(xrefInfo.newRef, stream, buffer, <String, dynamic>{});
  buffer.add('startxref\n${baseOffset}\n%%EOF\n');
}

Future<Uint8List> incrementalUpdate({
  required Uint8List originalData,
  required dynamic xrefInfo,
  required RefSetCache changes,
  dynamic xref,
  bool hasXfa = false,
  Ref? xfaDatasetsRef,
  bool hasXfaDatasetsEntry = false,
  bool needAppearances = false,
  Ref? acroFormRef,
  Dict? acroForm,
  String? xfaData,
  bool useXrefStream = false,
}) async {
  final info = XRefInfo.from(xrefInfo);

  updateAcroform(
    xref: xref,
    acroForm: acroForm,
    acroFormRef: acroFormRef,
    hasXfa: hasXfa,
    hasXfaDatasetsEntry: hasXfaDatasetsEntry,
    xfaDatasetsRef: xfaDatasetsRef,
    needAppearances: needAppearances,
    changes: changes,
  );

  if (hasXfa) {
    updateXFA(
      xfaData: xfaData,
      xfaDatasetsRef: xfaDatasetsRef,
      changes: changes,
      xref: xref,
    );
  }

  final newXref = getTrailerDict(info, changes, useXrefStream);
  final buffer = <String>[];
  final newRefs = await writeChanges(changes, xref, buffer);

  var baseOffset = originalData.length;
  final int? lastByte = originalData.isNotEmpty ? originalData[originalData.length - 1] : null;
  if (lastByte != 0x0a && lastByte != 0x0d) {
    // Avoid concatenating %%EOF with an object definition.
    buffer.add('\n');
    baseOffset += 1;
  }

  for (final entry in newRefs) {
    if (entry.data != null) {
      buffer.add(entry.data as String);
    }
  }

  if (useXrefStream) {
    await getXRefStreamTable(info, baseOffset, newRefs, newXref, buffer);
  } else {
    await getXRefTable(info, baseOffset, newRefs, newXref, buffer);
  }

  var totalLength = originalData.length;
  for (final str in buffer) {
    totalLength += str.length;
  }
  final array = Uint8List(totalLength);

  // Original data
  array.setRange(0, originalData.length, originalData);
  var offset = originalData.length;

  // New data
  for (final str in buffer) {
    offset = writeString(str, offset, array);
  }

  return array;
}
