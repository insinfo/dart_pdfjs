// Copyright 2017 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:pdfjs/src/core/stream.dart';
import '../test_utils.dart';

void main() {
  group('primitives', () {
    group('Name', () {
      test('should retain the given name', () {
        const givenName = 'Font';
        final name = Name.get(givenName);
        expect(name.name, equals(givenName));
      });

      test('should create only one object for a name and cache it', () {
        final firstFont = Name.get('Font');
        final secondFont = Name.get('Font');
        final firstSubtype = Name.get('Subtype');
        final secondSubtype = Name.get('Subtype');

        expect(identical(firstFont, secondFont), isTrue);
        expect(identical(firstSubtype, secondSubtype), isTrue);
        expect(identical(firstFont, firstSubtype), isFalse);
      });

      test('should create only one object for *empty* names and cache it', () {
        final firstEmpty = Name.get('');
        final secondEmpty = Name.get('');
        final normalName = Name.get('string');

        expect(identical(firstEmpty, secondEmpty), isTrue);
        expect(identical(firstEmpty, normalName), isFalse);
      });

      test('should not accept to create a non-string name', () {
        expect(() => Name.get(123), throwsA(isA<ArgumentError>()));
      });
    });

    group('Cmd', () {
      test('should retain the given cmd name', () {
        const givenCmd = 'BT';
        final cmd = Cmd.get(givenCmd);
        expect(cmd.cmd, equals(givenCmd));
      });

      test('should create only one object for a command and cache it', () {
        final firstBT = Cmd.get('BT');
        final secondBT = Cmd.get('BT');
        final firstET = Cmd.get('ET');
        final secondET = Cmd.get('ET');

        expect(identical(firstBT, secondBT), isTrue);
        expect(identical(firstET, secondET), isTrue);
        expect(identical(firstBT, firstET), isFalse);
      });

      test('should not accept to create a non-string cmd', () {
        expect(() => Cmd.get(123), throwsA(isA<ArgumentError>()));
      });
    });

    group('Dict', () {
      void checkInvalidHasValues(Dict dict) {
        expect(dict.has(), isFalse);
        expect(dict.has('Prev'), isFalse);
      }

      void checkInvalidKeyValues(Dict dict) {
        expect(dict.get(), isNull);
        expect(dict.get('Prev'), isNull);
        expect(dict.get('D', 'Decode'), isNull);
        expect(dict.get('FontFile', 'FontFile2', 'FontFile3'), isNull);
      }

      late Dict emptyDict;
      late Dict dictWithSizeKey;
      late Dict dictWithManyKeys;
      const storedSize = 42;
      const testFontFile = 'file1';
      const testFontFile2 = 'file2';
      const testFontFile3 = 'file3';

      setUp(() {
        emptyDict = Dict();

        dictWithSizeKey = Dict();
        dictWithSizeKey.set('Size', storedSize);

        dictWithManyKeys = Dict();
        dictWithManyKeys.set('FontFile', testFontFile);
        dictWithManyKeys.set('FontFile2', testFontFile2);
        dictWithManyKeys.set('FontFile3', testFontFile3);
      });

      test('should allow assigning an XRef table after creation', () {
        final dict = Dict(null);
        expect(dict.xref, isNull);

        final xref = XRefMock([]);
        dict.assignXref(xref);
        expect(dict.xref, equals(xref));
      });

      test('should return correct size', () {
        final dict = Dict(null);
        expect(dict.size, equals(0));

        dict.set('Type', Name.get('Page'));
        expect(dict.size, equals(1));

        dict.set('Contents', Ref.get(10, 0));
        expect(dict.size, equals(2));
      });

      test('should return invalid values for unknown keys', () {
        checkInvalidHasValues(emptyDict);
        checkInvalidKeyValues(emptyDict);
      });

      test('should return correct value for stored Size key', () {
        expect(dictWithSizeKey.has('Size'), isTrue);

        expect(dictWithSizeKey.get('Size'), equals(storedSize));
        expect(dictWithSizeKey.get('Prev', 'Size'), equals(storedSize));
        expect(
            dictWithSizeKey.get('Prev', 'Root', 'Size'), equals(storedSize));
      });

      test('should return invalid values for unknown keys when Size key is stored',
          () {
        checkInvalidHasValues(dictWithSizeKey);
        checkInvalidKeyValues(dictWithSizeKey);
      });

      test('should not accept to set a non-string key', () {
        final dict = Dict();
        expect(() => dict.set(123, 'val'), throwsA(isA<ArgumentError>()));
        expect(dict.has(123), isFalse);
        checkInvalidKeyValues(dict);
      });

      test('should not accept to set a key with an undefined value', () {
        final dict = Dict();
        expect(() => dict.set('Size'), throwsA(isA<ArgumentError>()));
        expect(dict.has('Size'), isFalse);
        checkInvalidKeyValues(dict);
      });

      test('should return correct values for multiple stored keys', () {
        expect(dictWithManyKeys.has('FontFile'), isTrue);
        expect(dictWithManyKeys.has('FontFile2'), isTrue);
        expect(dictWithManyKeys.has('FontFile3'), isTrue);

        expect(dictWithManyKeys.get('FontFile3'), equals(testFontFile3));
        expect(dictWithManyKeys.get('FontFile2', 'FontFile3'),
            equals(testFontFile2));
        expect(dictWithManyKeys.get('FontFile', 'FontFile2', 'FontFile3'),
            equals(testFontFile));
      });

      test('should asynchronously fetch unknown keys', () async {
        final keyPromises = [
          dictWithManyKeys.getAsync('Size'),
          dictWithSizeKey.getAsync('FontFile', 'FontFile2', 'FontFile3'),
        ];

        final values = await Future.wait(keyPromises);
        expect(values[0], isNull);
        expect(values[1], isNull);
      });

      test('should asynchronously fetch correct values for multiple stored keys',
          () async {
        final keyPromises = [
          dictWithManyKeys.getAsync('FontFile3'),
          dictWithManyKeys.getAsync('FontFile2', 'FontFile3'),
          dictWithManyKeys.getAsync('FontFile', 'FontFile2', 'FontFile3'),
        ];

        final values = await Future.wait(keyPromises);
        expect(values[0], equals(testFontFile3));
        expect(values[1], equals(testFontFile2));
        expect(values[2], equals(testFontFile));
      });

      test('should iterate through each stored key', () {
        expect(dictWithManyKeys.toList(), equals([
          ['FontFile', testFontFile],
          ['FontFile2', testFontFile2],
          ['FontFile3', testFontFile3],
        ]));
      });

      test('should handle keys pointing to indirect objects, both sync and async',
          () async {
        final fontRef = Ref.get(1, 0);
        final xref = XRefMock([
          {'ref': fontRef, 'data': testFontFile}
        ]);
        final fontDict = Dict(xref);
        fontDict.set('FontFile', fontRef);

        expect(fontDict.getRaw('FontFile'), equals(fontRef));
        expect(fontDict.get('FontFile', 'FontFile2', 'FontFile3'),
            equals(testFontFile));

        final value = await fontDict.getAsync(
            'FontFile', 'FontFile2', 'FontFile3');
        expect(value, equals(testFontFile));
      });

      test('should handle arrays containing indirect objects', () {
        final minCoordRef = Ref.get(1, 0);
        final maxCoordRef = Ref.get(2, 0);
        const minCoord = 0;
        const maxCoord = 1;
        final xref = XRefMock([
          {'ref': minCoordRef, 'data': minCoord},
          {'ref': maxCoordRef, 'data': maxCoord},
        ]);
        final xObjectDict = Dict(xref);
        xObjectDict.set('BBox', [minCoord, maxCoord, minCoordRef, maxCoordRef]);

        expect(xObjectDict.get('BBox'), equals([
          minCoord,
          maxCoord,
          minCoordRef,
          maxCoordRef,
        ]));
        expect(xObjectDict.getArray('BBox'), equals([
          minCoord,
          maxCoord,
          minCoord,
          maxCoord,
        ]));
      });

      test('should get all key names', () {
        final expectedKeys = ['FontFile', 'FontFile2', 'FontFile3'];
        final keys = dictWithManyKeys.getKeys().toList()..sort();
        expect(keys, equals(expectedKeys));
      });

      test('should get all raw values', () {
        final expectedRawValues1 = [testFontFile, testFontFile2, testFontFile3];
        final rawValues1 = dictWithManyKeys.getRawValues().toList()..sort();
        expect(rawValues1, equals(expectedRawValues1));

        final typeName = Name.get('Page');
        final resources = Dict(null);
        final resourcesRef = Ref.get(5, 0);
        final contents = StringStream('data');
        final contentsRef = Ref.get(10, 0);
        final xref = XRefMock([
          {'ref': resourcesRef, 'data': resources},
          {'ref': contentsRef, 'data': contents},
        ]);

        final dict = Dict(xref);
        dict.set('Type', typeName);
        dict.set('Resources', resourcesRef);
        dict.set('Contents', contentsRef);

        final rawValues2 = dict.getRawValues().toList();
        expect(rawValues2.contains(typeName), isTrue);
        expect(rawValues2.contains(resourcesRef), isTrue);
        expect(rawValues2.contains(contentsRef), isTrue);
      });

      test('should get all raw entries', () {
        final rawEntries = dictWithManyKeys
            .getRawEntries()
            .map((e) => [e.key, e.value])
            .toList()
          ..sort((a, b) => (a[0] as String).compareTo(b[0] as String));
        expect(rawEntries, equals([
          ['FontFile', testFontFile],
          ['FontFile2', testFontFile2],
          ['FontFile3', testFontFile3],
        ]));
      });

      test('should create only one object for Dict.empty', () {
        final firstDictEmpty = Dict.empty;
        final secondDictEmpty = Dict.empty;

        expect(identical(firstDictEmpty, secondDictEmpty), isTrue);
        expect(identical(firstDictEmpty, emptyDict), isFalse);
      });

      test('should correctly merge dictionaries', () {
        final expectedKeys = ['FontFile', 'FontFile2', 'FontFile3', 'Size'];

        final fontFileDict = Dict();
        fontFileDict.set('FontFile', 'Type1 font file');
        final mergedDict = Dict.merge(
          xref: null,
          dictArray: [dictWithManyKeys, dictWithSizeKey, fontFileDict],
        );
        final mergedKeys = mergedDict.getKeys().toList()..sort();

        expect(mergedKeys, equals(expectedKeys));
        expect(mergedDict.get('FontFile'), equals(testFontFile));
      });

      test('should correctly merge sub-dictionaries', () {
        final localFontDict = Dict();
        localFontDict.set('F1', 'Local font one');

        final globalFontDict = Dict();
        globalFontDict.set('F1', 'Global font one');
        globalFontDict.set('F2', 'Global font two');
        globalFontDict.set('F3', 'Global font three');

        final localDict = Dict();
        localDict.set('Font', localFontDict);

        final globalDict = Dict();
        globalDict.set('Font', globalFontDict);

        final mergedDict = Dict.merge(
          xref: null,
          dictArray: [localDict, globalDict],
        );
        final mergedSubDict = Dict.merge(
          xref: null,
          dictArray: [localDict, globalDict],
          mergeSubDicts: true,
        );

        final mergedFontDict = mergedDict.get('Font');
        final mergedSubFontDict = mergedSubDict.get('Font');

        expect(mergedFontDict, isA<Dict>());
        expect(mergedSubFontDict, isA<Dict>());

        expect((mergedFontDict as Dict).getKeys().toList(), equals(['F1']));
        expect((mergedSubFontDict as Dict).getKeys().toList(),
            equals(['F1', 'F2', 'F3']));

        expect(mergedFontDict.getRawValues().toList(),
            equals(['Local font one']));
        expect(mergedSubFontDict.getRawValues().toList(),
            equals(['Local font one', 'Global font two', 'Global font three']));
      });

      test('should set the values if they are as expected', () {
        final dict = Dict();
        dict.set('key', 'value');

        dict.setIfNotExists('key', 'new value');
        expect(dict.get('key'), equals('value'));

        dict.setIfNotExists('key1', 'value');
        expect(dict.get('key1'), equals('value'));

        dict.setIfNumber('a', 123);
        expect(dict.get('a'), equals(123));

        dict.setIfNumber('b', 'not a number');
        expect(dict.has('b'), isFalse);

        dict.setIfArray('c', [1, 2, 3]);
        expect(dict.get('c'), equals([1, 2, 3]));

        dict.setIfArray('d', Uint8List.fromList([4, 5, 6]));
        expect(dict.get('d'), equals(Uint8List.fromList([4, 5, 6])));

        dict.setIfArray('e', 'not an array');
        expect(dict.has('e'), isFalse);

        dict.setIfDefined('f', 'defined');
        expect(dict.get('f'), equals('defined'));

        dict.setIfDefined('g', null);
        expect(dict.has('g'), isFalse);

        dict.setIfName('i', Name.get('name'));
        expect(dict.get('i'), equals(Name.get('name')));

        dict.setIfName('j', 'name');
        expect(dict.get('j'), equals(Name.get('name')));

        dict.setIfName('k', 1234);
        expect(dict.has('k'), isFalse);

        dict.setIfDict('l', Dict());
        expect(dict.get('l'), isA<Dict>());

        dict.setIfDict('m', 'not a dict');
        expect(dict.has('m'), isFalse);
      });
    });

    group('Ref', () {
      test('should get a string representation', () {
        final nonZeroRef = Ref.get(4, 2);
        expect(nonZeroRef.toString(), equals('4R2'));

        final zeroRef = Ref.get(4, 0);
        expect(zeroRef.toString(), equals('4R'));
      });

      test('should retain the stored values', () {
        const storedNum = 4;
        const storedGen = 2;
        final ref = Ref.get(storedNum, storedGen);
        expect(ref.num, equals(storedNum));
        expect(ref.gen, equals(storedGen));
      });

      test('should create only one object for a reference and cache it', () {
        final firstRef = Ref.get(4, 2);
        final secondRef = Ref.get(4, 2);
        final firstOtherRef = Ref.get(5, 2);
        final secondOtherRef = Ref.get(5, 2);

        expect(identical(firstRef, secondRef), isTrue);
        expect(identical(firstOtherRef, secondOtherRef), isTrue);
        expect(identical(firstRef, firstOtherRef), isFalse);
      });
    });

    group('RefSet', () {
      final ref1 = Ref.get(4, 2);
      final ref2 = Ref.get(5, 2);
      late RefSet refSet;

      setUp(() {
        refSet = RefSet();
      });

      test('should have a stored value', () {
        refSet.put(ref1);
        expect(refSet.has(ref1), isTrue);
      });

      test('should not have an unknown value', () {
        expect(refSet.has(ref1), isFalse);
        refSet.put(ref1);
        expect(refSet.has(ref2), isFalse);
      });

      test('should support iteration', () {
        refSet.put(ref1);
        refSet.put(ref2);
        expect(refSet.toList(), equals([ref1.toString(), ref2.toString()]));
      });
    });

    group('RefSetCache', () {
      final ref1 = Ref.get(4, 2);
      final ref2 = Ref.get(5, 2);
      final obj1 = Name.get('foo');
      final obj2 = Name.get('bar');
      late RefSetCache cache;

      setUp(() {
        cache = RefSetCache();
      });

      test('should put, have and get a value', () {
        cache.put(ref1, obj1);
        expect(cache.has(ref1), isTrue);
        expect(cache.has(ref2), isFalse);
        expect(identical(cache.get(ref1), obj1), isTrue);
      });

      test('should put, have and get a value by alias', () {
        cache.put(ref1, obj1);
        cache.putAlias(ref2, ref1);
        expect(cache.has(ref1), isTrue);
        expect(cache.has(ref2), isTrue);
        expect(identical(cache.get(ref1), obj1), isTrue);
        expect(identical(cache.get(ref2), obj1), isTrue);
      });

      test('should report the size of the cache', () {
        cache.put(ref1, obj1);
        expect(cache.size, equals(1));
        cache.put(ref2, obj2);
        expect(cache.size, equals(2));
      });

      test('should clear the cache', () {
        cache.put(ref1, obj1);
        expect(cache.size, equals(1));
        cache.clear();
        expect(cache.size, equals(0));
      });

      test('should support iteration', () {
        cache.put(ref1, obj1);
        cache.put(ref2, obj2);
        expect(cache.toList(), equals([obj1, obj2]));
      });

      test('should support iteration over key-value pairs', () {
        cache.put(ref1, obj1);
        cache.put(ref2, obj2);
        expect(cache.items().toList(), equals([
          [ref1, obj1],
          [ref2, obj2],
        ]));
      });

      test('should support iteration over keys', () {
        cache.put(ref1, obj1);
        cache.put(ref2, obj2);
        expect(cache.keys().toList(), equals([ref1, ref2]));
      });
    });

    group('isName', () {
      test('handles non-names', () {
        expect(isName({}), isFalse);
      });

      test('handles names', () {
        final name = Name.get('Font');
        expect(isName(name), isTrue);
      });

      test('handles names with name check', () {
        final name = Name.get('Font');
        expect(isName(name, 'Font'), isTrue);
        expect(isName(name, 'Subtype'), isFalse);
      });

      test('handles *empty* names, with name check', () {
        final emptyName = Name.get('');
        expect(isName(emptyName), isTrue);
        expect(isName(emptyName, ''), isTrue);
        expect(isName(emptyName, 'string'), isFalse);
      });
    });

    group('isCmd', () {
      test('handles non-commands', () {
        expect(isCmd({}), isFalse);
      });

      test('handles commands', () {
        final cmd = Cmd.get('BT');
        expect(isCmd(cmd), isTrue);
      });

      test('handles commands with cmd check', () {
        final cmd = Cmd.get('BT');
        expect(isCmd(cmd, 'BT'), isTrue);
        expect(isCmd(cmd, 'ET'), isFalse);
      });
    });

    group('isDict', () {
      test('handles non-dictionaries', () {
        expect(isDict({}), isFalse);
      });

      test('handles empty dictionaries with type check', () {
        final dict = Dict.empty;
        expect(isDict(dict), isTrue);
        expect(isDict(dict, 'Page'), isFalse);
      });

      test('handles dictionaries with type check', () {
        final dict = Dict();
        dict.set('Type', Name.get('Page'));
        expect(isDict(dict, 'Page'), isTrue);
        expect(isDict(dict, 'Contents'), isFalse);
      });
    });

    group('isRefsEqual', () {
      test('should handle Refs pointing to the same object', () {
        final ref1 = Ref.get(1, 0);
        final ref2 = Ref.get(1, 0);
        expect(isRefsEqual(ref1, ref2), isTrue);
      });

      test('should handle Refs pointing to different objects', () {
        final ref1 = Ref.get(1, 0);
        final ref2 = Ref.get(2, 0);
        expect(isRefsEqual(ref1, ref2), isFalse);
      });
    });
  });
}
