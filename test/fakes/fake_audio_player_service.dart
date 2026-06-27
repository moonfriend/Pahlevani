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
  }

  @override
  Future<void> setSource(String path) async {
    lastSetSourcePath = path;
  }

  @override
  Future<void> pause() async {
    paused = true;
  }

  @override
  Future<void> resume() async {
    resumed = true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
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
