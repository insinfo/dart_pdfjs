import 'package:test/test.dart';

import '../../example/src/ui_utils.dart';

void main() {
  group('binarySearchFirstItem', () {
    bool greaterThanThree(int value) => value > 3;

    test('handles empty and singleton lists', () {
      expect(binarySearchFirstItem(<int>[], greaterThanThree), 0);
      expect(binarySearchFirstItem(<int>[1], greaterThanThree), 1);
      expect(binarySearchFirstItem(<int>[4], greaterThanThree), 0);
    });

    test('finds the first matching item', () {
      expect(
          binarySearchFirstItem(<int>[0, 1, 2, 3, 4, 5], greaterThanThree), 4);
      expect(binarySearchFirstItem(<int>[4, 5, 6], greaterThanThree), 0);
      expect(binarySearchFirstItem(<int>[0, 1, 2], greaterThanThree), 3);
    });

    test('honours the start index', () {
      expect(
          binarySearchFirstItem(<int>[0, 1, 2, 3, 4], greaterThanThree, 2), 4);
      expect(binarySearchFirstItem(<int>[2, 3, 4], greaterThanThree, 2), 2);
      expect(binarySearchFirstItem(<int>[4, 5, 6], greaterThanThree, 1), 1);
    });
  });

  test('approximateFraction matches the order-eight Farey approximation', () {
    expect(approximateFraction(1), <int>[1, 1]);
    expect(approximateFraction(0.5), <int>[1, 2]);
    expect(approximateFraction(5.5), <int>[6, 1]);
    expect(approximateFraction(1 / 9), <int>[1, 8]);
    expect(approximateFraction(3.14159265), <int>[3, 1]);
  });

  test('floorToDivide rounds down to a multiple', () {
    expect(floorToDivide(6, 4), 4);
    expect(floorToDivide(12, 4), 12);
    expect(floorToDivide(17, 4), 16);
  });

  group('validation helpers', () {
    test('rotation accepts integer multiples of 90 only', () {
      expect(isValidRotation(null), isFalse);
      expect(isValidRotation('90'), isFalse);
      expect(isValidRotation(90.5), isFalse);
      expect(isValidRotation(45), isFalse);
      expect(isValidRotation(0), isTrue);
      expect(isValidRotation(-270), isTrue);
      expect(isValidRotation(540), isTrue);
    });

    test('scroll and spread modes exclude unknown values', () {
      expect(isValidScrollMode(ScrollMode.unknown), isFalse);
      expect(isValidScrollMode(ScrollMode.vertical), isTrue);
      expect(isValidScrollMode(ScrollMode.page), isTrue);
      expect(isValidScrollMode(4), isFalse);
      expect(isValidSpreadMode(SpreadMode.unknown), isFalse);
      expect(isValidSpreadMode(SpreadMode.none), isTrue);
      expect(isValidSpreadMode(SpreadMode.even), isTrue);
      expect(isValidSpreadMode(3), isFalse);
    });
  });

  group('query parsing', () {
    test('parses and lowercases keys', () {
      expect(parseQueryString('Key1=Value1&KEY2=Value2'),
          <String, String>{'key1': 'Value1', 'key2': 'Value2'});
    });

    test('decodes keys, values, plus signs, and absent values', () {
      expect(parseQueryString('k%C3%ABy1=valu%C3%AB1&empty&x=a+b'),
          <String, String>{'këy1': 'valuë1', 'empty': '', 'x': 'a b'});
    });
  });

  group('removeNullCharacters', () {
    test('does not modify ordinary strings', () {
      expect(removeNullCharacters('string without null chars'),
          'string without null chars');
    });

    test('removes null characters', () {
      expect(removeNullCharacters('string\x00With\x00Null'), 'stringWithNull');
    });

    test('replaces non-displayable characters when requested', () {
      final source = List<String>.generate(
        32,
        (index) => '${String.fromCharCode(index)}a',
      ).join();
      expect(
        removeNullCharacters(source, replaceInvisible: true),
        'a${List<String>.filled(31, ' a').join()}',
      );
    });
  });

  group('page size and viewer mode conversion', () {
    test('converts PDF points to inches and accounts for rotation', () {
      final portrait = getPageSizeInches(
        view: <num>[0, 0, 612, 792],
        userUnit: 1,
        rotate: 0,
      );
      expect(portrait.width, 8.5);
      expect(portrait.height, 11);
      expect(isPortraitOrientation(portrait), isTrue);

      final landscape = getPageSizeInches(
        view: <num>[0, 0, 612, 792],
        userUnit: 1,
        rotate: 90,
      );
      expect(landscape.width, 11);
      expect(landscape.height, 8.5);
      expect(isPortraitOrientation(landscape), isFalse);
    });

    test('maps API page layouts', () {
      var modes = apiPageLayoutToViewerModes('SinglePage');
      expect(modes.scrollMode, ScrollMode.page);
      expect(modes.spreadMode, SpreadMode.none);
      modes = apiPageLayoutToViewerModes('TwoColumnLeft');
      expect(modes.scrollMode, ScrollMode.vertical);
      expect(modes.spreadMode, SpreadMode.odd);
      modes = apiPageLayoutToViewerModes('TwoPageRight');
      expect(modes.scrollMode, ScrollMode.page);
      expect(modes.spreadMode, SpreadMode.even);
    });

    test('maps API page modes', () {
      expect(apiPageModeToSidebarView('UseNone'), SidebarView.none);
      expect(apiPageModeToSidebarView('UseThumbs'), SidebarView.thumbs);
      expect(apiPageModeToSidebarView('UseOutlines'), SidebarView.outline);
      expect(
          apiPageModeToSidebarView('UseAttachments'), SidebarView.attachments);
      expect(apiPageModeToSidebarView('UseOC'), SidebarView.layers);
      expect(apiPageModeToSidebarView('FullScreen'), SidebarView.none);
    });
  });

  group('getVisibleElements', () {
    test('finds, measures, and sorts partially visible pages', () {
      final pages = <ViewerElement<void>>[
        _page(0, top: 0, width: 100, height: 100),
        _page(1, top: 110, width: 100, height: 100),
        _page(2, top: 220, width: 100, height: 100),
      ];
      final result = getVisibleElements<void>(
        scrollElement: const ViewportGeometry(
          scrollTop: 50,
          scrollLeft: 0,
          clientHeight: 200,
          clientWidth: 100,
        ),
        views: pages,
        sortByVisibility: true,
      );
      expect(result.first?.id, 0);
      expect(result.last?.id, 2);
      expect(result.ids, <int>{0, 1, 2});
      expect(result.views.map((item) => item.id), <int>[1, 0, 2]);
      expect(result.views.first.percent, 100);
    });

    test('handles empty and completely hidden page lists', () {
      const viewport = ViewportGeometry(
        scrollTop: 1000,
        scrollLeft: 0,
        clientHeight: 100,
        clientWidth: 100,
      );
      var result = getVisibleElements<void>(
        scrollElement: viewport,
        views: const <ViewerElement<void>>[],
      );
      expect(result.views, isEmpty);
      expect(result.first, isNull);
      result = getVisibleElements<void>(
        scrollElement: viewport,
        views: <ViewerElement<void>>[
          _page(0, top: 0, width: 100, height: 100),
        ],
      );
      expect(result.views, isEmpty);
    });
  });
}

ViewerElement<void> _page(
  int id, {
  required int top,
  required int width,
  required int height,
}) =>
    ViewerElement<void>(
      id: id,
      div: _Geometry(
        offsetLeft: 0,
        offsetTop: top,
        clientWidth: width,
        clientHeight: height,
      ),
    );

final class _Geometry implements ElementGeometry {
  const _Geometry({
    required this.offsetLeft,
    required this.offsetTop,
    required this.clientWidth,
    required this.clientHeight,
  });

  @override
  final int offsetLeft;
  @override
  final int offsetTop;
  @override
  final int clientWidth;
  @override
  final int clientHeight;
  @override
  int get clientLeft => 0;
  @override
  int get clientTop => 0;
}
