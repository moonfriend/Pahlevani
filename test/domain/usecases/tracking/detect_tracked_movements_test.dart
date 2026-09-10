import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_type.dart';
import 'package:pahlevani/domain/usecases/tracking/detect_tracked_movements.dart';

const _exercise = Exercise(id: 1, name: 'Shena', repetitionsDefault: 1);

ItemDetail _detail({
  required int position,
  required int reps,
  TrackedMovementType? type,
}) =>
    ItemDetail(
      item: TrainingItem(
        id: position,
        sessionId: 1,
        exerciseId: _exercise.id,
        position: position,
        prescription: RepsPresc(reps),
        trackedMovementType: type,
      ),
      exercise: _exercise,
    );

void main() {
  group('detectTrackedMovements', () {
    test('returns an empty map when no items are tracked', () {
      final items = [_detail(position: 1, reps: 3)];
      expect(detectTrackedMovements(items), isEmpty);
    });

    test('sums programmed reps per tracked type', () {
      final items = [
        _detail(
            position: 1, reps: 3, type: TrackedMovementType.shenoSarnavazi),
        _detail(
            position: 2, reps: 5, type: TrackedMovementType.shenoSarnavazi),
        _detail(position: 3, reps: 2, type: TrackedMovementType.meelAram),
        _detail(position: 4, reps: 1), // untracked, excluded
      ];

      final result = detectTrackedMovements(items);

      expect(result[TrackedMovementType.shenoSarnavazi], 8);
      expect(result[TrackedMovementType.meelAram], 2);
      expect(result.length, 2);
    });
  });
}
