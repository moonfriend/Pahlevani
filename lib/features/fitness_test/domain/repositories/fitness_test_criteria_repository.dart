import '../entities/fitness_test_criteria.dart';

/// Source of truth for the fitness-test rubric — lives in Supabase, edited
/// via the admin panel, never hardcoded in the app.
abstract class FitnessTestCriteriaRepository {
  Future<List<FitnessTestChart>> fetchCriteria();
}
