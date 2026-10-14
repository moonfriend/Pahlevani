import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/datasources/announcement/announcement_remote_datasource.dart';
import 'package:pahlevani/data/repositories_impl/announcement_repository_impl.dart';
import 'package:pahlevani/domain/entities/info/info_link.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRemote implements AnnouncementRemoteDataSource {
  Map<String, dynamic>? row;
  bool fail = false;

  @override
  Future<Map<String, dynamic>?> fetchActive() async {
    if (fail) throw Exception('offline');
    return row;
  }
}

void main() {
  late _FakeRemote remote;
  late AnnouncementRepositoryImpl repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remote = _FakeRemote();
    repo = AnnouncementRepositoryImpl(remoteDataSource: remote);
  });

  const meel = InfoLink(
      title: 'How to get your meel',
      description: 'Make your own, order, or pre-order.',
      url: 'https://rahaavi.com/meel');

  test('refresh returns the server card and caches it for offline', () async {
    remote.row = {
      'title': meel.title,
      'description': meel.description,
      'url': meel.url,
    };
    expect(await repo.refresh(), meel);

    remote.fail = true;
    expect(await repo.cached(), meel);
    await expectLater(repo.refresh(), throwsException);
    expect(await repo.cached(), meel, reason: 'a failed fetch keeps it');
  });

  test('no active card on the server clears the cache', () async {
    remote.row = {'title': 'x', 'description': '', 'url': 'https://x.com'};
    await repo.refresh();
    remote.row = null;
    expect(await repo.refresh(), isNull);
    expect(await repo.cached(), isNull);
  });

  test('a card that is not an https link is ignored', () async {
    remote.row = {'title': 'x', 'description': '', 'url': 'http://x.com'};
    expect(await repo.refresh(), isNull);
  });

  test('remembers which version was opened', () async {
    expect(await repo.seenKey(), isNull);
    await repo.markSeen(meel.contentKey);
    expect(await repo.seenKey(), meel.contentKey);
  });
}
