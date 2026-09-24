import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/domain/repositories/learnt_exercises_repository.dart';
import 'package:pahlevani/presentation/widgets/player/learnt_toggle.dart';

import '../../../fakes/fake_learnt_exercises_repository.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: PahlevaniTheme.dark(), home: Scaffold(body: child));

void main() {
  tearDown(() => getIt.reset());

  testWidgets('reflects the exercise\'s stored learnt state', (tester) async {
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository(learntIds: {42}));

    await tester.pumpWidget(_wrap(const LearntToggle(exerciseId: 42)));
    await tester.pump();

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isTrue);
  });

  testWidgets('defaults to off for an exercise never marked learnt',
      (tester) async {
    getIt.registerSingleton<LearntExercisesRepository>(
        FakeLearntExercisesRepository());

    await tester.pumpWidget(_wrap(const LearntToggle(exerciseId: 42)));
    await tester.pump();

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isFalse);
  });

  testWidgets('tapping the switch persists the new learnt state',
      (tester) async {
    final repo = FakeLearntExercisesRepository();
    getIt.registerSingleton<LearntExercisesRepository>(repo);

    await tester.pumpWidget(_wrap(const LearntToggle(exerciseId: 42)));
    await tester.pump();

    await tester.tap(find.byType(Switch));
    await tester.pump();

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isTrue);
    expect(repo.learntIds, contains(42));
  });

  testWidgets('toggling off removes it from the learnt set', (tester) async {
    final repo = FakeLearntExercisesRepository(learntIds: {42});
    getIt.registerSingleton<LearntExercisesRepository>(repo);

    await tester.pumpWidget(_wrap(const LearntToggle(exerciseId: 42)));
    await tester.pump();

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(repo.learntIds, isNot(contains(42)));
  });
}
