import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/repositories/download_preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadPreferencesRepositoryImpl
    implements DownloadPreferencesRepository {
  static const _key = 'download.preferredTier';

  @override
  Future<DownloadTier?> getPreferredTier() async {
    final stored = (await SharedPreferences.getInstance()).getString(_key);
    for (final tier in DownloadTier.values) {
      if (tier.name == stored) return tier;
    }
    return null; // never chosen, or a value this version doesn't know
  }

  @override
  Future<void> setPreferredTier(DownloadTier tier) async =>
      (await SharedPreferences.getInstance()).setString(_key, tier.name);
}
