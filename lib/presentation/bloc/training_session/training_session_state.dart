part of 'training_session_cubit.dart';

sealed class TrainingSessionState extends Equatable {
  const TrainingSessionState();
  @override
  List<Object?> get props => [];
}

class TrainingSessionInitial extends TrainingSessionState {
  @override
  List<Object?> get props => [];
}

// Represents general loading (fetching domainSnapShot)
class TrainingSessionLoading extends TrainingSessionState {
  final TrainingSessionsUiModel uiModel;
  const TrainingSessionLoading({required this.uiModel});

  @override
  List<Object?> get props => [uiModel];
}

// Represents state where domainSnapShot are loaded and displayed
class TrainingSessionLoaded extends TrainingSessionState {
  final TrainingSessionsUiModel uiModel;

  const TrainingSessionLoaded({required this.uiModel});

  @override
  List<Object?> get props => [uiModel];
}

// Represents state during an active download
class TrainingSessionDownloading extends TrainingSessionState {
  final TrainingSessionsUiModel uiModel;
  final Map<int, double> downloadProgress; // Progress map
  final int downloadingTrainingSessionId; // ID being downloaded

  const TrainingSessionDownloading({
    required this.uiModel,
    required this.downloadProgress,
    required this.downloadingTrainingSessionId,
  });

  @override
  List<Object?> get props =>
      [uiModel, downloadProgress, downloadingTrainingSessionId];
}

// Represents an error state (fetching or downloading)
class TrainingSessionError extends TrainingSessionState {
  final String message;
  final TrainingSessionsUiModel uiModel;

  const TrainingSessionError({
    required this.message,
    required this.uiModel,
  });

  @override
  List<Object?> get props => [message, uiModel];
}
