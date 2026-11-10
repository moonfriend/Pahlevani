/// The player's single source of time for the current move.
///
/// A move can last longer than one audio clip: the engine loops a single
/// clip, or plays a queue of clips (a Morshed's variants) one after another,
/// and its position restarts at 0 whenever a clip starts. This clock turns
/// those raw engine readings into one continuous "logical" timeline:
///
///     logical = (length of the clips finished so far) + current engine position
///
/// Because it is derived purely from engine readings, it stops whenever the
/// audio is paused or buffering (no readings arrive) and never loses time
/// when a reading arrives late — unlike a counter that adds a fixed amount
/// per timer tick. Pure Dart: no Flutter, streams or timers.
class PlaybackClock {
  /// Clip lengths by queue index, as the engine reported them.
  final List<Duration?> _lengths = [];
  int _index = 0;
  Duration _completed = Duration.zero;
  Duration _lastEnginePosition = Duration.zero;
  int _wrapCount = 0;
  bool _started = false;

  /// How many times the engine has moved on by itself since [start] —
  /// looped a single clip or started the next clip of the queue; not seeks,
  /// not [restartLoop]. Lets a caller notice it (e.g. to realign the demo
  /// video) by comparing before and after a reading.
  int get wrapCount => _wrapCount;

  /// Whether [start] has been called for the current move.
  bool get isStarted => _started;

  /// Queue index of the clip the last reading belonged to.
  int get index => _index;

  /// Current logical position (finished clips + last engine reading).
  Duration get logicalPosition => _completed + _lastEnginePosition;

  /// The length the engine reported for the clip at [index], if any.
  Duration? clipLength(int index) =>
      index < _lengths.length ? _lengths[index] : null;

  /// Begins timing a new move of [clipCount] clips, once the engine has
  /// reported the length of the clip at [index].
  void start(Duration clipLength, {int index = 0, int clipCount = 1}) {
    reset();
    _lengths.addAll(List<Duration?>.filled(clipCount, null));
    _started = true;
    _index = index;
    setClipLength(index, clipLength);
  }

  /// Records the engine-reported length of the clip at [index].
  void setClipLength(int index, Duration length) {
    if (index < _lengths.length) _lengths[index] = length;
  }

  /// Forgets everything — call when a new source starts loading.
  void reset() {
    _lengths.clear();
    _started = false;
    _index = 0;
    _wrapCount = 0;
    _completed = Duration.zero;
    _lastEnginePosition = Duration.zero;
  }

  /// Feeds one engine position reading (inside the clip at queue [index])
  /// and returns the logical position.
  ///
  /// A new [index] is the engine moving on to another clip: the finished one
  /// is added in full (its reported length, else its last reading). Within
  /// the same clip, a drop of more than half the clip can only be the engine
  /// looping it (our own seeks go through [jumpTo] / [restartLoop], which
  /// update the baseline first). Smaller backward steps are engine jitter.
  Duration onEnginePosition(Duration enginePosition, {int index = 0}) {
    if (!_started) return enginePosition;
    if (index != _index) {
      final finished = clipLength(_index) ?? _lastEnginePosition;
      setClipLength(_index, finished);
      _completed += finished;
      _index = index;
      _wrapCount++;
    } else {
      final clip = clipLength(index);
      if (clip != null && _lastEnginePosition - enginePosition > clip ~/ 2) {
        _completed += clip;
        _wrapCount++;
      }
    }
    _lastEnginePosition = enginePosition;
    return logicalPosition;
  }

  /// Moves the timeline to [clipPosition] inside the clip at [index], with
  /// [completed] already played before it (see ClipSequence.locate). Not
  /// counted as the engine moving on.
  void jumpTo({
    required int index,
    required Duration clipPosition,
    required Duration completed,
  }) {
    _index = index;
    _completed = completed;
    _lastEnginePosition = clipPosition;
  }

  /// Records that we restarted the clip ourselves after [loopLength] (used
  /// when the prescribed reps are fewer than the clip's own, so the "loop"
  /// is shorter than the clip). The engine is expected to be at 0 next.
  void restartLoop(Duration loopLength) {
    _completed += loopLength;
    _lastEnginePosition = Duration.zero;
  }
}
