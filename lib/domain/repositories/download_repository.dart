import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

abstract class DownloadRepository {
  /// Initial download statuses for all known sessions (from SharedPreferences).
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses();

  /// Stream of progress 0.0→1.0 for downloading all audio files in [session].
  Stream<double> downloadTrainingSession(SessionDetail session);

  /// True if all files for [sessionId] exist on disk.
  Future<bool> isTrainingSessionDownloaded(int sessionId);

  /// Local file path for [song] if downloaded, otherwise null.
  Future<String?> getLocalSongPath(int sessionId, ItemDetail song);
}
