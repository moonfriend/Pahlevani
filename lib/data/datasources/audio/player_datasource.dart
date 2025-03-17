import 'package:audioplayers/audioplayers.dart';

import '../../../domain/entities/audio/audio_track.dart';

/// Data source for managing audio playback
abstract class PlayerDataSource {
  /// Play an audio track
  Future<void> play(AudioTrack track);

  /// Pause playback
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

  /// Release resources
  Future<void> dispose();
}

/// Implementation of [PlayerDataSource] using audioplayers package
class PlayerDataSourceImpl implements PlayerDataSource {
  final AudioPlayer _audioPlayer;

  PlayerDataSourceImpl({
    AudioPlayer? audioPlayer,
  }) : _audioPlayer = audioPlayer ?? AudioPlayer();

  @override
  Future<void> play(AudioTrack track) async {
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(track.filePath));
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  @override
  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  @override
  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  @override
  Future<Duration?> getCurrentPosition() async {
    return await _audioPlayer.getCurrentPosition();
  }

  @override
  Future<Duration?> getDuration() async {
    return await _audioPlayer.getDuration();
  }

  @override
  Stream<Duration> get positionStream => _audioPlayer.onPositionChanged;

  @override
  Stream<Duration> get durationStream => _audioPlayer.onDurationChanged;

  @override
  Future<void> setLoopMode(bool loop) async {
    await _audioPlayer.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
  }

  @override
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
