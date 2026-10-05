import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LearntExercisesRepositoryImpl implements LearntExercisesRepository {
  static const _keyLearntIds = 'learnt_exercises.ids';

  @override
  Future<Set<int>> getLearntExerciseIds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_keyLearntIds) ?? const [];
    return stored.map(int.parse).toSet();
  }

  @override
  Future<void> setExerciseLearnt(int exerciseId, bool learnt) async {
    final prefs = await SharedPreferences.getInstance();
    final ids =
        (prefs.getStringList(_keyLearntIds) ?? const []).map(int.parse).toSet();
    if (learnt) {
      ids.add(exerciseId);
    } else {
      ids.remove(exerciseId);
    }
    await prefs.setStringList(
        _keyLearntIds, ids.map((id) => id.toString()).toList());
  }
}
