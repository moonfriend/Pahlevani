import 'dart:async';
import 'dart:math' as math;

import 'package:pahlevani/domain/player/move_timeline.dart';

/// The demo video, as far as [VideoFollower] needs it — a seam so the sync
/// logic is testable without a real video player.
abstract interface class FollowedVideo {
  Duration get duration;
  bool get isPlaying;
  Future<Duration> position();
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
}

/// Where the demo video must be when the audio is [clipMs] into its clip and
/// [moveMs] into the move.
///
/// [offsetMs] shifts the video so its main beat ("sarzarb") lines up with
/// the recording's (video anchor − audio anchor). A negative offset means
/// the video's beat comes earlier than the audio's: at the very start of a
/// move the video waits at frame 0 until the audio has played that far
/// ([holdUntilMoveMs], in audio time — so a pause doesn't break it). Once
/// the move has looped, that stretch maps to the tail of the video's
/// previous loop instead, so the video keeps moving rather than freezing at
/// every loop.
({int seekToMs, int? holdUntilMoveMs}) videoAlignment({
  required int clipMs,
  required int moveMs,
  required int? offsetMs,
  required int videoMs,
}) {
  if (videoMs <= 0) return (seekToMs: 0, holdUntilMoveMs: null);
  final offset = offsetMs ?? 0;
  if (moveMs + offset < 0) return (seekToMs: 0, holdUntilMoveMs: -offset);
  final raw = clipMs + offset;
  return (
    seekToMs: ((raw % videoMs) + videoMs) % videoMs,
    holdUntilMoveMs: null
  );
}

/// Keeps the muted demo video in step with the move's audio.
///
/// Follows the [MoveTimeline] directly — its events (start, seek, loop) and,
/// during a hold, its progress — instead of page rebuilds, so it reacts
/// exactly once per thing that happened. The session's play/pause intent
/// comes in through [setPlaying]. Owned by the video widget: one follower
/// per move's video.
class VideoFollower {
  /// Drift below this after an audio loop is left alone: a native video seek
  /// is a visible hiccup on Android, worse than a few frames of drift.
  static const loopTolerance = Duration(milliseconds: 120);

  final MoveTimeline _timeline;
  final int? _offsetMs;
  late final StreamSubscription<MoveEvent> _eventsSub;
  late final StreamSubscription<MoveProgress> _progressSub;

  FollowedVideo? _video;
  bool _playing = false;
  bool _disposed = false;

  /// Set while the video waits at frame 0 for the audio (negative offset).
  int? _holdUntilMoveMs;

  bool _seekInFlight = false;
  int? _pendingSeekMs;

  VideoFollower({required MoveTimeline timeline, required int? startOffsetMs})
      : _timeline = timeline,
        _offsetMs = startOffsetMs {
    _eventsSub = timeline.events.listen(_onEvent);
    _progressSub = timeline.progress.listen(_onProgress);
  }

  /// The video is ready to be commanded: align it to where the audio is now
  /// (the move may already be playing when the video finishes loading).
  void attach(FollowedVideo video) {
    if (_disposed) return;
    _video = video;
    unawaited(_align(_timeline.current));
  }

  void setPlaying(bool playing) {
    _playing = playing;
    unawaited(_applyPlaying());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_eventsSub.cancel());
    unawaited(_progressSub.cancel());
  }

  void _onEvent(MoveEvent event) {
    switch (event) {
      case MoveStarted():
        unawaited(_align(MoveProgress.none));
      case MoveSeeked():
        unawaited(_align(_timeline.current));
      case MoveLooped():
        unawaited(_realignIfDrifted(_timeline.current));
      case MoveTargetReached():
        break;
    }
  }

  void _onProgress(MoveProgress progress) {
    final hold = _holdUntilMoveMs;
    if (hold == null || progress.position.inMilliseconds < hold) return;
    _holdUntilMoveMs = null;
    unawaited(_applyPlaying());
  }

  ({int seekToMs, int? holdUntilMoveMs})? _alignmentFor(MoveProgress at) {
    final video = _video;
    if (video == null) return null;
    return videoAlignment(
      clipMs: at.clipPosition.inMilliseconds,
      moveMs: at.position.inMilliseconds,
      offsetMs: _offsetMs,
      videoMs: video.duration.inMilliseconds,
    );
  }

  Future<void> _align(MoveProgress at) async {
    final target = _alignmentFor(at);
    if (target == null || _disposed) return;
    _holdUntilMoveMs = target.holdUntilMoveMs;
    // Stop first when holding, so the video doesn't run on during the wait.
    if (_holdUntilMoveMs != null) await _applyPlaying();
    await _seek(target.seekToMs);
    await _applyPlaying();
  }

  Future<void> _realignIfDrifted(MoveProgress at) async {
    final video = _video;
    final target = _alignmentFor(at);
    if (video == null || target == null || _disposed) return;
    final videoMs = video.duration.inMilliseconds;
    final actual = (await video.position()).inMilliseconds;
    final diff = (actual - target.seekToMs).abs();
    // Positions wrap around the video's own loop.
    final drift = videoMs > 0 ? math.min(diff, videoMs - diff) : diff;
    if (drift < loopTolerance.inMilliseconds) return;
    await _align(at);
  }

  /// At most one native seek in flight; targets arriving meanwhile replace
  /// each other and only the latest is applied. A seek-bar drag sends many
  /// per second, and each native seek is expensive (a re-buffer on Android).
  Future<void> _seek(int targetMs) async {
    final video = _video;
    if (video == null || _disposed) return;
    if (_seekInFlight) {
      _pendingSeekMs = targetMs;
      return;
    }
    _seekInFlight = true;
    try {
      await video.seekTo(Duration(milliseconds: targetMs));
    } finally {
      _seekInFlight = false;
    }
    final next = _pendingSeekMs;
    _pendingSeekMs = null;
    if (next != null && !_disposed) await _seek(next);
  }

  Future<void> _applyPlaying() async {
    final video = _video;
    if (video == null || _disposed) return;
    final shouldPlay = _playing && _holdUntilMoveMs == null;
    if (shouldPlay && !video.isPlaying) {
      await video.play();
    } else if (!shouldPlay && video.isPlaying) {
      await video.pause();
    }
  }
}
