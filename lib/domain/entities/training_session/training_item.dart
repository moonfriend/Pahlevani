import 'package:pahlevani/domain/entities/training_session/prescription.dart';

class TrainingItem {
  final int id; // composed: sessionId * 10000 + position
  final int sessionId;
  final int exerciseId;
  final int position;
  final Prescription prescription;

  const TrainingItem({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.position,
    required this.prescription,
  });
}
