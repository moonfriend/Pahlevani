
import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

class TrainingSessionsUiModel extends Equatable {
  const TrainingSessionsUiModel({
    required this.trainingSessions,
    required this.downloadStatuses,
  });

  final List<TrainingSession> trainingSessions;
  final Map<int, DownloadStatus> downloadStatuses;

  TrainingSessionsUiModel copyWith({
    List<TrainingSession>? trainingSessions,
    Map<int, DownloadStatus>? downloadStatuses,
  }) {
    return TrainingSessionsUiModel(
      trainingSessions: trainingSessions ?? this.trainingSessions,
      downloadStatuses: downloadStatuses ?? this.downloadStatuses,
    );
  }

  @override
  List<Object?> get props => [trainingSessions, downloadStatuses];
}
