import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/entities/tracking/movement_key.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_count.dart';

void main() {
  group('HiveSessionCompletionRecord', () {
    test(
        'round-trips a record with movement counts through fromDomain/toDomain',
        () {
      final original = SessionCompletionRecord(
        id: 'session-1-1000',
        sessionId: 1,
        sessionTitle: 'Beginner Warm-up',
        completedAt: DateTime(2026, 9, 10, 12, 30),
        movementCounts: [
          TrackedMovementCount(
              key: MovementKey.fromValue('m:10'),
              displayName: 'Sheno Sarnavazi',
              count: 12),
          TrackedMovementCount(
              key: MovementKey.fromValue('m:20'),
              displayName: 'Meel Aram',
              count: 4),
        ],
      );

      final restored =
          HiveSessionCompletionRecord.fromDomain(original).toDomain();

      expect(restored.id, original.id);
      expect(restored.sessionId, original.sessionId);
      expect(restored.sessionTitle, original.sessionTitle);
      expect(restored.completedAt, original.completedAt);
      expect(
        {for (final c in restored.movementCounts) c.key: c},
        {for (final c in original.movementCounts) c.key: c},
      );
    });

    test('round-trips a record with no tracked movements', () {
      final original = SessionCompletionRecord(
        id: 'session-2-2000',
        sessionId: 2,
        sessionTitle: 'Advanced Drill',
        completedAt: DateTime(2026, 9, 11),
        movementCounts: const [],
      );

      final restored =
          HiveSessionCompletionRecord.fromDomain(original).toDomain();

      expect(restored, original);
    });

    test('toDomain falls back to the raw key as the name when unrecorded', () {
      final hive = HiveSessionCompletionRecord(
        id: 'session-3-3000',
        sessionId: 3,
        sessionTitle: 'Old Session',
        completedAtMillis: DateTime(2026, 9, 1).millisecondsSinceEpoch,
        movementCounts: const {'m:10': 3},
        movementNames: const {},
      );

      final domain = hive.toDomain();

      expect(domain.movementCounts.single.displayName, 'm:10');
      expect(domain.movementCounts.single.count, 3);
    });
  });
}
