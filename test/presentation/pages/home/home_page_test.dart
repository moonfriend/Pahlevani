import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/auth/app_user.dart';
import 'package:pahlevani/domain/entities/auth/consent.dart';
import 'package:pahlevani/domain/entities/info/info_link.dart';
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

import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_training_history_repository.dart';

final _today = DateTime(2026, 9, 30, 9); // a Wednesday

TrainingSession _session(int id, String title,
        {int? slot, bool needsMeel = false, bool isPublic = true}) =>
    TrainingSession(
        id: id,
        title: title,
        description: '',
        difficulty: 3,
        homePosition: slot,
        needsMeel: needsMeel,
        isPublic: isPublic,
        ownerTrainerId: isPublic ? null : 'trainer-1');

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

const _info = InfoLink(title: 'Rahaavi', url: 'https://rahaavi.com');

class _Calls {
  final opened = <TrainingSession>[];
  final menus = <TrainingSession>[];
  final infoOpened = <InfoLink>[];
  int calendar = 0;
}

Future<_Calls> _pump(
  WidgetTester tester, {
  List<HomeSession>? sessions,
  List<SessionCompletionRecord> history = const [],
  AppUser? user,
  Size size = const Size(360, 740),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
        onOpenCalendar: () => calls.calendar++,
        infoLink: _info,
        onOpenInfo: calls.infoOpened.add,
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
              id: 'u',
              email: 'sara@example.com',
              consentAccepted: true,
              termsVersion: currentTermsVersion));
      expect(find.text('Salam, sara'), findsOneWidget);
    });
  });

  group('sessions', () {
    testWidgets('the main card shows the first session with its length',
        (tester) async {
      await _pump(tester);
      expect(find.text('TODAY'), findsOneWidget);
      final main = find.byKey(const ValueKey('home-today'));
      expect(find.descendant(of: main, matching: find.text('Session 1')),
          findsOneWidget);
      expect(find.text('61 min · 7 moves'), findsOneWidget);
    });

    testWidgets('admin slots: 1 is the main card, 2 and 3 the small ones',
        (tester) async {
      await _pump(tester, sessions: [
        (
          session: _session(1, 'Morning Ritual', slot: 3),
          moves: 6,
          minutes: 20
        ),
        (
          session: _session(2, 'Full Pahlevani', slot: 1),
          moves: 29,
          minutes: 70
        ),
        (
          session: _session(3, 'Sheno Explosion', slot: 2),
          moves: 7,
          minutes: 15
        ),
        (session: _session(4, 'Not on Home'), moves: 3, minutes: 9),
      ]);
      final main = find.byKey(const ValueKey('home-today'));
      final small = find.byKey(const ValueKey('home-small-sessions'));
      expect(find.descendant(of: main, matching: find.text('Full Pahlevani')),
          findsOneWidget);
      expect(find.descendant(of: small, matching: find.text('Sheno Explosion')),
          findsOneWidget);
      expect(find.descendant(of: small, matching: find.text('Morning Ritual')),
          findsOneWidget);
      expect(find.text('Not on Home'), findsNothing);
    });

    testWidgets("a trainer's session takes the main card", (tester) async {
      await _pump(tester,
          user: const AppUser(
              id: 'me',
              email: 'sara@example.com',
              consentAccepted: true,
              termsVersion: currentTermsVersion),
          sessions: [
            (session: _session(1, 'Full', slot: 1), moves: 9, minutes: 60),
            (
              session: _session(9, 'For Sara', isPublic: false),
              moves: 5,
              minutes: 20
            ),
          ]);
      expect(find.text('FROM YOUR TRAINER'), findsOneWidget);
      final main = find.byKey(const ValueKey('home-today'));
      expect(find.descendant(of: main, matching: find.text('For Sara')),
          findsOneWidget);
    });

    testWidgets('a session that needs meel is tagged', (tester) async {
      await _pump(tester, sessions: [
        (session: _session(1, 'Full', slot: 1), moves: 9, minutes: 60),
        (
          session: _session(2, 'Morning Ritual', slot: 2, needsMeel: true),
          moves: 6,
          minutes: 20
        ),
        (session: _session(3, 'Sheno', slot: 3), moves: 7, minutes: 15),
      ]);
      expect(find.text('NEEDS MEEL'), findsOneWidget);
    });

    testWidgets('Start and the cards open their session', (tester) async {
      final calls = await _pump(tester);
      await tester.tap(find.text('Start'));
      await tester.tap(find.text('Session 2'));
      expect(calls.opened.map((s) => s.id), [1, 2]);
    });

    testWidgets('long-pressing a session card opens its hidden menu',
        (tester) async {
      final calls = await _pump(tester);
      await tester.longPress(find.text('Session 1'));
      await tester.longPress(find.text('Session 3'));
      expect(calls.menus.map((s) => s.id), [1, 3]);
      expect(calls.opened, isEmpty);
    });

    testWidgets('no sessions yet: a calm placeholder, no Start',
        (tester) async {
      await _pump(tester, sessions: const []);
      expect(find.text('Start'), findsNothing);
      expect(find.textContaining('Sessions are on their way'), findsOneWidget);
    });

    testWidgets('no shamseh, rep cards or All sessions on Home (release 1)',
        (tester) async {
      await _pump(tester, history: [
        _done(DateTime(2026, 9, 21), {'Shena': 42, 'Meel': 50}),
      ]);
      expect(find.textContaining('shamseh'), findsNothing);
      expect(find.text('All sessions'), findsNothing);
      expect(find.byKey(const ValueKey('home-rep-summary')), findsNothing);
    });
  });

  group('calendar and info', () {
    final history = [
      _done(DateTime(2026, 9, 16), {'Shena': 40}),
      _done(DateTime(2026, 9, 21), {'Shena': 42}),
    ];

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

    testWidgets('the info card shows its title and opens its link',
        (tester) async {
      final calls = await _pump(tester);
      await tester.scrollUntilVisible(find.text('Rahaavi'), 80,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Rahaavi'));
      expect(calls.infoOpened, [_info]);
    });
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

  group('responsive bento', () {
    const tablet = Size(834, 1194);
    const web = Size(1440, 900);

    Rect rectOf(WidgetTester tester, String key) =>
        tester.getRect(find.byKey(ValueKey(key)));

    testWidgets('phone: the small sessions side by side under the main card',
        (tester) async {
      await _pump(tester);
      final main = rectOf(tester, 'home-today');
      final small = rectOf(tester, 'home-small-sessions');
      expect(small.top, greaterThan(main.bottom));
      expect(tester.getRect(find.text('Session 2')).top,
          tester.getRect(find.text('Session 3')).top);
      expect(rectOf(tester, 'home-month-strip').top, greaterThan(small.bottom));
    });

    testWidgets(
        'tablet: the main card over two columns, the small sessions '
        'stacked beside it; the month strip below', (tester) async {
      await _pump(tester, size: tablet);
      expect(tester.takeException(), isNull);
      final main = rectOf(tester, 'home-today');
      final small = rectOf(tester, 'home-small-sessions');
      expect(small.top, main.top);
      expect(main.width, greaterThan(small.width * 1.8));
      expect(tester.getRect(find.text('Session 3')).top,
          greaterThan(tester.getRect(find.text('Session 2')).top));
      expect(rectOf(tester, 'home-month-strip').top, greaterThan(main.bottom));
      expect(find.byKey(const ValueKey('home-calendar')), findsNothing);
    });

    testWidgets(
        'web: main card, small sessions and the month calendar on '
        'one row', (tester) async {
      await _pump(tester, size: web);
      expect(tester.takeException(), isNull);
      final main = rectOf(tester, 'home-today');
      expect(rectOf(tester, 'home-small-sessions').top, main.top);
      expect(rectOf(tester, 'home-calendar').top, main.top);
      expect(find.byKey(const ValueKey('home-month-strip')), findsNothing);
    });

    for (final size in const [
      Size(600, 900),
      Size(1100, 800),
      Size(1101, 700),
      Size(2560, 1440)
    ]) {
      testWidgets('lays out without overflow at the edge size $size',
          (tester) async {
        await _pump(tester, size: size);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
