import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/exercise_row.dart';
import 'package:pahlevani/data/dtos/movement_row.dart';
import 'package:pahlevani/data/dtos/training_item_row.dart';
import 'package:pahlevani/data/dtos/training_session_row.dart';
import 'package:pahlevani/data/mappers/row_to_domain.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';

void main() {
  // ---------- mapExercise ----------

  group('mapExercise', () {
    ExerciseRow baseRow({
      int id = 1,
      int? movementId,
      String? name,
      String? author,
      String? url,
      int repetitions = 3,
      String? mediaType,
      String? mediaSrc,
      String? mediaPoster,
    }) =>
        ExerciseRow(
          id: id,
          movementId: movementId,
          name: name,
          author: author,
          url: url,
          repetitions: repetitions,
          mediaType: mediaType,
          mediaSrc: mediaSrc,
          mediaPoster: mediaPoster,
        );

    MovementRow baseMovement({
      int id = 10,
      String name = 'Movement Name',
      String? titleFa,
      String? gloss,
      String? type,
      String mediaType = 'photo',
      String? mediaSrc,
      String? mediaPoster,
    }) =>
        MovementRow(
          id: id,
          name: name,
          titleFa: titleFa,
          gloss: gloss,
          type: type,
          mediaType: mediaType,
          mediaSrc: mediaSrc,
          mediaPoster: mediaPoster,
        );

    test('uses movement name when movement is present', () {
      final ex = mapExercise(
        baseRow(name: 'Row Name'),
        movement: baseMovement(name: 'Movement Name'),
      );
      expect(ex.name, 'Movement Name');
    });

    test('falls back to row name when no movement', () {
      final ex = mapExercise(baseRow(name: 'Row Name'));
      expect(ex.name, 'Row Name');
    });

    test('falls back to Exercise {id} when both names are null', () {
      final ex = mapExercise(baseRow(id: 7, name: null));
      expect(ex.name, 'Exercise 7');
    });

    test('maps id, author, audioFileUrl, repetitionsDefault from row', () {
      final ex = mapExercise(
        baseRow(
            id: 42,
            author: 'Morshed Ali',
            url: 'https://audio.mp3',
            repetitions: 5),
      );
      expect(ex.id, 42);
      expect(ex.author, 'Morshed Ali');
      expect(ex.audioFileUrl, 'https://audio.mp3');
      expect(ex.repetitionsDefault, 5);
    });

    test('media type comes from movement when movement present', () {
      final ex = mapExercise(
        baseRow(mediaType: 'video'),
        movement: baseMovement(mediaType: 'photo'),
      );
      expect(ex.media.type, 'photo');
    });

    test('media type falls back to row when no movement', () {
      final ex = mapExercise(baseRow(mediaType: 'video'));
      expect(ex.media.type, 'video');
    });

    test('media type defaults to none when both row and movement have null',
        () {
      final ex = mapExercise(baseRow(mediaType: null));
      expect(ex.media.type, 'none');
    });

    test('media src comes from movement when present', () {
      final ex = mapExercise(
        baseRow(mediaSrc: 'row-src.jpg'),
        movement: baseMovement(mediaSrc: 'movement-src.jpg'),
      );
      expect(ex.media.src, 'movement-src.jpg');
    });

    test('media src falls back to row when no movement', () {
      final ex = mapExercise(baseRow(mediaSrc: 'row-src.jpg'));
      expect(ex.media.src, 'row-src.jpg');
    });

    test('movementId is set from row when present', () {
      final ex = mapExercise(baseRow(movementId: 99));
      expect(ex.movementId, 99);
    });

    test('movementId falls back to movement.id when row.movementId is null',
        () {
      final ex = mapExercise(
        baseRow(movementId: null),
        movement: baseMovement(id: 55),
      );
      expect(ex.movementId, 55);
    });
  });

  // ---------- mapSession ----------

  group('mapSession', () {
    TrainingSessionRow row({
      int id = 1,
      String? title,
      String? description,
      int? difficulty,
      DateTime? createdAt,
    }) =>
        TrainingSessionRow(
          id: id,
          title: title,
          description: description,
          difficulty: difficulty,
          createdAt: createdAt,
        );

    test('maps id, title, description, difficulty', () {
      final s = mapSession(
          row(id: 5, title: 'My Session', description: 'Desc', difficulty: 3));
      expect(s.id, 5);
      expect(s.title, 'My Session');
      expect(s.description, 'Desc');
      expect(s.difficulty, 3);
    });

    test('defaults title to Sample Session when null', () {
      final s = mapSession(row(title: null));
      expect(s.title, 'Sample Session');
    });

    test('defaults description to Description when null', () {
      final s = mapSession(row(description: null));
      expect(s.description, 'Description');
    });

    test('defaults difficulty to 5 when null', () {
      final s = mapSession(row(difficulty: null));
      expect(s.difficulty, 5);
    });

    test('preserves createdAt', () {
      final dt = DateTime(2024, 1, 15);
      final s = mapSession(row(createdAt: dt));
      expect(s.createdAt, dt);
    });

    test('maps assignedToUserId and assignedByTrainerId when present', () {
      final s = mapSession(TrainingSessionRow(
        id: 1,
        assignedToUserId: 'trainee-uuid',
        assignedByTrainerId: 'trainer-uuid',
      ));
      expect(s.assignedToUserId, 'trainee-uuid');
      expect(s.assignedByTrainerId, 'trainer-uuid');
      expect(s.isIndividualized, isTrue);
    });

    test('isIndividualized is false for an original (unassigned) session', () {
      final s = mapSession(row());
      expect(s.assignedToUserId, isNull);
      expect(s.isIndividualized, isFalse);
    });
  });

  // ---------- mapItem ----------

  group('mapItem', () {
    TrainingItemRow item({
      int sessionId = 1,
      int exerciseId = 10,
      int position = 0,
      int repsToDo = 3,
    }) =>
        TrainingItemRow(
          trainingSessionId: sessionId,
          exerciseId: exerciseId,
          position: position,
          repsToDo: repsToDo,
        );

    test('composes id as sessionId * 10000 + position', () {
      final it = mapItem(item(sessionId: 3, position: 5));
      expect(it.id, 3 * 10000 + 5);
    });

    test('id is unique across sessions for same position', () {
      final a = mapItem(item(sessionId: 1, position: 0));
      final b = mapItem(item(sessionId: 2, position: 0));
      expect(a.id, isNot(b.id));
    });

    test('id is unique within session for different positions', () {
      final a = mapItem(item(sessionId: 1, position: 0));
      final b = mapItem(item(sessionId: 1, position: 1));
      expect(a.id, isNot(b.id));
    });

    test('maps sessionId, exerciseId, position', () {
      final it = mapItem(item(sessionId: 7, exerciseId: 42, position: 3));
      expect(it.sessionId, 7);
      expect(it.exerciseId, 42);
      expect(it.position, 3);
    });

    test('prescription is RepsPresc with repsToDo count', () {
      final it = mapItem(item(repsToDo: 8));
      expect(it.prescription, isA<RepsPresc>());
      expect((it.prescription as RepsPresc).count, 8);
    });

    test('position 0 produces valid id (not sessionId)', () {
      final it = mapItem(item(sessionId: 2, position: 0));
      expect(it.id, 20000);
      expect(it.id, isNot(it.sessionId));
    });
  });
}
