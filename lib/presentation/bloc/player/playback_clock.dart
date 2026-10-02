/// The player's single source of time for the current move.
///
/// A move can last longer than its audio clip (prescribed reps > the clip's
/// own reps), so the engine loops the clip and its position restarts at 0 on
/// every loop. This clock turns those raw engine readings into one continuous
/// "logical" timeline:
///
///     logical = (length of completed loops) + current engine position
///
/// Because it is derived purely from engine readings, it stops whenever the
/// audio is paused or buffering (no readings arrive) and never loses time
/// when a reading arrives late — unlike a counter that adds a fixed amount
/// per timer tick. Pure Dart: no Flutter, streams or timers.
class PlaybackClock {
  Duration? _clip;
  Duration _completedLoops = Duration.zero;
  Duration _lastEnginePosition = Duration.zero;

  /// Whether [start] has been called for the current move.
  bool get isStarted => _clip != null;

  /// Current logical position (completed loops + last engine reading).
  Duration get logicalPosition => _completedLoops + _lastEnginePosition;

  /// Begins timing a new move whose audio clip is [clipDuration] long.
  void start(Duration clipDuration) {
    _clip = clipDuration;
    _completedLoops = Duration.zero;
    _lastEnginePosition = Duration.zero;
  }

  /// Forgets everything — call when a new source starts loading.
  void reset() {
    _clip = null;
    _completedLoops = Duration.zero;
    _lastEnginePosition = Duration.zero;
  }

  /// Feeds one engine position reading and returns the logical position.
  ///
  /// A drop of more than half a clip can only be the engine wrapping back to
  /// the start of the clip (our own seeks go through [seekTo] / [restartLoop],
  /// which update the baseline first), so it is counted as one completed loop.
  /// Smaller backward steps are engine jitter and are not.
  Duration onEnginePosition(Duration enginePosition) {
    final clip = _clip;
    if (clip == null) return enginePosition;
    if (_lastEnginePosition - enginePosition > clip ~/ 2) {
      _completedLoops += clip;
    }
    _lastEnginePosition = enginePosition;
    return logicalPosition;
  }

  /// Moves the logical timeline to [logical] and returns where the engine
  /// must seek to within the clip. Not counted as a loop.
  Duration seekTo(Duration logical) {
    final clip = _clip;
    if (clip == null || clip <= Duration.zero) return logical;
    final loops = logical.inMilliseconds ~/ clip.inMilliseconds;
    _completedLoops = clip * loops;
    _lastEnginePosition = logical - _completedLoops;
    return _lastEnginePosition;
  }

  /// Records that we restarted the clip ourselves after [loopLength] (used
  /// when the prescribed reps are fewer than the clip's own, so the "loop"
  /// is shorter than the clip). The engine is expected to be at 0 next.
  void restartLoop(Duration loopLength) {
    _completedLoops += loopLength;
    _lastEnginePosition = Duration.zero;
  }
}
