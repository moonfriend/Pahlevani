/// Platform-agnostic audio playback abstraction.
/// The production implementation wraps `audioplayers`; tests inject a fake.
/// Swapping to `just_audio` (or a web-specific backend) only requires a new
/// implementation of this interface — no changes to the cubit or tests.
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

  /// Stop current source, load [path], and start playing immediately.
  /// [path] may be a remote URL (`https://…`), an absolute local path (`/…`),
  /// or an asset path (`assets/…` or bare asset name).
  Future<void> play(String path);

  /// Stop current source and load [path] without starting playback.
  Future<void> setSource(String path);

  /// Pause playback (preserves position).
  Future<void> pause();

  /// Resume from current position.
  Future<void> resume();

  /// Stop playback and reset position to zero.
  Future<void> stop();

  /// Seek to [position] within the current source.
  Future<void> seek(Duration position);

  /// Enable or disable seamless looping of the current source.
  Future<void> setLooping(bool loop);

  /// Release all resources. Call once when the owner is disposed.
  Future<void> dispose();
}
