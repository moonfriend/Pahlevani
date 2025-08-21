import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/pages/training_session/download_status.dart';

/// Interface for fetching and managing training_session data and downloads.
abstract class TrainingSessionRepository {
  /// Fetches the list of training_sessions (e.g., from a remote source).
  Future<List<TrainingSession>> getTrainingSessions();

  /// Gets the initial download status for all known training_sessions (e.g., from local storage).
  Future<Map<int, DownloadStatus>> getInitialDownloadStatuses();

  /// Initiates the download process for a specific training_session.
  /// Returns a stream of download progress (0.0 to 1.0) or throws an error.
  Stream<double> downloadTrainingSession(TrainingSession training_session);

  /// Checks if a specific training_session is considered fully downloaded locally.
  Future<bool> isTrainingSessionDownloaded(int training_sessionId);

  /// Gets the local file path for a song if downloaded, otherwise null.
  Future<String?> getLocalSongPath(int training_sessionId, TrainingSessionItem song);

  /// Saves a training_session to the repository.
  Future<TrainingSession> saveTrainingSession(TrainingSession training_session, {Map<int, int>? repetitionsMap});

  /// Updates a training_session in the repository.
  Future<void> updateTrainingSession(TrainingSession training_session, {Map<int, int>? repetitionsMap});

  /// Deletes a training_session and its downloaded files.
  Future<void> deleteTrainingSession(int training_sessionId);
}


// todo: what we can do:
// separate repository into two or more sets: exercise repo and training session repo, and later: training program
// build on the current style: separating concerns of the audio(t_item) and audiotrack