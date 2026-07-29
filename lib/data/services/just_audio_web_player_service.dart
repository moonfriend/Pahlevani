import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';

/// [AudioPlayerService] implementation backed by [just_audio], used only on
/// Flutter Web.
///
/// `audioplayers_web`'s `<audio>` element unconditionally sets
/// `crossOrigin = 'anonymous'` (required for its stereo-panning Web Audio
/// graph — see audioplayers_web's `wrapped_player.dart`), which makes the
/// browser reject cross-origin media unless the server sends CORS headers.
/// `just_audio_web` only sets `crossOrigin` when explicitly asked
/// (`setWebCrossOrigin`, never called here) and never builds a Web Audio
/// graph, so a plain cross-origin `<audio>` load works with no server-side
/// CORS configuration needed — confirmed by direct reproduction in a real
/// browser: `audioplayers_web`-style `crossOrigin='anonymous'` load of an R2
/// URL fails with `MEDIA_ERR_SRC_NOT_SUPPORTED`; the same URL with no
/// `crossOrigin` set plays fine.
///
/// Owns its own [AudioPlayer] instance (no [PahlevaniAudioHandler] — that
/// class exists for OS lock-screen/notification integration via
/// `audio_service`, which this app does not initialize on web). No
/// notification sync is needed here; web uses [NoOpNotificationService]
/// already, same as Linux desktop.
///
/// `play()`/`resume()` contract matches [JustAudioPlayerService]: just_audio's
/// `AudioPlayer.play()` future only completes when playback STOPS, so it must
/// never be awaited — fire it and return once dispatched.
class JustAudioWebPlayerService implements AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

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
    _firePlay();
  }

  @override
  Future<void> setSource(String path) => _setSource(path);

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() async {
    _firePlay();
  }

  void _firePlay() {
    unawaited(_player.play().catchError((Object e, StackTrace st) {
      AppLogger.w('just_audio (web) play() failed', error: e, stackTrace: st);
    }));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setLooping(bool loop) =>
      _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);

  @override
  Future<void> dispose() => _player.dispose();

  /// True when [path] is a remote URL (dispatched via `setUrl`) rather than
  /// a local file path (dispatched via `setFilePath`).
  static bool isRemoteUrl(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  Future<void> _setSource(String path) async {
    if (isRemoteUrl(path)) {
      await _player.setUrl(path);
    } else {
      await _player.setFilePath(path);
    }
  }
}
