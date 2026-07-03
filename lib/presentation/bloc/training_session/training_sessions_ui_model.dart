import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/entities/download_status.dart';
import 'package:pahlevani/presentation/widgets/training_session/session_tools.dart';

class TrainingSessionsUiModel extends Equatable {
  const TrainingSessionsUiModel({
    required this.trainingSessions,
    required this.downloadStatuses,
    this.sessionItemCounts = const {},
    this.sessionDurations = const {},
    this.sessionTools = const {},
  });

  final List<TrainingSession> trainingSessions;
  final Map<int, DownloadStatus> downloadStatuses;

  /// Number of items (exercises) per session id.
  final Map<int, int> sessionItemCounts;

  /// Total duration in seconds per session id (null entries = duration unknown).
  final Map<int, int> sessionDurations;

  /// Tools/equipment each session requires (derived from its disciplines).
  final Map<int, List<SessionTool>> sessionTools;

  TrainingSessionsUiModel copyWith({
    List<TrainingSession>? trainingSessions,
    Map<int, DownloadStatus>? downloadStatuses,
    Map<int, int>? sessionItemCounts,
    Map<int, int>? sessionDurations,
    Map<int, List<SessionTool>>? sessionTools,
  }) {
    return TrainingSessionsUiModel(
      trainingSessions: trainingSessions ?? this.trainingSessions,
      downloadStatuses: downloadStatuses ?? this.downloadStatuses,
      sessionItemCounts: sessionItemCounts ?? this.sessionItemCounts,
      sessionDurations: sessionDurations ?? this.sessionDurations,
      sessionTools: sessionTools ?? this.sessionTools,
    );
  }

  @override
  List<Object?> get props => [
        trainingSessions,
        downloadStatuses,
        sessionItemCounts,
        sessionDurations,
        sessionTools,
      ];
}
