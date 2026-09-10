/// A small, explicit set of movements a trainer can flag on a
/// [TrainingItem] (via `training_session_item.tracked_movement_type`) for
/// rep tracking. Adding a new trackable movement is one new enum value here
/// plus one new option in scripts/admin.py's Session Builder — the two
/// lists of keys must be kept in sync by hand.
enum TrackedMovementType {
  shenoSarnavazi('sheno_sarnavazi', 'شنو سرنوازی'),
  meelAram('meel_aram', 'میل آرام');

  /// Matches `training_session_item.tracked_movement_type` in Supabase.
  final String key;
  final String displayName;

  const TrackedMovementType(this.key, this.displayName);

  static TrackedMovementType? fromKey(String? key) {
    if (key == null) return null;
    for (final type in values) {
      if (type.key == key) return type;
    }
    return null;
  }
}
