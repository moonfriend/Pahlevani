import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/datasources/media/media_size_remote_datasource.dart';
import 'package:pahlevani/data/repositories_impl/media_size_repository_impl.dart';

class _FakeRemote implements MediaSizeRemoteDataSource {
  final Map<String, int> table;
  final List<List<String>> calls = [];
  _FakeRemote(this.table);

  @override
  Future<Map<String, int>> fetchSizes(List<String> urls) async {
    calls.add(urls);
    return {
      for (final u in urls)
        if (table.containsKey(u)) u: table[u]!
    };
  }
}

void main() {
  test('asks in batches (URLs travel in the query string) and merges',
      () async {
    final urls = [for (var i = 0; i < 120; i++) 'https://cdn/$i.mp3'];
    final remote = _FakeRemote({for (final u in urls) u: 7});
    final repo = MediaSizeRepositoryImpl(remote: remote);

    final sizes = await repo.sizesFor(urls.toSet());

    expect(sizes.length, 120);
    expect(remote.calls.length, greaterThan(1));
    expect(
        remote.calls
            .every((c) => c.length <= MediaSizeRepositoryImpl.batchSize),
        isTrue);
  });

  test('URLs without a media_asset row are simply absent', () async {
    final repo = MediaSizeRepositoryImpl(
        remote: _FakeRemote({'https://cdn/known.mp3': 5}));
    expect(await repo.sizesFor({'https://cdn/known.mp3', 'https://cdn/x.mp3'}),
        {'https://cdn/known.mp3': 5});
  });

  test('no URLs → no request', () async {
    final remote = _FakeRemote({});
    expect(await MediaSizeRepositoryImpl(remote: remote).sizesFor({}), isEmpty);
    expect(remote.calls, isEmpty);
  });
}
