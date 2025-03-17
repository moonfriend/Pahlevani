import '../entities/audio/audio_track.dart';

/// Repository interface for player operations
abstract class PlayerRepository {
  /// Play the audio track
  Future<void> play(AudioTrack track);

  /// Pause the current playback
  Future<void> pause();

  /// Resume playback
  Future<void> resume();

  /// Stop playback
  Future<void> stop();

  /// Seek to a specific position
  Future<void> seekTo(Duration position);

  /// Get current playback position
  Future<Duration?> getCurrentPosition();

  /// Get total duration of the current track
  Future<Duration?> getDuration();

  /// Stream of current position updates
  Stream<Duration> get positionStream;

  /// Stream of duration updates
  Stream<Duration> get durationStream;

  /// Set loop mode
  Future<void> setLoopMode(bool loop);
}
