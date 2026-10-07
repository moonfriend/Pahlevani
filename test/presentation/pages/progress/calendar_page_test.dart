import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/tracking/movement_key.dart';
import 'package:pahlevani/domain/entities/tracking/session_completion_record.dart';
import 'package:pahlevani/domain/entities/tracking/tracked_movement_count.dart';
import 'package:pahlevani/presentation/bloc/tracking/training_history_cubit.dart';
import 'package:pahlevani/presentation/pages/progress/calendar_page.dart';

import '../../../fakes/fake_training_history_repository.dart';

final _today = DateTime(2026, 9, 30, 12);

SessionCompletionRecord _record(String id, String title, DateTime at,
        {List<(String, int)> counts = const []}) =>
    SessionCompletionRecord(
      id: id,
      sessionId: 1,
      sessionTitle: title,
      completedAt: at,
      movementCounts: [
        for (final (name, count) in counts)
          TrackedMovementCount(
              key: MovementKey.fromValue('m:$name'),
              displayName: name,
              count: count),
      ],
    );

Future<void> _pump(
    WidgetTester tester, List<SessionCompletionRecord> records) async {
  final repo = FakeTrainingHistoryRepository();
  for (final r in records) {
    await repo.recordCompletion(r);
  }
  final history = TrainingHistoryCubit(historyRepository: repo);
  addTearDown(history.close);
  await tester.runAsync(history.load);
  await tester.binding.setSurfaceSize(const Size(360, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(BlocProvider.value(
    value: history,
    child: MaterialApp(
      theme: PahlevaniTheme.light(),
      home: CalendarPage(now: () => _today),
    ),
  ));
}

void main() {
  testWidgets('tapping a trained day lists its sessions and reps',
      (tester) async {
    await _pump(tester, [
      _record('a', 'Morning Ritual', DateTime(2026, 9, 3, 7, 30),
          counts: [('Shena', 40), ('Meel', 12)]),
      _record('b', 'Sheno Explosion', DateTime(2026, 9, 3, 19, 5)),
      _record('c', 'Other day', DateTime(2026, 9, 4, 8)),
    ]);

    await tester.tap(find.text('3'));
    await tester.pump();

    expect(find.text('Thursday 3 September'), findsOneWidget);
    expect(find.text('Morning Ritual'), findsOneWidget);
    expect(find.text('Sheno Explosion'), findsOneWidget);
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text('Shena'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('Meel'), findsOneWidget);
    expect(find.text('Other day'), findsNothing);
  });

  testWidgets('a day without training says so', (tester) async {
    await _pump(tester, [
      _record('a', 'Morning Ritual', DateTime(2026, 9, 3, 7, 30)),
    ]);

    await tester.tap(find.text('10'));
    await tester.pump();

    expect(find.text('Thursday 10 September'), findsOneWidget);
    expect(find.text('Rest day — no session recorded.'), findsOneWidget);
  });

  testWidgets('opens on today', (tester) async {
    await _pump(tester, [
      _record('t', 'Today session', DateTime(2026, 9, 30, 9)),
    ]);
    expect(find.text('Wednesday 30 September'), findsOneWidget);
    expect(find.text('Today session'), findsOneWidget);
  });
}
