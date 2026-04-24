import 'package:test/test.dart';

import 'package:pdfjs/src/core/core_utils.dart';
import 'package:pdfjs/src/core/dataset_reader.dart';

void main() {
  group('DatasetReader', () {
    test('reads scalar values from datasets XML', () {
      final reader = DatasetReader({
        'datasets':
            '<xfa:datasets><form><name>JosÃ©</name><age>42</age></form></xfa:datasets>',
      });

      expect(reader.getValue('form.name'), 'José');
      expect(reader.getValue('form.age'), '42');
      expect(reader.getValue('form.missing'), '');
    });

    test('reads repeated value children as a list', () {
      final reader = DatasetReader({
        'datasets':
            '<xfa:datasets><form><choice><value>A</value><value>B</value></choice></form></xfa:datasets>',
      });

      expect(reader.getValue('form.choice'), ['A', 'B']);
    });

    test('extracts xfa:datasets from an xdp:xdp packet', () {
      final reader = DatasetReader({
        'xdp:xdp':
            '<xdp:xdp><template/><xfa:datasets><form><field>ok</field></form></xfa:datasets></xdp:xdp>',
      });

      expect(reader.getValue('form.field'), 'ok');
    });
  });

  group('parseXFAPath', () {
    test('parses repeated path components', () {
      final path = parseXFAPath('form.items[2].name');

      expect(path[0].name, 'form');
      expect(path[0].pos, 0);
      expect(path[1].name, 'items');
      expect(path[1].pos, 2);
      expect(path[2].name, 'name');
      expect(path[2].pos, 0);
    });
  });
}
