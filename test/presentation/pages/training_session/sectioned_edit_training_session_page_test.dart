import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/prescription.dart';
import 'package:pahlevani/domain/entities/training_session/session_details.dart';
import 'package:pahlevani/domain/entities/training_session/training_item.dart';
import 'package:pahlevani/domain/entities/training_session/training_section.dart';
import 'package:pahlevani/domain/entities/training_session/training_session.dart';
import 'package:pahlevani/presentation/pages/training_session/sectioned_edit_training_session_page.dart';

Exercise _ex(int id, String name, {int reps = 2, int? seconds}) => Exercise(
    id: id, name: name, repetitionsDefault: reps, durationSeconds: seconds);

ItemDetail _item(Exercise ex, int position, TrainingSection section,
        {int reps = 2}) =>
    ItemDetail(
      item: TrainingItem(
        id: 700 * 10000 + position,
        sessionId: 700,
        exerciseId: ex.id,
        position: position,
        prescription: RepsPresc(reps),
        section: section,
      ),
      exercise: ex,
    );

final _session = TrainingSession(
  id: 700,
  title: 'Plan',
  description: '',
  difficulty: 2,
  isUserCreated: true,
);

Widget _harness({
  required List<ItemDetail> items,
  required List<Exercise> available,
  ValueChanged<Map<String, dynamic>?>? onPop,
}) =>
    MaterialApp(
      theme: PahlevaniTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SectionedEditTrainingSessionPage(
                      trainingSession: _session,
                      items: items,
                      availableExercises: available,
                    ),
                  ),
                );
                onPop?.call(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('items are grouped under their discipline tab', (tester) async {
    final meelEx = _ex(1, 'Meel Swing');
    final shenoEx = _ex(2, 'Shena');
    await tester.pumpWidget(_harness(
      items: [
        _item(meelEx, 0, TrainingSection.meel),
        _item(shenoEx, 1, TrainingSection.sheno),
      ],
      available: const [],
    ));
    await _openEditor(tester);

    // Meel tab is not the first tab; tap it and the Meel exercise shows.
    await tester.tap(find.text('Meel (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Meel Swing'), findsOneWidget);

    await tester.tap(find.text('Sheno (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Shena'), findsOneWidget);
  });

  testWidgets('reassigning an item moves it to another discipline tab',
      (tester) async {
    final ex = _ex(1, 'Mover');
    await tester.pumpWidget(_harness(
      items: [_item(ex, 0, TrainingSection.other)],
      available: const [],
    ));
    await _openEditor(tester);

    // Starts under Other (last tab — scroll the tab bar to reach it).
    await tester.ensureVisible(find.text('Other (1)'));
    await tester.tap(find.text('Other (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Mover'), findsOneWidget);

    // Change its section dropdown to Sang.
    await tester.tap(find.byType(DropdownButton<TrainingSection>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sang').last);
    await tester.pumpAndSettle();

    // Now it lives under the Sang tab, and Other is empty.
    expect(find.text('Sang (1)'), findsOneWidget);
    expect(find.text('Other (0)'), findsOneWidget);
  });

  testWidgets('save returns items carrying their section', (tester) async {
    Map<String, dynamic>? popped;
    final meelEx = _ex(1, 'Meel Swing');
    final sangEx = _ex(2, 'Sang Lift');
    await tester.pumpWidget(_harness(
      items: [
        _item(meelEx, 0, TrainingSection.meel),
        _item(sangEx, 1, TrainingSection.sang),
      ],
      available: const [],
      onPop: (r) => popped = r,
    ));
    await _openEditor(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final items = popped!['items'] as List<ItemDetail>;
    final sections = {for (final d in items) d.exercise.id: d.item.section};
    expect(sections[1], TrainingSection.meel);
    expect(sections[2], TrainingSection.sang);
  });

  testWidgets('adding an exercise from the picker inserts it into the section',
      (tester) async {
    await tester.pumpWidget(_harness(
      items: const [],
      available: [_ex(9, 'New Move')],
    ));
    await _openEditor(tester);

    // On the first (Warm up) tab, open the picker and add the exercise.
    await tester.tap(find.text('Add exercise to Warm up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Move'));
    await tester.pumpAndSettle();

    expect(find.text('Warm up (1)'), findsOneWidget);
    expect(find.text('New Move'), findsOneWidget);
  });

  testWidgets('summary tab reports the total duration', (tester) async {
    // 60s at default 2 reps → 30s/rep; 4 reps → 120s = 2 min.
    final ex = _ex(1, 'Timed', reps: 2, seconds: 60);
    await tester.pumpWidget(_harness(
      items: [_item(ex, 0, TrainingSection.warmUp, reps: 4)],
      available: const [],
    ));
    await _openEditor(tester);

    await tester.ensureVisible(find.text('Summary'));
    await tester.tap(find.text('Summary'));
    await tester.pumpAndSettle();

    expect(find.text('1 exercises'), findsOneWidget);
    expect(find.textContaining('Total ≈ 2 min'), findsOneWidget);
  });
}
