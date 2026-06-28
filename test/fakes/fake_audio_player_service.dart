import 'dart:async';
import 'package:pahlevani/domain/services/audio_player_service.dart';

/// Controllable in-memory fake for [AudioPlayerService].
/// Tests push values via [emitPosition] / [emitDuration] and inspect
/// [lastPlayedPath], [stopped], [seekedTo], etc.
class FakeAudioPlayerService implements AudioPlayerService {
  final _positionCtrl = StreamController<Duration>.broadcast();
  final _durationCtrl = StreamController<Duration>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();

  String? lastPlayedPath;
  String? lastSetSourcePath;
  bool stopped = false;
  bool paused = false;
  bool resumed = false;
  bool looping = false;
  bool disposed = false;
  Duration? seekedTo;
  int playCallCount = 0;

  /// When set, [resume] blocks until this completer is completed.
  /// Use to test that callers declare intent before the engine catches up.
  Completer<void>? resumeCompleter;

  /// When true, models `just_audio` semantics: [play] and [resume] return a
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

  void emitPosition(Duration d) => _positionCtrl.add(d);
  void emitDuration(Duration d) => _durationCtrl.add(d);

  /// Simulates an engine playing/paused state event (including the engine's own
  /// internal loop-cycle transitions). The cubit must NOT mirror these into its
  /// state — it is the sole authority over isPlaying. Tests use this to assert
  /// the cubit ignores engine-originated state changes.
  void emitPlaying(bool playing) => _playingCtrl.add(playing);

  @override
  Future<void> play(String path) async {
    lastPlayedPath = path;
    stopped = false;
    paused = false;
    playCallCount++;
    if (completePlayOnPause) {
      final c = Completer<void>();
      _pendingPlayCompleters.add(c);
      await c.future;
    }
  }

  @override
  Future<void> setSource(String path) async {
    lastSetSourcePath = path;
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
  Future<void> seek(Duration position) async {
    seekedTo = position;
  }

  @override
  Future<void> setLooping(bool loop) async {
    looping = loop;
  }

  @override
  Future<void> dispose() async {
    await _positionCtrl.close();
    await _durationCtrl.close();
    await _playingCtrl.close();
    disposed = true;
  }
}
