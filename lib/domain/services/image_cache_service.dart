/// Contract for a content-addressed, persistent image cache.
///
/// Implementations maintain an in-memory index (urlHash → localPath) backed by
/// a Hive box so that [lookup] is synchronous and I/O-free on every render.
abstract class ImageCacheService {
  /// Returns the local file path for [imageUrl] if it is already cached,
  /// or null if not. Always synchronous — no I/O.
  String? lookup(String imageUrl);

  /// Schedules a background download of [imageUrl] to the local cache.
  /// Returns immediately; no-op if the URL is already cached or in flight.
  void prefetch(String imageUrl);

  /// Resolves [imageUrl] to a local path, downloading it if necessary.
  /// Returns null on failure.
  Future<String?> resolve(String imageUrl);

  /// Records a [localPath] for [imageUrl] in both the in-memory index and the
  /// Hive box. Called automatically by [resolve]; also callable externally when
  /// a file is downloaded by another path (e.g. the session download flow).
  Future<void> record(String imageUrl, String localPath);
}
