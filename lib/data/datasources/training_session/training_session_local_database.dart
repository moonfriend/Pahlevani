import 'package:hive_flutter/hive_flutter.dart';
import 'package:pahlevani/data/models/hive_models.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';

/// Service for handling local database operations using Hive
class TrainingSessionLocalDatabase {
  static const String _training_sessionBoxName = 'training_sessions';
  static const String _lastSyncKey = 'last_sync';

  /// Initialize Hive and register adapters
  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(HiveTrainingSessionAdapter());
    Hive.registerAdapter(HiveAudioAdapter());
    Hive.registerAdapter(HiveTrainingSessionItemAdapter());
  }

  /// Get the training_sessions box
  Future<Box<HiveTrainingSession>> getTrainingSessionBox() async {
    return await Hive.openBox<HiveTrainingSession>(_training_sessionBoxName);
  }

  /// Get the settings box for last sync time
  Future<Box> _getSettingsBox() async {
    return await Hive.openBox('settings');
  }

  static const String _trackBoxName = 'tracks';
  static const String _training_sessionSongBoxName = 'training_session_items';

  Future<Box<HiveExercise>> _getTrackBox() async {
    return await Hive.openBox<HiveExercise>(_trackBoxName);
  }

  Future<Box<HiveTrainingSessionItem>> getTrainingSessionSongBox() async {
    return await Hive.openBox<HiveTrainingSessionItem>(_training_sessionSongBoxName);
  }

  /// Save training_sessions to local database
  Future<void> saveTrainingSessions(List<TrainingSession> training_sessions) async {
    final box = await getTrainingSessionBox();
    final settingsBox = await _getSettingsBox();

    // Convert domain models to Hive models
    final hiveTrainingSessions = training_sessions.map((p) => HiveTrainingSession.fromDomain(p)).toList();

    // Save all training_sessions
    await box.clear(); // Clear existing data
    await box.addAll(hiveTrainingSessions);

    // Update last sync time
    await settingsBox.put(_lastSyncKey, DateTime.now().toIso8601String());
  }

  /// Get all training_sessions from local database
  Future<List<TrainingSession>> getTrainingSessions() async {
    final box = await getTrainingSessionBox();
    return box.values.map((p) => p.toDomain()).toList();
  }

  /// Save tracks to local database
  /// [tracks] is a list of HiveAudio objects representing the tracks table.
  Future<void> saveTracks(List<HiveExercise> tracks) async {
    final box = await _getTrackBox();
    await box.clear();
    await box.addAll(tracks);
  }

  /// Get all tracks from local database
  /// Returns a list of HiveAudio objects.
  Future<List<HiveExercise>> getTracks() async {
    final box = await _getTrackBox();
    return box.values.toList();
  }

  /// Save training_session_items to local database
  /// [training_sessionSongs] is a list of HiveTrainingSessionSong objects representing the training_session_items table.
  Future<void> saveTrainingSessionSongs(List<HiveTrainingSessionItem> training_sessionSongs) async {
    final box = await getTrainingSessionSongBox();
    await box.clear();
    await box.addAll(training_sessionSongs);
  }

  /// Get all training_session_items from local database
  /// Returns a list of HiveTrainingSessionSong objects.
  Future<List<HiveTrainingSessionItem>> getTrainingSessionSongs() async {
    final box = await getTrainingSessionSongBox();
    return box.values.toList();
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    final settingsBox = await _getSettingsBox();
    final lastSyncStr = settingsBox.get(_lastSyncKey) as String?;
    if (lastSyncStr == null) return null;
    return DateTime.parse(lastSyncStr);
  }

  /// Check if local data is stale (older than 180 days)
  Future<bool> isDataStale() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastSync);
    return difference.inDays >= 180;
  }

  /// Clear all local data
  Future<void> clearAll() async {
    final box = await getTrainingSessionBox();
    final settingsBox = await _getSettingsBox();
    final trackBox = await _getTrackBox();
    final training_sessionSongBox = await getTrainingSessionSongBox();
    await box.clear();
    await settingsBox.clear();
    await trackBox.clear();
    await training_sessionSongBox.clear();
  }
}
