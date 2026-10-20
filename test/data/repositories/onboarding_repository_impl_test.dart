import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/datasources/onboarding/onboarding_remote_datasource.dart';
import 'package:pahlevani/data/repositories_impl/onboarding_repository_impl.dart';
import 'package:pahlevani/domain/entities/onboarding/onboarding_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRemote implements OnboardingRemoteDataSource {
  List<Map<String, dynamic>> rows = [];
  Object? error;

  @override
  Future<List<Map<String, dynamic>>> fetchActiveCards() async {
    if (error != null) throw error!;
    return rows;
  }
}

Map<String, dynamic> _row(int position, String title) => {
      'id': position,
      'position': position,
      'title_en': title,
      'body_en': 'body $title',
      'builtin_image': 'figure',
      'is_active': true,
    };

void main() {
  late _FakeRemote remote;
  late OnboardingRepositoryImpl repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remote = _FakeRemote();
    repo = OnboardingRepositoryImpl(remoteDataSource: remote);
  });

  test('nothing cached yet → the built-in cards', () async {
    expect(await repo.cachedCards(), defaultOnboardingCards);
  });

  test('refresh returns the server cards in order and caches them', () async {
    remote.rows = [_row(1, 'One'), _row(2, 'Two')];

    final fresh = await repo.refresh();
    expect(fresh.map((c) => c.title), ['One', 'Two']);

    final relaunched =
        OnboardingRepositoryImpl(remoteDataSource: _FakeRemote());
    expect((await relaunched.cachedCards()).map((c) => c.title), ['One', 'Two'],
        reason: 'offline next time still shows the last server cards');
  });

  test('invalid rows are skipped', () async {
    remote.rows = [_row(1, 'One'), _row(2, '   ')];
    expect((await repo.refresh()).map((c) => c.title), ['One']);
  });

  test('no active cards on the server → built-in cards, cache cleared',
      () async {
    remote.rows = [_row(1, 'Old')];
    await repo.refresh();

    remote.rows = [];
    expect(await repo.refresh(), defaultOnboardingCards);
    expect(await repo.cachedCards(), defaultOnboardingCards);
  });

  test('a failed fetch throws and leaves the cache alone', () async {
    remote.rows = [_row(1, 'Cached')];
    await repo.refresh();

    remote.error = Exception('offline');
    await expectLater(repo.refresh(), throwsException);
    expect((await repo.cachedCards()).single.title, 'Cached');
  });

  test('a corrupt cache falls back to the built-in cards', () async {
    SharedPreferences.setMockInitialValues(
        {OnboardingRepositoryImpl.cacheKey: '{not json'});
    expect(await repo.cachedCards(), defaultOnboardingCards);
  });
}
