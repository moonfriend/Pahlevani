/// Platform-agnostic audio playback abstraction: just_audio on Android, iOS
/// and the web, audioplayers on the Linux desktop dev build; tests inject a
/// fake. Plays a queue of one or more paths (a move's recordings).
abstract class AudioPlayerService {
  /// Fires whenever the playback position advances.
  Stream<Duration> get onPositionChanged;

  /// Fires when the player learns the duration of the current source.
  Stream<Duration> get onDurationChanged;

  /// Fires whenever the engine's actual playing/paused state changes.
  ///
  /// NOTE: this is an *informational* signal, not an authority. It also fires
  /// for the engine's own internal transitions (e.g. stopped→playing on every
  /// loop cycle), so consumers must not blindly mirror it into their own state
  /// — doing so causes play/pause desync. The cubit owns playing-state and
  /// drives the engine, not the other way around. A future audio-focus handler
  /// may observe this stream to *raise an intent*, but must never write state
  /// directly from it.
  Stream<bool> get onPlayingChanged;

  /// Stop the current source, load [paths] as one queue, and start playing.
  ///
  /// The paths play one after another — gapless where the backend allows
  /// (just_audio preloads the next one). With looping on, a single path loops
  /// by itself and a longer queue starts over from its first path. Each path
  /// may be a remote URL (`https://…`) or an absolute local path (`/…`).
  Future<void> playQueue(List<String> paths);

  /// Stop the current source and load [paths] as one queue without starting
  /// playback.
  Future<void> setQueue(List<String> paths);

  /// Index in the current queue of the path playing now (0 for a single
  /// path). Read it together with an [onPositionChanged] reading: that
  /// position is inside this path, and [onDurationChanged] reports this
  /// path's length.
  int get currentIndex;

  /// Pause playback (preserves position).
  Future<void> pause();

  /// Resume from current position.
  Future<void> resume();

  /// Stop playback and reset position to zero.
  Future<void> stop();

  /// Seek to [position] within the current path, or within the path at
  /// [index] of the queue.
  Future<void> seek(Duration position, {int? index});

  /// Enable or disable seamless looping (see [playQueue]). Applies to the
  /// current queue and every later one.
  Future<void> setLooping(bool loop);

  /// Output volume, 0 (silent) to 1 (full). Playback keeps running at 0.
  Future<void> setVolume(double volume);

  /// Release all resources. Call once when the owner is disposed.
  Future<void> dispose();
}
