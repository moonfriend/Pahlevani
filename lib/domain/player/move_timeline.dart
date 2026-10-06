import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/player/playback_clock.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';

/// One move as the timeline needs it.
class MoveSpec extends Equatable {
  /// Local file (or, on the web, remote URL) of the move's recording.
  final String audioPath;

  /// Reps the recording itself contains.
  final int clipReps;

  /// Reps prescribed for this move — the move lasts
  /// `clip length ÷ clipReps × targetReps`, looping the clip as needed.
  final int targetReps;

  /// Zoorkhaneh: the move never ends on its own; it loops until the user
  /// moves on, and the rep count keeps climbing past [targetReps].
  final bool loopForever;

  const MoveSpec({
    required this.audioPath,
    required this.clipReps,
    required this.targetReps,
    this.loopForever = false,
  });

  @override
  List<Object?> get props => [audioPath, clipReps, targetReps, loopForever];
}

/// Where the current move is. Changes many times a second while playing.
class MoveProgress extends Equatable {
  /// Before a move's clip length is known.
  static const none = MoveProgress();

  /// Time into the move, across loops of the clip.
  final Duration position;

  /// The whole move's length; zero until the clip's length is known.
  final Duration length;

  /// The audio engine's position inside the clip (restarts on every loop).
  final Duration clipPosition;

  /// Current rep, from 1. Capped at [repsTotal] unless the move loops
  /// forever.
  final int rep;
  final int repsTotal;

  const MoveProgress({
    this.position = Duration.zero,
    this.length = Duration.zero,
    this.clipPosition = Duration.zero,
    this.rep = 1,
    this.repsTotal = 1,
  });

  bool get isKnown => length > Duration.zero;

  @override
  List<Object?> get props => [position, length, clipPosition, rep, repsTotal];
}

/// Something that happened to the current move — rare, unlike progress.
sealed class MoveEvent extends Equatable {
  const MoveEvent();

  @override
  List<Object?> get props => [];
}

/// A new move's audio was handed to the engine; its clip starts at 0.
final class MoveStarted extends MoveEvent {
  const MoveStarted();
}

/// The move was moved to a new spot (seek bar, lock screen, "‹" restart).
final class MoveSeeked extends MoveEvent {
  /// The engine's new position inside the clip.
  final Duration clipPosition;
  const MoveSeeked(this.clipPosition);

  @override
  List<Object?> get props => [clipPosition];
}

/// The clip went back to its start (the engine looped it, or we restarted
/// it early for a Zoorkhaneh move with fewer reps than the clip).
final class MoveLooped extends MoveEvent {
  const MoveLooped();
}

/// The move has played its prescribed reps. Announced once per move, only
/// while playing, and never for a move that loops forever.
final class MoveTargetReached extends MoveEvent {
  const MoveTargetReached();
}

enum LoadOutcome {
  /// This load is still the current one.
  current,

  /// A newer load started meanwhile; the caller should drop this one.
  superseded,
}

/// The one place that runs a move's audio and keeps its time.
///
/// It owns the audio engine for its lifetime (one player page): loads each
/// move, turns raw engine positions into a continuous move timeline
/// ([PlaybackClock]), and says when the move has played its reps. It decides
/// nothing about the session — what happens after a move is the session
/// cubit's call — and never reports "playing" upward: the session cubit is
/// the only authority on that, and tells the timeline via [load], [resume],
/// [pause] and [stop].
///
/// Outputs: [progress] (fast) and [current] for whoever joins mid-move, and
/// [events] (rare) for discrete things like seeks and loops.
class MoveTimeline {
  final AudioPlayerService _engine;
  final _clock = PlaybackClock();

  // Progress is delivered synchronously so a listener is never a reading
  // behind; events go through the event loop, so a listener may safely start
  // a new load (e.g. on MoveTargetReached) without re-entering this class.
  final _progress = StreamController<MoveProgress>.broadcast(sync: true);
  final _events = StreamController<MoveEvent>.broadcast();
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;

  MoveSpec? _spec;
  Duration? _clip;
  Duration? _length;
  MoveProgress _current = MoveProgress.none;

  /// The session's playing intent, as last commanded.
  bool _playing = false;

  /// False from the start of a load until its source has been handed to
  /// the engine, so late readings from the previous clip are ignored.
  bool _sourceDispatched = false;
  bool _targetAnnounced = false;

  /// Loop-forever with fewer reps than the clip: set after we restart the
  /// clip ourselves, until the engine confirms it is back before the target.
  bool _awaitingLoopRestart = false;

  /// Bumped by every load; an older load that finds it changed gives up.
  int _generation = 0;
  bool _closed = false;

  MoveTimeline(this._engine) {
    _positionSub = _engine.onPositionChanged.listen(_onEnginePosition);
    _durationSub = _engine.onDurationChanged.listen(_onEngineDuration);
    // Engine playing/paused events are deliberately not listened to: the
    // engine reports stopped→playing on every loop, which would fight the
    // session's own play/pause intent.
    unawaited(_engine.setLooping(true));
  }

  Stream<MoveProgress> get progress => _progress.stream;
  MoveProgress get current => _current;
  Stream<MoveEvent> get events => _events.stream;
  bool get isPlaying => _playing;

  /// Starts [spec] from its beginning, playing or paused.
  ///
  /// Throws if the engine can't load it (the engine is stopped first),
  /// unless a newer load has started meanwhile.
  Future<LoadOutcome> load(MoveSpec spec, {required bool play}) async {
    final generation = ++_generation;
    bool superseded() => _closed || generation != _generation;
    _startNewMove(spec);
    _playing = play;
    try {
      if (spec.audioPath.isEmpty) {
        throw StateError('Audio source path is empty');
      }
      // Set before handing the source over: the engine reports the new
      // clip's length while play()/setSource() is still in progress.
      _sourceDispatched = true;
      _addEvent(const MoveStarted());
      if (play) {
        // Not followed by any state change: just_audio completes play() only
        // when playback later stops, so nothing may depend on it returning.
        await _engine.play(spec.audioPath);
      } else {
        await _engine.stop();
        if (superseded()) return LoadOutcome.superseded;
        await _engine.setSource(spec.audioPath);
      }
      return superseded() ? LoadOutcome.superseded : LoadOutcome.current;
    } catch (_) {
      if (superseded()) return LoadOutcome.superseded;
      await _engine.stop();
      rethrow;
    }
  }

  /// Continues the current move after a pause.
  Future<void> resume() async {
    _playing = true;
    await _engine.resume();
  }

  void pause() {
    _playing = false;
    unawaited(_engine.pause());
  }

  Future<void> stop() async {
    _playing = false;
    await _engine.stop();
  }

  /// Moves to [position] in the move (clamped to the move) and returns the
  /// engine's new position inside the clip, or null while the clip's length
  /// isn't known yet.
  Future<Duration?> seek(Duration position) async {
    final length = _length;
    if (!_clock.isStarted || length == null) return null;
    final clamped = Duration(
        milliseconds: position.inMilliseconds.clamp(0, length.inMilliseconds));
    // The clock re-bases first, so the engine's jump is never taken for a
    // loop.
    final clipPosition = _clock.seekTo(clamped);
    _awaitingLoopRestart = false;
    await _engine.seek(clipPosition);
    _publish(clamped, clipPosition);
    _addEvent(MoveSeeked(clipPosition));
    return clipPosition;
  }

  Future<void> close() async {
    _closed = true;
    await _positionSub.cancel();
    await _durationSub.cancel();
    await _engine.dispose();
    await _progress.close();
    await _events.close();
  }

  void _startNewMove(MoveSpec spec) {
    _spec = spec;
    _sourceDispatched = false;
    _targetAnnounced = false;
    _awaitingLoopRestart = false;
    _clip = null;
    _length = null;
    _clock.reset();
    _current = MoveProgress.none;
    if (!_progress.isClosed) _progress.add(_current);
  }

  void _onEngineDuration(Duration clip) {
    final spec = _spec;
    if (!_sourceDispatched || spec == null || clip <= Duration.zero) return;
    _clip = clip;
    _length = _moveLength(clip, spec);
    // Engines may re-report the same clip's length mid-move; only the first
    // report starts the timeline, so progress isn't wiped.
    if (!_clock.isStarted) _clock.start(clip);
    _publish(_clock.logicalPosition, _current.clipPosition);
  }

  /// The single place where the move's progress — and its end — is decided.
  void _onEnginePosition(Duration clipPosition) {
    final spec = _spec;
    final length = _length;
    final clip = _clip;
    if (!_sourceDispatched ||
        spec == null ||
        !_clock.isStarted ||
        length == null ||
        clip == null) {
      return;
    }

    // Loop forever, prescribed reps fewer than the clip's: we loop the first
    // `length` of the clip ourselves. Ignore readings until our seek(0)
    // lands.
    final loopsShortClip = spec.loopForever && length < clip;
    if (loopsShortClip && _awaitingLoopRestart) {
      if (clipPosition >= length) return;
      _awaitingLoopRestart = false;
    }

    final wrapsBefore = _clock.wrapCount;
    var logical = _clock.onEnginePosition(clipPosition);
    final engineLooped = _clock.wrapCount > wrapsBefore;
    final restartShortClip =
        loopsShortClip && _playing && clipPosition >= length;
    if (restartShortClip) {
      _clock.restartLoop(length);
      _awaitingLoopRestart = true;
      logical = _clock.logicalPosition;
      unawaited(_engine.seek(Duration.zero));
    }
    _publish(logical, restartShortClip ? Duration.zero : clipPosition);
    if (engineLooped || restartShortClip) _addEvent(const MoveLooped());

    if (!_playing || spec.loopForever || _targetAnnounced) return;
    if (logical >= length) {
      _targetAnnounced = true;
      _addEvent(const MoveTargetReached());
    }
  }

  void _publish(Duration position, Duration clipPosition) {
    final spec = _spec;
    final length = _length ?? Duration.zero;
    if (spec == null || _progress.isClosed) return;
    _current = MoveProgress(
      position: position,
      length: length,
      clipPosition: clipPosition,
      rep: _repAt(position, length, spec),
      repsTotal: spec.targetReps,
    );
    _progress.add(_current);
  }

  void _addEvent(MoveEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Clip length scaled from the clip's own reps to the prescribed reps
  /// (e.g. a 10 s, 1-rep clip prescribed ×3 → 30 s).
  static Duration _moveLength(Duration clip, MoveSpec spec) {
    if (spec.clipReps <= 0) return clip;
    return Duration(
        milliseconds:
            (clip.inMilliseconds / spec.clipReps * spec.targetReps).round());
  }

  static int _repAt(Duration position, Duration length, MoveSpec spec) {
    final total = spec.targetReps < 1 ? 1 : spec.targetReps;
    if (length <= Duration.zero) return 1;
    final perRepMs = length.inMilliseconds / total;
    final rep = (position.inMilliseconds / perRepMs).floor() + 1;
    return spec.loopForever ? rep : rep.clamp(1, total);
  }
}
