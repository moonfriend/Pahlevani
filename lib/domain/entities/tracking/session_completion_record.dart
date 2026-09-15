import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_count.dart';

/// One completed play-through of a training session — created right after
/// the player shows its completion screen. [movementCounts] only holds
/// entries for movements actually flagged (`TrainingItem.isTracked`) in
/// that session; most sessions will have an empty list.
class SessionCompletionRecord extends Equatable {
  final String id;
  final int sessionId;

  /// Snapshot of the session's title at completion time — the session
  /// itself may later be edited or deleted.
  final String sessionTitle;
  final DateTime completedAt;
  final List<TrackedMovementCount> movementCounts;

  const SessionCompletionRecord({
    required this.id,
    required this.sessionId,
    required this.sessionTitle,
    required this.completedAt,
    required this.movementCounts,
  });

  @override
  List<Object?> get props =>
      [id, sessionId, sessionTitle, completedAt, movementCounts];
}
