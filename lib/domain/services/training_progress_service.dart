/// Records how far a trainee got in a session *today*, and reports it back.
///
/// Progress is keyed by calendar day so it resets automatically each morning —
/// "how much of today's training is done". Track positions are the 0-based play
/// order within the session (the same order the player advances through).
abstract class TrainingProgressService {
  /// The set of track positions completed today for [sessionId].
  Future<Set<int>> completedToday(int sessionId);

  /// Marks track [position] of [sessionId] completed for today.
  Future<void> markCompletedToday(int sessionId, int position);
}
