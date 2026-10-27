// The learning card's video can go full screen: with the ⛶ button, or by
// holding a phone sideways. It is the same video (no second player).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/presentation/pages/library/learning_card_page.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../fakes/fake_learnt_exercises_repository.dart';
import '../../../fakes/fake_video_player_platform.dart';

const _move = LearningMove(
    exerciseId: 1, name: 'Shena', videoSrc: 'https://r2/learn.mp4');

late FakeVideoPlayerPlatform _video;

Future<void> _open(WidgetTester tester,
    {Size size = const Size(360, 740)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: PahlevaniTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showLearningCard(context, _move),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await _settle(tester);
  if (_video.created > 0) {
    _video.sendInitialized(0);
    await _settle(tester);
  }
}

/// No pumpAndSettle: the video's controls animate.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

final _fullscreen = find.byKey(const ValueKey('learning-card-fullscreen'));

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());
    _video = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = _video;
  });
  tearDown(() => getIt.reset());

  testWidgets('⛶ shows the same video alone; ✕ goes back to the card',
      (tester) async {
    await _open(tester);
    expect(find.byKey(const ValueKey('learning-card')), findsOneWidget);
    expect(_video.created, 1);

    await tester.tap(find.bySemanticsLabel('Full screen'));
    await _settle(tester);
    expect(_fullscreen, findsOneWidget);
    expect(find.byKey(const ValueKey('learning-card')), findsNothing);
    expect(_video.created, 1, reason: 'the same player, moved');

    await tester.tap(find.bySemanticsLabel('Exit full screen'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('learning-card')), findsOneWidget);
    expect(_video.created, 1);
  });

  testWidgets('Back leaves full screen first and keeps the card open',
      (tester) async {
    await _open(tester);
    await tester.tap(find.bySemanticsLabel('Full screen'));
    await _settle(tester);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(_fullscreen, findsNothing);
    expect(find.byKey(const ValueKey('learning-card')), findsOneWidget);
  });

  testWidgets('a phone held sideways shows the video full screen',
      (tester) async {
    await _open(tester, size: const Size(740, 360));
    expect(_fullscreen, findsOneWidget);
  });
}
