import 'dart:async';
import 'dart:io';

import 'package:pahlevani/data/datasources/training_session/training_session_local_database.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_remote_datasource.dart';
import 'package:pahlevani/data/dtos/exercise_row.dart';
import 'package:pahlevani/data/dtos/training_item_row.dart';
import 'package:pahlevani/data/dtos/training_session_row.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

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

      final snap = buildDomainSnapshot(
        sessionRows: TSMaps.map((e) => TrainingSessionRow.fromJson(e)).toList(),
        itemRows: TSItemMaps.map((e) => TrainingItemRow.fromJson(e)).toList(),
        exerciseRows: exercisesMaps.map((e) => ExerciseRow.fromJson(e)).toList(),
      );
      _domainSnapshot = snap;

      // Cache all three tables to Hive for offline use (best-effort).
      try {
        await localDatabase.saveExercises(
          exercisesMaps.map((e) => HiveExercise.fromJson(e)).toList(),
        );
        await localDatabase.saveTrainingSessionItems(
          TSItemMaps.map((e) => HiveTrainingSessionItem.fromJson(e)).toList(),
        );
        await localDatabase.saveTrainingSessions(
          snap.sessionsById.values.toList(),
        );
      } catch (cacheError) {
        print("Warning: failed to write Hive cache: $cacheError");
      }

      return snap;
    } catch (e) {
      print("Error fetching from remote: $e");

      // Fall back to Hive cache.
      try {
        final hiveExercises = await localDatabase.getTracks();
        final hiveItems = await localDatabase.getTrainingSessionItems();
        final hiveSessions = await localDatabase.getTrainingSessionBox();

        final snap = buildDomainSnapshot(
          sessionRows: hiveSessions.values
              .map((s) => TrainingSessionRow.fromJson(s.toJson()))
              .toList(),
          itemRows: hiveItems
              .map((i) => TrainingItemRow.fromJson(i.toJson()))
              .toList(),
          exerciseRows: hiveExercises
              .map((ex) => ExerciseRow.fromJson(ex.toJson()))
              .toList(),
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
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses() async {
    final statuses = <int, DownloadStatus>{};
    try {
      final downloadedIds = await localDataSource.getDownloadedTrainingSessionIds();
      for (final idStr in downloadedIds) {
        final id = int.tryParse(idStr);
        if (id != null) {
          // Verify directory existence for robustness
          if (await localDataSource.training_sessionDirectoryExists(id)) {
            statuses[id] = DownloadStatus.downloaded;
          } else {
            // Mark as error or not downloaded if directory is missing?
            // Or clean up the entry in SharedPreferences?
            print("Directory missing for supposedly downloaded training_session $id");
            statuses[id] = DownloadStatus.error; // Indicate an issue
            // Consider removing from prefs here
          }
        }
      }
    } catch (e) {
      print("Error getting initial download statuses: $e");
      // Don't throw, just return potentially empty map
    }
    return statuses;
  }

  @override
  Stream<double> downloadTrainingSession(TrainingSession training_session) {
    final controller = StreamController<double>();

    // Start the download process asynchronously
    _downloadTrainingSessionAsync(training_session, controller);

    return controller.stream;
  }

  Future<void> _downloadTrainingSessionAsync(
      TrainingSession training_session, StreamController<double> controller) async {

    // return;

    final trainingSessionId = training_session.id;

    try {
      // Get and create target directory
      final targetDirPath =
          await localDataSource.getTrainingSessionDirectoryPath(trainingSessionId);
      final targetDir = Directory(targetDirPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Snapshot must exist before download can proceed — fetch it if missing.
      if (_domainSnapshot == null) {
        await fetchTrainingSessions();
      }
      if (_domainSnapshot == null) {
        controller.addError(Exception("Cannot download: session data not loaded yet."));
        await controller.close();
        return;
      }

      final sessionDetails = buildSessionDetail(trainingSessionId, _domainSnapshot!);
      final validItemDetails =
          sessionDetails.items.where((s) => s.exercise.audioFileUrl!.trim().isNotEmpty).toList();

      // final validUrls =
      //     training_session.items.where((s) => s.audioFileUrl.trim().isNotEmpty).toList();
      final totalItems = validItemDetails.length;

      if (totalItems == 0) {
        controller
            .addError(Exception("TrainingSession has no valid exercises to download."));
        await controller.close();
        await _saveDownloadStatus(trainingSessionId, DownloadStatus.error);
        return;
      }

      int downloadedCount = 0;
      controller.add(0.0); // Initial progress
      print(
          "Starting download for training_session $trainingSessionId with $totalItems songs");

      // Download each item
      for (final itemDetail in validItemDetails) {
        final filename = _getSafeFilename(itemDetail);
        final savePath = '$targetDirPath/$filename';
        print("Downloading song: ${itemDetail.exercise.name}");

        try {
          await localDataSource.downloadFile(
            itemDetail.exercise.audioFileUrl ?? '',
            savePath,
            (received, total) {
              if (total > 0) {
                double songProgress = received / total;
                double overallProgress =
                    (downloadedCount + songProgress) / totalItems;
                final progress = overallProgress.clamp(0.0, 1.0);
                // print("Download progress: ${(progress * 100).toStringAsFixed(1)}%");
                controller.add(progress);
              }
            },
          );

          downloadedCount++;
          final progress = (downloadedCount / totalItems).clamp(0.0, 1.0);
          print(
              "Song completed: ${itemDetail.exercise.name}, overall progress: ${(progress * 100).toStringAsFixed(1)}%");
          controller.add(progress);

          // Add a small delay between downloads to prevent overwhelming the server
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print("Error downloading song ${itemDetail.exercise.name}: $e");
          controller.addError(
              Exception("Failed to download song: ${itemDetail.exercise.name} - $e"));
          await _saveDownloadStatus(trainingSessionId, DownloadStatus.error);
          await controller.close();
          return;
        }
      }

      // Verify all files were downloaded
      bool allFilesExist = true;
      for (final song in validItemDetails) {
        final filename = _getSafeFilename(song);
        final filePath = '$targetDirPath/$filename';
        if (!await File(filePath).exists()) {
          allFilesExist = false;
          break;
        }
      }

      if (allFilesExist && downloadedCount == totalItems) {
        await _saveDownloadStatus(trainingSessionId, DownloadStatus.downloaded);
        controller.add(1.0);
        print("TrainingSession $trainingSessionId download complete.");
      } else {
        print("TrainingSession $trainingSessionId download incomplete.");
        await _saveDownloadStatus(trainingSessionId, DownloadStatus.error);
        controller.addError(
            Exception("Download incomplete - some files are missing."));
      }

      await controller.close();
    } catch (e) {
      print("Error during training_session download process for $trainingSessionId: $e");
      await _saveDownloadStatus(trainingSessionId, DownloadStatus.error);
      controller.addError(e);
      await controller.close();
    }
  }

  /// Helper to save download status via local data source
  Future<void> _saveDownloadStatus(
      int trainingSessionId, DownloadStatus status) async {
    try {
      final currentList = await localDataSource.getDownloadedTrainingSessionIds();
      final idStr = trainingSessionId.toString();
      bool changed = false;

      if (status == DownloadStatus.downloaded) {
        if (!currentList.contains(idStr)) {
          currentList.add(idStr);
          changed = true;
        }
      } else {
        // Not downloaded or error
        if (currentList.contains(idStr)) {
          currentList.remove(idStr);
          changed = true;
          // Optionally delete files when status is explicitly set to not downloaded/error
          // await localDataSource.deleteTrainingSessionDirectory(training_sessionId);
        }
      }

      if (changed) {
        await localDataSource.saveDownloadedTrainingSessionIds(currentList);
      }
    } catch (e) {
      print("Error saving training_session download status: $e");
    }
  }

  @override
  Future<bool> isTrainingSessionDownloaded(int training_sessionId) async {
    // Check both SharedPreferences and directory existence for robustness
    final downloadedIds = await localDataSource.getDownloadedTrainingSessionIds();
    if (!downloadedIds.contains(training_sessionId.toString())) {
      return false;
    }
    return await localDataSource.training_sessionDirectoryExists(training_sessionId);
  }

  @override
  Future<String?> getLocalSongPath(int training_sessionId, ItemDetail song) async {
    if (await isTrainingSessionDownloaded(training_sessionId)) {
      final training_sessionDirPath =
          await localDataSource.getTrainingSessionDirectoryPath(training_sessionId);
      final filename = _getSafeFilename(song);
      final localPath = '$training_sessionDirPath/$filename';
      if (await File(localPath).exists()) {
        return localPath;
      }
    }
    return null; // Return null if not downloaded or file missing
  }

  /// Helper to create a safe filename
  String _getSafeFilename(ItemDetail item) {
    final safeName = item.exercise.name
        .replaceAll(RegExp(r'[^a-zA-Z0-9 \-_]+'), '_')
        .replaceAll(' ', '_');
    String extension = '.mp3';
    try {
      final uri = Uri.parse(item.exercise.audioFileUrl ?? '');
      if (uri.pathSegments.isNotEmpty && uri.pathSegments.last.contains('.')) {
        extension = uri.pathSegments.last
            .substring(uri.pathSegments.last.lastIndexOf('.'));
        if (!['.mp3', '.m4a', '.wav', '.ogg']
            .contains(extension.toLowerCase())) {
          extension = '.mp3';
        }
      }
    } catch (_) {
      /* Keep default */
    }
    return '${item.item.id}_${safeName}$extension';
  }

  @override
  Future<void> deleteTrainingSession(int training_sessionId) {
    // TODO: implement deleteTrainingSession
    throw UnimplementedError();
  }

  @override
  Future<TrainingSession> saveTrainingSession(TrainingSession training_session, {Map<int, int>? repetitionsMap}) {
    // TODO: implement saveTrainingSession
    throw UnimplementedError();
  }

  @override
  Future<void> updateTrainingSession(TrainingSession training_session, {Map<int, int>? repetitionsMap}) {
    // TODO: implement updateTrainingSession
    throw UnimplementedError();
  }
  //
  // @override
  // Future<TrainingSession> saveTrainingSession(TrainingSession training_session,
  //     {Map<int, int>? repetitionsMap}) async {
  //   try {
  //     // Generate a new ID for the training_session
  //     final newId = DateTime.now().millisecondsSinceEpoch;
  //     final newTrainingSession = TrainingSession(
  //       id: newId,
  //       title: training_session.title,
  //       description: training_session.description,
  //       difficulty: training_session.difficulty,
  //       createdAt: DateTime.now(),
  //       items: training_session.items,
  //       isUserCreated: true, // Always mark as user-created
  //     );
  //
  //     // Save to local database
  //     await localDatabase.saveTrainingSessions([newTrainingSession]);
  //
  //     // Save training_session_items with repsToDo
  //     if (repetitionsMap != null) {
  //       final training_sessionSongs = training_session.items.asMap().entries.map((entry) {
  //         final index = entry.key;
  //         final song = entry.value;
  //         return HiveTrainingSessionItem(
  //           training_sessionId: newId,
  //           itemId: song.id,
  //           position: index,
  //           repsToDo: repetitionsMap[song.id] ?? 1,
  //         );
  //       }).toList();
  //       await localDatabase.saveTrainingSessionItems(training_sessionSongs);
  //     }
  //
  //     return newTrainingSession;
  //   } catch (e) {
  //     throw Exception('Failed to save training_session: $e');
  //   }
  // }
  //
  // @override
  // Future<void> updateTrainingSession(TrainingSession training_session,
  //     {Map<int, int>? repetitionsMap}) async {
  //   try {
  //     // Update HiveTrainingSession (metadata)
  //     final training_sessionsMetaBox = await localDatabase.getTrainingSessionBox();
  //     final existingMetaIndex = training_sessionsMetaBox.values
  //         .toList()
  //         .indexWhere((p) => p.id == training_session.id);
  //     final newHiveTrainingSession = HiveTrainingSession(
  //       id: training_session.id,
  //       title: training_session.title,
  //       description: training_session.description,
  //       difficulty: training_session.difficulty,
  //       createdAt: training_session.createdAt,
  //       items: training_session.items.map((s) => HiveExercise.fromDomain(s)).toList(),
  //       isUserCreated: true,
  //     );
  //     if (existingMetaIndex != -1) {
  //       final key = training_sessionsMetaBox.keyAt(existingMetaIndex);
  //       await training_sessionsMetaBox.put(key, newHiveTrainingSession);
  //     } else {
  //       await training_sessionsMetaBox.add(newHiveTrainingSession);
  //     }
  //
  //     // Update HiveTrainingSessionSong (song links and repsToDo)
  //     final training_sessionSongBox = await localDatabase.getTrainingSessionItemBox();
  //     // Remove old song links for this training_session
  //     final oldKeys = training_sessionSongBox.keys.where((k) {
  //       final ps = training_sessionSongBox.get(k);
  //       return ps != null && ps.training_sessionId == training_session.id;
  //     }).toList();
  //     for (final k in oldKeys) {
  //       await training_sessionSongBox.delete(k);
  //     }
  //     // Add new song links
  //     final training_sessionSongs = training_session.items.asMap().entries.map((entry) {
  //       final index = entry.key;
  //       final song = entry.value;
  //       final repsToDo = repetitionsMap?[song.id] ?? 1;
  //       return HiveTrainingSessionItem(
  //         training_sessionId: training_session.id,
  //         itemId: song.id,
  //         position: index,
  //         repsToDo: repsToDo,
  //       );
  //     }).toList();
  //     await training_sessionSongBox.addAll(training_sessionSongs);
  //   } catch (e) {
  //     throw Exception('Failed to update training_session: $e');
  //   }
  // }
  //
  // @override
  // Future<void> deleteTrainingSession(int training_sessionId) async {
  //   try {
  //     // Get existing training_sessions
  //     final training_sessions = await localDatabase.getTrainingSessions();
  //     final index = training_sessions.indexWhere((p) => p.id == training_sessionId);
  //
  //     if (index != -1) {
  //       // Remove the training_session from the list
  //       training_sessions.removeAt(index);
  //       // Save the updated list
  //       await localDatabase.saveTrainingSessions(training_sessions);
  //
  //       // Delete downloaded files if any
  //       if (await isTrainingSessionDownloaded(training_sessionId)) {
  //         await localDataSource.deleteTrainingSessionDirectory(training_sessionId);
  //         await _saveDownloadStatus(training_sessionId, DownloadStatus.notDownloaded);
  //       }
  //     } else {
  //       throw Exception('TrainingSession not found');
  //     }
  //   } catch (e) {
  //     throw Exception('Failed to delete training_session: $e');
  //   }
  // }
  //

  

}
