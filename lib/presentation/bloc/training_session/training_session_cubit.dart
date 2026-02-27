import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_sessions_ui_model.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

part 'training_session_state.dart';

class TrainingSessionCubit extends Cubit<TrainingSessionState> {
  final TrainingSessionRepository _training_sessionRepository;
  StreamSubscription? _downloadSubscription;

  // Store current data locally in cubit to avoid passing it around in states excessively
  // todo: design issue: data should go in the state
  DomainSnapshot _currentTSSnapshot = NullDomainSnapshot();
  Map<int, DownloadStatus> _currentDownloadStatus = {};
  Map<int, double> _currentDownloadProgress = {};

  // Future<DomainSnapshot> get currentTSSnapshot => _training_sessionRepository.getTrainingSessions();

  TrainingSessionCubit({required TrainingSessionRepository training_sessionRepository})
      : _training_sessionRepository = training_sessionRepository,
        super(TrainingSessionInitial());

  /// Loads initial download statuses and fetches the training_session list.
  Future<void> initialize() async {
    await loadInitialStatuses();
    await fetchTrainingSessions();
  }

  /// Loads download statuses from the repository.
  Future<void> loadInitialStatuses() async {
    // No need for loading state here, happens quickly
    try {
      _currentDownloadStatus = await _training_sessionRepository.getInitialDownloadStatuses();
      // If training_sessions are already loaded, emit loaded state with statuses
      if (_currentTSSnapshot.isNotEmpty) {
          emit(TrainingSessionLoaded(
            uiModel: TrainingSessionsUiModel(
                trainingSessions: _currentTSSnapshot.sessionsById.values.toList(),
                downloadStatuses: _currentDownloadStatus,
            ),
            // domainSnapShot: _currentTSSnapshot,
            // downloadStatus: _currentDownloadStatus,
          ));
        }
    } catch (e) {
      // Handle error getting statuses, maybe emit error state?
      print("Error loading initial statuses: $e");
      // Don't necessarily block training_session loading if status load fails
      // emit(TrainingSessionError(message: "Failed to load download status", training_sessions: _currentTrainingSessions, downloadStatus: _currentDownloadStatus));
    }
  }

  /// Fetches training_sessions from the repository.
  Future<void> fetchTrainingSessions({bool forceRefresh = false}) async {
    // Avoid refetch if already loaded unless forced
    if (state is TrainingSessionLoaded && !forceRefresh) {
      return;
    }
    // Use TrainingSessionLoading state, preserving current lists/statuses
    emit(TrainingSessionLoading(
        uiModel: buildTrainingSessionsUiModel()));

        // domainSnapShot: _currentTSSnapshot, downloadStatus: _currentDownloadStatus));
    try {
      _currentTSSnapshot = await _training_sessionRepository.getTrainingSessions();
      // Merge fetched training_sessions with current download statuses
      emit(TrainingSessionLoaded(
        uiModel: buildTrainingSessionsUiModel(),
        // domainSnapShot: _currentTSSnapshot,
        // downloadStatus: _currentDownloadStatus,
      ));
    } catch (e) {
      print("Error fetching training_sessions: $e");
      emit(TrainingSessionError(
        message: "Failed to load training_sessions: ${e.toString()}",
        uiModel: buildTrainingSessionsUiModel(),
      ));
    }
  }

  /// Initiates download for a specific training_session.
  Future<void> downloadTrainingSession(int training_sessionId) async {
    TrainingSession? training_session;
    try {
      training_session = _currentTSSnapshot.sessionsById[training_sessionId];
    } catch (e) {
      training_session = null;
    }

    if (training_session == null) {
      emit(TrainingSessionError(
          message: "TrainingSession with ID $training_sessionId not found.",
          uiModel: buildTrainingSessionsUiModel(),
          )
      );
      return;
    }

    // Check if already downloading
    if (_currentDownloadStatus[training_sessionId] == DownloadStatus.downloading) return;

    // Cancel any previous download stream for safety
    await _downloadSubscription?.cancel();

    // Update status immediately to downloading
    _currentDownloadStatus[training_sessionId] = DownloadStatus.downloading;
    _currentDownloadProgress[training_sessionId] = 0.0;
    emit(TrainingSessionDownloading(
      uiModel: buildTrainingSessionsUiModel(),
          downloadProgress: Map.of(_currentDownloadProgress),
          downloadingTrainingSessionId: training_sessionId));
    try {
      final downloadStream = _training_sessionRepository.downloadTrainingSession(training_session);
      _downloadSubscription = downloadStream.listen(
        (progress) {
          // Update progress
          _currentDownloadProgress[training_sessionId] = progress;
          // print("Download progress received: ${(progress * 100).toStringAsFixed(1)}% for training_session $training_sessionId");
          emit(TrainingSessionDownloading(
              uiModel: buildTrainingSessionsUiModel(),
              downloadProgress: Map.of(_currentDownloadProgress),
              downloadingTrainingSessionId: training_sessionId));
        },
        onError: (error) {
          print("Download error for training_session $training_sessionId: $error");
          _currentDownloadStatus[training_sessionId] = DownloadStatus.error;
          _currentDownloadProgress.remove(training_sessionId);
          emit(TrainingSessionError(
              message: "Download failed for ${training_session?.title ?? 'TrainingSession $training_sessionId'}: $error",
              uiModel: buildTrainingSessionsUiModel()));
        },
        onDone: () {
          print("Download stream done for training_session $training_sessionId");
          // Verify final status (repository should have updated it)
          _training_sessionRepository.isTrainingSessionDownloaded(training_sessionId).then((isDownloaded) {
            print("Download verification for training_session $training_sessionId: isDownloaded = $isDownloaded");
            _currentDownloadStatus[training_sessionId] = isDownloaded ? DownloadStatus.downloaded : DownloadStatus.error;
            _currentDownloadProgress.remove(training_sessionId);
            emit(TrainingSessionLoaded(
              uiModel: buildTrainingSessionsUiModel()
              // domainSnapShot: _currentTSSnapshot,
              // downloadStatus: Map.of(_currentDownloadStatus),
            ));
          });
        },
      );
    } catch (e) {
      print("Error starting download stream for training_session $training_sessionId: $e");
      _currentDownloadStatus[training_sessionId] = DownloadStatus.error;
      _currentDownloadProgress.remove(training_sessionId);
      emit(TrainingSessionError(
          message: "Failed to start download for ${training_session.title}: $e",
          uiModel: buildTrainingSessionsUiModel()));
    }
  }

  TrainingSessionsUiModel buildTrainingSessionsUiModel() {
    final itemCounts = {
      for (final entry in _currentTSSnapshot.itemsBySessionId.entries)
        entry.key: entry.value.length
    };
    return TrainingSessionsUiModel(
        trainingSessions: _currentTSSnapshot.sessionsById.values.toList(),
        downloadStatuses: _currentDownloadStatus,
        sessionItemCounts: itemCounts);
  }

  //List<TrainingSession> getTrainingSessions(String id) => domainSnapshot.sessionsById.values.toList();

  void updateTrainingSession(TrainingSession updatedTrainingSession, {Map<int, int>? repetitionsMap}) {
    print("Updating training_session: ${updatedTrainingSession.title} (ID: ${updatedTrainingSession.id}, isUserCreated: ${updatedTrainingSession.isUserCreated})");
    return;
    // Get current training_sessions and download status from any state
    // List<TrainingSession> currentTrainingSessions = [];
    // Map<int, DownloadStatus> currentDownloadStatus = {};
    //
    // if (state is TrainingSessionLoaded) {
    //   final currentState = state as TrainingSessionLoaded;
    //   currentTrainingSessions = List<TrainingSession>.from(currentState.training_sessions);
    //   currentDownloadStatus = Map.from(currentState.downloadStatus);
    //   print("Current state: TrainingSessionLoaded with ${currentTrainingSessions.length} training_sessions");
    // } else if (state is TrainingSessionLoading) {
    //   final currentState = state as TrainingSessionLoading;
    //   currentTrainingSessions = List<TrainingSession>.from(currentState.domainSnapShot);
    //   currentDownloadStatus = Map.from(currentState.downloadStatus);
    //   print("Current state: TrainingSessionLoading with ${currentTrainingSessions.length} training_sessions");
    // } else if (state is TrainingSessionDownloading) {
    //   final currentState = state as TrainingSessionDownloading;
    //   currentTrainingSessions = List<TrainingSession>.from(currentState.training_sessions);
    //   currentDownloadStatus = Map.from(currentState.downloadStatus);
    //   print("Current state: TrainingSessionDownloading with ${currentTrainingSessions.length} training_sessions");
    // } else if (state is TrainingSessionError) {
    //   final currentState = state as TrainingSessionError;
    //   currentTrainingSessions = List<TrainingSession>.from(currentState.training_sessions);
    //   currentDownloadStatus = Map.from(currentState.downloadStatus);
    //   print("Current state: TrainingSessionError with ${currentTrainingSessions.length} training_sessions");
    // } else {
    //   // If no training_sessions loaded yet, just fetch them
    //   print("No training_sessions loaded yet, fetching training_sessions...");
    //   fetchTrainingSessions(forceRefresh: true);
    //   return;
    // }
    //
    // // Update the training_sessions list
    // final updatedTrainingSessions = List<TrainingSession>.from(currentTrainingSessions);
    //
    // if (updatedTrainingSession.isUserCreated) {
    //   // For user-created training_sessions, update in place if it exists
    //   final index = updatedTrainingSessions.indexWhere((p) => p.id == updatedTrainingSession.id && p.isUserCreated);
    //   if (index != -1) {
    //     // Update existing training_session
    //     print("Updating existing training_session at index $index");
    //     _training_sessionRepository.updateTrainingSession(updatedTrainingSession, repetitionsMap: repetitionsMap).then((_) {
    //       print("TrainingSession updated successfully in repository");
    //       updatedTrainingSessions[index] = updatedTrainingSession;
    //       // Update internal state variables
    //       currentTSSnapshot = updatedTrainingSessions;
    //       _currentDownloadStatus = currentDownloadStatus;
    //       print("Emitting TrainingSessionLoaded with ${updatedTrainingSessions.length} training_sessions");
    //       emit(TrainingSessionLoaded(
    //         training_sessions: updatedTrainingSessions,
    //         downloadStatus: currentDownloadStatus,
    //       ));
    //     }).catchError((error) {
    //       print("Error updating training_session: $error");
    //       emit(TrainingSessionError(
    //         message: "Failed to update training_session: $error",
    //         training_sessions: currentTrainingSessions,
    //         downloadStatus: currentDownloadStatus,
    //       ));
    //     });
    //   } else {
    //     // Add as new training_session if not found
    //     print("Adding as new training_session (not found in existing list)");
    //     _training_sessionRepository.saveTrainingSession(updatedTrainingSession, repetitionsMap: repetitionsMap).then((savedTrainingSession) {
    //       print("TrainingSession saved successfully in repository");
    //       updatedTrainingSessions.add(savedTrainingSession);
    //       // Update internal state variables
    //       currentTSSnapshot = updatedTrainingSessions;
    //       _currentDownloadStatus = currentDownloadStatus;
    //       print("Emitting TrainingSessionLoaded with ${updatedTrainingSessions.length} training_sessions");
    //       emit(TrainingSessionLoaded(
    //         training_sessions: updatedTrainingSessions,
    //         downloadStatus: currentDownloadStatus,
    //       ));
    //     }).catchError((error) {
    //       print("Error saving training_session: $error");
    //       emit(TrainingSessionError(
    //         message: "Failed to save training_session: $error",
    //         training_sessions: currentTrainingSessions,
    //         downloadStatus: currentDownloadStatus,
    //       ));
    //     });
    //   }
    // } else {
    //   // For server training_sessions, always treat as new item
    //   print("Saving server training_session as new item");
    //   _training_sessionRepository.saveTrainingSession(updatedTrainingSession, repetitionsMap: repetitionsMap).then((savedTrainingSession) {
    //     print("Server training_session saved successfully in repository");
    //     updatedTrainingSessions.add(savedTrainingSession);
    //     // Update internal state variables
    //     currentTSSnapshot = updatedTrainingSessions;
    //     _currentDownloadStatus = currentDownloadStatus;
    //     print("Emitting TrainingSessionLoaded with ${updatedTrainingSessions.length} training_sessions");
    //     emit(TrainingSessionLoaded(
    //       training_sessions: updatedTrainingSessions,
    //       downloadStatus: currentDownloadStatus,
    //     ));
    //   }).catchError((error) {
    //     print("Error saving server training_session: $error");
    //     emit(TrainingSessionError(
    //       message: "Failed to save training_session: $error",
    //       training_sessions: currentTrainingSessions,
    //       downloadStatus: currentDownloadStatus,
    //     ));
    //   });
    // }
  }

  Future<void> deleteTrainingSession(int training_sessionId) async {
    return;
    // try {
    //   await _training_sessionRepository.deleteTrainingSession(training_sessionId);
    //
    //   if (state is TrainingSessionLoaded) {
    //     final currentState = state as TrainingSessionLoaded;
    //     final updatedTrainingSessions = List<TrainingSession>.from(currentState.training_sessions)
    //       ..removeWhere((p) => p.id == training_sessionId);
    //
    //     emit(TrainingSessionLoaded(
    //       training_sessions: updatedTrainingSessions,
    //       downloadStatus: currentState.downloadStatus,
    //     ));
    //   }
    // } catch (e) {
    //   emit(TrainingSessionError(
    //     message: 'Failed to delete training_session: $e',
    //     training_sessions: state is TrainingSessionLoaded ? (state as TrainingSessionLoaded).training_sessions : [],
    //     downloadStatus: state is TrainingSessionLoaded ? (state as TrainingSessionLoaded).downloadStatus : {},
    //   ));
    // }
  }

  @override
  Future<void> close() {
    _downloadSubscription?.cancel();
    return super.close();
  }
}
