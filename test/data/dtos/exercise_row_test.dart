import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/exercise_row.dart';

void main() {
  group('ExerciseRow.fromMap', () {
    test('parses full map', () {
      final row = ExerciseRow.fromJson({
        'id': 123, // int
        'name': 'Push Ups',
        'author': 'Coach A',
        'type': 'bodyweight',
        'url': 'https://example.com/pushups',
        'repetitions': 10,
      });

      expect(row.id, 123);
      expect(row.name, 'Push Ups');
      expect(row.author, 'Coach A');
      expect(row.type, 'bodyweight');
      expect(row.url, 'https://example.com/pushups');
      expect(row.repetitions, 10);
    });

    test('casts numeric types (double → int)', () {
      final row = ExerciseRow.fromJson({
        'id': 123.0, // double
        'repetitions': 7.9, // double → int
      });

      expect(row.id, 123);
      expect(row.repetitions, 7); // toInt truncates
    });

    test('defaults repetitions to 0 when null/absent', () {
      //convention: repetition=0 means loop it until user commands
      final row = ExerciseRow.fromJson({
        'id': 1,
        'name': null,
        'repetitions': null, // explicit null
      });
      expect(row.repetitions, 0);

      final row2 = ExerciseRow.fromJson({
        'id': 2,
        // repetitions missing
      });
      expect(row2.repetitions, 0);
    });

    test('allows nullable text fields', () {
      final row = ExerciseRow.fromJson({
        'id': 1,
        'name': null,
        'author': null,
        'type': null,
        'url': null,
        'repetitions': 3,
      });
      expect(row.name, isNull);
      expect(row.author, isNull);
      expect(row.type, isNull);
      expect(row.url, isNull);
    });

    test('throws if id is missing or not numeric', () {
      expect(
        () => ExerciseRow.fromJson({'repetitions': 5}),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => ExerciseRow.fromJson({'id': 'abc', 'repetitions': 5}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
