import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/training_item_row.dart';

void main() {
  group('TrainingItemRow.fromMap', () {
    test('parses full map', () {
      final row = TrainingItemRow.fromJson({
        'training_session_id': 10,
        'exercise_id': 2001,
        'position': 3,
        'reps_to_do': 12,
      });

      expect(row.trainingSessionId, 10);
      expect(row.exerciseId, 2001);
      expect(row.position, 3);
      expect(row.repsToDo, 12);
    });

    test('casts numeric types (double → int) and defaults reps_to_do to 1', () {
      final row = TrainingItemRow.fromJson({
        'training_session_id': 10.0,
        'exercise_id': 2001.0,
        'position': 3.9,
        // reps_to_do missing → default
      });

      expect(row.trainingSessionId, 10);
      expect(row.exerciseId, 2001);
      expect(row.position, 3);
      expect(row.repsToDo, 1);
    });

    test('throws if required numerics are missing or not numeric', () {
      expect(
            () => TrainingItemRow.fromJson({'exercise_id': 1, 'position': 0}),
        throwsA(isA<TypeError>()), // missing training_session_id
      );
      expect(
            () => TrainingItemRow.fromJson({'training_session_id': 's', 'exercise_id': 1, 'position': 0}),
        throwsA(isA<TypeError>()),
      );
      expect(
            () => TrainingItemRow.fromJson({'training_session_id': 1, 'exercise_id': 'x', 'position': 0}),
        throwsA(isA<TypeError>()),
      );
      expect(
            () => TrainingItemRow.fromJson({'training_session_id': 1, 'exercise_id': 1, 'position': 'p'}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}