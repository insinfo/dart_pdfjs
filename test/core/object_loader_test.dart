import 'package:pdfjs/src/core/core_utils.dart';
import 'package:pdfjs/src/core/object_loader.dart';
import 'package:pdfjs/src/core/primitives.dart';
import 'package:test/test.dart';

class MockStreamManager {
  final List<dynamic> requestedRanges = [];
  bool requestedAllChunks = false;

  Future<void> requestRanges(List<dynamic> ranges) async {
    requestedRanges.addAll(ranges);
  }

  Future<void> requestAllChunks() async {
    requestedAllChunks = true;
  }
}

class MockXRefStream {
  bool isDataLoaded = false;
  final manager = MockStreamManager();
}

class MockXRef {
  final stream = MockXRefStream();
  final Map<String, dynamic> store = {};
  int fetchCount = 0;

  dynamic fetch(Ref ref) {
    fetchCount++;
    final key = '${ref.num}_${ref.gen}';
    if (!store.containsKey(key)) {
      // Simula missing data se especificado
      throw MissingDataException(100, 200);
    }
    return store[key];
  }
}

void main() {
  group('ObjectLoader', () {
    test('skips traversal if stream is already loaded', () async {
      final xref = MockXRef();
      xref.stream.isDataLoaded = true;

      final dict = Dict();
      dict.set('Key1', Ref.get(1, 0));

      await ObjectLoader.load(dict, ['Key1'], xref);
      expect(xref.fetchCount, equals(0));
    });

    test('walks object graph and fetches references with cycle protection', () async {
      final xref = MockXRef();
      final ref1 = Ref.get(1, 0);
      final ref2 = Ref.get(2, 0);


      // Setup a cycle: ref1 -> dict containing ref2; ref2 -> dict containing ref1
      final dict1 = Dict();
      dict1.set('Next', ref2);
      xref.store['1_0'] = dict1;

      final dict2 = Dict();
      dict2.set('Back', ref1);
      xref.store['2_0'] = dict2;

      final root = Dict();
      root.set('Start', ref1);

      await ObjectLoader.load(root, ['Start'], xref);

      // Both ref1 and ref2 fetched once, no infinite loop
      expect(xref.fetchCount, equals(2));
    });

    test('requests missing data ranges and revisits nodes', () async {
      final ref1 = Ref.get(5, 0);

      final root = Dict();
      root.set('Item', ref1);

      // On first fetch, ref 5 is missing, throwing MissingDataException(100, 200).
      // When requestRanges is called, we simulate receiving the chunk and populate the store!
      bool firstAttempt = true;
      dynamic customFetch(Ref r) {
        if (firstAttempt) {
          firstAttempt = false;
          throw MissingDataException(100, 200);
        }
        return Dict();
      }

      final xrefWithRetry = _RetryXRef(customFetch);
      await ObjectLoader.load(root, ['Item'], xrefWithRetry);

      expect(xrefWithRetry.stream.manager.requestedRanges.length, equals(1));
      expect(xrefWithRetry.stream.manager.requestedRanges.first.begin, equals(100));
      expect(xrefWithRetry.stream.manager.requestedRanges.first.end, equals(200));
      expect(xrefWithRetry.callCount, equals(2));
    });
  });
}

class _RetryXRef {
  final stream = MockXRefStream();
  final dynamic Function(Ref) onFetch;
  int callCount = 0;

  _RetryXRef(this.onFetch);

  dynamic fetch(Ref ref) {
    callCount++;
    return onFetch(ref);
  }
}

