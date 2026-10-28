// The learning card can also show the move's follow-along video: a small
// Learning / Follow-along toggle at the top right of its media.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/presentation/pages/library/learning_card_page.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../fakes/fake_learnt_exercises_repository.dart';
import '../../../fakes/fake_video_player_platform.dart';

const _followAlong = ExerciseMedia(
    type: 'video', src: '/follow-along.mp4', poster: '/poster.jpg');

/// A move with no learning video made yet.
const _noLearning = Exercise(id: 1, name: 'Charkh', media: _followAlong);

/// A move with a learning video.
const _withLearning = Exercise(
    id: 2, name: 'Shena', media: _followAlong, videoUrl: 'https://r2/l.mp4');

late FakeVideoPlayerPlatform _video;

final _toggle = find.byKey(const ValueKey('learning-card-video-toggle'));
final _fullscreen = find.byKey(const ValueKey('learning-card-fullscreen'));

Future<void> _open(WidgetTester tester, LearningMove move,
    {Size size = const Size(360, 740), bool autoplay = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: PahlevaniTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => pushLearningCard(
              context, LearningCardPage(move: move, autoplayVideo: autoplay)),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await _settle(tester);
}

/// No pumpAndSettle: the video's controls animate.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _choose(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: _toggle, matching: find.text(label)));
  await _settle(tester);
  for (var id = 0; id < _video.created; id++) {
    _video.sendInitialized(id);
  }
  await _settle(tester);
}

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());
    _video = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = _video;
  });
  tearDown(() => getIt.reset());

  group('LearningMove.fromExercise', () {
    test('a ready follow-along video becomes the card\'s second video', () {
      final move = LearningMove.fromExercise(_noLearning,
          media: _followAlong, learningVideoSrc: null, followAlongReady: true);
      expect(move.followAlongVideoSrc, '/follow-along.mp4');
      expect(move.videoSrc, isNull, reason: 'still no learning video');
    });

    test('not on the device → none', () {
      final move = LearningMove.fromExercise(_noLearning,
          media: _followAlong, learningVideoSrc: null, followAlongReady: false);
      expect(move.followAlongVideoSrc, isNull);
    });

    test('a photo move has none', () {
      final move = LearningMove.fromExercise(_noLearning,
          media: const ExerciseMedia(type: 'photo', src: '/p.jpg'),
          learningVideoSrc: null,
          followAlongReady: true);
      expect(move.followAlongVideoSrc, isNull);
    });
  });

  testWidgets(
      'no learning video: opens on the still with the new label; '
      'Follow-along plays that video, Learning goes back', (tester) async {
    await _open(
        tester,
        LearningMove.fromExercise(_noLearning,
            media: _followAlong,
            learningVideoSrc: null,
            followAlongReady: true));

    expect(_toggle, findsOneWidget);
    expect(find.text('Learning video coming soon'), findsOneWidget);
    expect(find.text('For now, you can watch the follow-along video.'),
        findsOneWidget);
    expect(_video.created, 0);

    await _choose(tester, 'Follow-along');
    expect(_video.sources, ['/follow-along.mp4']);
    expect(find.text('Learning video coming soon'), findsNothing);

    await _choose(tester, 'Learning');
    expect(find.text('Learning video coming soon'), findsOneWidget);
  });

  testWidgets('with a learning video: the toggle switches the video',
      (tester) async {
    await _open(
        tester,
        LearningMove.fromExercise(_withLearning,
            media: _followAlong,
            learningVideoSrc: '/learn.mp4',
            followAlongReady: true),
        autoplay: true);
    expect(_video.sources, ['/learn.mp4']);

    await _choose(tester, 'Follow-along');
    expect(_video.sources.last, '/follow-along.mp4');

    await _choose(tester, 'Learning');
    expect(_video.sources.last, '/learn.mp4');
  });

  testWidgets('no follow-along video on the device: no toggle', (tester) async {
    await _open(
        tester,
        LearningMove.fromExercise(_noLearning,
            media: _followAlong,
            learningVideoSrc: null,
            followAlongReady: false));

    expect(_toggle, findsNothing);
  });

  testWidgets('the wide (tablet / web) card has the toggle too',
      (tester) async {
    await _open(
        tester,
        LearningMove.fromExercise(_noLearning,
            media: _followAlong,
            learningVideoSrc: null,
            followAlongReady: true),
        size: const Size(1280, 800));

    expect(_toggle, findsOneWidget);
    await _choose(tester, 'Follow-along');
    expect(_video.sources, ['/follow-along.mp4']);
  });

  testWidgets('full screen shows the chosen video alone, without the toggle',
      (tester) async {
    await _open(
        tester,
        LearningMove.fromExercise(_noLearning,
            media: _followAlong,
            learningVideoSrc: null,
            followAlongReady: true));
    await _choose(tester, 'Follow-along');

    await tester.tap(find.bySemanticsLabel('Full screen'));
    await _settle(tester);
    expect(_fullscreen, findsOneWidget);
    expect(_toggle, findsNothing);
    expect(_video.created, 1, reason: 'the same player, moved');
  });
}
