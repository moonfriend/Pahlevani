import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_type.dart';

/// Sums the programmed reps of [items] grouped by [TrackedMovementType],
/// skipping items the trainer didn't flag. Used right after a session
/// finishes to compute the movement-count dialog's default values.
Map<TrackedMovementType, int> detectTrackedMovements(List<ItemDetail> items) {
  final counts = <TrackedMovementType, int>{};
  for (final detail in items) {
    final type = detail.item.trackedMovementType;
    if (type == null) continue;
    final reps = detail.item.prescription is RepsPresc
        ? (detail.item.prescription as RepsPresc).count
        : 1;
    counts[type] = (counts[type] ?? 0) + reps;
  }
  return counts;
}
