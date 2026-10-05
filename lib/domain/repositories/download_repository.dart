import 'package:pahlevani/domain/entities/download/download_plan.dart';
import 'package:pahlevani/domain/entities/download/download_progress.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

abstract class DownloadRepository {
  /// Initial download statuses for all known sessions (from SharedPreferences).
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses();

  /// Local audio path for [item] if the file exists in the shared media
  /// cache (works for partial caches too). Shared across every session that
  /// references the same exercise.
  Future<String?> getLocalAudioPath(ItemDetail item);

  /// Local image path for [imageUrl] if the file exists in the shared media
  /// cache.
  Future<String?> getLocalImagePath(String imageUrl);

  /// Local video path for [videoUrl] if the file exists in the shared media
  /// cache. Videos only ever play from this local cache — never streamed
  /// over network — so callers should treat a null result as "not ready
  /// yet" rather than falling back to the remote URL.
  Future<String?> getLocalVideoPath(String videoUrl);

  /// URLs of [plan]'s files that are already on the device.
  Future<Set<String>> localUrlsIn(DownloadPlan plan);

  /// Downloads [plan]'s missing files one by one, reporting progress (bytes
  /// from [knownSizes], refined by the server as files start). Files already
  /// on the device are skipped, so after a failure (stream error) the next
  /// call carries on with what's still missing. Cancelling the subscription
  /// stops the running transfer; finished files are kept.
  Stream<DownloadProgress> downloadPlan(DownloadPlan plan,
      {Map<String, int> knownSizes = const {}});

  /// Records that a session's media is fully on the device (the list's
  /// "downloaded" badge).
  Future<void> markTrainingSessionDownloaded(int sessionId);
}
