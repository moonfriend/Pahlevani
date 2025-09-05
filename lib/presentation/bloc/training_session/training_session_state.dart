part of 'training_session_cubit.dart';

@immutable
abstract class TrainingSessionState extends Equatable {
  const TrainingSessionState();
}

class TrainingSessionInitial extends TrainingSessionState {
  @override
  List<Object?> get props => [];
}

// Represents general loading (fetching domainSnapShot)
class TrainingSessionLoading extends TrainingSessionState {
  final DomainSnapshot  domainSnapShot; // Keep existing domainSnapShot if available
  final Map<int, DownloadStatus> downloadStatus;

  const TrainingSessionLoading({required this.domainSnapShot, required this.downloadStatus});

  @override
  List<Object?> get props => [domainSnapShot, downloadStatus];
}

// Represents state where domainSnapShot are loaded and displayed
class TrainingSessionLoaded extends TrainingSessionState {
  final DomainSnapshot domainSnapShot;
  final Map<int, DownloadStatus> downloadStatus;

  const TrainingSessionLoaded({required this.domainSnapShot, required this.downloadStatus});

  @override
  List<Object?> get props => [domainSnapShot, downloadStatus];
}

// Represents state during an active download
class TrainingSessionDownloading extends TrainingSessionState {
  final DomainSnapshot domainSnapShot;
  final Map<int, DownloadStatus> downloadStatus; // Updated status map
  final Map<int, double> downloadProgress; // Progress map
  final int downloadingTrainingSessionId; // ID being downloaded

  const TrainingSessionDownloading({
    required this.domainSnapShot,
    required this.downloadStatus,
    required this.downloadProgress,
    required this.downloadingTrainingSessionId,
  });

  @override
  List<Object?> get props => [domainSnapShot, downloadStatus, downloadProgress, downloadingTrainingSessionId];
}

// Represents an error state (fetching or downloading)
class TrainingSessionError extends TrainingSessionState {
  final String message;
  final DomainSnapshot domainSnapShot; // Keep domainSnapShot if possible
  final Map<int, DownloadStatus> downloadStatus;

  const TrainingSessionError({
    required this.message,
    required this.domainSnapShot,
    required this.downloadStatus,
  });

  @override
  List<Object?> get props => [message, domainSnapShot, downloadStatus];
}
