import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';

/// `audioplayers`-backed implementation of [AudioPlayerService].
/// Source-type detection (URL / local file / asset) lives here so the cubit
/// stays free of any `audioplayers` imports.
class AudioPlayersServiceImpl implements AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  @override
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  @override
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  @override
  Stream<bool> get onPlayingChanged =>
      _player.onPlayerStateChanged.map((s) => s == PlayerState.playing);

  @visibleForTesting
  static Source sourceFor(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return UrlSource(path);
    } else if (path.startsWith('/')) {
      return DeviceFileSource(path);
    } else if (path.startsWith('assets/')) {
      return AssetSource(path.replaceFirst('assets/', ''));
    } else {
      return AssetSource(path);
    }
  }

  @override
  Future<void> play(String path) => _player.play(sourceFor(path));

  @override
  Future<void> setSource(String path) => _player.setSource(sourceFor(path));

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setLooping(bool loop) =>
      _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);

  @override
  Future<void> dispose() => _player.dispose();
}
