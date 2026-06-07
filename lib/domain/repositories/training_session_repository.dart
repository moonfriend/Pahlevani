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
}