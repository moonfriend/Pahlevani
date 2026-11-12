import 'dart:async';
import 'package:pahlevani/domain/services/audio_player_service.dart';

/// Controllable in-memory fake for [AudioPlayerService].
/// Tests push values via [emitPosition] / [emitDuration] and inspect
/// [lastPlayedPath], [stopped], [seekedTo], etc.
class FakeAudioPlayerService implements AudioPlayerService {
  final _positionCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();

  /// The first path of the last queue played / set — most moves have one.
  String? lastPlayedPath;
  String? lastSetSourcePath;
  List<String>? lastPlayedQueue;
  List<String>? lastSetQueue;

  /// What [currentIndex] reports; [emitPosition] / [emitDuration] can move
  /// it, the way a real engine moves on to the next path of a queue.
  @override
  int currentIndex = 0;
  int? seekedIndex;
  bool stopped = false;
  bool paused = false;
  bool resumed = false;
  bool looping = false;
  double volume = 1;
  bool disposed = false;
  Duration? seekedTo;
  int playCallCount = 0;

  /// When set, [resume] blocks until this completer is completed.
  /// Use to test that callers declare intent before the engine catches up.
  Completer<void>? resumeCompleter;

  /// When true, models `just_audio` semantics: [playQueue] and [resume] return a
  /// future that completes only when playback later stops — i.e. when [pause]
  /// or [stop] is called — NOT when playback starts. (audioplayers, by
  /// contrast, completes these futures promptly once the command is dispatched.)
  /// The cubit must remain correct under BOTH semantics; this flag lets a test
  /// pin that the cubit never derives isPlaying from when these futures resolve.
  bool completePlayOnPause = false;
  final _pendingPlayCompleters = <Completer<void>>[];

  void _resolvePendingPlays() {
    for (final c in _pendingPlayCompleters) {
      if (!c.isCompleted) c.complete();
    }
    _pendingPlayCompleters.clear();
  }

  @override
  Stream<Duration> get onPositionChanged => _positionCtrl.stream;

  @override
  Stream<Duration> get onDurationChanged => _durationCtrl.stream;

  @override
  Stream<bool> get onPlayingChanged => _playingCtrl.stream;

  /// [index]: the queue path the reading belongs to (unchanged if omitted).
  void emitPosition(Duration d, {int? index}) {
    if (index != null) currentIndex = index;
    _positionCtrl.add(d);
  }

  void emitDuration(Duration d, {int? index}) {
    if (index != null) currentIndex = index;
    _durationCtrl.add(d);
  }

  /// Simulates an engine playing/paused state event (including the engine's own
  /// internal loop-cycle transitions). The cubit must NOT mirror these into its
  /// state — it is the sole authority over isPlaying. Tests use this to assert
  /// the cubit ignores engine-originated state changes.
  void emitPlaying(bool playing) => _playingCtrl.add(playing);

  /// Per-path gates: [playQueue] starting with that path doesn't return until
  /// its completer completes — an engine that is slow to start one clip.
  final Map<String, Completer<void>> playGates = {};

  @override
  Future<void> playQueue(List<String> paths) async {
    final path = paths.first;
    lastPlayedPath = path;
    lastPlayedQueue = paths;
    currentIndex = 0;
    stopped = false;
    paused = false;
    playCallCount++;
    await playGates[path]?.future;
    if (completePlayOnPause) {
      final c = Completer<void>();
      _pendingPlayCompleters.add(c);
      await c.future;
    }
  }

  @override
  Future<void> setQueue(List<String> paths) async {
    lastSetSourcePath = paths.first;
    lastSetQueue = paths;
    currentIndex = 0;
  }

  @override
  Future<void> pause() async {
    paused = true;
    // just_audio's play() future resolves when playback stops — pause is one
    // such moment. Mirror that so a blocked play()/resume() unblocks here.
    _resolvePendingPlays();
  }

  @override
  Future<void> resume() async {
    if (resumeCompleter != null) await resumeCompleter!.future;
    resumed = true;
    paused = false;
    if (completePlayOnPause) {
      final c = Completer<void>();
      _pendingPlayCompleters.add(c);
      await c.future;
    }
  }

  @override
  Future<void> stop() async {
    stopped = true;
    _resolvePendingPlays();
  }

  @override
  Future<void> seek(Duration position, {int? index}) async {
    seekedTo = position;
    seekedIndex = index;
    if (index != null) currentIndex = index;
  }

  @override
  Future<void> setLooping(bool loop) async {
    looping = loop;
  }

  @override
  Future<void> setVolume(double v) async {
    volume = v;
  }

  @override
  Future<void> dispose() async {
    await _positionCtrl.close();
    await _durationCtrl.close();
    await _playingCtrl.close();
    disposed = true;
  }
}
