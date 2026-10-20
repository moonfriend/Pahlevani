/// Tracks which path items the athlete has marked done. Local-only for now
/// (not synced to Supabase) — deliberately narrow so a sync method could be
/// added later without reshaping this interface.
abstract class PathProgressRepository {
  Future<Set<int>> getCompletedItemIds();

  Future<void> setItemCompleted(int itemId, bool completed);
}
