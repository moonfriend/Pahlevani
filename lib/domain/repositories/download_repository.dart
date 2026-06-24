import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

abstract class DownloadRepository {
  /// Initial download statuses for all known sessions (from SharedPreferences).
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses();

  /// Stream of progress 0.0→1.0 for downloading all audio and image files in [session].
  Stream<double> downloadTrainingSession(SessionDetail session);

  /// True if [sessionId] is marked downloaded and every exercise audio in
  /// [items] is present in the shared media cache.
  Future<bool> isTrainingSessionDownloaded(
      int sessionId, List<ItemDetail> items);

  /// Local audio path for [item] if the file exists in the shared media
  /// cache (works for partial caches too). Shared across every session that
  /// references the same exercise.
  Future<String?> getLocalAudioPath(ItemDetail item);

  /// Local image path for [imageUrl] if the file exists in the shared media
  /// cache.
  Future<String?> getLocalImagePath(String imageUrl);

  /// Download a single audio track and return its local path. No-op if
  /// already cached — including by a different session that references the
  /// same exercise.
  Future<String?> cacheAudio(ItemDetail item);

  /// Returns a local file path for [item]'s audio, downloading it first if
  /// necessary. Unlike [cacheAudio], this never returns null on success —
  /// callers should hand the result straight to playback instead of reading
  /// [ItemDetail.exercise.audioFileUrl] themselves, so the file is fetched
  /// exactly once (not once to stream it and once more to cache it).
  /// Falls back to the original remote URL if the download fails.
  Future<String> resolvePlayableAudioPath(ItemDetail item);

  /// Download a single image and return its local path. No-op if already
  /// cached — including by a different session that references the same
  /// exercise.
  Future<String?> cacheImage(String url);

  /// Returns true if every exercise audio in [items] is cached locally.
  /// If all are cached, also marks the session as downloaded in persistent storage
  /// so the badge appears on the sessions list without requiring an explicit download.
  Future<bool> checkAllCachedAndMark(int sessionId, List<ItemDetail> items);
}
