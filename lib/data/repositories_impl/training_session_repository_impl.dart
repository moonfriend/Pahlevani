import 'dart:async';
import 'dart:io';

import 'package:pahlevani/data/datasources/training_session/training_session_local_database.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_local_datasource.dart';
import 'package:pahlevani/data/datasources/training_session/training_session_remote_datasource.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/entities/training_session/audio.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

/// Implementation of the [TrainingSessionRepository] interface.
class TrainingSessionRepositoryImpl implements TrainingSessionRepository {
  final TrainingSessionRemoteDataSource remoteDataSource;
  final TrainingSessionLocalDataSource localDataSource;
  final TrainingSessionLocalDatabase localDatabase;

  TrainingSessionRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.localDatabase,
  });

  @override
  Future<List<TrainingSession>> getTrainingSessions() async {
    print("getTrainingSessions invoked");
    try {
      // Load all local data
      final localTrainingSessionItems = await localDatabase.getTrainingSessionItems();
      final localTrainingSessionsMetaBox = await localDatabase.getTrainingSessionBox();
      final localTracks = await localDatabase.getTracks();

      // Group training_sessionItems by training_sessionId
      final Map<int, List<HiveTrainingSessionItem>> grouped = {};
      for (final ps in localTrainingSessionItems) {
        grouped.putIfAbsent(ps.training_sessionId, () => []).add(ps);
      }

      // Build training_sessions from grouped training_sessionItems
      final localTrainingSessions = <TrainingSession>[];
      for (final entry in grouped.entries) {
        final training_sessionId = entry.key;
        final trainingItems = entry.value
          ..sort((a, b) => (a.position).compareTo(b.position));
        HiveTrainingSession? meta;
        try {
          meta = localTrainingSessionsMetaBox.values.firstWhere((p) => p.id == training_sessionId);
        } catch (_) {
          meta = null;
        }
        if (meta == null) continue;
        final songs = trainingItems.map((ps) {
          final track = localTracks.firstWhere((t) => t.id == ps.itemId,
              orElse: () => HiveExercise(
                    id: 0,
                    name: '',
                    author: '',
                    type: '',
                    url: '',
                    position: 0,
                    repetitions: null,
                  ));
          return TrainingSessionItem(
            id: track.id,
            name: track.name,
            author: track.author,
            type: track.type,
            audioFileUrl: track.url,
            position: ps.position,
            // repsToDo: ps.repsToDo,
          );
        }).toList();
        localTrainingSessions.add(TrainingSession(
          id: training_sessionId,
          title: meta.title,
          description: meta.description,
          difficulty: meta.difficulty,
          createdAt: meta.createdAt,
          items: songs,
          isUserCreated: meta is HiveTrainingSession
              ? (meta as dynamic).isUserCreated ?? false
              : false,
        ));
      }

      // Fetch all tables from remote
      final training_sessionsRaw = await remoteDataSource.fetchTrainingSessionsTable();
      final ExercisesRaw = await remoteDataSource.fetchExerciseTable();
      final trainingSessionItemRaw = await remoteDataSource.fetchTrainingSessionItemTable();

      // Convert to Hive models
      final remoteExercises = ExercisesRaw.map((e) => HiveExercise.fromJson(e)).toList();
      final remoteTrainingSessionItems =
          trainingSessionItemRaw.map((e) => HiveTrainingSessionItem.fromJson(e)).toList();

      // Save tracks locally
      await localDatabase.saveExercises(remoteExercises);

      // Merge remote and local training_session songs instead of overwriting
      final existingTrainingSessionItems = await localDatabase.getTrainingSessionItems();
      final mergedTrainingSessionItems = <HiveTrainingSessionItem>[];

      // Add all existing local training_session songs (preserves user customizations)
      mergedTrainingSessionItems.addAll(existingTrainingSessionItems);

      // Add remote training_session songs only if they don't already exist locally
      for (final remotePs in remoteTrainingSessionItems) {
        final existsLocally = existingTrainingSessionItems.any((localPs) =>
            localPs.training_sessionId == remotePs.training_sessionId &&
            localPs.itemId == remotePs.itemId &&
            localPs.position == remotePs.position);
        if (!existsLocally) {
          mergedTrainingSessionItems.add(remotePs);
        }
      }

      await localDatabase.saveTrainingSessionSongs(mergedTrainingSessionItems);

      // Build training_sessions by joining tables (remote)
      final serverTrainingSessions = training_sessionsRaw
          .map((training_sessionJson) {
            final training_sessionId = training_sessionJson['id'] as int?;
            if (training_sessionId == null) return null;
            final training_sessionSongLinks = remoteTrainingSessionItems
                .where((ps) => ps.training_sessionId == training_sessionId)
                .toList();
            training_sessionSongLinks
                .sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));
            final training_sessionTracks = training_sessionSongLinks.map((ps) {
              final track = remoteExercises.firstWhere((t) => t.id == ps.itemId,
                  orElse: () => HiveExercise(
                        id: 0,
                        name: '',
                        author: '',
                        type: '',
                        url: '',
                        position: 0,
                        repetitions: null,
                      ));
              return TrainingSessionItem(
                id: track.id,
                name: track.name,
                author: track.author,
                type: track.type,
                audioFileUrl: track.url,
                position: ps.position ?? 0,
              );
            }).toList();
            return TrainingSession(
              id: training_sessionId,
              title: training_sessionJson['title'] as String? ?? 'Unknown TrainingSession',
              description: training_sessionJson['description'] as String? ?? '',
              difficulty: training_sessionJson['difficulty'] as int? ?? 1,
              createdAt: training_sessionJson['created_at'] is String
                  ? DateTime.tryParse(training_sessionJson['created_at'])
                  : null,
              items: training_sessionTracks,
              isUserCreated: false,
            );
          })
          .whereType<TrainingSession>()
          .toList();

      // Combine server training_sessions with user-created ones
      final combinedTrainingSessions = [
        ...serverTrainingSessions,
        ...localTrainingSessions.where((p) => p.isUserCreated)
      ];

      // Save to local database (metadata only)
      await localDatabase.saveTrainingSessions([
        ...serverTrainingSessions.map((p) => p.copyWith(isUserCreated: false)),
        ...localTrainingSessions.where((p) => p.isUserCreated)
      ]);

      return combinedTrainingSessions;
    } catch (e) {
      print("Error fetching from remote: $e");

      // If remote fetch fails, try to get from local database (rebuild from training_sessionItems)
      try {
        final training_sessionSongs = await localDatabase.getTrainingSessionItems();
        final training_sessionsMetaBox = await localDatabase.getTrainingSessionBox();
        final tracks = await localDatabase.getTracks();
        final Map<int, List<HiveTrainingSessionItem>> grouped = {};
        for (final ps in training_sessionSongs) {
          grouped.putIfAbsent(ps.training_sessionId, () => []).add(ps);
        }
        final localTrainingSessions = <TrainingSession>[];
        for (final entry in grouped.entries) {
          final training_sessionId = entry.key;
          final songLinks = entry.value
            ..sort((a, b) => (a.position).compareTo(b.position));
          HiveTrainingSession? meta;
          try {
            meta =
                training_sessionsMetaBox.values.firstWhere((p) => p.id == training_sessionId);
          } catch (_) {
            meta = null;
          }
          if (meta == null) continue;
          final songs = songLinks.map((ps) {
            final track = tracks.firstWhere((t) => t.id == ps.itemId,
                orElse: () => HiveExercise(
                      id: 0,
                      name: '',
                      author: '',
                      type: '',
                      url: '',
                      position: 0,
                      repetitions: null,
                    ));
            return TrainingSessionItem(
              id: track.id,
              name: track.name,
              author: track.author,
              type: track.type,
              audioFileUrl: track.url,
              position: ps.position,
            );
          }).toList();
          localTrainingSessions.add(TrainingSession(
            id: training_sessionId,
            title: meta.title,
            description: meta.description,
            difficulty: meta.difficulty,
            createdAt: meta.createdAt,
            items: songs,
            isUserCreated: meta is HiveTrainingSession
                ? (meta as dynamic).isUserCreated ?? false
                : false,
          ));
        }
        return localTrainingSessions;
      } catch (localError) {
        print("Error reading from local database: $localError");
      }

      // If both remote and local fail, throw the original error
      throw Exception('Could not fetch training_sessions: $e');
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
    final training_sessionId = training_session.id;

    try {
      // Get and create target directory
      final targetDirPath =
          await localDataSource.getTrainingSessionDirectoryPath(training_sessionId);
      final targetDir = Directory(targetDirPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Filter valid songs and calculate total
      final validSongs =
          training_session.items.where((s) => s.audioFileUrl.trim().isNotEmpty).toList();
      final totalSongs = validSongs.length;

      if (totalSongs == 0) {
        controller
            .addError(Exception("TrainingSession has no valid songs to download."));
        await controller.close();
        await _saveDownloadStatus(training_sessionId, DownloadStatus.error);
        return;
      }

      int downloadedCount = 0;
      controller.add(0.0); // Initial progress
      print(
          "Starting download for training_session $training_sessionId with $totalSongs songs");

      // Download each song
      for (final song in validSongs) {
        final filename = _getSafeFilename(song);
        final savePath = '$targetDirPath/$filename';
        print("Downloading song: ${song.name}");

        try {
          await localDataSource.downloadFile(
            song.audioFileUrl,
            savePath,
            (received, total) {
              if (total > 0) {
                double songProgress = received / total;
                double overallProgress =
                    (downloadedCount + songProgress) / totalSongs;
                final progress = overallProgress.clamp(0.0, 1.0);
                // print("Download progress: ${(progress * 100).toStringAsFixed(1)}%");
                controller.add(progress);
              }
            },
          );

          downloadedCount++;
          final progress = (downloadedCount / totalSongs).clamp(0.0, 1.0);
          print(
              "Song completed: ${song.name}, overall progress: ${(progress * 100).toStringAsFixed(1)}%");
          controller.add(progress);

          // Add a small delay between downloads to prevent overwhelming the server
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print("Error downloading song ${song.name}: $e");
          controller.addError(
              Exception("Failed to download song: ${song.name} - $e"));
          await _saveDownloadStatus(training_sessionId, DownloadStatus.error);
          await controller.close();
          return;
        }
      }

      // Verify all files were downloaded
      bool allFilesExist = true;
      for (final song in validSongs) {
        final filename = _getSafeFilename(song);
        final filePath = '$targetDirPath/$filename';
        if (!await File(filePath).exists()) {
          allFilesExist = false;
          break;
        }
      }

      if (allFilesExist && downloadedCount == totalSongs) {
        await _saveDownloadStatus(training_sessionId, DownloadStatus.downloaded);
        controller.add(1.0);
        print("TrainingSession $training_sessionId download complete.");
      } else {
        print("TrainingSession $training_sessionId download incomplete.");
        await _saveDownloadStatus(training_sessionId, DownloadStatus.error);
        controller.addError(
            Exception("Download incomplete - some files are missing."));
      }

      await controller.close();
    } catch (e) {
      print("Error during training_session download process for $training_sessionId: $e");
      await _saveDownloadStatus(training_sessionId, DownloadStatus.error);
      controller.addError(e);
      await controller.close();
    }
  }

  /// Helper to save download status via local data source
  Future<void> _saveDownloadStatus(
      int training_sessionId, DownloadStatus status) async {
    try {
      final currentList = await localDataSource.getDownloadedTrainingSessionIds();
      final idStr = training_sessionId.toString();
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
  Future<String?> getLocalSongPath(int training_sessionId, TrainingSessionItem song) async {
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

  /// Helper to create a safe filename (duplicate from page, should be centralized)
  String _getSafeFilename(TrainingSessionItem song) {
    final safeName = song.name
        .replaceAll(RegExp(r'[^a-zA-Z0-9 \-_]+'), '_')
        .replaceAll(' ', '_');
    String extension = '.mp3';
    try {
      final uri = Uri.parse(song.audioFileUrl);
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
    return '${song.id}_${safeName}$extension';
  }

  @override
  Future<TrainingSession> saveTrainingSession(TrainingSession training_session,
      {Map<int, int>? repetitionsMap}) async {
    try {
      // Generate a new ID for the training_session
      final newId = DateTime.now().millisecondsSinceEpoch;
      final newTrainingSession = TrainingSession(
        id: newId,
        title: training_session.title,
        description: training_session.description,
        difficulty: training_session.difficulty,
        createdAt: DateTime.now(),
        items: training_session.items,
        isUserCreated: true, // Always mark as user-created
      );

      // Save to local database
      await localDatabase.saveTrainingSessions([newTrainingSession]);

      // Save training_session_items with repsToDo
      if (repetitionsMap != null) {
        final training_sessionSongs = training_session.items.asMap().entries.map((entry) {
          final index = entry.key;
          final song = entry.value;
          return HiveTrainingSessionItem(
            training_sessionId: newId,
            itemId: song.id,
            position: index,
            repsToDo: repetitionsMap[song.id] ?? 1,
          );
        }).toList();
        await localDatabase.saveTrainingSessionSongs(training_sessionSongs);
      }

      return newTrainingSession;
    } catch (e) {
      throw Exception('Failed to save training_session: $e');
    }
  }

  @override
  Future<void> updateTrainingSession(TrainingSession training_session,
      {Map<int, int>? repetitionsMap}) async {
    try {
      // Update HiveTrainingSession (metadata)
      final training_sessionsMetaBox = await localDatabase.getTrainingSessionBox();
      final existingMetaIndex = training_sessionsMetaBox.values
          .toList()
          .indexWhere((p) => p.id == training_session.id);
      final newHiveTrainingSession = HiveTrainingSession(
        id: training_session.id,
        title: training_session.title,
        description: training_session.description,
        difficulty: training_session.difficulty,
        createdAt: training_session.createdAt,
        items: training_session.items.map((s) => HiveExercise.fromDomain(s)).toList(),
        isUserCreated: true,
      );
      if (existingMetaIndex != -1) {
        final key = training_sessionsMetaBox.keyAt(existingMetaIndex);
        await training_sessionsMetaBox.put(key, newHiveTrainingSession);
      } else {
        await training_sessionsMetaBox.add(newHiveTrainingSession);
      }

      // Update HiveTrainingSessionSong (song links and repsToDo)
      final training_sessionSongBox = await localDatabase.getTrainingSessionItemBox();
      // Remove old song links for this training_session
      final oldKeys = training_sessionSongBox.keys.where((k) {
        final ps = training_sessionSongBox.get(k);
        return ps != null && ps.training_sessionId == training_session.id;
      }).toList();
      for (final k in oldKeys) {
        await training_sessionSongBox.delete(k);
      }
      // Add new song links
      final training_sessionSongs = training_session.items.asMap().entries.map((entry) {
        final index = entry.key;
        final song = entry.value;
        final repsToDo = repetitionsMap?[song.id] ?? 1;
        return HiveTrainingSessionItem(
          training_sessionId: training_session.id,
          itemId: song.id,
          position: index,
          repsToDo: repsToDo,
        );
      }).toList();
      await training_sessionSongBox.addAll(training_sessionSongs);
    } catch (e) {
      throw Exception('Failed to update training_session: $e');
    }
  }

  @override
  Future<void> deleteTrainingSession(int training_sessionId) async {
    try {
      // Get existing training_sessions
      final training_sessions = await localDatabase.getTrainingSessions();
      final index = training_sessions.indexWhere((p) => p.id == training_sessionId);

      if (index != -1) {
        // Remove the training_session from the list
        training_sessions.removeAt(index);
        // Save the updated list
        await localDatabase.saveTrainingSessions(training_sessions);

        // Delete downloaded files if any
        if (await isTrainingSessionDownloaded(training_sessionId)) {
          await localDataSource.deleteTrainingSessionDirectory(training_sessionId);
          await _saveDownloadStatus(training_sessionId, DownloadStatus.notDownloaded);
        }
      } else {
        throw Exception('TrainingSession not found');
      }
    } catch (e) {
      throw Exception('Failed to delete training_session: $e');
    }
  }
}
