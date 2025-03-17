import '../entities/audio/audio_track.dart';
import '../entities/track.dart';

/// Interface for the audio repository
abstract class AudioRepository {
  /// Get a list of all available tracks
  Future<List<Track>> getTracks();

  /// Get a specific track by index
  Future<Track?> getTrackByIndex(int index);

  /// Get a list of all available tracks as AudioTrack objects
  Future<List<AudioTrack>> getAudioTracks();

  /// Get a specific track by index as AudioTrack
  Future<AudioTrack?> getAudioTrackByIndex(int index);
}
