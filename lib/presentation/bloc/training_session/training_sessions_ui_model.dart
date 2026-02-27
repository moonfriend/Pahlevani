
import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

class TrainingSessionsUiModel extends Equatable {
  const TrainingSessionsUiModel({
    required this.trainingSessions,
    required this.downloadStatuses,
    this.sessionItemCounts = const {},
  });

  final List<TrainingSession> trainingSessions;
  final Map<int, DownloadStatus> downloadStatuses;
  /// Number of items (exercises) per session id.
  final Map<int, int> sessionItemCounts;

  TrainingSessionsUiModel copyWith({
    List<TrainingSession>? trainingSessions,
    Map<int, DownloadStatus>? downloadStatuses,
    Map<int, int>? sessionItemCounts,
  }) {
    return TrainingSessionsUiModel(
      trainingSessions: trainingSessions ?? this.trainingSessions,
      downloadStatuses: downloadStatuses ?? this.downloadStatuses,
      sessionItemCounts: sessionItemCounts ?? this.sessionItemCounts,
    );
  }

  @override
  List<Object?> get props => [trainingSessions, downloadStatuses, sessionItemCounts];
}
