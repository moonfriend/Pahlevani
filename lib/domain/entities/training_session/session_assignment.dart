/// One row of supabase/migrations/0014_session_assignment.sql's
/// session_assignments join table — a session assigned to one trainee. A
/// session can have any number of these; that's the whole point of the
/// join table over a single column on TrainingSession.
class SessionAssignment {
  final int id;
  final int sessionId;
  final String traineeUserId;
  final String? assignedByTrainerId;
  final DateTime assignedAt;

  /// Free-text context from the trainee — often empty, sometimes a full
  /// paragraph. Trainee-writable on their own assignment.
  final String? traineeNote;

  const SessionAssignment({
    required this.id,
    required this.sessionId,
    required this.traineeUserId,
    this.assignedByTrainerId,
    required this.assignedAt,
    this.traineeNote,
  });
}
