import '../entities/info/info_link.dart';

/// Home's info card (an admin-set announcement linking to our website) and
/// which version of it this device has opened.
abstract class AnnouncementRepository {
  /// The last card fetched, from the device; null when none was ever
  /// fetched or the server had none.
  Future<InfoLink?> cached();

  /// Fetches the active card and caches it (null and cache cleared when
  /// there is none). Throws when the fetch fails, leaving the cache as is.
  Future<InfoLink?> refresh();

  /// [InfoLink.contentKey] of the version the user last opened.
  Future<String?> seenKey();

  Future<void> markSeen(String contentKey);
}
