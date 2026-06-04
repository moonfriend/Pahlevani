import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pahlevani/data/mappers/snapshot_builders.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/training_session_repository.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_sessions_ui_model.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

part 'training_session_state.dart';

class TrainingSessionCubit extends Cubit<TrainingSessionState> {
  final TrainingSessionRepository _training_sessionRepository;
  final DownloadRepository _downloadRepository;
  StreamSubscription? _downloadSubscription;

  // Store current data locally in cubit to avoid passing it around in states excessively
  // todo: design issue: data should go in the state
  DomainSnapshot _currentTSSnapshot = NullDomainSnapshot();
  Map<int, DownloadStatus> _currentDownloadStatus = {};
  Map<int, double> _currentDownloadProgress = {};

  // Future<DomainSnapshot> get currentTSSnapshot => _training_sessionRepository.getTrainingSessions();

  TrainingSessionCubit({
    required TrainingSessionRepository sessionRepository,
    required DownloadRepository downloadRepository,
  })  : _training_sessionRepository = sessionRepository,
        _downloadRepository = downloadRepository,
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
      _currentDownloadStatus = await _downloadRepository.getInitialDownloadStatuses();
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

  /// Initiates download for a specific training session.
  Future<void> downloadTrainingSession(int sessionId) async {
    final detail = getSessionDetail(sessionId);
    if (detail == null) {
      emit(TrainingSessionError(
        message: 'Session $sessionId not found in snapshot.',
        uiModel: buildTrainingSessionsUiModel(),
      ));
      return;
    }

    if (_currentDownloadStatus[sessionId] == DownloadStatus.downloading) return;

    await _downloadSubscription?.cancel();
    _currentDownloadStatus[sessionId] = DownloadStatus.downloading;
    _currentDownloadProgress[sessionId] = 0.0;
    emit(TrainingSessionDownloading(
      uiModel: buildTrainingSessionsUiModel(),
      downloadProgress: Map.of(_currentDownloadProgress),
      downloadingTrainingSessionId: sessionId,
    ));

    try {
      final stream = _downloadRepository.downloadTrainingSession(detail);
      _downloadSubscription = stream.listen(
        (progress) {
          _currentDownloadProgress[sessionId] = progress;
          emit(TrainingSessionDownloading(
            uiModel: buildTrainingSessionsUiModel(),
            downloadProgress: Map.of(_currentDownloadProgress),
            downloadingTrainingSessionId: sessionId,
          ));
        },
        onError: (error) {
          _currentDownloadStatus[sessionId] = DownloadStatus.error;
          _currentDownloadProgress.remove(sessionId);
          emit(TrainingSessionError(
            message: 'Download failed: $error',
            uiModel: buildTrainingSessionsUiModel(),
          ));
        },
        onDone: () {
          _downloadRepository.isTrainingSessionDownloaded(sessionId).then((ok) {
            _currentDownloadStatus[sessionId] =
                ok ? DownloadStatus.downloaded : DownloadStatus.error;
            _currentDownloadProgress.remove(sessionId);
            emit(TrainingSessionLoaded(uiModel: buildTrainingSessionsUiModel()));
          });
        },
      );
    } catch (e) {
      _currentDownloadStatus[sessionId] = DownloadStatus.error;
      _currentDownloadProgress.remove(sessionId);
      emit(TrainingSessionError(
        message: 'Failed to start download: $e',
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

  /// Returns the detailed item list for a session, built from the in-memory snapshot.
  /// Returns null if the snapshot hasn't loaded yet.
  SessionDetail? getSessionDetail(int sessionId) {
    if (_currentTSSnapshot.isEmpty) return null;
    try {
      return buildSessionDetail(sessionId, _currentTSSnapshot);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateTrainingSession(
    TrainingSession session, {
    List<ItemDetail>? items,
  }) async {
    try {
      // User sessions with a matching id → update in-place.
      // Copies of server sessions (new timestamp id) → save as new.
      final existsAsUserSession =
          _currentTSSnapshot.sessionsById[session.id]?.isUserCreated ?? false;
      if (existsAsUserSession) {
        await _training_sessionRepository.updateTrainingSession(session, items: items);
      } else {
        await _training_sessionRepository.saveTrainingSession(session, items: items);
      }
      await fetchTrainingSessions(forceRefresh: true);
    } catch (e) {
      emit(TrainingSessionError(
        message: 'Failed to update session: $e',
        uiModel: buildTrainingSessionsUiModel(),
      ));
    }
  }

  Future<void> deleteTrainingSession(int sessionId) async {
    try {
      await _training_sessionRepository.deleteTrainingSession(sessionId);
      await fetchTrainingSessions(forceRefresh: true);
    } catch (e) {
      emit(TrainingSessionError(
        message: 'Failed to delete session: $e',
        uiModel: buildTrainingSessionsUiModel(),
      ));
    }
  }

  @override
  Future<void> close() {
    _downloadSubscription?.cancel();
    return super.close();
  }
}
