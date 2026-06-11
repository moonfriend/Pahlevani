import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/exercise_row.dart';
import 'package:pahlevani/data/dtos/training_item_row.dart';
import 'package:pahlevani/data/dtos/training_session_row.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

// ---------- helpers ----------

TrainingSessionRow sessionRow(int id, {String? title}) =>
    TrainingSessionRow(id: id, title: title ?? 'Session $id');

ExerciseRow exerciseRow(int id, {int repetitions = 1}) =>
    ExerciseRow(id: id, repetitions: repetitions);

TrainingItemRow itemRow({
  required int sessionId,
  required int exerciseId,
  required int position,
  int repsToDo = 1,
}) =>
    TrainingItemRow(
      trainingSessionId: sessionId,
      exerciseId: exerciseId,
      position: position,
      repsToDo: repsToDo,
    );

TrainingSession domainSession(int id) => TrainingSession(
      id: id,
      title: 'Session $id',
      description: '',
      difficulty: 1,
    );

Exercise domainExercise(int id) => Exercise(id: id, name: 'Ex $id');

TrainingItem domainItem({
  required int sessionId,
  required int exerciseId,
  required int position,
}) =>
    TrainingItem(
      id: sessionId * 10000 + position,
      sessionId: sessionId,
      exerciseId: exerciseId,
      position: position,
      prescription: const RepsPresc(1),
    );

// ---------- tests ----------

void main() {
  // ---------- NullDomainSnapshot ----------

  group('NullDomainSnapshot', () {
    test('isEmpty is true', () {
      expect(NullDomainSnapshot().isEmpty, isTrue);
    });

    test('isNotEmpty is false', () {
      expect(NullDomainSnapshot().isNotEmpty, isFalse);
    });

    test('all maps are empty', () {
      final snap = NullDomainSnapshot();
      expect(snap.sessionsById, isEmpty);
      expect(snap.itemsBySessionId, isEmpty);
      expect(snap.exercisesById, isEmpty);
    });
  });

  // ---------- buildDomainSnapshot ----------

  group('buildDomainSnapshot', () {
    test('empty inputs produce empty snapshot', () {
      final snap = buildDomainSnapshot(
        sessionRows: [],
        itemRows: [],
        exerciseRows: [],
      );
      expect(snap.isEmpty, isTrue);
    });

    test('sessions are keyed by id', () {
      final snap = buildDomainSnapshot(
        sessionRows: [sessionRow(1), sessionRow(2)],
        itemRows: [],
        exerciseRows: [],
      );
      expect(snap.sessionsById.keys, containsAll([1, 2]));
    });

    test('exercises are keyed by id', () {
      final snap = buildDomainSnapshot(
        sessionRows: [],
        itemRows: [],
        exerciseRows: [exerciseRow(10), exerciseRow(11)],
      );
      expect(snap.exercisesById.keys, containsAll([10, 11]));
    });

    test('items are grouped by sessionId', () {
      final snap = buildDomainSnapshot(
        sessionRows: [sessionRow(1), sessionRow(2)],
        itemRows: [
          itemRow(sessionId: 1, exerciseId: 10, position: 0),
          itemRow(sessionId: 1, exerciseId: 11, position: 1),
          itemRow(sessionId: 2, exerciseId: 10, position: 0),
        ],
        exerciseRows: [exerciseRow(10), exerciseRow(11)],
      );
      expect(snap.itemsBySessionId[1]!.length, 2);
      expect(snap.itemsBySessionId[2]!.length, 1);
    });

    test('items within a session are sorted ascending by position', () {
      final snap = buildDomainSnapshot(
        sessionRows: [sessionRow(1)],
        itemRows: [
          itemRow(sessionId: 1, exerciseId: 10, position: 2),
          itemRow(sessionId: 1, exerciseId: 11, position: 0),
          itemRow(sessionId: 1, exerciseId: 12, position: 1),
        ],
        exerciseRows: [exerciseRow(10), exerciseRow(11), exerciseRow(12)],
      );
      final positions =
          snap.itemsBySessionId[1]!.map((i) => i.position).toList();
      expect(positions, [0, 1, 2]);
    });

    test('session with no items has empty list in itemsBySessionId', () {
      final snap = buildDomainSnapshot(
        sessionRows: [sessionRow(1)],
        itemRows: [],
        exerciseRows: [],
      );
      expect(snap.itemsBySessionId[1], isNull);
    });

    test('isNotEmpty is true when sessions present', () {
      final snap = buildDomainSnapshot(
        sessionRows: [sessionRow(1)],
        itemRows: [],
        exerciseRows: [],
      );
      expect(snap.isNotEmpty, isTrue);
    });
  });

  // ---------- buildDomainSnapshotFromDomain ----------

  group('buildDomainSnapshotFromDomain', () {
    test('empty inputs produce empty snapshot', () {
      final snap = buildDomainSnapshotFromDomain(
        sessions: [],
        items: [],
        exercises: [],
      );
      expect(snap.isEmpty, isTrue);
    });

    test('sessions keyed by id', () {
      final snap = buildDomainSnapshotFromDomain(
        sessions: [domainSession(1), domainSession(2)],
        items: [],
        exercises: [],
      );
      expect(snap.sessionsById.keys, containsAll([1, 2]));
    });

    test('exercises keyed by id', () {
      final snap = buildDomainSnapshotFromDomain(
        sessions: [],
        items: [],
        exercises: [domainExercise(5), domainExercise(6)],
      );
      expect(snap.exercisesById.keys, containsAll([5, 6]));
    });

    test('items grouped by sessionId and sorted by position', () {
      final snap = buildDomainSnapshotFromDomain(
        sessions: [domainSession(1)],
        items: [
          domainItem(sessionId: 1, exerciseId: 10, position: 1),
          domainItem(sessionId: 1, exerciseId: 11, position: 0),
        ],
        exercises: [domainExercise(10), domainExercise(11)],
      );
      final positions =
          snap.itemsBySessionId[1]!.map((i) => i.position).toList();
      expect(positions, [0, 1]);
    });
  });

  // ---------- buildSessionDetail ----------

  group('buildSessionDetail', () {
    DomainSnapshot snapshotWith({
      required List<TrainingSession> sessions,
      required List<TrainingItem> items,
      required List<Exercise> exercises,
    }) =>
        buildDomainSnapshotFromDomain(
          sessions: sessions,
          items: items,
          exercises: exercises,
        );

    test('returns SessionDetail with session and ordered items', () {
      final snap = snapshotWith(
        sessions: [domainSession(1)],
        items: [
          domainItem(sessionId: 1, exerciseId: 10, position: 1),
          domainItem(sessionId: 1, exerciseId: 11, position: 0),
        ],
        exercises: [domainExercise(10), domainExercise(11)],
      );
      final detail = buildSessionDetail(1, snap);
      expect(detail.session.id, 1);
      expect(detail.items.length, 2);
      expect(detail.items[0].item.position, 0);
      expect(detail.items[1].item.position, 1);
    });

    test('returns SessionDetail with empty items for session that has none',
        () {
      final snap = snapshotWith(
        sessions: [domainSession(1)],
        items: [],
        exercises: [],
      );
      final detail = buildSessionDetail(1, snap);
      expect(detail.items, isEmpty);
    });

    test('throws StateError when session not found', () {
      final snap = NullDomainSnapshot();
      expect(() => buildSessionDetail(99, snap), throwsStateError);
    });

    test('throws StateError when exercise missing for an item', () {
      final snap = snapshotWith(
        sessions: [domainSession(1)],
        items: [domainItem(sessionId: 1, exerciseId: 999, position: 0)],
        exercises: [], // exercise 999 is missing
      );
      expect(() => buildSessionDetail(1, snap), throwsStateError);
    });

    test('joins ItemDetail with correct exercise for each item', () {
      final snap = snapshotWith(
        sessions: [domainSession(1)],
        items: [domainItem(sessionId: 1, exerciseId: 10, position: 0)],
        exercises: [domainExercise(10)],
      );
      final detail = buildSessionDetail(1, snap);
      expect(detail.items[0].exercise.id, 10);
    });
  });
}
