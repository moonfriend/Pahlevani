import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';

/// In-memory fake for [LearntExercisesRepository] — no real SharedPreferences
/// involved, so tests don't need `SharedPreferences.setMockInitialValues`.
class FakeLearntExercisesRepository implements LearntExercisesRepository {
  FakeLearntExercisesRepository({Set<int>? learntIds})
      : learntIds = learntIds ?? {};

  Set<int> learntIds;

  @override
  Future<Set<int>> getLearntExerciseIds() async => Set.of(learntIds);

  @override
  Future<void> setExerciseLearnt(int exerciseId, bool learnt) async {
    if (learnt) {
      learntIds.add(exerciseId);
    } else {
      learntIds.remove(exerciseId);
    }
  }
}
