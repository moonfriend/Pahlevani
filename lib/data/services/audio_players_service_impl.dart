import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:pahlevani/domain/services/audio_player_service.dart';

/// `audioplayers`-backed implementation of [AudioPlayerService] — the Linux
/// desktop dev build. Source-type detection (URL / local file / asset) lives
/// here so the cubit stays free of any `audioplayers` imports.
///
/// audioplayers has no playlist, so a queue of several paths is stepped
/// through here: when one path completes, the next one starts. That leaves
/// a short gap between recordings — fine for a dev build.
class AudioPlayersServiceImpl implements AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<void> _completeSub;

  List<String> _queue = const [];
  int _index = 0;
  bool _looping = false;

  AudioPlayersServiceImpl() {
    _completeSub = _player.onPlayerComplete.listen((_) => _playNextInQueue());
  }

  @override
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  @override
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  @override
  Stream<bool> get onPlayingChanged =>
      _player.onPlayerStateChanged.map((s) => s == PlayerState.playing);

  @visibleForTesting
  static Source sourceFor(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return UrlSource(path);
    } else if (path.startsWith('/')) {
      return DeviceFileSource(path);
    } else if (path.startsWith('assets/')) {
      return AssetSource(path.replaceFirst('assets/', ''));
    } else {
      return AssetSource(path);
    }
  }

  @override
  int get currentIndex => _index;

  @override
  Future<void> playQueue(List<String> paths) async {
    await _startQueue(paths);
    await _player.play(sourceFor(_queue.first));
  }

  @override
  Future<void> setQueue(List<String> paths) async {
    await _startQueue(paths);
    await _player.setSource(sourceFor(_queue.first));
  }

  Future<void> _startQueue(List<String> paths) async {
    if (paths.isEmpty) throw ArgumentError.value(paths, 'paths', 'is empty');
    _queue = List.unmodifiable(paths);
    _index = 0;
    await _applyReleaseMode();
  }

  /// A single path loops natively; a longer queue must stop at each path's
  /// end, so completion fires and [_playNextInQueue] moves on.
  Future<void> _applyReleaseMode() => _player.setReleaseMode(
      _looping && _queue.length <= 1 ? ReleaseMode.loop : ReleaseMode.stop);

  void _playNextInQueue() {
    if (_queue.length <= 1) return;
    var next = _index + 1;
    if (next >= _queue.length) {
      if (!_looping) return;
      next = 0;
    }
    _index = next;
    unawaited(_player.play(sourceFor(_queue[next])));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position, {int? index}) async {
    if (index == null || index == _index || index >= _queue.length) {
      return _player.seek(position);
    }
    _index = index;
    final source = sourceFor(_queue[index]);
    if (_player.state == PlayerState.playing) {
      await _player.play(source, position: position);
    } else {
      await _player.setSource(source);
      await _player.seek(position);
    }
  }

  @override
  Future<void> setLooping(bool loop) {
    _looping = loop;
    return _applyReleaseMode();
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() async {
    await _completeSub.cancel();
    await _player.dispose();
  }
}
