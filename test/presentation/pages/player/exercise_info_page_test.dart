import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/presentation/pages/player/exercise_info_page.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

Widget _wrap(Exercise ex, {ExerciseMedia? media}) => MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: ExerciseInfoPage(exercise: ex, media: media),
    );

// Minimal from-scratch VideoPlayerPlatform fake (mirrors
// exercise_video_sync_test.dart's pattern — the real fake is internal to
// the video_player package and not exported for downstream tests).
class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final _controllers = <int, StreamController<VideoEvent>>{};
  final calls = <String>[];
  int _nextId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    _controllers[id] = StreamController<VideoEvent>.broadcast();
    return id;
  }

  void sendInitialized(int playerId) {
    _controllers[playerId]!.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(1280, 720),
    ));
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _controllers[playerId]!.stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

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

void main() {
  testWidgets('shows the move name, gloss and description', (tester) async {
    await tester.pumpWidget(_wrap(const Exercise(
      id: 1,
      name: 'Shena',
      titleFa: 'شنو',
      gloss: 'push-up variation',
      description: 'Lower slowly, keeping the back straight.',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Shena'), findsWidgets);
    expect(find.text('push-up variation'), findsOneWidget);
    expect(
        find.text('Lower slowly, keeping the back straight.'), findsOneWidget);
  });

  testWidgets('falls back to a placeholder when there is no description',
      (tester) async {
    await tester.pumpWidget(_wrap(const Exercise(id: 2, name: 'Meel')));
    await tester.pumpAndSettle();

    expect(find.text('No description yet.'), findsOneWidget);
  });

  testWidgets('shows a video placeholder when a video URL is present',
      (tester) async {
    await tester.pumpWidget(_wrap(const Exercise(
      id: 3,
      name: 'Charkh',
      videoUrl: 'https://r2/charkh.mp4',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Video coming soon'), findsOneWidget);
  });

  group('video-type media', () {
    late _FakeVideoPlayerPlatform fakePlatform;

    setUp(() {
      fakePlatform = _FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakePlatform;
    });

    testWidgets(
        'shows the real video (not the coming-soon placeholder) when the '
        'exercise has a locally cached demo video', (tester) async {
      await tester.pumpWidget(_wrap(
        const Exercise(id: 4, name: 'Sarnavazi'),
        media: const ExerciseMedia(type: 'video', src: '/local/clip.mp4'),
      ));
      await tester.pump(); // build the video controller
      fakePlatform.sendInitialized(0);
      await tester.pump(); // let initialize().then(...) run

      expect(find.text('Video coming soon'), findsNothing);
      expect(find.byType(VideoPlayer), findsOneWidget);
    });

    testWidgets('tapping the video toggles play/pause', (tester) async {
      await tester.pumpWidget(_wrap(
        const Exercise(id: 4, name: 'Sarnavazi'),
        media: const ExerciseMedia(type: 'video', src: '/local/clip.mp4'),
      ));
      await tester.pump();
      fakePlatform.sendInitialized(0);
      await tester.pump();

      // Tap the play/pause icon overlay, not the VideoPlayer render object
      // beneath it, so the hit test lands on the topmost widget.
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(fakePlatform.calls, contains('play'));

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(fakePlatform.calls, contains('pause'));
    });

    testWidgets(
        'falls back to the poster image (not a broken video load) when the '
        'video is not yet cached locally', (tester) async {
      await tester.pumpWidget(_wrap(
        const Exercise(id: 4, name: 'Sarnavazi'),
        media: const ExerciseMedia(
            type: 'video',
            src: 'https://r2.example.com/clip.mp4',
            poster: 'https://r2.example.com/poster.jpg'),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(VideoPlayer), findsNothing);
      expect(find.text('Video coming soon'), findsNothing);
      expect(fakePlatform.calls, isEmpty); // never attempted to open the URL
    });
  });
}
