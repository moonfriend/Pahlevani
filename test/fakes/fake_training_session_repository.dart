import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';

/// Reusable fake for [TrainingSessionRepository].
/// Holds an in-memory [DomainSnapshot] that mutates on save/update/delete.
/// Tracks call counts for assertion.
class FakeTrainingSessionRepository implements TrainingSessionRepository {
  DomainSnapshot _snapshot;
  int getCallCount = 0;
  bool lastRefreshArgument = false;
  int syncCallCount = 0;

  FakeTrainingSessionRepository(DomainSnapshot snapshot) : _snapshot = snapshot;

  void updateSnapshot(DomainSnapshot snap) => _snapshot = snap;
  DomainSnapshot get currentSnapshot => _snapshot;

  @override
  Future<DomainSnapshot> getTrainingSessions({bool refresh = false}) async {
    lastRefreshArgument = refresh;
    getCallCount++;
    return _snapshot;
  }

  @override
  Future<DomainSnapshot> syncFromRemote() async {
    syncCallCount++;
    return _snapshot;
  }

  @override
  Future<TrainingSession> saveTrainingSession(TrainingSession session,
      {List<ItemDetail>? items}) async {
    final saved = session.copyWith(isUserCreated: true);
    _snapshot = DomainSnapshot(
      sessionsById: {..._snapshot.sessionsById, saved.id: saved},
      itemsBySessionId: {..._snapshot.itemsBySessionId},
      exercisesById: {..._snapshot.exercisesById},
    );
    return saved;
  }

  @override
  Future<void> updateTrainingSession(TrainingSession session,
      {List<ItemDetail>? items}) async {
    _snapshot = DomainSnapshot(
      sessionsById: {..._snapshot.sessionsById, session.id: session},
      itemsBySessionId: {..._snapshot.itemsBySessionId},
      exercisesById: {..._snapshot.exercisesById},
    );
  }

  @override
  Future<void> deleteTrainingSession(int sessionId) async {
    final updated = Map<int, TrainingSession>.from(_snapshot.sessionsById)
      ..remove(sessionId);
    _snapshot = DomainSnapshot(
      sessionsById: updated,
      itemsBySessionId: {..._snapshot.itemsBySessionId}..remove(sessionId),
      exercisesById: {..._snapshot.exercisesById},
    );
  }
}
