// The learning card plays only the move's learning (educational) video,
// never the follow-along video the player shows during a session.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/presentation/pages/library/learning_card_page.dart';

import '../../../fakes/fake_learnt_exercises_repository.dart';

const _followAlong = ExerciseMedia(
    type: 'video', src: '/follow-along.mp4', poster: '/poster.jpg');

const _move = Exercise(
  id: 1,
  name: 'Shena',
  media: _followAlong,
  videoUrl: 'https://r2/learn.mp4',
  description: 'A wave-like press.',
);

Future<void> _open(WidgetTester tester, LearningMove move) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: PahlevaniTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () =>
              pushLearningCard(context, LearningCardPage(move: move)),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());
  });
  tearDown(() => getIt.reset());

  test('the card plays the resolved learning video', () {
    final move = LearningMove.fromExercise(_move,
        media: _followAlong, learningVideoSrc: '/learn.mp4');
    expect(move.videoSrc, '/learn.mp4');
  });

  test('a ready follow-along video is never played on the card', () {
    final move = LearningMove.fromExercise(_move,
        media: _followAlong, learningVideoSrc: null);
    expect(move.videoSrc, isNull);
  });

  testWidgets(
      'without a learning video on the device: no play button, the '
      'follow-along poster stays as the still', (tester) async {
    await _open(
        tester,
        LearningMove.fromExercise(_move,
            media: _followAlong, learningVideoSrc: null));

    expect(find.bySemanticsLabel('Play video'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('with a learning video: the play button shows', (tester) async {
    await _open(
        tester,
        LearningMove.fromExercise(_move,
            media: _followAlong, learningVideoSrc: '/learn.mp4'));

    expect(find.bySemanticsLabel('Play video'), findsOneWidget);
  });
}
