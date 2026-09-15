import 'package:pahlevani/domain/entities/training_session/prescription.dart';

class TrainingItem {
  final int id; // composed: sessionId * 10000 + position
  final int sessionId;
  final int exerciseId;
  final int position;
  final Prescription prescription;

  /// Set by the trainer when designing the session (admin.py's Session
  /// Builder) — a plain "count this item's reps toward movement history"
  /// toggle. Never authored inside the Flutter app.
  final bool isTracked;

  const TrainingItem({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.position,
    required this.prescription,
    this.isTracked = false,
  });
}
