import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/dtos/training_session_row.dart';

void main() {
  group('TrainingSessionRow.frdomJson', () {
    test('parses full map with valid created_at and explicit fields', () {
      final row = TrainingSessionRow.fromJson({
        'id': 42,
        'title': 'Morning Strength',
        'description': 'Upper body focus',
        'difficulty': 3,
        'created_at': '2024-01-02T10:15:30.000Z',
        'is_user_created': true,
      });

      expect(row.id, 42);
      expect(row.title, 'Morning Strength');
      expect(row.description, 'Upper body focus');
      expect(row.difficulty, 3);
      expect(row.createdAt, DateTime.parse('2024-01-02T10:15:30.000Z'));
      expect(row.isUserCreated, isTrue);
    });

    test('applies defaults when fields are null or absent', () {
      final row = TrainingSessionRow.fromJson({
        // id missing → default to 1
        'title': null, // → 'Unknown TrainingSession'
        // description missing → ''
        'difficulty': null, // → 1
        'created_at': null, // → null
        'is_user_created': null, // → false
      });

      expect(row.id, 1);
      expect(row.title, 'Unknown TrainingSession');
      expect(row.description, ''); // default
      expect(row.difficulty, 1); // default
      expect(row.createdAt, isNull); // tryParse not called / null
      expect(row.isUserCreated, isFalse); // default
    });

    test('invalid created_at string yields null (tryParse)', () {
      final row = TrainingSessionRow.fromJson({
        'id': 1,
        'created_at': 'not-a-date',
      });
      expect(row.createdAt, isNull);
    });

    test('non-string created_at is ignored (null result)', () {
      final row = TrainingSessionRow.fromJson({
        'id': 1,
        'created_at': 12345, // not a String → parser skipped
      });
      expect(row.createdAt, isNull);
    });

    test('strict casts: non-int id throws (e.g., double)', () {
      expect(
        () => TrainingSessionRow.fromJson({
          'id': 7.0, // double cannot be cast with "as int?"
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test('strict casts: non-int difficulty throws (e.g., double)', () {
      expect(
        () => TrainingSessionRow.fromJson({
          'id': 1,
          'difficulty': 2.5, // double cannot be cast with "as int?"
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test('strict casts: non-string title/description throw', () {
      expect(
        () => TrainingSessionRow.fromJson({
          'id': 1,
          'title': 123, // not a String?
        }),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => TrainingSessionRow.fromJson({
          'id': 1,
          'description': 999, // not a String?
        }),
        throwsA(isA<TypeError>()),
      );
    });

    test('is_user_created defaults to false; true respected when provided', () {
      final defFalse = TrainingSessionRow.fromJson({'id': 1});
      expect(defFalse.isUserCreated, isFalse);

      final userCreated =
          TrainingSessionRow.fromJson({'id': 1, 'is_user_created': true});
      expect(userCreated.isUserCreated, isTrue);
    });
  });
}
