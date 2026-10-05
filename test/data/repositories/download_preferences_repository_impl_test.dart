import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/repositories_impl/download_preferences_repository_impl.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('no tier chosen yet → null (the dialog asks)', () async {
    expect(
        await DownloadPreferencesRepositoryImpl().getPreferredTier(), isNull);
  });

  test('a chosen tier is remembered across instances', () async {
    await DownloadPreferencesRepositoryImpl()
        .setPreferredTier(DownloadTier.followAlong);
    expect(await DownloadPreferencesRepositoryImpl().getPreferredTier(),
        DownloadTier.followAlong);
  });

  test('an unknown stored value (e.g. from a newer app version) → null',
      () async {
    SharedPreferences.setMockInitialValues(
        {'download.preferredTier': 'hologram'});
    expect(
        await DownloadPreferencesRepositoryImpl().getPreferredTier(), isNull);
  });
}
