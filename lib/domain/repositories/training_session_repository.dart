import 'package:pahlevani/domain/entities/training_session/session_assignment.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

import '../../data/mappers/snapshot_builders.dart';

/// Manages session data: fetching, caching, and user-created session CRUD.
abstract class TrainingSessionRepository {
  Future<DomainSnapshot> getTrainingSessions({bool refresh = false});

  /// Fetches fresh data from the remote, updates Hive, and returns an updated snapshot.
  /// Call this in the background after the initial Hive load.
  Future<DomainSnapshot> syncFromRemote();

  Future<TrainingSession> saveTrainingSession(TrainingSession session,
      {List<ItemDetail>? items});

  Future<void> updateTrainingSession(TrainingSession session,
      {List<ItemDetail>? items});

  Future<void> deleteTrainingSession(int sessionId);

  /// Trainer-only. Unlike saveTrainingSession()/updateTrainingSession()
  /// (intentionally local-only, for the unrelated isUserCreated concept),
  /// this performs a real remote write — required for the session to ever
  /// reach an assigned trainee's own device. [session.id] of 0 means "new".
  /// This only saves the session's own content — it isn't assigned to
  /// anyone until assignSessionToTrainee() is also called.
  Future<TrainingSession> saveOwnedSession({
    required TrainingSession session,
    required List<ItemDetail> items,
  });

  /// Trainer-only. Assigns an already-saved owned session to one trainee —
  /// call once per trainee to assign to several. Idempotent (re-assigning
  /// the same trainee updates rather than duplicates).
  Future<void> assignSessionToTrainee({
    required int sessionId,
    required String traineeUserId,
  });

  /// Trainer-only. All assignments for a session this trainer owns.
  Future<List<SessionAssignment>> listAssignments(int sessionId);
}
