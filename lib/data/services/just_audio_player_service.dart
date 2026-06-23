import 'package:just_audio/just_audio.dart';
import 'package:pahlevani/data/services/pahlevani_audio_handler.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';

/// [AudioPlayerService] implementation backed by [just_audio].
///
/// All operations go directly to the [AudioPlayer] inside the handler so that
/// the foreground service lifecycle and notification state stay in sync.
/// After mutating playback state, we call [handler.syncPlaybackState] so the
/// OS notification reflects the change.
class JustAudioPlayerService implements AudioPlayerService {
  final PahlevaniAudioHandler _handler;

  JustAudioPlayerService(this._handler);

  AudioPlayer get _player => _handler.player;

  @override
  Stream<Duration> get onPositionChanged => _player.positionStream;

  @override
  Stream<Duration> get onDurationChanged =>
      _player.durationStream.where((d) => d != null).map((d) => d!);

  @override
  Future<void> play(String path) async {
    await _setSource(path);
    await _player.play();
    _handler.syncPlaybackState(playing: true);
  }

  @override
  Future<void> setSource(String path) async {
    await _setSource(path);
    _handler.syncPlaybackState(playing: false);
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _handler.syncPlaybackState(playing: false);
  }

  @override
  Future<void> resume() async {
    await _player.play();
    _handler.syncPlaybackState(playing: true);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _handler.syncPlaybackState(playing: false);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setLooping(bool loop) =>
      _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);

  // _player is the singleton PahlevaniAudioHandler's player, not owned by
  // this wrapper — disposing it here would kill audio for every future
  // session. Stop playback instead; the player itself lives for the app's
  // lifetime.
  @override
  Future<void> dispose() => _player.stop();

  Future<void> _setSource(String path) async {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      await _player.setUrl(path);
    } else {
      await _player.setFilePath(path);
    }
  }
}
