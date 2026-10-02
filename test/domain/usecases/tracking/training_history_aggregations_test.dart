import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/tracking/movement_key.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_count.dart';
import 'package:pahlevani/domain/usecases/tracking/training_history_aggregations.dart';

final _sheno = MovementKey.fromValue('m:10');
final _meel = MovementKey.fromValue('m:20');

SessionCompletionRecord _record({
  required String id,
  required DateTime completedAt,
  List<TrackedMovementCount> counts = const [],
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

  group('computeMovementStats', () {
    test('sums totals across completions, grouped by movement', () {
      final records = [
        _record(
          id: 'a',
          completedAt: DateTime(2026, 9, 1),
          counts: [
            TrackedMovementCount(key: _sheno, displayName: 'Sheno', count: 10)
          ],
        ),
        _record(
          id: 'b',
          completedAt: DateTime(2026, 9, 2),
          counts: [
            TrackedMovementCount(key: _sheno, displayName: 'Sheno', count: 5),
            TrackedMovementCount(key: _meel, displayName: 'Meel', count: 3),
          ],
        ),
      ];

      final stats = computeMovementStats(records);
      final sheno = stats.firstWhere((s) => s.key == _sheno);
      final meel = stats.firstWhere((s) => s.key == _meel);

      expect(sheno.total, 15);
      expect(meel.total, 3);
    });

    test('returns an empty list for no completions', () {
      expect(computeMovementStats(const []), isEmpty);
    });

    test('sorts by total descending', () {
      final records = [
        _record(
          id: 'a',
          completedAt: DateTime(2026, 9, 1),
          counts: [
            TrackedMovementCount(key: _meel, displayName: 'Meel', count: 3),
            TrackedMovementCount(key: _sheno, displayName: 'Sheno', count: 20),
          ],
        ),
      ];

      final stats = computeMovementStats(records);
      expect(stats.first.key, _sheno);
      expect(stats.last.key, _meel);
    });

    test('buckets counts by calendar month per movement', () {
      final records = [
        _record(
          id: 'a',
          completedAt: DateTime(2026, 8, 5),
          counts: [
            TrackedMovementCount(key: _sheno, displayName: 'Sheno', count: 4)
          ],
        ),
        _record(
          id: 'b',
          completedAt: DateTime(2026, 8, 20),
          counts: [
            TrackedMovementCount(key: _sheno, displayName: 'Sheno', count: 6)
          ],
        ),
        _record(
          id: 'c',
          completedAt: DateTime(2026, 9, 1),
          counts: [
            TrackedMovementCount(key: _sheno, displayName: 'Sheno', count: 2)
          ],
        ),
      ];

      final stats = computeMovementStats(records);
      final sheno = stats.firstWhere((s) => s.key == _sheno);

      expect(sheno.byMonth[DateTime(2026, 8)], 10);
      expect(sheno.byMonth[DateTime(2026, 9)], 2);
    });

    test('displayName reflects the most recently recorded name', () {
      final records = [
        _record(
          id: 'a',
          completedAt: DateTime(2026, 9, 1),
          counts: [
            TrackedMovementCount(key: _sheno, displayName: 'Old Name', count: 1)
          ],
        ),
        _record(
          id: 'b',
          completedAt: DateTime(2026, 9, 2),
          counts: [
            TrackedMovementCount(key: _sheno, displayName: 'New Name', count: 1)
          ],
        ),
      ];

      final stats = computeMovementStats(records);
      expect(stats.single.displayName, 'New Name');
    });
  });

  group('recentMovementCounts', () {
    TrackedMovementCount count(MovementKey key, String name, int n) =>
        TrackedMovementCount(key: key, displayName: name, count: n);

    test('per move: counts in completion order, latest last', () {
      final records = [
        // Deliberately out of order: the helper sorts by completedAt.
        _record(
            id: 'b',
            completedAt: DateTime(2026, 9, 12),
            counts: [count(_sheno, 'Shena', 38)]),
        _record(
            id: 'a',
            completedAt: DateTime(2026, 9, 10),
            counts: [count(_sheno, 'Shena', 34), count(_meel, 'Meel', 44)]),
        _record(
            id: 'c',
            completedAt: DateTime(2026, 9, 14),
            counts: [count(_sheno, 'Shena', 42)]),
      ];

      final trends = recentMovementCounts(records);
      final shena = trends.firstWhere((t) => t.key == _sheno);
      final meel = trends.firstWhere((t) => t.key == _meel);

      expect(shena.counts, [34, 38, 42]);
      expect(shena.latest, 42);
      expect(meel.counts, [44]);
    });

    test('keeps only the last [limit] counts', () {
      final records = [
        for (var day = 1; day <= 9; day++)
          _record(
              id: '$day',
              completedAt: DateTime(2026, 9, day),
              counts: [count(_sheno, 'Shena', day)]),
      ];

      expect(recentMovementCounts(records, limit: 6).single.counts,
          [4, 5, 6, 7, 8, 9]);
    });

    test('most recently logged move first; latest display name wins', () {
      final records = [
        _record(
            id: 'a',
            completedAt: DateTime(2026, 9, 1),
            counts: [count(_sheno, 'Sheno (old)', 30)]),
        _record(
            id: 'b',
            completedAt: DateTime(2026, 9, 2),
            counts: [count(_meel, 'Meel', 40)]),
        _record(
            id: 'c',
            completedAt: DateTime(2026, 9, 3),
            counts: [count(_sheno, 'Shena', 31)]),
      ];

      final trends = recentMovementCounts(records);
      expect(trends.map((t) => t.key), [_sheno, _meel]);
      expect(trends.first.displayName, 'Shena');
    });

    test('no records → no trends', () {
      expect(recentMovementCounts(const []), isEmpty);
    });
  });
}
