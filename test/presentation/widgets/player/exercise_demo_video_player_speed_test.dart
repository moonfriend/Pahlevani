// The learning video's speed button: 1× → 1.5× → 2× → 1×.
//
// video_player's own fake platform is internal to its package, so this is a
// minimal from-scratch VideoPlayerPlatform fake (same pattern as
// video_resync_test.dart).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/widgets/player/exercise_demo_video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final _events = StreamController<VideoEvent>.broadcast();
  final speeds = <double>[];
  final calls = <String>[];

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 0;

  void sendInitialized() => _events.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 10),
        size: const Size(1280, 720),
      ));

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events.stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async =>
      speeds.add(speed);

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.shrink();

  @override
  Future<void> dispose(int playerId) async {}
}

void main() {
  late _FakeVideoPlayerPlatform platform;

  setUp(() {
    platform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ExerciseDemoVideoPlayer(src: '/learn.mp4')),
    ));
    await tester.pump();
    platform.sendInitialized();
    await tester.pump();
    await tester.pump();
    // The controller's own set-up (it pauses once initialised) is not ours.
    platform.calls.clear();
    platform.speeds.clear();
  }

  /// Taps the video itself (play/pause), away from the speed button.
  Future<void> tapVideo(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
  }

  testWidgets('starts at 1× and cycles 1.5×, 2×, back to 1×', (tester) async {
    await pump(tester);
    expect(find.text('1×'), findsOneWidget);

    await tester.tap(find.text('1×'));
    await tester.pump();
    expect(find.text('1.5×'), findsOneWidget);

    await tester.tap(find.text('1.5×'));
    await tester.pump();
    expect(find.text('2×'), findsOneWidget);

    await tester.tap(find.text('2×'));
    await tester.pump();
    expect(find.text('1×'), findsOneWidget);
  });

  testWidgets('the chosen speed is what the video plays at', (tester) async {
    await pump(tester);
    await tester.tap(find.text('1×'));
    await tester.pump();
    await tapVideo(tester);
    expect(platform.speeds.last, 1.5);

    await tester.tap(find.text('1.5×'));
    await tester.pump();
    expect(platform.speeds.last, 2.0);
  });

  testWidgets('changing speed does not play or pause the video',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('1×'));
    await tester.pump();
    expect(platform.calls, isEmpty);
  });

  testWidgets('the button says what it does for screen readers',
      (tester) async {
    await pump(tester);
    expect(find.bySemanticsLabel(RegExp('Playback speed')), findsOneWidget);
  });
}
