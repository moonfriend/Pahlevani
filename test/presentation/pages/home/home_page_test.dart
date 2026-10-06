import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/entities/tracking/movement_key.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_count.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/bloc/auth/auth_cubit.dart';
import 'package:pahlevani/presentation/bloc/tracking/training_history_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_sessions_ui_model.dart';
import 'package:pahlevani/presentation/pages/home/home_page.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_day_tile.dart';
import 'package:pahlevani/presentation/widgets/kashi/shamseh.dart';

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_training_history_repository.dart';

final _today = DateTime(2026, 9, 30, 9); // a Wednesday

TrainingSession _session(int id, String title) =>
    TrainingSession(id: id, title: title, description: '', difficulty: 3);

List<HomeSession> _sessions(int n) => [
      for (var i = 1; i <= n; i++)
        (session: _session(i, 'Session $i'), moves: 6 + i, minutes: 60 + i),
    ];

SessionCompletionRecord _done(DateTime at, Map<String, int> reps) =>
    SessionCompletionRecord(
      id: at.toIso8601String(),
      sessionId: 1,
      sessionTitle: 'S',
      completedAt: at,
      movementCounts: [
        for (final e in reps.entries)
          TrackedMovementCount(
              key: MovementKey.fromValue('m:${e.key}'),
              displayName: e.key,
              count: e.value),
      ],
    );

class _Calls {
  final opened = <TrainingSession>[];
  final menus = <TrainingSession>[];
  int allSessions = 0, progress = 0, calendar = 0;
}

Future<_Calls> _pump(
  WidgetTester tester, {
  List<HomeSession>? sessions,
  List<SessionCompletionRecord> history = const [],
  AppUser? user,
  Size size = const Size(360, 740),
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = FakeTrainingHistoryRepository();
  for (final r in history) {
    await repo.recordCompletion(r);
  }
  final historyCubit = TrainingHistoryCubit(historyRepository: repo);
  final auth = AuthCubit(repository: FakeAuthRepository(initialUser: user));
  addTearDown(historyCubit.close);
  addTearDown(auth.close);
  await tester.runAsync(() async {
    await historyCubit.load();
    await auth.initialize();
  });

  final calls = _Calls();
  await tester.pumpWidget(MultiBlocProvider(
    providers: [
      BlocProvider.value(value: historyCubit),
      BlocProvider.value(value: auth),
    ],
    child: MaterialApp(
      theme: theme ?? PahlevaniTheme.light(),
      home: HomePage(
        sessions: sessions ?? _sessions(3),
        now: () => _today,
        onOpenSession: calls.opened.add,
        onSessionMenu: calls.menus.add,
        onOpenAllSessions: () => calls.allSessions++,
        onOpenProgress: () => calls.progress++,
        onOpenCalendar: () => calls.calendar++,
      ),
    ),
  ));
  await tester.pump();
  return calls;
}

void main() {
  group('header', () {
    testWidgets('date and a greeting', (tester) async {
      await _pump(tester);
      expect(find.text('Wednesday · 30 Sep'), findsOneWidget);
      expect(find.text('Salam, Pahlevan'), findsOneWidget);
    });

    testWidgets('greets a signed-in user by name', (tester) async {
      await _pump(tester,
          user: const AppUser(
              id: 'u', email: 'sara@example.com', consentAccepted: true));
      expect(find.text('Salam, sara'), findsOneWidget);
    });
  });

  group('Today card', () {
    testWidgets('suggests the first session with its length', (tester) async {
      await _pump(tester);
      expect(find.text('TODAY · SUGGESTED'), findsOneWidget);
      expect(find.text('Session 1'), findsOneWidget);
      expect(find.text('61 min · 7 moves'), findsOneWidget);
    });

    testWidgets('Start and the card open the shown session', (tester) async {
      final calls = await _pump(tester);
      await tester.tap(find.text('Start'));
      await tester.tap(find.text('Session 1'));
      expect(calls.opened.map((s) => s.id), [1, 1]);
    });

    testWidgets('long-pressing the card opens the session menu',
        (tester) async {
      final calls = await _pump(tester);
      await tester.longPress(find.text('Session 1'));
      expect(calls.menus.map((s) => s.id), [1]);
      expect(calls.opened, isEmpty);
    });

    testWidgets('dots pick a session; swiping moves through them',
        (tester) async {
      final calls = await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('today-dot-2')));
      await tester.pumpAndSettle();
      expect(find.text('Session 3'), findsOneWidget);
      expect(find.text('SESSION 3 OF 3'), findsOneWidget);

      await tester.fling(find.text('Session 3'), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Session 2'), findsOneWidget);

      await tester.tap(find.text('Start'));
      expect(calls.opened.single.id, 2);
    });

    testWidgets('shows at most five sessions', (tester) async {
      await _pump(tester, sessions: _sessions(9));
      expect(find.byKey(const ValueKey('today-dot-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('today-dot-5')), findsNothing);
    });

    testWidgets('no sessions yet: a calm placeholder, no Start',
        (tester) async {
      await _pump(tester, sessions: const []);
      expect(find.text('Start'), findsNothing);
      expect(find.textContaining('Sessions are on their way'), findsOneWidget);
    });
  });

  group('tiles from training history', () {
    final history = [
      _done(DateTime(2026, 9, 16), {'Shena': 40, 'Meel Giri': 48}),
      _done(DateTime(2026, 9, 21), {'Shena': 42, 'Meel Giri': 50}),
    ];

    testWidgets('shamseh tile: tiles laid; tap opens Progress', (tester) async {
      final calls = await _pump(tester, history: history);
      expect(find.text('2 tiles laid'), findsOneWidget);
      expect(tester.widget<Shamseh>(find.byType(Shamseh)).tilesLaid, 2);

      await tester.tap(find.text('Your shamseh'));
      expect(calls.progress, 1);
    });

    testWidgets('rep tiles: the last value of each counted move',
        (tester) async {
      await _pump(tester, history: history);
      expect(find.text('Shena · last'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Meel Giri · last'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('no counted moves yet: a hint instead of rep tiles',
        (tester) async {
      await _pump(tester);
      expect(find.textContaining('Counted moves appear here'), findsOneWidget);
    });

    testWidgets(
        'month strip: this month\'s days, trained ones starred; '
        'tap opens the calendar', (tester) async {
      final calls = await _pump(tester, history: history);

      expect(find.text('September'), findsOneWidget);
      final tiles = tester.widgetList<KashiDayTile>(find.byType(KashiDayTile));
      expect(tiles, hasLength(30));
      expect(tiles.where((t) => t.state == DayTileState.trained), hasLength(2));

      await tester.tap(find.text('Calendar →'));
      expect(calls.calendar, 1);
    });
  });

  testWidgets('All sessions opens the full list', (tester) async {
    final calls = await _pump(tester);
    await tester.scrollUntilVisible(find.text('All sessions'), 80,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('All sessions'));
    expect(calls.allSessions, 1);
  });

  for (final size in const [Size(360, 740), Size(320, 568), Size(1440, 900)]) {
    testWidgets('lays out without overflow at $size', (tester) async {
      await _pump(tester, size: size, theme: PahlevaniTheme.dark(), history: [
        _done(DateTime(2026, 9, 21), {'Shena': 42, 'Meel': 50, 'Sang': 9}),
      ]);
      expect(tester.takeException(), isNull);
    });
  }

  group('homeSessionsFrom', () {
    final model = TrainingSessionsUiModel(
      trainingSessions: [_session(1, 'A'), _session(2, 'B')],
      downloadStatuses: const {},
      sessionItemCounts: const {1: 7, 2: 4},
      sessionDurations: const {1: 71 * 60 + 20},
    );

    test('maps the loaded sessions with moves and minutes', () {
      final sessions = homeSessionsFrom(TrainingSessionLoaded(uiModel: model));
      expect(sessions.map((s) => s.session.title), ['A', 'B']);
      expect(sessions.first.moves, 7);
      expect(sessions.first.minutes, 71);
      expect(sessions.last.minutes, isNull, reason: 'duration unknown');
    });

    test('keeps showing sessions while refreshing or after an error', () {
      expect(homeSessionsFrom(TrainingSessionLoading(uiModel: model)),
          hasLength(2));
      expect(
          homeSessionsFrom(TrainingSessionError(message: 'x', uiModel: model)),
          hasLength(2));
    });

    test('nothing before the first load', () {
      expect(homeSessionsFrom(TrainingSessionInitial()), isEmpty);
    });
  });
}
