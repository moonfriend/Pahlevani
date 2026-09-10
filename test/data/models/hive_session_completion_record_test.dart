import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_type.dart';

void main() {
  group('HiveSessionCompletionRecord', () {
    test('round-trips a record with movement counts through fromDomain/toDomain', () {
      final original = SessionCompletionRecord(
        id: 'session-1-1000',
        sessionId: 1,
        sessionTitle: 'Beginner Warm-up',
        completedAt: DateTime(2026, 9, 10, 12, 30),
        movementCounts: const {
          TrackedMovementType.shenoSarnavazi: 12,
          TrackedMovementType.meelAram: 4,
        },
      );

      final restored =
          HiveSessionCompletionRecord.fromDomain(original).toDomain();

      expect(restored, original);
    });

    test('round-trips a record with no tracked movements', () {
      final original = SessionCompletionRecord(
        id: 'session-2-2000',
        sessionId: 2,
        sessionTitle: 'Advanced Drill',
        completedAt: DateTime(2026, 9, 11),
        movementCounts: const {},
      );

      final restored =
          HiveSessionCompletionRecord.fromDomain(original).toDomain();

      expect(restored, original);
    });

    test('toDomain drops an unrecognized stored key rather than throwing', () {
      final hive = HiveSessionCompletionRecord(
        id: 'session-3-3000',
        sessionId: 3,
        sessionTitle: 'Old Session',
        completedAtMillis: DateTime(2026, 9, 1).millisecondsSinceEpoch,
        movementCounts: const {'retired_type': 7, 'sheno_sarnavazi': 3},
      );

      final domain = hive.toDomain();

      expect(domain.movementCounts[TrackedMovementType.shenoSarnavazi], 3);
      expect(domain.movementCounts.length, 1);
    });
  });
}
