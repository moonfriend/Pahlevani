part of 'training_session_cubit.dart';

@immutable
abstract class TrainingSessionState extends Equatable {
  const TrainingSessionState();
}

class TrainingSessionInitial extends TrainingSessionState {
  @override
  List<Object?> get props => [];
}

// Represents general loading (fetching training_sessions)
class TrainingSessionLoading extends TrainingSessionState {
  final List<TrainingSession> training_sessions; // Keep existing training_sessions if available
  final Map<int, DownloadStatus> downloadStatus;

  const TrainingSessionLoading({required this.training_sessions, required this.downloadStatus});

  @override
  List<Object?> get props => [training_sessions, downloadStatus];
}

// Represents state where training_sessions are loaded and displayed
class TrainingSessionLoaded extends TrainingSessionState {
  final List<TrainingSession> training_sessions;
  final Map<int, DownloadStatus> downloadStatus;

  const TrainingSessionLoaded({required this.training_sessions, required this.downloadStatus});

  @override
  List<Object?> get props => [training_sessions, downloadStatus];
}

// Represents state during an active download
class TrainingSessionDownloading extends TrainingSessionState {
  final List<TrainingSession> training_sessions;
  final Map<int, DownloadStatus> downloadStatus; // Updated status map
  final Map<int, double> downloadProgress; // Progress map
  final int downloadingTrainingSessionId; // ID being downloaded

  const TrainingSessionDownloading({
    required this.training_sessions,
    required this.downloadStatus,
    required this.downloadProgress,
    required this.downloadingTrainingSessionId,
  });

  @override
  List<Object?> get props => [training_sessions, downloadStatus, downloadProgress, downloadingTrainingSessionId];
}

// Represents an error state (fetching or downloading)
class TrainingSessionError extends TrainingSessionState {
  final String message;
  final List<TrainingSession> training_sessions; // Keep training_sessions if possible
  final Map<int, DownloadStatus> downloadStatus;

  const TrainingSessionError({
    required this.message,
    required this.training_sessions,
    required this.downloadStatus,
  });

  @override
  List<Object?> get props => [message, training_sessions, downloadStatus];
}
