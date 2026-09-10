import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_type.dart';

class TrainingItem {
  final int id; // composed: sessionId * 10000 + position
  final int sessionId;
  final int exerciseId;
  final int position;
  final Prescription prescription;

  /// Set by the trainer when designing the session (admin.py's Session
  /// Builder) — null means this item isn't counted toward any movement
  /// total. Never authored inside the Flutter app.
  final TrackedMovementType? trackedMovementType;

  const TrainingItem({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.position,
    required this.prescription,
    this.trackedMovementType,
  });
}
