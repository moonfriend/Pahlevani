import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:pahlevani/domain/entities/audio/audio_clip.dart';
import 'package:pahlevani/domain/player/clip_sequence.dart';
import 'package:pahlevani/domain/player/playback_clock.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';

/// One move as the timeline needs it.
class MoveSpec extends Equatable {
  /// The recordings to play, in order (see pickRecordingSequence). One clip
  /// loops by itself; several play one after another, and the whole
  /// sequence starts over after the last.
  final List<AudioClip> clips;

  /// Reps prescribed for this move. The move ends exactly when the clips
  /// have played this many reps, usually inside a clip (for one clip:
  /// `clip length ÷ clip reps × targetReps`).
  final int targetReps;

  /// Zoorkhaneh: the move never ends on its own; it loops until the user
  /// moves on, and the rep count keeps climbing past [targetReps].
  final bool loopForever;

  const MoveSpec({
    required this.clips,
    required this.targetReps,
    this.loopForever = false,
  });

  @override
  List<Object?> get props => [clips, targetReps, loopForever];
}

/// Where the current move is. Changes many times a second while playing.
class MoveProgress extends Equatable {
  /// Before a move's clip length is known.
  static const none = MoveProgress();

  /// Time into the move, across loops of the clip.
  final Duration position;

  /// The whole move's length; zero until the clip's length is known.
  final Duration length;

  /// The audio engine's position inside the clip (restarts on every loop
  /// and every new clip).
  final Duration clipPosition;

  /// Which of the move's clips is playing (index into [MoveSpec.clips]).
  final int clipIndex;

  /// Current rep, from 1. Capped at [repsTotal] unless the move loops
  /// forever.
  final int rep;
  final int repsTotal;

  const MoveProgress({
    this.position = Duration.zero,
    this.length = Duration.zero,
    this.clipPosition = Duration.zero,
    this.clipIndex = 0,
    this.rep = 1,
    this.repsTotal = 1,
  });

  bool get isKnown => length > Duration.zero;

  @override
  List<Object?> get props =>
      [position, length, clipPosition, clipIndex, rep, repsTotal];
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

/// A clip started over or the next clip started: the engine looped the clip,
/// moved on to the move's next recording, or we restarted the clip early
/// for a Zoorkhaneh move with fewer reps than the clip.
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
  ClipSequence? _sequence;
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

  /// 0 while muted. Re-applied on every load, and reset to full for every
  /// new timeline: on native platforms the engine is shared app-wide, so a
  /// mute must never leak into the next session.
  double _volume = 1;

  MoveTimeline(this._engine) {
    _positionSub = _engine.onPositionChanged.listen(_onEnginePosition);
    _durationSub = _engine.onDurationChanged.listen(_onEngineDuration);
    // Engine playing/paused events are deliberately not listened to: the
    // engine reports stopped→playing on every loop, which would fight the
    // session's own play/pause intent.
    unawaited(_engine.setLooping(true));
    unawaited(_engine.setVolume(_volume));
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
    unawaited(_engine.setVolume(_volume));
    try {
      final paths = [for (final clip in spec.clips) clip.path];
      if (paths.isEmpty || paths.any((p) => p.isEmpty)) {
        throw StateError('Audio source path is empty');
      }
      // Set before handing the source over: the engine reports the new
      // clip's length while playQueue()/setQueue() is still in progress.
      _sourceDispatched = true;
      _addEvent(const MoveStarted());
      if (play) {
        // Not followed by any state change: just_audio completes play() only
        // when playback later stops, so nothing may depend on it returning.
        await _engine.playQueue(paths);
      } else {
        await _engine.stop();
        if (superseded()) return LoadOutcome.superseded;
        await _engine.setQueue(paths);
      }
      return superseded() ? LoadOutcome.superseded : LoadOutcome.current;
    } catch (_) {
      if (superseded()) return LoadOutcome.superseded;
      await _engine.stop();
      rethrow;
    }
  }

  /// Silences (or restores) the morshed's audio; playback keeps running.
  Future<void> setMuted(bool muted) {
    _volume = muted ? 0 : 1;
    return _engine.setVolume(_volume);
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
    final sequence = _sequence;
    if (!_clock.isStarted || length == null || sequence == null) return null;
    final clamped = Duration(
        milliseconds: position.inMilliseconds.clamp(0, length.inMilliseconds));
    final at = sequence.locate(clamped);
    // The clock re-bases first, so the engine's jump is never taken for a
    // loop or a new clip.
    _clock.jumpTo(
        index: at.index,
        clipPosition: at.clipPosition,
        completed: at.completed);
    _awaitingLoopRestart = false;
    await _engine.seek(at.clipPosition,
        index: sequence.clips.length > 1 ? at.index : null);
    _publish(clamped, at.clipPosition);
    _addEvent(MoveSeeked(at.clipPosition));
    return at.clipPosition;
  }

  /// The clip at [index] of the current move (see [MoveProgress.clipIndex]),
  /// or null when out of range.
  AudioClip? clipAt(int index) {
    final clips = _spec?.clips ?? const <AudioClip>[];
    return index >= 0 && index < clips.length ? clips[index] : null;
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
    _sequence = ClipSequence(spec.clips, _clock.clipLength);
    _sourceDispatched = false;
    _targetAnnounced = false;
    _awaitingLoopRestart = false;
    _length = null;
    _clock.reset();
    _current = MoveProgress.none;
    if (!_progress.isClosed) _progress.add(_current);
  }

  void _onEngineDuration(Duration clip) {
    final spec = _spec;
    final sequence = _sequence;
    final index = _engine.currentIndex;
    if (!_sourceDispatched ||
        spec == null ||
        sequence == null ||
        clip <= Duration.zero ||
        index >= spec.clips.length) {
      return;
    }
    // Engines may re-report the same clip's length mid-move; only the first
    // report starts the timeline, so progress isn't wiped.
    if (_clock.isStarted) {
      _clock.setClipLength(index, clip);
    } else {
      _clock.start(clip, index: index, clipCount: spec.clips.length);
    }
    _length = sequence.timeAtReps(spec.targetReps);
    _publish(_clock.logicalPosition, _current.clipPosition);
  }

  /// The single place where the move's progress — and its end — is decided.
  void _onEnginePosition(Duration clipPosition) {
    final spec = _spec;
    final length = _length;
    final index = _engine.currentIndex;
    if (!_sourceDispatched ||
        spec == null ||
        !_clock.isStarted ||
        length == null ||
        index >= spec.clips.length) {
      return;
    }

    // Loop forever on a single clip, prescribed reps fewer than the clip's:
    // we loop the first `length` of the clip ourselves. Ignore readings
    // until our seek(0) lands.
    final clip = _clock.clipLength(0);
    final loopsShortClip = spec.loopForever &&
        spec.clips.length == 1 &&
        clip != null &&
        length < clip;
    if (loopsShortClip && _awaitingLoopRestart) {
      if (clipPosition >= length) return;
      _awaitingLoopRestart = false;
    }

    final wrapsBefore = _clock.wrapCount;
    var logical = _clock.onEnginePosition(clipPosition, index: index);
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
      clipIndex: _clock.index,
      rep: _repAt(position, spec),
      repsTotal: spec.targetReps,
    );
    _progress.add(_current);
  }

  void _addEvent(MoveEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Current rep, from 1: reps already played (clip by clip, each at its own
  /// tempo) + 1. Capped at the prescribed reps unless the move loops forever.
  int _repAt(Duration position, MoveSpec spec) {
    final total = spec.targetReps < 1 ? 1 : spec.targetReps;
    final sequence = _sequence;
    if (sequence == null || !_clock.isStarted) return 1;
    final rep = sequence.repsAt(position).floor() + 1;
    return spec.loopForever ? rep : rep.clamp(1, total);
  }
}
