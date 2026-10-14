import 'package:pahlevani/domain/entities/training_session/exercise.dart';

/// The Library's moves: one per movement that has something to learn from
/// (see [Exercise.hasLearningContent]), sorted by name.
///
/// Several exercise rows can share a movement (one per session use); they
/// carry the same name, media and content, so the lowest id stands for the
/// movement. An exercise without a movement is a move of its own.
List<Exercise> libraryMoves(Iterable<Exercise> exercises) {
  final byMove = <Object, Exercise>{};
  for (final exercise in exercises) {
    if (!exercise.hasLearningContent) continue;
    final key = exercise.movementId ?? 'exercise:${exercise.id}';
    final current = byMove[key];
    if (current == null || exercise.id < current.id) byMove[key] = exercise;
  }
  return byMove.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
