// Copyright 2020 Mozilla Foundation
// Ported to Dart, 2026. Apache License 2.0.

import 'package:test/test.dart';
import 'package:pdfjs/src/display/annotation_storage.dart';

void main() {
  group('AnnotationStorage', () {
    group('GetOrDefaultValue', () {
      test('should get and set a new value in the annotation storage', () {
        final annotationStorage = AnnotationStorage();
        var value = annotationStorage.getValue('123A', {
          'value': 'hello world',
        })['value'];
        expect(value, equals('hello world'));

        annotationStorage.setValue('123A', {
          'value': 'hello world',
        });

        // the second argument is the default value to use
        // if the key isn't in the storage
        value = annotationStorage.getValue('123A', {
          'value': 'an other string',
        })['value'];
        expect(value, equals('hello world'));
      });

      test('should get set values and default ones in the annotation storage',
          () {
        final annotationStorage = AnnotationStorage();
        annotationStorage.setValue('123A', {
          'value': 'hello world',
          'hello': 'world',
        });

        final result = annotationStorage.getValue('123A', {
          'value': 'an other string',
          'world': 'hello',
        });
        expect(result, equals({
          'value': 'hello world',
          'hello': 'world',
          'world': 'hello',
        }));
      });
    });

    group('SetValue', () {
      test('should set a new value in the annotation storage', () {
        final annotationStorage = AnnotationStorage();
        annotationStorage.setValue('123A', {'value': 'an other string'});
        final value = annotationStorage.getRawValue('123A')['value'];
        expect(value, equals('an other string'));
      });

      test('should call onSetModified() if value is changed', () {
        final annotationStorage = AnnotationStorage();
        var called = false;
        void callback() {
          called = true;
        }

        annotationStorage.onSetModified = callback;

        annotationStorage.setValue('asdf', {'value': 'original'});
        expect(called, isTrue);

        // changing value
        annotationStorage.setValue('asdf', {'value': 'modified'});
        expect(called, isTrue);

        // not changing value
        called = false;
        annotationStorage.setValue('asdf', {'value': 'modified'});
        expect(called, isFalse);
      });
    });

    group('ResetModified', () {
      test('should call onResetModified() if set', () {
        final annotationStorage = AnnotationStorage();
        var called = false;
        void callback() {
          called = true;
        }

        annotationStorage.onResetModified = callback;
        annotationStorage.setValue('asdf', {'value': 'original'});
        annotationStorage.resetModified();
        expect(called, isTrue);
        called = false;

        // not changing value
        annotationStorage.setValue('asdf', {'value': 'original'});
        annotationStorage.resetModified();
        expect(called, isFalse);

        // changing value
        annotationStorage.setValue('asdf', {'value': 'modified'});
        annotationStorage.resetModified();
        expect(called, isTrue);
      });
    });
  });
}
