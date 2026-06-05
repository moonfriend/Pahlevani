import 'package:pahlevani/data/datasources/training_session/training_session_local_database.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_remote_datasource.dart';
import 'package:pahlevani/data/dtos/exercise_row.dart';
import 'package:pahlevani/data/dtos/movement_row.dart';
import 'package:pahlevani/data/dtos/training_item_row.dart';
import 'package:pahlevani/data/dtos/training_session_row.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';

/// Implementation of the [TrainingSessionRepository] interface.
class TrainingSessionRepositoryImpl implements TrainingSessionRepository {
  final TrainingSessionRemoteDataSource remoteDataSource;
  final TrainingSessionLocalDataSource localDataSource;
  final TrainingSessionLocalDatabase localDatabase;

  DomainSnapshot? _domainSnapshot;

  TrainingSessionRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.localDatabase,
  });


  @override
  Future<DomainSnapshot> getTrainingSessions({bool refresh = false}) async {
    if (_domainSnapshot != null && !refresh) {
      return Future.value(_domainSnapshot!);
    }
    // If refresh is true or snapshot is null, fetch from remote
    return fetchTrainingSessions();
  }

  Future<DomainSnapshot> fetchTrainingSessions() async {
    print("getTrainingSessions invoked");
    try {
      final TSMaps = await remoteDataSource.fetchTrainingSessionsTable();
      final exercisesMaps = await remoteDataSource.fetchExerciseTable();
      final TSItemMaps = await remoteDataSource.fetchTrainingSessionItemTable();
      final movementMaps = await remoteDataSource.fetchMovementTable();

      final snap = buildDomainSnapshot(
        sessionRows: TSMaps.map((e) => TrainingSessionRow.fromJson(e)).toList(),
        itemRows: TSItemMaps.map((e) => TrainingItemRow.fromJson(e)).toList(),
        exerciseRows: exercisesMaps.map((e) => ExerciseRow.fromJson(e)).toList(),
        movementRows: movementMaps.map((e) => MovementRow.fromJson(e)).toList(),
      );

      // Cache to Hive using domain objects so movement data is denormalized in.
      try {
        await localDatabase.saveExercises(
          snap.exercisesById.values.map(HiveExercise.fromDomain).toList(),
        );
        await localDatabase.saveTrainingSessionItems(
          TSItemMaps.map((e) => HiveTrainingSessionItem.fromJson(e)).toList(),
          serverSessionIds: snap.sessionsById.keys.toSet(),
        );
        await localDatabase.saveTrainingSessions(
          snap.sessionsById.values.toList(),
        );
      } catch (cacheError) {
        print("Warning: failed to write Hive cache: $cacheError");
      }

      // Merge user-created sessions from Hive into the snapshot so they
      // appear alongside server sessions in the UI.
      try {
        final box = await localDatabase.getTrainingSessionBox();
        final allItems = await localDatabase.getTrainingSessionItems();
        for (final hive in box.values.where((s) => s.isUserCreated)) {
          final session = hive.toDomain();
          snap.sessionsById[session.id] = session;
          snap.itemsBySessionId[session.id] = allItems
              .where((i) => i.trainingSessionId == session.id)
              .map((i) => TrainingItem(
                    id: i.trainingSessionId * 10000 + i.position,
                    sessionId: i.trainingSessionId,
                    exerciseId: i.itemId,
                    position: i.position,
                    prescription: RepsPresc(i.repsToDo),
                  ))
              .toList()
            ..sort((a, b) => a.position.compareTo(b.position));
        }
      } catch (mergeError) {
        print("Warning: failed to merge user sessions: $mergeError");
      }

      _domainSnapshot = snap;
      return snap;
    } catch (e) {
      print("Error fetching from remote: $e");

      // Fall back to Hive cache. Exercises are already denormalized
      // (movement data was embedded when the cache was last written).
      try {
        final hiveExercises = await localDatabase.getTracks();
        final hiveItems = await localDatabase.getTrainingSessionItems();
        final hiveSessions = await localDatabase.getTrainingSessionBox();

        final snap = buildDomainSnapshotFromDomain(
          sessions: hiveSessions.values.map((s) => s.toDomain()).toList(),
          exercises: hiveExercises.map((e) => e.toDomain()).toList(),
          items: hiveItems.map((i) => TrainingItem(
            id: i.trainingSessionId * 10000 + i.position,
            sessionId: i.trainingSessionId,
            exerciseId: i.itemId,
            position: i.position,
            prescription: RepsPresc(i.repsToDo),
          )).toList(),
        );
        _domainSnapshot = snap;
        return snap;
      } catch (localError) {
        print("Error reading from local cache: $localError");
        throw Exception('Could not fetch training sessions: $e');
      }
    }
  }


  @override
  Future<void> deleteTrainingSession(int trainingSessionId) async {
    try {
      final box = await localDatabase.getTrainingSessionBox();
      final key = box.keys.firstWhere(
        (k) => box.get(k)?.id == trainingSessionId,
        orElse: () => null,
      );
      if (key != null) await box.delete(key);

      final itemBox = await localDatabase.getTrainingSessionItemBox();
      final itemKeys = itemBox.keys
          .where((k) => itemBox.get(k)?.trainingSessionId == trainingSessionId)
          .toList();
      await itemBox.deleteAll(itemKeys);

      if (await localDataSource.training_sessionDirectoryExists(trainingSessionId)) {
        await localDataSource.deleteTrainingSessionDirectory(trainingSessionId);
        final ids = await localDataSource.getDownloadedTrainingSessionIds();
        ids.remove(trainingSessionId.toString());
        await localDataSource.saveDownloadedTrainingSessionIds(ids);
      }
    } catch (e) {
      throw Exception('Failed to delete session: $e');
    }
  }

  @override
  Future<TrainingSession> saveTrainingSession(
    TrainingSession trainingSession, {
    List<ItemDetail>? items,
  }) async {
    try {
      final saved = trainingSession.copyWith(
        id: trainingSession.isUserCreated
            ? trainingSession.id
            : DateTime.now().millisecondsSinceEpoch,
        createdAt: trainingSession.createdAt ?? DateTime.now(),
        isUserCreated: true,
      );
      await localDatabase.saveTrainingSessions([saved]);
      if (items != null) {
        await _saveItemDetails(saved.id, items);
      }
      return saved;
    } catch (e) {
      throw Exception('Failed to save session: $e');
    }
  }

  @override
  Future<void> updateTrainingSession(
    TrainingSession trainingSession, {
    List<ItemDetail>? items,
  }) async {
    try {
      final box = await localDatabase.getTrainingSessionBox();
      final key = box.keys.firstWhere(
        (k) => box.get(k)?.id == trainingSession.id,
        orElse: () => null,
      );
      final hive = HiveTrainingSession.fromDomain(trainingSession);
      if (key != null) {
        await box.put(key, hive);
      } else {
        await box.add(hive);
      }
      if (items != null) {
        await _saveItemDetails(trainingSession.id, items);
      }
    } catch (e) {
      throw Exception('Failed to update session: $e');
    }
  }

  /// Replaces all HiveTrainingSessionItems for [sessionId] with [items].
  Future<void> _saveItemDetails(int sessionId, List<ItemDetail> items) async {
    final itemBox = await localDatabase.getTrainingSessionItemBox();
    final oldKeys = itemBox.keys
        .where((k) => itemBox.get(k)?.trainingSessionId == sessionId)
        .toList();
    await itemBox.deleteAll(oldKeys);

    final hiveItems = items.asMap().entries.map((entry) {
      final position = entry.key;
      final detail = entry.value;
      final reps = detail.item.prescription is RepsPresc
          ? (detail.item.prescription as RepsPresc).count
          : 1;
      return HiveTrainingSessionItem(
        trainingSessionId: sessionId,
        itemId: detail.item.exerciseId,
        position: position,
        repsToDo: reps,
      );
    }).toList();
    await itemBox.addAll(hiveItems);
  }
}
