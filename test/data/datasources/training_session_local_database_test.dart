import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_database.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

// Registers each adapter exactly once per process (Hive throws if you register
// the same typeId twice).
bool _adaptersRegistered = false;
void _ensureAdapters() {
  if (_adaptersRegistered) return;
  _adaptersRegistered = true;
  Hive
    ..registerAdapter(HiveTrainingSessionAdapter())
    ..registerAdapter(HiveExerciseAdapter())
    ..registerAdapter(HiveTrainingSessionItemAdapter());
}

void main() {
  late Directory tmpDir;
  late TrainingSessionLocalDatabase db;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('pahlevani_hive_test_');
    Hive.init(tmpDir.path);
    _ensureAdapters();
    db = TrainingSessionLocalDatabase();
  });

  tearDown(() async {
    await Hive.close();
    if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
  });

  // ── Training sessions ──────────────────────────────────────────────────────

  group('saveTrainingSessions / getTrainingSessions', () {
    test('returns empty list when nothing is saved', () async {
      expect(await db.getTrainingSessions(), isEmpty);
    });

    test('round-trips a server session', () async {
      final s = TrainingSession(
          id: 1, title: 'Shena Warm-up', description: 'Basics', difficulty: 1);
      await db.saveTrainingSessions([s]);

      final result = await db.getTrainingSessions();
      expect(result, hasLength(1));
      expect(result.first.id, 1);
      expect(result.first.title, 'Shena Warm-up');
    });

    test('upserts updated session by id', () async {
      final original = TrainingSession(
          id: 1, title: 'Old Title', description: '', difficulty: 1);
      await db.saveTrainingSessions([original]);

      final updated = TrainingSession(
          id: 1, title: 'New Title', description: '', difficulty: 2);
      await db.saveTrainingSessions([updated]);

      final result = await db.getTrainingSessions();
      expect(result, hasLength(1));
      expect(result.first.title, 'New Title');
    });

    test('removes server sessions absent from the new list', () async {
      final s1 =
          TrainingSession(id: 1, title: 'A', description: '', difficulty: 1);
      final s2 =
          TrainingSession(id: 2, title: 'B', description: '', difficulty: 1);
      await db.saveTrainingSessions([s1, s2]);

      // Server no longer sends session 2.
      await db.saveTrainingSessions([s1]);

      final result = await db.getTrainingSessions();
      expect(result.map((s) => s.id).toList(), [1]);
    });

    test('never removes user-created sessions', () async {
      final server = TrainingSession(
          id: 1, title: 'Server', description: '', difficulty: 1);
      final user = TrainingSession(
          id: 2,
          title: 'My Session',
          description: '',
          difficulty: 1,
          isUserCreated: true);
      // Save user-created session directly via box
      final box = await db.getTrainingSessionBox();
      await box.add(HiveTrainingSession.fromDomain(user));

      await db.saveTrainingSessions([server]);

      final result = await db.getTrainingSessions();
      final ids = result.map((s) => s.id).toSet();
      expect(ids, containsAll([1, 2]));
    });
  });

  // ── Exercises (tracks) ─────────────────────────────────────────────────────

  group('saveExercises / getTracks', () {
    test('returns empty list when nothing is saved', () async {
      expect(await db.getTracks(), isEmpty);
    });

    test('round-trips a list of exercises', () async {
      final exercises = [
        HiveExercise(
            id: 101,
            name: 'Shena',
            url: 'https://ex.com/s.mp3',
            repetitions: 3),
        HiveExercise(
            id: 102,
            name: 'Kabbadeh',
            url: 'https://ex.com/k.mp3',
            repetitions: 1),
      ];
      await db.saveExercises(exercises);

      final result = await db.getTracks();
      expect(result, hasLength(2));
      expect(result.map((e) => e.id).toSet(), {101, 102});
    });

    test('clear-and-replace on second save', () async {
      await db.saveExercises([
        HiveExercise(id: 1, name: 'Old'),
      ]);
      await db.saveExercises([
        HiveExercise(id: 2, name: 'New'),
      ]);

      final result = await db.getTracks();
      expect(result, hasLength(1));
      expect(result.first.id, 2);
    });
  });

  // ── Training session items ─────────────────────────────────────────────────

  group('saveTrainingSessionItems / getTrainingSessionItems', () {
    test('returns empty list when nothing is saved', () async {
      expect(await db.getTrainingSessionItems(), isEmpty);
    });

    test('round-trips items', () async {
      final items = [
        HiveTrainingSessionItem(
            trainingSessionId: 1, itemId: 101, position: 1, repsToDo: 3),
        HiveTrainingSessionItem(
            trainingSessionId: 1, itemId: 102, position: 2, repsToDo: 1),
      ];
      await db.saveTrainingSessionItems(items);

      final result = await db.getTrainingSessionItems();
      expect(result, hasLength(2));
    });

    test('replaces server session items when serverSessionIds provided',
        () async {
      final existing = HiveTrainingSessionItem(
          trainingSessionId: 1, itemId: 101, position: 1, repsToDo: 1);
      await db.saveTrainingSessionItems([existing]);

      final newItem = HiveTrainingSessionItem(
          trainingSessionId: 1, itemId: 202, position: 1, repsToDo: 2);
      await db.saveTrainingSessionItems([newItem], serverSessionIds: {1});

      final result = await db.getTrainingSessionItems();
      expect(result, hasLength(1));
      expect(result.first.itemId, 202);
    });

    test('preserves user-session items when replacing server items', () async {
      final serverItem = HiveTrainingSessionItem(
          trainingSessionId: 1, itemId: 101, position: 1, repsToDo: 1);
      final userItem = HiveTrainingSessionItem(
          trainingSessionId: 2, itemId: 200, position: 1, repsToDo: 3);
      await db.saveTrainingSessionItems([serverItem, userItem]);

      // Replace only server session 1.
      final updatedServerItem = HiveTrainingSessionItem(
          trainingSessionId: 1, itemId: 999, position: 1, repsToDo: 5);
      await db
          .saveTrainingSessionItems([updatedServerItem], serverSessionIds: {1});

      final result = await db.getTrainingSessionItems();
      expect(result, hasLength(2));
      expect(result.map((i) => i.trainingSessionId).toSet(), {1, 2});
    });
  });

  // ── Sync time ──────────────────────────────────────────────────────────────

  group('getLastSyncTime / isDataStale', () {
    test('getLastSyncTime returns null before first save', () async {
      expect(await db.getLastSyncTime(), isNull);
    });

    test('isDataStale returns true when no sync has happened', () async {
      expect(await db.isDataStale(), isTrue);
    });

    test('saveTrainingSessions records sync time', () async {
      await db.saveTrainingSessions([]);
      expect(await db.getLastSyncTime(), isNotNull);
    });

    test('isDataStale returns false after a fresh save', () async {
      await db.saveTrainingSessions([]);
      expect(await db.isDataStale(), isFalse);
    });
  });

  // ── clearAll ──────────────────────────────────────────────────────────────

  group('clearAll', () {
    test('empties all boxes', () async {
      final s =
          TrainingSession(id: 1, title: 'Test', description: '', difficulty: 1);
      await db.saveTrainingSessions([s]);
      await db.saveExercises([
        HiveExercise(id: 1, name: 'Ex'),
      ]);

      await db.clearAll();

      expect(await db.getTrainingSessions(), isEmpty);
      expect(await db.getTracks(), isEmpty);
      expect(await db.getTrainingSessionItems(), isEmpty);
      expect(await db.getLastSyncTime(), isNull);
    });
  });
}
