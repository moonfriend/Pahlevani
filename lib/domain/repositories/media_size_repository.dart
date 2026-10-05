/// Recorded sizes (bytes) of media files, keyed by URL (table media_asset,
/// migration 0041). Used to show a download's size before it starts.
abstract class MediaSizeRepository {
  /// Sizes for [urls]; URLs with no recorded size are absent from the map.
  Future<Map<String, int>> sizesFor(Set<String> urls);
}
