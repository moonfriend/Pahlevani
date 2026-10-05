import 'package:pahlevani/domain/entities/download/download_plan.dart';

/// The athlete's remembered download tier — asked at the first download,
/// reused as the default afterwards, changeable in the download dialog.
abstract class DownloadPreferencesRepository {
  /// Null until the athlete has chosen once.
  Future<DownloadTier?> getPreferredTier();

  Future<void> setPreferredTier(DownloadTier tier);
}
