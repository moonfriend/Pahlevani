import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/tracking/movement_key.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_count.dart';
import 'package:pahlevani/domain/usecases/tracking/detect_tracked_movements.dart';

const _shenoA = Exercise(
    id: 1, movementId: 10, name: 'Shena (Narrator A)', repetitionsDefault: 1);
const _shenoB = Exercise(
    id: 2, movementId: 10, name: 'Shena (Narrator B)', repetitionsDefault: 1);
const _meel = Exercise(
    id: 3, movementId: 20, name: 'Meel', titleFa: 'میل', repetitionsDefault: 1);
const _legacyNoMovement =
    Exercise(id: 4, name: 'Legacy Exercise', repetitionsDefault: 1);

ItemDetail _detail({
  required int position,
  required int reps,
  required Exercise exercise,
  bool isTracked = false,
}) =>
    ItemDetail(
      item: TrainingItem(
        id: position,
        sessionId: 1,
        exerciseId: exercise.id,
        position: position,
        prescription: RepsPresc(reps),
        isTracked: isTracked,
      ),
      exercise: exercise,
    );

void main() {
  group('detectTrackedMovements', () {
    test('returns an empty list when no items are tracked', () {
      final items = [_detail(position: 1, reps: 3, exercise: _shenoA)];
      expect(detectTrackedMovements(items), isEmpty);
    });

    test('sums programmed reps per movement, pooling different recordings', () {
      final items = [
        _detail(position: 1, reps: 3, exercise: _shenoA, isTracked: true),
        _detail(position: 2, reps: 5, exercise: _shenoB, isTracked: true),
        _detail(position: 3, reps: 2, exercise: _meel, isTracked: true),
        _detail(position: 4, reps: 1, exercise: _shenoA), // untracked
      ];

      final result = detectTrackedMovements(items);

      final sheno = result.firstWhere((e) => e.key == MovementKey.of(_shenoA));
      final meel = result.firstWhere((e) => e.key == MovementKey.of(_meel));
      expect(sheno.count, 8);
      expect(meel.count, 2);
      expect(result.length, 2);
    });

    test('display name comes from the exercise (titleFa preferred)', () {
      final items = [
        _detail(position: 1, reps: 4, exercise: _meel, isTracked: true),
      ];
      final result = detectTrackedMovements(items);
      expect(result.single.displayName, 'میل');
    });

    test('falls back to exercise id when the exercise has no movement link',
        () {
      final items = [
        _detail(
            position: 1, reps: 4, exercise: _legacyNoMovement, isTracked: true),
      ];
      final result = detectTrackedMovements(items);
      expect(result.single.key, MovementKey.of(_legacyNoMovement));
      expect(result.single.displayName, 'Legacy Exercise');
    });
  });

  group('countLoggedMovements', () {
    test('turns logged reps into counts, by move index', () {
      final items = [
        _detail(position: 0, reps: 3, exercise: _meel, isTracked: true),
        _detail(position: 1, reps: 5, exercise: _legacyNoMovement),
      ];
      expect(countLoggedMovements(items, {0: 7}), [
        TrackedMovementCount(
            key: MovementKey.of(_meel), displayName: 'میل', count: 7),
      ]);
    });

    test('pools moves of the same movement, in first-seen order', () {
      final items = [
        _detail(position: 0, reps: 3, exercise: _shenoA, isTracked: true),
        _detail(position: 1, reps: 3, exercise: _meel, isTracked: true),
        _detail(position: 2, reps: 3, exercise: _shenoB, isTracked: true),
      ];
      final counts = countLoggedMovements(items, {0: 10, 1: 4, 2: 12});
      expect(counts.map((c) => (c.key, c.count)), [
        (MovementKey.of(_shenoA), 22),
        (MovementKey.of(_meel), 4),
      ]);
    });

    test('skipped moves and out-of-range indexes are left out', () {
      final items = [
        _detail(position: 0, reps: 3, exercise: _meel, isTracked: true),
      ];
      expect(countLoggedMovements(items, {}), isEmpty);
      expect(countLoggedMovements(items, {5: 3}), isEmpty);
    });
  });
}
