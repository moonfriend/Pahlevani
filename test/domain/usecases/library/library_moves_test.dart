import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/usecases/library/library_moves.dart';

Exercise _ex(int id, String name, {int? movementId}) =>
    Exercise(id: id, name: name, movementId: movementId);

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
}
