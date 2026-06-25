import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/domain/services/player_notification_service.dart';

/// Audio handler wired to the OS media session (lock screen / notification card).
///
/// The handler has two distinct call paths:
///
///   1. **Cubit path** — [JustAudioPlayerService] calls [player] methods directly
///      then calls [syncPlaybackState] so the notification stays in sync.
///   2. **Notification path** — the OS calls the [BaseAudioHandler] overrides
///      ([play], [pause], [skipToNext], [skipToPrevious]).  These actually
///      control the player AND emit a [NotificationCommand] so the cubit can
///      update its own state.
///
/// Keeping these paths distinct avoids circular call loops.
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
  Future<void> play() async {
    AppLogger.d(
        '[player-diag] PahlevaniAudioHandler.play() (OS/notification path) entered');
    await _player.play();
    syncPlaybackState(playing: true);
    _commandController.add(NotificationCommand.play);
    AppLogger.d(
        '[player-diag] PahlevaniAudioHandler.play() returned, command forwarded');
  }

  @override
  Future<void> pause() async {
    AppLogger.d(
        '[player-diag] PahlevaniAudioHandler.pause() (OS/notification path) entered');
    await _player.pause();
    syncPlaybackState(playing: false);
    _commandController.add(NotificationCommand.pause);
    AppLogger.d(
        '[player-diag] PahlevaniAudioHandler.pause() returned, command forwarded');
  }

  @override
  Future<void> skipToNext() async {
    _commandController.add(NotificationCommand.skipNext);
  }

  @override
  Future<void> skipToPrevious() async {
    _commandController.add(NotificationCommand.skipPrev);
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    syncPlaybackState();
  }

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
