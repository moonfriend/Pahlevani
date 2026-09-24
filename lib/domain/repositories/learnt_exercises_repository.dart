/// Tracks which exercises the athlete has marked "Learnt" — Learning Mode
/// skips its pre-track prompt for these, starting them immediately instead.
/// Local-only for now (not synced to Supabase); keyed by `Exercise.id`,
/// which is stable across sessions and across resolved-Morshed-audio swaps.
abstract class LearntExercisesRepository {
  Future<Set<int>> getLearntExerciseIds();

  Future<void> setExerciseLearnt(int exerciseId, bool learnt);
}
