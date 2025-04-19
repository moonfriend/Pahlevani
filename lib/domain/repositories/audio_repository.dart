import '../entities/audio/audio_track.dart';

/// Interface for the audio repository
abstract class AudioRepository {
  /// Get a list of all available tracks as AudioTrack objects
  Future<List<AudioTrack>> getAudioTracks();
}
