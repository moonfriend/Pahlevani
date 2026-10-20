import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';

/// Audio handler wired to the OS media session (lock screen / notification card).
///
/// The handler has two distinct call paths:
///
///   1. **Cubit path** — [JustAudioPlayerService] calls [player] methods directly
///      then calls [syncPlaybackState] so the notification stays in sync.
///   2. **Notification path** — the OS calls the [BaseAudioHandler] overrides
///      ([play], [pause], [seek], [skipToNext], [skipToPrevious]). These ONLY
///      forward a [NotificationCommand]; the cubit (the single authority over
///      playback) acts on it through path 1.
///
/// The notification path must not drive the engine itself: when it did, the
/// app and the OS diverged — just_audio's play() future completes only when
/// playback next stops, so a lock-screen play reached the cubit late, and a
/// lock-screen seek moved the audio without the cubit's timeline or the video
/// knowing.
class PahlevaniAudioHandler extends BaseAudioHandler
    with SeekHandler
    implements PlayerNotificationService {
  final _player = AudioPlayer();
  final _commandController = StreamController<NotificationCommand>.broadcast();

  AudioPlayer get player => _player;

  PahlevaniAudioHandler() {
    // Forward processing-state changes (loading / buffering) automatically.
    _player.playbackEventStream.listen((_) => syncPlaybackState());
  }

  // ── PlayerNotificationService ───────────────────────────────────────────────

  @override
  void update({
    required String trackTitle,
    String? artUri,
    required bool isPlaying,
    Duration? duration,
  }) {
    mediaItem.add(MediaItem(
      id: trackTitle,
      title: trackTitle,
      artUri: artUri != null
          ? (artUri.startsWith('http://') || artUri.startsWith('https://')
              ? Uri.tryParse(artUri)
              : Uri.file(artUri))
          : null,
      duration: duration,
    ));
    syncPlaybackState(playing: isPlaying);
  }

  @override
  Stream<NotificationCommand> get commands => _commandController.stream;

  // ── Called by JustAudioPlayerService after cubit-initiated operations ───────

  void syncPlaybackState({bool? playing}) {
    final isPlaying = playing ?? _player.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (isPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(_player.processingState),
      playing: isPlaying,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: 1.0,
    ));
  }

  // ── BaseAudioHandler — OS / notification button presses ────────────────────

  @override
  Future<void> play() async => _commandController.add(NotificationCommand.play);

  @override
  Future<void> pause() async =>
      _commandController.add(NotificationCommand.pause);

  @override
  Future<void> skipToNext() async {
    _commandController.add(NotificationCommand.skipNext);
  }

  @override
  Future<void> skipToPrevious() async {
    _commandController.add(NotificationCommand.skipPrev);
  }

  @override
  Future<void> seek(Duration position) async =>
      _commandController.add(NotificationCommand.seek(position));

  // ── Helpers ─────────────────────────────────────────────────────────────────

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    syncPlaybackState(playing: false);
  }
}
