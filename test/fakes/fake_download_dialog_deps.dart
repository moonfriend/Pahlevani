import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/repositories/audio_catalog_repository.dart';
import 'package:pahlevani/domain/repositories/download_preferences_repository.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/media_size_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';

import 'fake_download_repository.dart';
import 'fake_training_session_repository.dart';
import 'test_seed_data.dart';

/// No media sizes known.
class NoMediaSizes implements MediaSizeRepository {
  @override
  Future<Map<String, int>> sizesFor(Set<String> urls) async => {};
}

/// Download tier preference kept in memory.
class MemoryDownloadPreferences implements DownloadPreferencesRepository {
  DownloadTier? tier;
  @override
  Future<DownloadTier?> getPreferredTier() async => tier;
  @override
  Future<void> setPreferredTier(DownloadTier t) async => tier = t;
}

/// Registers what the media download dialog resolves from getIt. With a
/// catalog that has no recordings, everything is "already here" and the
/// dialog offers Continue.
void registerDownloadDialogFakes(AudioCatalogRepository catalog) {
  getIt
    ..registerSingleton<AudioCatalogRepository>(catalog)
    ..registerSingleton<TrainingSessionRepository>(
        FakeTrainingSessionRepository(buildTestSnapshot()))
    ..registerSingleton<DownloadRepository>(FakeDownloadRepository())
    ..registerSingleton<MediaSizeRepository>(NoMediaSizes())
    ..registerSingleton<DownloadPreferencesRepository>(
        MemoryDownloadPreferences());
}
