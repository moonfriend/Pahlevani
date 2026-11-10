import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/domain/entities/usage/usage_event.dart';
import 'package:pahlevani/domain/repositories/download_repository.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/bloc/tracking/training_history_cubit.dart';
import 'package:pahlevani/presentation/pages/home/home_page.dart';
import 'package:pahlevani/presentation/pages/library/learning_card_page.dart';
import 'package:pahlevani/presentation/pages/library/library_page.dart';
import 'package:pahlevani/presentation/usage/usage_scope.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_download_repository.dart';
import '../../fakes/fake_learnt_exercises_repository.dart';
import '../../fakes/fake_training_history_repository.dart';
import '../../fakes/fake_usage_tracker.dart';

HomeSession _session(int id, String title, {int? slot}) => (
      session: TrainingSession(
          id: id,
          title: title,
          description: '',
          difficulty: 3,
          homePosition: slot),
      moves: 5,
      minutes: 12,
    );

final _sessions = [
  _session(2, 'Full Pahlevani', slot: 1),
  _session(4, 'Sheno Explosion', slot: 2),
  _session(3, 'Advanced Sang'),
];

const _moves = [
  Exercise(id: 11, movementId: 1, name: 'Vorod'),
  Exercise(id: 12, movementId: 4, name: 'Shena'),
];

Widget _app(FakeUsageTracker usage, Widget home) => UsageScope(
      tracker: usage,
      child: MaterialApp(theme: PahlevaniTheme.light(), home: home),
    );

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() async {
    await getIt.reset();
    getIt
      ..registerSingleton<LearntExercisesRepository>(
          FakeLearntExercisesRepository())
      ..registerSingleton<DownloadRepository>(FakeDownloadRepository());
  });
  tearDown(getIt.reset);

  group('Home', () {
    Future<FakeUsageTracker> pump(WidgetTester tester) async {
      _size(tester, const Size(360, 740));
      final history = TrainingHistoryCubit(
          historyRepository: FakeTrainingHistoryRepository());
      final auth = AuthCubit(repository: FakeAuthRepository());
      addTearDown(history.close);
      addTearDown(auth.close);
      await tester.runAsync(() async {
        await history.load();
        await auth.initialize();
      });
      final usage = FakeUsageTracker();
      await tester.pumpWidget(_app(
        usage,
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: history),
            BlocProvider.value(value: auth),
          ],
          child: HomePage(
            sessions: _sessions,
            now: () => DateTime(2026, 9, 30),
            onOpenSession: (_) {},
            onSessionMenu: (_) {},
            onOpenCalendar: () {},
          ),
        ),
      ));
      await tester.pump();
      return usage;
    }

    testWidgets('Start on the Today card is slot 0, the start button',
        (tester) async {
      final usage = await pump(tester);
      await tester.tap(find.text('Start'));
      final tap = usage.of<HomeSessionCardTapped>().single;
      expect([tap.slot, tap.sessionId, tap.target],
          [0, 2, HomeCardTarget.startButton]);
    });

    testWidgets('the Today card body is the card', (tester) async {
      final usage = await pump(tester);
      await tester.tap(find.text('Full Pahlevani'));
      expect(
          usage.of<HomeSessionCardTapped>().single.target, HomeCardTarget.card);
    });

    testWidgets('a small card is slot 1, and its play button is start',
        (tester) async {
      final usage = await pump(tester);
      await tester.tap(find.text('Sheno Explosion'));
      await tester.tap(find.byTooltip('Start Sheno Explosion'));
      final taps = usage.of<HomeSessionCardTapped>();
      expect([for (final t in taps) '${t.slot}:${t.target.wire}'],
          ['1:card', '1:start_button']);
    });

    testWidgets('a long press opens the session menu', (tester) async {
      final usage = await pump(tester);
      await tester.longPress(find.text('Full Pahlevani'));
      expect(usage.of<HomeSessionMenuOpened>().single.sessionId, 2);
    });
  });

  group('Library', () {
    Future<FakeUsageTracker> pump(WidgetTester tester) async {
      _size(tester, const Size(360, 2000));
      final usage = FakeUsageTracker();
      await tester.pumpWidget(_app(
        usage,
        LibraryPage(
          moves: _moves,
          sessions: _sessions,
          onOpenSession: (_) {},
          onSessionMenu: (_) {},
        ),
      ));
      return usage;
    }

    testWidgets('a move opens its card, logged with its position',
        (tester) async {
      final usage = await pump(tester);
      await tester.tap(find.text('Shena'));
      await tester.pumpAndSettle();
      final opened = usage.of<LibraryMoveOpened>().single;
      expect([opened.movementId, opened.position], [12, 1]);
      final card = usage.of<LearningCardOpened>().single;
      expect([card.movementId, card.from], [12, CardSource.library]);
    });

    testWidgets('a session is logged with its position', (tester) async {
      final usage = await pump(tester);
      await tester.tap(find.text('Sheno Explosion'));
      final opened = usage.of<LibrarySessionOpened>().single;
      expect([opened.sessionId, opened.position], [4, 1]);
    });
  });

  group('learning card', () {
    testWidgets('its action and the learnt switch are logged', (tester) async {
      _size(tester, const Size(360, 900));
      final usage = FakeUsageTracker();
      await tester.pumpWidget(_app(
        usage,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => pushLearningCard(
                  context,
                  const LearningCardPage(
                      move: LearningMove(
                          name: 'Shena', exerciseId: 12, steps: []))),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(usage.of<LearningCardLearntToggled>().single.learnt, isTrue);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(usage.of<LearningCardAction>().single.movementId, 12);
    });
  });
}
