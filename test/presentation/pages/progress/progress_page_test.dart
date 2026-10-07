import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/tracking/movement_key.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_count.dart';
import 'package:pahlevani/presentation/bloc/tracking/training_history_cubit.dart';
import 'package:pahlevani/presentation/pages/progress/calendar_page.dart';
import 'package:pahlevani/presentation/pages/progress/progress_page.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_day_tile.dart';
import 'package:pahlevani/presentation/widgets/kashi/shamseh.dart';

import '../../../fakes/fake_training_history_repository.dart';

final _today = DateTime(2026, 9, 30, 12);
final _shena = MovementKey.fromValue('m:1');

SessionCompletionRecord _session(DateTime at, {int? shena}) =>
    SessionCompletionRecord(
      id: at.toIso8601String(),
      sessionId: 1,
      sessionTitle: 'Full Pahlevani',
      completedAt: at,
      movementCounts: [
        if (shena != null)
          TrackedMovementCount(key: _shena, displayName: 'Shena', count: shena),
      ],
    );

Future<TrainingHistoryCubit> _cubitWith(
    WidgetTester tester, List<SessionCompletionRecord> records) async {
  final repo = FakeTrainingHistoryRepository();
  for (final r in records) {
    await repo.recordCompletion(r);
  }
  final cubit = TrainingHistoryCubit(historyRepository: repo);
  addTearDown(cubit.close);
  await cubit.load();
  return cubit;
}

Future<void> _pump(WidgetTester tester, TrainingHistoryCubit cubit, Widget page,
    {Size size = const Size(360, 740), ThemeData? theme}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? PahlevaniTheme.light(),
    home: BlocProvider.value(value: cubit, child: page),
  ));
}

void main() {
  final records = [
    _session(DateTime(2026, 8, 20), shena: 34),
    _session(DateTime(2026, 9, 16, 7), shena: 38),
    _session(DateTime(2026, 9, 16, 19), shena: 40),
    _session(DateTime(2026, 9, 21), shena: 42),
  ];

  group('ProgressPage', () {
    testWidgets('opens on the shamseh: one tile per completed session',
        (tester) async {
      final cubit = await _cubitWith(tester, records);
      await _pump(tester, cubit, ProgressPage(now: () => _today));

      expect(find.text('Your shamseh'), findsOneWidget);
      expect(find.text('4 sessions · it never resets'), findsOneWidget);
      final shamseh = tester.widget<Shamseh>(
          find.byWidgetPredicate((w) => w is Shamseh && w.size > 100));
      expect(shamseh.tilesLaid, 4);
      expect(find.text('Ring 1 · 3 / 8'), findsOneWidget);
      expect(find.text('Ring 2 · 0 / 16'), findsOneWidget);
    });

    testWidgets('logged moves: latest value per counted move', (tester) async {
      final cubit = await _cubitWith(tester, records);
      await _pump(tester, cubit, ProgressPage(now: () => _today));

      expect(find.text('LOGGED MOVES'), findsOneWidget);
      expect(find.text('Shena · last'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('the preview swaps to the calendar of the current month',
        (tester) async {
      final cubit = await _cubitWith(tester, records);
      await _pump(tester, cubit, ProgressPage(now: () => _today));

      await tester.tap(find.byTooltip('Show calendar'));
      await tester.pumpAndSettle();

      expect(find.text('Your calendar'), findsOneWidget);
      expect(find.text('3 sessions in September'), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('Trained · 2'), findsOneWidget,
          reason: 'two trained days (16th twice, 21st)');

      await tester.tap(find.byTooltip('Show shamseh'));
      await tester.pumpAndSettle();
      expect(find.text('Your shamseh'), findsOneWidget);
    });

    testWidgets('in the calendar view, tapping a day shows what was done',
        (tester) async {
      final cubit = await _cubitWith(tester, records);
      await _pump(tester, cubit, ProgressPage(now: () => _today));
      await tester.tap(find.byTooltip('Show calendar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('21'));
      await tester.pumpAndSettle();

      expect(find.text('Monday 21 September'), findsOneWidget);
      expect(find.text('Full Pahlevani'), findsOneWidget);
    });

    testWidgets('no history yet: empty shamseh and a friendly hint',
        (tester) async {
      final cubit = await _cubitWith(tester, const []);
      await _pump(tester, cubit, ProgressPage(now: () => _today));

      expect(find.text('0 sessions · it never resets'), findsOneWidget);
      expect(find.textContaining('Counted moves appear here'), findsOneWidget);
    });

    for (final size in const [
      Size(360, 740),
      Size(320, 568),
      Size(1440, 900)
    ]) {
      testWidgets('lays out without overflow at $size', (tester) async {
        final cubit = await _cubitWith(tester, records);
        await _pump(tester, cubit, ProgressPage(now: () => _today),
            size: size, theme: PahlevaniTheme.dark());
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('CalendarPage', () {
    testWidgets('shows the current month with trained days starred',
        (tester) async {
      final cubit = await _cubitWith(tester, records);
      await _pump(tester, cubit, CalendarPage(now: () => _today));

      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);
      final trained = tester
          .widgetList<KashiDayTile>(find.byType(KashiDayTile))
          .where((t) => t.day != null) // the legend's sample tile has none
          .where((t) => t.state == DayTileState.trained)
          .map((t) => t.day);
      expect(trained, unorderedEquals([16, 21]));
      expect(
          find.textContaining('the tile wall from the splash'), findsOneWidget);
    });

    testWidgets('‹ goes back as far as the first session, › to today',
        (tester) async {
      final cubit = await _cubitWith(tester, records);
      await _pump(tester, cubit, CalendarPage(now: () => _today));

      await tester.tap(find.byTooltip('Next month'));
      await tester.pump();
      expect(find.text('September 2026'), findsOneWidget,
          reason: 'no months after the current one');

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pump();
      expect(find.text('August 2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pump();
      expect(find.text('August 2026'), findsOneWidget,
          reason: 'nothing before the first session');
    });

    testWidgets('lays out without overflow on a small phone', (tester) async {
      final cubit = await _cubitWith(tester, records);
      await _pump(tester, cubit, CalendarPage(now: () => _today),
          size: const Size(320, 568));
      expect(tester.takeException(), isNull);
    });
  });
}
