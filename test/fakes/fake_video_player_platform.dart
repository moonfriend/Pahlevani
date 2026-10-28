import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A minimal VideoPlayerPlatform fake (video_player's own is internal to its
/// package). [created] counts the native players made, so a test can prove a
/// video was moved, not re-created.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final _controllers = <int, StreamController<VideoEvent>>{};
  int created = 0;

  /// The file path or URL of each player made, in order.
  final sources = <String?>[];

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = created++;
    final uri = options.dataSource.uri;
    // Local files arrive as file:// URIs; record them as plain paths.
    sources.add(uri != null && uri.startsWith('file://')
        ? Uri.parse(uri).toFilePath()
        : uri ?? options.dataSource.asset);
    _controllers[id] = StreamController<VideoEvent>.broadcast();
    return id;
  }

  void sendInitialized(int playerId) => _controllers[playerId]!.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 10),
        size: const Size(1280, 720),
      ));

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _controllers[playerId]!.stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.shrink();

  @override
  Future<void> dispose(int playerId) async {}
}
