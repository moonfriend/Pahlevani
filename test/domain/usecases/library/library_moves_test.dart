import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/usecases/library/library_moves.dart';

Exercise _ex(int id, String name,
        {int? movementId, String? description = 'How'}) =>
    Exercise(
        id: id, name: name, movementId: movementId, description: description);

void main() {
  test('one entry per movement, the lowest exercise id standing for it', () {
    final moves = libraryMoves([
      _ex(7, 'Shena', movementId: 4),
      _ex(3, 'Shena', movementId: 4),
      _ex(5, 'Vorod', movementId: 1),
    ]);
    expect(moves.map((e) => e.id), [3, 5]);
  });

  test('exercises without a movement are each their own move', () {
    final moves = libraryMoves([_ex(1, 'A'), _ex(2, 'B')]);
    expect(moves.map((e) => e.id), [1, 2]);
  });

  test('sorted by name, ignoring case', () {
    final moves = libraryMoves([
      _ex(1, 'vorod', movementId: 1),
      _ex(2, 'Charkh', movementId: 2),
      _ex(3, 'Meel', movementId: 3),
    ]);
    expect(moves.map((e) => e.name), ['Charkh', 'Meel', 'vorod']);
  });

  test('only moves with a video or explanation text', () {
    final moves = libraryMoves([
      _ex(1, 'Text', movementId: 1),
      _ex(2, 'Nothing', movementId: 2, description: null),
      const Exercise(
          id: 3,
          movementId: 3,
          name: 'Video',
          media: ExerciseMedia(type: 'video', src: 'https://x/v.mp4')),
      const Exercise(
          id: 4, movementId: 4, name: 'Edu', videoUrl: 'https://x/e.mp4'),
    ]);
    expect(moves.map((e) => e.name), ['Edu', 'Text', 'Video']);
  });

  test('moves with a learning video come first, then the rest, by name', () {
    final moves = libraryMoves([
      _ex(1, 'Charkh', movementId: 1),
      const Exercise(
          id: 2, movementId: 2, name: 'Vorod', videoUrl: 'https://x/v.mp4'),
      _ex(3, 'Anjam', movementId: 3),
      const Exercise(
          id: 4, movementId: 4, name: 'Meel', videoUrl: 'https://x/m.mp4'),
    ]);
    expect(moves.map((e) => e.name), ['Meel', 'Vorod', 'Anjam', 'Charkh']);
  });
}
