import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

import '../../data/mappers/snapshot_builders.dart';

/// Manages session data: fetching, caching, and user-created session CRUD.
abstract class TrainingSessionRepository {
  Future<DomainSnapshot> getTrainingSessions({bool refresh = false});

  Future<TrainingSession> saveTrainingSession(TrainingSession session,
      {List<ItemDetail>? items});

  Future<void> updateTrainingSession(TrainingSession session,
      {List<ItemDetail>? items});

  Future<void> deleteTrainingSession(int sessionId);
}