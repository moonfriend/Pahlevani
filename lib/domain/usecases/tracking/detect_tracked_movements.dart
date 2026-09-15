import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/tracking/movement_key.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_count.dart';

/// Sums the programmed reps of [items] flagged `isTracked`, grouped by the
/// underlying movement (so different recordings of the same movement pool
/// together — see [MovementKey]). Used right after a session finishes to
/// compute the movement-count dialog's default values.
List<TrackedMovementCount> detectTrackedMovements(List<ItemDetail> items) {
  final counts = <MovementKey, TrackedMovementCount>{};
  for (final detail in items) {
    if (!detail.item.isTracked) continue;
    final key = MovementKey.of(detail.exercise);
    final reps = detail.item.prescription is RepsPresc
        ? (detail.item.prescription as RepsPresc).count
        : 1;
    final displayName = detail.exercise.titleFa ?? detail.exercise.name;
    final existing = counts[key];
    counts[key] = existing == null
        ? TrackedMovementCount(key: key, displayName: displayName, count: reps)
        : existing.copyWith(count: existing.count + reps);
  }
  return counts.values.toList();
}
