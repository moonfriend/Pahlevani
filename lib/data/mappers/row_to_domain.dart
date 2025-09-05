import 'package:pahlevani/data/dtos/exercise_row.dart';
import 'package:pahlevani/data/dtos/training_item_row.dart';
import 'package:pahlevani/data/dtos/training_session_row.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

/// ======== MAPPERS (DB rows → Domain) ========

Exercise mapExercise(ExerciseRow r) => Exercise(
  id: r.id.toString(),
  name: r.name ?? 'Exercise ${r.id}',
  author: r.author,
  type: r.type,
  audioFileUrl: r.url,
  repetitionsDefault: r.repetitions,
);

TrainingSession mapSession(TrainingSessionRow r) => TrainingSession(
  id: r.id.toString(),
  title: r.title ?? 'Sample Session',
  description: r.description ?? 'Description',
  difficulty: r.difficulty ?? 5,
  createdAt: r.createdAt,
);

/// Your schema only exposes `reps_to_do`. If you later add time-based items,
/// extend TrainingItemRow and map to TimePresc when appropriate.
TrainingItem mapItem(TrainingItemRow r) => TrainingItem(
  id: '${r.trainingSessionId}:${r.position}', // deterministic id
  sessionId: r.trainingSessionId.toString(),
  exerciseId: r.exerciseId.toString(),
  position: r.position,
  prescription: RepsPresc(r.repsToDo),
);
