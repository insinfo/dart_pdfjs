// Copyright 2026 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:test/test.dart';
import 'package:pdfjs/src/core/name_number_tree.dart';
import 'package:pdfjs/src/core/primitives.dart';
import '../test_utils.dart';

void main() {
  group('NameOrNumberTree', () {
    group('NameTree', () {
      test('should return an empty map when root is null', () {
        final xref = XRefMock([]);
        final tree = NameTree(null, xref);
        expect(tree.getAll().length, equals(0));
      });

      test('should collect all entries from a flat tree', () {
        final root = Dict();
        root.set('Names', ['alpha', 'value_a', 'beta', 'value_b']);

        final xref = XRefMock([]);
        final tree = NameTree(root, xref);
        final map = tree.getAll();

        expect(map.length, equals(2));
        expect(map['alpha'], equals('value_a'));
        expect(map['beta'], equals('value_b'));
      });

      test('should collect all entries from a tree with Ref-based Kids', () {
        final leafRef = Ref.get(10, 0);
        final leaf = Dict();
        leaf.set('Names', ['key1', 'val1', 'key2', 'val2']);

        final root = Dict();
        root.set('Kids', [leafRef]);

        final xref = XRefMock([
          {'ref': leafRef, 'data': leaf}
        ]);
        final tree = NameTree(root, xref);
        final map = tree.getAll();

        expect(map.length, equals(2));
        expect(map['key1'], equals('val1'));
        expect(map['key2'], equals('val2'));
      });

      test(
          'should handle Kids containing inline (non-Ref) Dict nodes without throwing',
          () {
        final inlineLeaf = Dict();
        inlineLeaf.set('Names', ['key1', 'val1', 'key2', 'val2']);

        final root = Dict();
        root.set('Kids', [inlineLeaf]);

        final xref = XRefMock([]);
        final tree = NameTree(root, xref);

        final map = tree.getAll();
        expect(map.length, equals(2));
        expect(map['key1'], equals('val1'));
        expect(map['key2'], equals('val2'));
      });

      test('should throw on duplicate Ref entries in Kids', () {
        final leafRef = Ref.get(20, 0);
        final leaf = Dict();
        leaf.set('Names', ['a', 'b']);

        final root = Dict();
        root.set('Kids', [leafRef, leafRef]);

        final xref = XRefMock([
          {'ref': leafRef, 'data': leaf}
        ]);
        final tree = NameTree(root, xref);

        expect(
          () => tree.getAll(),
          throwsA(predicate((e) =>
              e.toString().contains('Duplicate entry in "Names" tree.'))),
        );
      });

      test('should resolve Ref values when isRaw is false', () {
        final valRef = Ref.get(30, 0);
        const valData = 'resolved_value';

        final root = Dict();
        root.set('Names', ['mykey', valRef]);

        final xref = XRefMock([
          {'ref': valRef, 'data': valData}
        ]);
        final tree = NameTree(root, xref);

        final map = tree.getAll();
        expect(map['mykey'], equals('resolved_value'));
      });

      test('should keep raw Ref values when isRaw is true', () {
        final valRef = Ref.get(31, 0);

        final root = Dict();
        root.set('Names', ['mykey', valRef]);

        final xref = XRefMock([
          {'ref': valRef, 'data': 'resolved_value'}
        ]);
        final tree = NameTree(root, xref);

        final map = tree.getAll(isRaw: true);
        expect(map['mykey'], equals(valRef));
      });
    });

    group('NumberTree', () {
      test('should collect all entries from a flat tree', () {
        final root = Dict();
        root.set('Nums', [1, 'one', 2, 'two']);

        final xref = XRefMock([]);
        final tree = NumberTree(root, xref);
        final map = tree.getAll();

        expect(map.length, equals(2));
        expect(map[1], equals('one'));
        expect(map[2], equals('two'));
      });

      test(
          'should handle Kids containing inline (non-Ref) Dict nodes without throwing',
          () {
        final inlineLeaf = Dict();
        inlineLeaf.set('Nums', [0, 'zero', 1, 'one']);

        final root = Dict();
        root.set('Kids', [inlineLeaf]);

        final xref = XRefMock([]);
        final tree = NumberTree(root, xref);

        final map = tree.getAll();
        expect(map.length, equals(2));
        expect(map[0], equals('zero'));
        expect(map[1], equals('one'));
      });

      test('should throw on duplicate Ref entries in Kids', () {
        final leafRef = Ref.get(40, 0);
        final leaf = Dict();
        leaf.set('Nums', [5, 'five']);

        final root = Dict();
        root.set('Kids', [leafRef, leafRef]);

        final xref = XRefMock([
          {'ref': leafRef, 'data': leaf}
        ]);
        final tree = NumberTree(root, xref);

        expect(
          () => tree.getAll(),
          throwsA(predicate((e) =>
              e.toString().contains('Duplicate entry in "Nums" tree.'))),
        );
      });
    });
  });
}
