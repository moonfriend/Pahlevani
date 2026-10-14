import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/info/info_link.dart';
import 'package:pahlevani/domain/repositories/announcement_repository.dart';
import 'package:pahlevani/presentation/bloc/announcement/announcement_cubit.dart';

class _FakeRepo implements AnnouncementRepository {
  InfoLink? cachedLink;
  InfoLink? serverLink;
  bool fail = false;
  String? seen;
  int refreshes = 0;

  @override
  Future<InfoLink?> cached() async => cachedLink;

  @override
  Future<InfoLink?> refresh() async {
    refreshes++;
    if (fail) throw Exception('offline');
    cachedLink = serverLink;
    return serverLink;
  }

  @override
  Future<String?> seenKey() async => seen;

  @override
  Future<void> markSeen(String contentKey) async => seen = contentKey;
}

const _v1 = InfoLink(title: 'Meel', url: 'https://rahaavi.com/meel');
const _v2 =
    InfoLink(title: 'Meel video is out', url: 'https://rahaavi.com/meel-video');

void main() {
  late _FakeRepo repo;
  late AnnouncementCubit cubit;

  setUp(() {
    repo = _FakeRepo();
    cubit = AnnouncementCubit(repository: repo);
  });
  tearDown(() => cubit.close());

  test('a card the user has not opened yet is new', () async {
    repo.serverLink = _v1;
    await cubit.load();
    expect(cubit.state.link, _v1);
    expect(cubit.state.isNew, isTrue);
  });

  test('opening it marks it seen; it stays seen on the next start', () async {
    repo.serverLink = _v1;
    await cubit.load();
    await cubit.markSeen();
    expect(cubit.state.isNew, isFalse);

    final next = AnnouncementCubit(repository: repo);
    addTearDown(next.close);
    await next.load();
    expect(next.state.isNew, isFalse);
  });

  test('a changed card is new again', () async {
    repo.serverLink = _v1;
    await cubit.load();
    await cubit.markSeen();

    repo.serverLink = _v2;
    await cubit.refresh();
    expect(cubit.state.link, _v2);
    expect(cubit.state.isNew, isTrue);
  });

  test('offline: shows the cached card, no error', () async {
    repo.cachedLink = _v1;
    repo.fail = true;
    await cubit.load();
    expect(cubit.state.link, _v1);
  });

  test('no card on the server: nothing to show', () async {
    await cubit.load();
    expect(cubit.state.link, isNull);
    expect(cubit.state.isNew, isFalse);
  });
}
