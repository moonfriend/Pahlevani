import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

void main() {
  // ── HiveTrainingSession ───────────────────────────────────────────────────

  group('HiveTrainingSession', () {
    test('fromDomain → toDomain round-trips all fields', () {
      final session = TrainingSession(
        id: 42,
        title: 'Test Session',
        titleFa: 'جلسه آزمایش',
        description: 'A description',
        difficulty: 3,
        createdAt: DateTime(2024, 1, 15, 10, 30),
        isUserCreated: true,
        assignedToUserId: 'user-123',
        assignedByTrainerId: 'trainer-456',
      );

      final hive = HiveTrainingSession.fromDomain(session);
      final result = hive.toDomain();

      expect(result.id, session.id);
      expect(result.title, session.title);
      expect(result.titleFa, session.titleFa);
      expect(result.description, session.description);
      expect(result.difficulty, session.difficulty);
      expect(result.createdAt, session.createdAt);
      expect(result.isUserCreated, session.isUserCreated);
      expect(result.assignedToUserId, session.assignedToUserId);
      expect(result.assignedByTrainerId, session.assignedByTrainerId);
    });

    test('fromDomain with null optional fields', () {
      final session = TrainingSession(
        id: 1,
        title: 'Minimal',
        description: '',
        difficulty: 1,
      );
      final result = HiveTrainingSession.fromDomain(session).toDomain();
      expect(result.titleFa, isNull);
      expect(result.createdAt, isNull);
      expect(result.assignedToUserId, isNull);
      expect(result.assignedByTrainerId, isNull);
      expect(result.isUserCreated, isFalse);
    });

    test('fromJson → toJson round-trip preserves all fields', () {
      final map = {
        'id': 10,
        'title': 'Shena session',
        'description': 'Push-up session',
        'difficulty': 4,
        'created_at': '2024-06-01T08:00:00.000',
        'is_user_created': false,
        'title_fa': 'ضرب',
        'assigned_to_user_id': 'u1',
        'assigned_by_trainer_id': 't1',
      };

      final hive = HiveTrainingSession.fromJson(map);
      final result = hive.toJson();

      expect(result['id'], 10);
      expect(result['title'], 'Shena session');
      expect(result['description'], 'Push-up session');
      expect(result['difficulty'], 4);
      expect(result['created_at'], '2024-06-01T08:00:00.000');
      expect(result['is_user_created'], false);
      expect(result['title_fa'], 'ضرب');
      expect(result['assigned_to_user_id'], 'u1');
      expect(result['assigned_by_trainer_id'], 't1');
    });

    test('fromJson with null created_at and optional fields', () {
      final map = {
        'id': 5,
        'title': 'No date',
        'description': '',
        'difficulty': 2,
        'created_at': null,
        'is_user_created': true,
      };
      final hive = HiveTrainingSession.fromJson(map);
      expect(hive.createdAt, isNull);
      expect(hive.titleFa, isNull);
      expect(hive.assignedToUserId, isNull);
      // toJson omits null optionals
      final json = hive.toJson();
      expect(json.containsKey('title_fa'), isFalse);
      expect(json.containsKey('assigned_to_user_id'), isFalse);
      expect(json.containsKey('created_at'), isFalse);
    });
  });

  // ── HiveExercise ──────────────────────────────────────────────────────────

  group('HiveExercise', () {
    test('fromDomain → toDomain round-trips all fields', () {
      const exercise = Exercise(
        id: 7,
        movementId: 3,
        name: 'Shena',
        titleFa: 'شنا',
        gloss: 'Push-up',
        author: 'Morshed Ali',
        type: 'reps',
        audioFileUrl: 'https://cdn.example.com/shena.mp3',
        repetitionsDefault: 10,
        durationSeconds: 45,
        media:
            ExerciseMedia(type: 'photo', src: 'img.jpg', poster: 'poster.jpg'),
      );

      final hive = HiveExercise.fromDomain(exercise);
      final result = hive.toDomain();

      expect(result.id, exercise.id);
      expect(result.movementId, exercise.movementId);
      expect(result.name, exercise.name);
      expect(result.titleFa, exercise.titleFa);
      expect(result.gloss, exercise.gloss);
      expect(result.author, exercise.author);
      expect(result.type, exercise.type);
      expect(result.audioFileUrl, exercise.audioFileUrl);
      expect(result.repetitionsDefault, exercise.repetitionsDefault);
      expect(result.durationSeconds, exercise.durationSeconds);
      expect(result.media.type, exercise.media.type);
      expect(result.media.src, exercise.media.src);
      expect(result.media.poster, exercise.media.poster);
    });

    test('null repetitions defaults to 1 in toDomain', () {
      final hive = HiveExercise(id: 1, name: 'Test', repetitions: null);
      expect(hive.toDomain().repetitionsDefault, 1);
    });

    test('null mediaType defaults to "none" in toDomain', () {
      final hive = HiveExercise(id: 1, name: 'Test', mediaType: null);
      expect(hive.toDomain().media.type, 'none');
    });

    test('fromDomain with null audioFileUrl preserved as null', () {
      const exercise = Exercise(
        id: 2,
        name: 'No audio',
        repetitionsDefault: 5,
        media: ExerciseMedia(type: 'none'),
      );
      final result = HiveExercise.fromDomain(exercise).toDomain();
      expect(result.audioFileUrl, isNull);
    });
  });

  // ── HiveTrainingSessionItem ───────────────────────────────────────────────

  group('HiveTrainingSessionItem', () {
    test('fromJson → toJson round-trip', () {
      final map = {
        'training_session_id': 1,
        'exercise_id': 5,
        'position': 2,
        'reps_to_do': 3,
      };
      final hive = HiveTrainingSessionItem.fromJson(map);
      final result = hive.toJson();

      expect(result['training_session_id'], 1);
      expect(result['exercise_id'], 5);
      expect(result['position'], 2);
      expect(result['reps_to_do'], 3);
    });

    test('fields match constructor args', () {
      final item = HiveTrainingSessionItem(
        trainingSessionId: 10,
        itemId: 20,
        position: 3,
        repsToDo: 5,
      );
      expect(item.trainingSessionId, 10);
      expect(item.itemId, 20);
      expect(item.position, 3);
      expect(item.repsToDo, 5);
    });
  });
}
