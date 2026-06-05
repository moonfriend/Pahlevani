
class TrainingItemRow {
  final int trainingSessionId; // FK → training_session.id
  final int exerciseId;        // FK → exercise.id
  final int position;          // order within session
  final int repsToDo;          // integer NOT NULL DEFAULT 1

  TrainingItemRow({
    required this.trainingSessionId,
    required this.exerciseId,
    required this.position,
    required this.repsToDo,
  });

  factory TrainingItemRow.fromJson(Map<String, dynamic> json) => TrainingItemRow(
    trainingSessionId: (json['training_session_id'] as num).toInt(),
    exerciseId: (json['exercise_id'] as num).toInt(),
    position: (json['position'] as num).toInt(),
    repsToDo: (json['reps_to_do'] as num?)?.toInt() ?? 1,
  );
}