import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/tracking/movement_key.dart';

void main() {
  group('MovementKey.of', () {
    test('uses the movement id when the exercise has one', () {
      const exercise =
          Exercise(id: 1, movementId: 42, name: 'Shena', repetitionsDefault: 1);
      expect(MovementKey.of(exercise), MovementKey.fromValue('m:42'));
    });

    test('falls back to the exercise id when there is no movement link', () {
      const exercise = Exercise(
          id: 7, movementId: null, name: 'Shena', repetitionsDefault: 1);
      expect(MovementKey.of(exercise), MovementKey.fromValue('e:7'));
    });

    test('two exercises sharing a movement produce the same key', () {
      const a = Exercise(
          id: 1,
          movementId: 5,
          name: 'Shena (Narrator A)',
          repetitionsDefault: 1);
      const b = Exercise(
          id: 2,
          movementId: 5,
          name: 'Shena (Narrator B)',
          repetitionsDefault: 1);
      expect(MovementKey.of(a), MovementKey.of(b));
    });

    test('two exercises with different movements produce different keys', () {
      const a =
          Exercise(id: 1, movementId: 5, name: 'Shena', repetitionsDefault: 1);
      const b =
          Exercise(id: 2, movementId: 6, name: 'Meel', repetitionsDefault: 1);
      expect(MovementKey.of(a), isNot(MovementKey.of(b)));
    });
  });
}
