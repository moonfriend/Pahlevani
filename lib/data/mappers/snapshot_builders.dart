import 'package:pahlevani/data/dtos/exercise_row.dart';
import 'package:pahlevani/data/dtos/training_item_row.dart';
import 'package:pahlevani/data/dtos/training_session_row.dart';
import 'package:pahlevani/data/mappers/row_to_domain.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:collection/collection.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import '../../domain/entities/training_session/training_item.dart';

/// ======== ASSEMBLY HELPERS ========
/// These functions convert a "snapshot" of three tables into
/// - maps of domain objects (useful for repository storage), and
/// - a ready `SessionDetail` for a chosen session.

class DomainSnapshot {
  final Map<int, TrainingSession> sessionsById;
  final Map<int, List<TrainingItem>> itemsBySessionId; // ordered
  final Map<int, Exercise> exercisesById;

  DomainSnapshot({
    required this.sessionsById,
    required this.itemsBySessionId,
    required this.exercisesById,
  });

  bool get isNotEmpty => sessionsById.isNotEmpty;
  bool get isEmpty => sessionsById.isEmpty;
}

class NullDomainSnapshot extends DomainSnapshot {
  NullDomainSnapshot()
      : super(
          sessionsById: {},
          itemsBySessionId: {},
          exercisesById: {},
        );
}

/// Build normalized domain maps from raw DB rows.
DomainSnapshot buildDomainSnapshot({
  required List<TrainingSessionRow> sessionRows,
  required List<TrainingItemRow> itemRows,
  required List<ExerciseRow> exerciseRows,
}) {
  final sessionsById = {for (final s in sessionRows.map(mapSession)) s.id: s};

  // group items by session, ordered by position
  final grouped = <int, List<TrainingItem>>{};
  for (final row in itemRows) {
    final item = mapItem(row);
    grouped.putIfAbsent(item.sessionId, () => []).add(item);
  }
  for (final list in grouped.values) {
    list.sortBy<num>((i) => i.position);
  }

  final exercisesById = {
    for (final e in exerciseRows.map(mapExercise)) e.id: e
  };

  return DomainSnapshot(
    sessionsById: sessionsById,
    itemsBySessionId: grouped,
    exercisesById: exercisesById,
  );
}

/// Build a read model for one session (ready for the UI)
SessionDetail buildSessionDetail(int sessionId, DomainSnapshot snap) {
  final session = snap.sessionsById[sessionId];
  if (session == null) {
    throw StateError('Session $sessionId not found');
  }
  final items = snap.itemsBySessionId[sessionId] ?? const <TrainingItem>[];
  final details = <ItemDetail>[];
  for (final it in items) {
    final ex = snap.exercisesById[it.exerciseId];
    if (ex == null) {
      // You can choose to skip or throw; here we fail fast.
      throw StateError('Exercise ${it.exerciseId} not found for item ${it.id}');
    }
    details.add(ItemDetail(item: it, exercise: ex));
  }
  return SessionDetail(session: session, items: details);
}
