import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/features/fitness_test/domain/entities/fitness_test_answer.dart';
import 'package:pahlevani/features/fitness_test/domain/entities/fitness_test_criteria.dart';
import 'package:pahlevani/features/fitness_test/presentation/widgets/ladder_picker.dart';

FitnessTestSubtest _subtest({String inputUnit = 'reps'}) => FitnessTestSubtest(
      subtestKey: 'push',
      displayName: 'Horizontal Push',
      needsBodyweight: false,
      needsHeight: false,
      levels: [
        FitnessTestLevel(
          levelNumber: 1,
          requirementLabel: 'Level 1 requirement',
          inputLabel: 'Level 1 input',
          inputUnit: inputUnit,
          thresholdValue: 10,
          comparison: FitnessRequirementComparison.directAscending,
          continuousFromPrevious: true,
        ),
        FitnessTestLevel(
          levelNumber: 2,
          requirementLabel: 'Level 2 requirement',
          inputLabel: 'Level 2 input',
          inputUnit: inputUnit,
          thresholdValue: 20,
          comparison: FitnessRequirementComparison.directAscending,
          continuousFromPrevious: true,
        ),
        FitnessTestLevel(
          levelNumber: 3,
          requirementLabel: 'Level 3 requirement',
          inputLabel: 'Level 3 input',
          inputUnit: inputUnit,
          thresholdValue: 30,
          comparison: FitnessRequirementComparison.directAscending,
          continuousFromPrevious: true,
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );

void main() {
  testWidgets('renders every level, none checked, level 1 active by default',
      (tester) async {
    await _pump(
        tester,
        LadderPicker(
          subtest: _subtest(),
          initialAnswer: null,
          profile: const FitnessTestProfile(),
          onChanged: (_) {},
        ));

    expect(find.text('Level 1 requirement'), findsOneWidget);
    expect(find.text('Level 2 requirement'), findsOneWidget);
    expect(find.text('Level 3 requirement'), findsOneWidget);
    // Only the active (first, unchecked) row shows an amount field.
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
      'tapping a row checks it and everything above, revealing the next row\'s amount field',
      (tester) async {
    FitnessTestSubtestAnswer? lastAnswer;
    await _pump(
        tester,
        LadderPicker(
          subtest: _subtest(),
          initialAnswer: null,
          profile: const FitnessTestProfile(),
          onChanged: (a) => lastAnswer = a,
        ));

    await tester.tap(find.text('Level 2 requirement'));
    await tester.pump();

    expect(lastAnswer?.failedAtLevel, 3);
    expect(lastAnswer?.enteredValue, isNull);

    await tester.enterText(find.byType(TextField), '5');
    expect(lastAnswer?.failedAtLevel, 3);
    expect(lastAnswer?.enteredValue, 5);
  });

  testWidgets(
      'a previously typed amount does not carry over when the active row changes',
      (tester) async {
    FitnessTestSubtestAnswer? lastAnswer;
    await _pump(
        tester,
        LadderPicker(
          subtest: _subtest(),
          initialAnswer: null,
          profile: const FitnessTestProfile(),
          onChanged: (a) => lastAnswer = a,
        ));

    await tester.tap(find.text('Level 2 requirement'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '5');
    expect(lastAnswer?.enteredValue, 5);

    // Move the boundary back down to level 1 — the amount field (now for
    // level 2) must NOT still show the stale '5'.
    await tester.tap(find.text('Level 1 requirement'));
    await tester.pump();

    expect(find.text('5'), findsNothing);
    expect(lastAnswer?.failedAtLevel, 2);
    expect(lastAnswer?.enteredValue, isNull);
  });

  testWidgets('tapping the last row checks everything (maxed), no amount field',
      (tester) async {
    FitnessTestSubtestAnswer? lastAnswer;
    await _pump(
        tester,
        LadderPicker(
          subtest: _subtest(),
          initialAnswer: null,
          profile: const FitnessTestProfile(),
          onChanged: (a) => lastAnswer = a,
        ));

    await tester.tap(find.text('Level 3 requirement'));
    await tester.pump();

    expect(lastAnswer?.isMaxed, isTrue);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
      'tapping an already-checked row unchecks it, moving the boundary back',
      (tester) async {
    FitnessTestSubtestAnswer? lastAnswer;
    await _pump(
        tester,
        LadderPicker(
          subtest: _subtest(),
          initialAnswer: null,
          profile: const FitnessTestProfile(),
          onChanged: (a) => lastAnswer = a,
        ));

    await tester.tap(find.text('Level 2 requirement'));
    await tester.pump();
    expect(lastAnswer?.failedAtLevel, 3);

    await tester.tap(find.text('Level 2 requirement'));
    await tester.pump();
    expect(lastAnswer?.failedAtLevel, 2);
  });

  testWidgets(
      'resumes from a non-maxed initial answer with the amount prefilled',
      (tester) async {
    await _pump(
        tester,
        LadderPicker(
          subtest: _subtest(),
          initialAnswer: const FitnessTestSubtestAnswer(
              subtestKey: 'push', failedAtLevel: 3, enteredValue: 6),
          profile: const FitnessTestProfile(),
          onChanged: (_) {},
        ));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('resumes from a maxed initial answer with no amount field',
      (tester) async {
    await _pump(
        tester,
        LadderPicker(
          subtest: _subtest(),
          initialAnswer: const FitnessTestSubtestAnswer.maxed('push'),
          profile: const FitnessTestProfile(),
          onChanged: (_) {},
        ));

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
      'minutes-unit levels use mm:ss entry and parse to decimal minutes',
      (tester) async {
    FitnessTestSubtestAnswer? lastAnswer;
    await _pump(
        tester,
        LadderPicker(
          subtest: _subtest(inputUnit: 'minutes'),
          initialAnswer: null,
          profile: const FitnessTestProfile(),
          onChanged: (a) => lastAnswer = a,
        ));

    await tester.enterText(find.byType(TextField), '3:30');
    expect(lastAnswer?.enteredValue, closeTo(3.5, 1e-9));
  });

  testWidgets(
      'resuming a minutes-unit level formats decimal minutes back to mm:ss',
      (tester) async {
    await _pump(
        tester,
        LadderPicker(
          subtest: _subtest(inputUnit: 'minutes'),
          initialAnswer: const FitnessTestSubtestAnswer(
              subtestKey: 'push', failedAtLevel: 1, enteredValue: 3.5),
          profile: const FitnessTestProfile(),
          onChanged: (_) {},
        ));

    expect(find.text('3:30'), findsOneWidget);
  });

  testWidgets(
      'ratio-based levels show a real computed number using the profile',
      (tester) async {
    const subtest = FitnessTestSubtest(
      subtestKey: 'broad_jump',
      displayName: 'Broad Jump',
      needsBodyweight: false,
      needsHeight: true,
      levels: [
        FitnessTestLevel(
          levelNumber: 1,
          requirementLabel: '',
          inputLabel: 'Broad Jump distance (cm)',
          inputUnit: 'cm',
          thresholdValue: 0.8,
          comparison: FitnessRequirementComparison.ratioToHeight,
          continuousFromPrevious: true,
        ),
      ],
    );

    await _pump(
        tester,
        LadderPicker(
          subtest: subtest,
          initialAnswer: null,
          profile: const FitnessTestProfile(heightValue: 180),
          onChanged: (_) {},
        ));

    // 0.8 * 180 = 144cm, 80% of height.
    expect(find.textContaining('144'), findsOneWidget);
    expect(find.textContaining('80%'), findsOneWidget);
  });
}
