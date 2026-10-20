import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/movement_info_row.dart';
import 'package:pahlevani/domain/entities/training_session/move_variation.dart';

void main() {
  group('MovementInfoRow.fromJson — learning content (migration 0042)', () {
    test('parses cues, steps and variations', () {
      final row = MovementInfoRow.fromJson({
        'movement_id': 7,
        'cues': ['Back straight', 'Breathe out on the push', 'Elbows in'],
        'steps': ['Hands under shoulders', 'Lower slowly'],
        'variations': [
          {'name': 'Knee shena', 'level': 'EASIER', 'reps': 12},
          {'name': 'Shena', 'level': 'STANDARD', 'reps': 20},
        ],
      });

      expect(
          row.cues, ['Back straight', 'Breathe out on the push', 'Elbows in']);
      expect(row.steps, ['Hands under shoulders', 'Lower slowly']);
      expect(row.variations, const [
        MoveVariation(name: 'Knee shena', level: 'EASIER', reps: 12),
        MoveVariation(name: 'Shena', level: 'STANDARD', reps: 20),
      ]);
    });

    test('a row from before 0042 (columns absent) gives empty lists', () {
      final row = MovementInfoRow.fromJson({'movement_id': 7});
      expect(row.cues, isEmpty);
      expect(row.steps, isEmpty);
      expect(row.variations, isEmpty);
    });

    test('null columns give empty lists', () {
      final row = MovementInfoRow.fromJson(
          {'movement_id': 7, 'cues': null, 'steps': null, 'variations': null});
      expect(row.cues, isEmpty);
      expect(row.steps, isEmpty);
      expect(row.variations, isEmpty);
    });

    test('blank and non-string entries are dropped', () {
      final row = MovementInfoRow.fromJson({
        'movement_id': 7,
        'cues': ['  ', 'Keep the rhythm', 3, null],
        'steps': ['', 'One'],
      });
      expect(row.cues, ['Keep the rhythm']);
      expect(row.steps, ['One']);
    });

    test('malformed variations are skipped, not thrown', () {
      final row = MovementInfoRow.fromJson({
        'movement_id': 7,
        'variations': [
          'not a map',
          {'level': 'NO NAME'},
          {'name': 'Ok', 'reps': 'ten'},
          {'name': 'Full', 'level': 'HARDER', 'reps': 30.0},
        ],
      });
      expect(row.variations, const [
        MoveVariation(name: 'Ok'),
        MoveVariation(name: 'Full', level: 'HARDER', reps: 30),
      ]);
    });

    test('a variations value that is not a list gives an empty list', () {
      final row = MovementInfoRow.fromJson({
        'movement_id': 7,
        'variations': {'name': 'x'},
        'cues': 'x'
      });
      expect(row.variations, isEmpty);
      expect(row.cues, isEmpty);
    });
  });
}
