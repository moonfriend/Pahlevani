import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/data/services/pahlevani_audio_handler.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';

/// [AudioPlayerService] implementation backed by [just_audio].
///
/// All operations go directly to the [AudioPlayer] inside the handler so that
/// the foreground service lifecycle and notification state stay in sync.
/// After mutating playback state, we call [handler.syncPlaybackState] so the
/// OS notification reflects the change.
///
/// IMPORTANT — `play()`/`resume()` contract: these return once playback has been
/// *dispatched* (started), NOT when it ends. just_audio's [AudioPlayer.play]
/// returns a future that only completes when playback STOPS (pause/complete),
/// so we must NOT await it — doing so would block every caller for the entire
/// duration of playback and resurrect a later pause as a stale "playing" emit.
/// We fire the play command and return immediately, matching the prompt
/// dispatch semantics that [AudioPlayersServiceImpl] (Linux/Web) already has.
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
  Stream<bool> get onPlayingChanged => _player.playingStream;

  @override
  Future<void> play(String path) async {
    await _setSource(path);
    // Fire the play command but do NOT await its future — see the class doc.
    // just_audio's play() future completes on STOP, not on START. We still
    // attach an error handler so a failed playback fails loud instead of
    // surfacing as an uncaught async error.
    _firePlay();
    _handler.syncPlaybackState(playing: true);
  }

  @override
  Future<void> setSource(String path) async {
    await _setSource(path);
    _handler.syncPlaybackState(playing: false);
  }

  @override
  Future<void> pause() async {
    AppLogger.d('[player-diag] JustAudioPlayerService.pause() entered, '
        'engine playing=${_player.playing}');
    await _player.pause();
    AppLogger.d('[player-diag] JustAudioPlayerService.pause() returned, '
        'engine playing=${_player.playing}');
    _handler.syncPlaybackState(playing: false);
  }

  @override
  Future<void> resume() async {
    AppLogger.d('[player-diag] JustAudioPlayerService.resume() entered, '
        'engine playing=${_player.playing}');
    // Fire-and-forget: awaiting play() would block until the NEXT pause and
    // then run syncPlaybackState(true) at exactly the wrong moment. See class doc.
    _firePlay();
    _handler.syncPlaybackState(playing: true);
    AppLogger.d('[player-diag] JustAudioPlayerService.resume() dispatched, '
        'engine playing=${_player.playing}');
  }

  /// Issues `_player.play()` without awaiting completion (it resolves on stop),
  /// attaching an error handler so a playback failure is logged rather than
  /// raised as an uncaught async error.
  void _firePlay() {
    unawaited(_player.play().catchError((Object e, StackTrace st) {
      AppLogger.w('just_audio play() failed', error: e, stackTrace: st);
    }));
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
