import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_type.dart';
import 'package:pahlevani/domain/usecases/tracking/training_history_aggregations.dart';

SessionCompletionRecord _record({
  required String id,
  required DateTime completedAt,
  Map<TrackedMovementType, int> counts = const {},
}) =>
    SessionCompletionRecord(
      id: id,
      sessionId: 1,
      sessionTitle: 'Session',
      completedAt: completedAt,
      movementCounts: counts,
    );

void main() {
  group('groupCompletionsByDay', () {
    test('groups multiple sessions on the same calendar day, drops time', () {
      final records = [
        _record(id: 'a', completedAt: DateTime(2026, 9, 10, 8, 0)),
        _record(id: 'b', completedAt: DateTime(2026, 9, 10, 20, 15)),
        _record(id: 'c', completedAt: DateTime(2026, 9, 11, 8, 0)),
      ];

      final grouped = groupCompletionsByDay(records);

      expect(grouped[DateTime(2026, 9, 10)]?.length, 2);
      expect(grouped[DateTime(2026, 9, 11)]?.length, 1);
      expect(grouped.length, 2);
    });
  });

  group('totalMovementCounts', () {
    test('sums movement counts across all completions', () {
      final records = [
        _record(
          id: 'a',
          completedAt: DateTime(2026, 9, 1),
          counts: {TrackedMovementType.shenoSarnavazi: 10},
        ),
        _record(
          id: 'b',
          completedAt: DateTime(2026, 9, 2),
          counts: {
            TrackedMovementType.shenoSarnavazi: 5,
            TrackedMovementType.meelAram: 3,
          },
        ),
      ];

      final totals = totalMovementCounts(records);

      expect(totals[TrackedMovementType.shenoSarnavazi], 15);
      expect(totals[TrackedMovementType.meelAram], 3);
    });

    test('returns an empty map for no completions', () {
      expect(totalMovementCounts(const []), isEmpty);
    });
  });

  group('monthlyMovementCounts', () {
    test('buckets counts by calendar month per movement type', () {
      final records = [
        _record(
          id: 'a',
          completedAt: DateTime(2026, 8, 5),
          counts: {TrackedMovementType.shenoSarnavazi: 4},
        ),
        _record(
          id: 'b',
          completedAt: DateTime(2026, 8, 20),
          counts: {TrackedMovementType.shenoSarnavazi: 6},
        ),
        _record(
          id: 'c',
          completedAt: DateTime(2026, 9, 1),
          counts: {TrackedMovementType.shenoSarnavazi: 2},
        ),
      ];

      final byMonth = monthlyMovementCounts(records);
      final shenoByMonth = byMonth[TrackedMovementType.shenoSarnavazi]!;

      expect(shenoByMonth[DateTime(2026, 8)], 10);
      expect(shenoByMonth[DateTime(2026, 9)], 2);
    });
  });
}
