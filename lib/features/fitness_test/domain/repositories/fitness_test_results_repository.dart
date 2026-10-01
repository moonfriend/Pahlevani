import '../entities/fitness_test_result.dart';

/// Local-only (Hive) storage of completed stage results. Syncing results to
/// Supabase is a future iteration, not this one.
abstract class FitnessTestResultsRepository {
  Future<void> saveResult(FitnessTestStageResult result);

  /// The most recent saved result for [chartKey], or null if that stage has
  /// never been completed.
  Future<FitnessTestStageResult?> latestResultFor(String chartKey);

  Future<List<FitnessTestStageResult>> allResults();
}
