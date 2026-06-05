import 'package:pahlevani/data/dtos/exercise_row.dart';
import 'package:pahlevani/data/dtos/movement_row.dart';
import 'package:pahlevani/data/dtos/training_item_row.dart';
import 'package:pahlevani/data/dtos/training_session_row.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

/// Maps an exercise row, joined with its movement row when available.
/// Falls back to any fields still present on the exercise row itself
/// (pre-migration state where name/media still live in the exercise table).
Exercise mapExercise(ExerciseRow r, {MovementRow? movement}) => Exercise(
  id: r.id,
  movementId: r.movementId ?? movement?.id,
  name: movement?.name ?? r.name ?? 'Exercise ${r.id}',
  titleFa: movement?.titleFa ?? r.titleFa,
  gloss: movement?.gloss ?? r.gloss,
  author: r.author,
  type: movement?.type ?? r.type,
  audioFileUrl: r.url,
  repetitionsDefault: r.repetitions,
  durationSeconds: r.durationSeconds,
  media: ExerciseMedia(
    type: movement?.mediaType ?? r.mediaType ?? 'none',
    src: movement?.mediaSrc ?? r.mediaSrc,
    poster: movement?.mediaPoster ?? r.mediaPoster,
  ),
);

TrainingSession mapSession(TrainingSessionRow r) => TrainingSession(
  id: r.id,
  title: r.title ?? 'Sample Session',
  titleFa: r.titleFa,
  description: r.description ?? 'Description',
  difficulty: r.difficulty ?? 5,
  createdAt: r.createdAt,
);

/// Your schema only exposes `reps_to_do`. If you later add time-based items,
/// extend TrainingItemRow and map to TimePresc when appropriate.
TrainingItem mapItem(TrainingItemRow r) => TrainingItem(
  id: r.trainingSessionId * 10000 + r.position,
  sessionId: r.trainingSessionId,
  exerciseId: r.exerciseId,
  position: r.position,
  prescription: RepsPresc(r.repsToDo),
);
