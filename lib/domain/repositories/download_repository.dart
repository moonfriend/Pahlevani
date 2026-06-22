import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

abstract class DownloadRepository {
  /// Initial download statuses for all known sessions (from SharedPreferences).
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses();

  /// Stream of progress 0.0→1.0 for downloading all audio and image files in [session].
  Stream<double> downloadTrainingSession(SessionDetail session);

  /// True if all files for [sessionId] exist on disk.
  Future<bool> isTrainingSessionDownloaded(int sessionId);

  /// Local file path for [song] if the full session is downloaded, otherwise null.
  Future<String?> getLocalSongPath(int sessionId, ItemDetail song);

  /// Local audio path for [item] if the file exists on disk (works for partial caches too).
  Future<String?> getLocalAudioPath(int sessionId, ItemDetail item);

  /// Local image path for [itemId] if the file exists on disk.
  /// Pass [imageUrl] so the hash-based filename can be resolved correctly.
  Future<String?> getLocalImagePath(int sessionId, int itemId,
      {String? imageUrl});

  /// Download a single audio track and return its local path. No-op if already cached.
  Future<String?> cacheAudio(int sessionId, ItemDetail item);

  /// Returns a local file path for [item]'s audio, downloading it first if
  /// necessary. Unlike [cacheAudio], this never returns null on success —
  /// callers should hand the result straight to playback instead of reading
  /// [ItemDetail.exercise.audioFileUrl] themselves, so the file is fetched
  /// exactly once (not once to stream it and once more to cache it).
  /// Falls back to the original remote URL if the download fails.
  Future<String> resolvePlayableAudioPath(int sessionId, ItemDetail item);

  /// Download a single image and return its local path. No-op if already cached.
  Future<String?> cacheImage(int sessionId, int itemId, String url);

  /// Returns true if every exercise audio in [items] is cached locally.
  /// If all are cached, also marks the session as downloaded in persistent storage
  /// so the badge appears on the sessions list without requiring an explicit download.
  Future<bool> checkAllCachedAndMark(int sessionId, List<ItemDetail> items);
}
