import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/theme/kashi/kashi_assets.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/entities/training_session/exercise.dart';
import 'package:pahlevani/domain/entities/training_session/move_variation.dart';
import 'package:pahlevani/presentation/widgets/kashi/kashi_labels.dart';
import 'package:pahlevani/presentation/widgets/kashi/learning_sheet.dart';

/// Opens the sheet from a button and records what it returned.
Future<List<bool>> _open(
  WidgetTester tester, {
  required Exercise exercise,
  int? targetReps,
  String actionLabel = 'Got it',
  Widget? footer,
}) async {
  final results = <bool>[];
  await tester.binding.setSurfaceSize(const Size(360, 740));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: PahlevaniTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => results.add(await showLearningSheet(
            context,
            exercise: exercise,
            media: exercise.media,
            videoReady: false,
            targetReps: targetReps,
            actionLabel: actionLabel,
            footer: footer,
          )),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('shows the name, the reps tag and the three cues',
      (tester) async {
    await _open(
      tester,
      exercise: const Exercise(
        id: 1,
        name: 'Shena',
        titleFa: 'شنا',
        cues: ['Back long', 'Breathe out', 'One rep per beat'],
      ),
      targetReps: 40,
    );

    expect(find.text('Shena'), findsOneWidget);
    expect(find.text('شنا'), findsOneWidget);
    expect(find.byType(KashiRepsTag), findsOneWidget);
    expect(find.text('40 reps'), findsOneWidget);
    expect(find.text('PAY ATTENTION TO'), findsOneWidget);
    for (final cue in ['Back long', 'Breathe out', 'One rep per beat']) {
      expect(find.text(cue), findsOneWidget);
    }
  });

  group('Lighter / Harder', () {
    const shena = Exercise(id: 1, name: 'Shena', variations: [
      MoveVariation(name: 'Knee shena', level: 'EASIER', reps: 12),
      MoveVariation(name: 'Shena', level: 'STANDARD', reps: 20),
      MoveVariation(name: 'Sar Navazi', level: 'HARDER', reps: 30),
    ]);

    testWidgets('starts on the standard (middle) variation', (tester) async {
      await _open(tester, exercise: shena, targetReps: 40);
      expect(find.text('Lighter'), findsOneWidget);
      expect(find.text('Harder'), findsOneWidget);
      expect(find.text('STANDARD'), findsOneWidget);
      expect(find.text('20 reps'), findsOneWidget);
    });

    testWidgets('Harder and Lighter step through; the reps follow',
        (tester) async {
      await _open(tester, exercise: shena, targetReps: 40);

      await tester.tap(find.text('Harder'));
      await tester.pump();
      expect(find.text('Sar Navazi'), findsOneWidget);
      expect(find.text('30 reps'), findsOneWidget);

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Lighter'));
        await tester.pump();
      }
      expect(find.text('Knee shena'), findsOneWidget);
      expect(find.text('12 reps'), findsOneWidget);
    });

    testWidgets('a move without variations has no selector', (tester) async {
      await _open(tester,
          exercise: const Exercise(id: 1, name: 'Charkh', cues: ['Spin']));
      expect(find.text('Lighter'), findsNothing);
    });
  });

  testWidgets('a move that is not counted has no reps tag', (tester) async {
    await _open(tester,
        exercise: const Exercise(id: 1, name: 'Charkh', cues: ['Spin']));
    expect(find.byType(KashiRepsTag), findsNothing);
  });

  testWidgets('without cues it falls back to the description', (tester) async {
    await _open(tester,
        exercise: const Exercise(
            id: 1, name: 'Charkh', description: 'Spin on the spot.'));

    expect(find.text('PAY ATTENTION TO'), findsNothing);
    expect(find.text('HOW TO'), findsOneWidget);
    expect(find.text('Spin on the spot.'), findsOneWidget);
  });

  testWidgets('with no content at all it still opens, without empty sections',
      (tester) async {
    await _open(tester, exercise: const Exercise(id: 1, name: 'Charkh'));

    expect(find.text('Charkh'), findsOneWidget);
    expect(find.text('PAY ATTENTION TO'), findsNothing);
    expect(find.text('HOW TO'), findsNothing);
    expect(find.text('Got it'), findsOneWidget);
  });

  testWidgets('the action returns true; ✕ returns false', (tester) async {
    final results =
        await _open(tester, exercise: const Exercise(id: 1, name: 'Shena'));
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(results, [true]);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(results, [true, false]);
  });

  testWidgets('shows a custom action label and footer', (tester) async {
    await _open(tester,
        exercise: const Exercise(id: 1, name: 'Shena'),
        actionLabel: 'Go',
        footer: const Text('learnt toggle'));
    expect(find.text('Go'), findsOneWidget);
    expect(find.text('learnt toggle'), findsOneWidget);
  });

  testWidgets('a move without a video or photo shows the illustration',
      (tester) async {
    await _open(tester, exercise: const Exercise(id: 1, name: 'Charkh'));
    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<AssetImage>()
        .map((a) => a.assetName);
    expect(assets, contains(KashiAssets.pahlevanFemale));
  });
}
