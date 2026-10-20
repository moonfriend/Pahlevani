import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/features/fitness_test/data/services/local_fitness_test_analyzer.dart';
import 'package:pahlevani/features/fitness_test/domain/entities/fitness_test_answer.dart';
import 'package:pahlevani/features/fitness_test/domain/entities/fitness_test_criteria.dart';

FitnessTestLevel _level(
  int n,
  double threshold, {
  FitnessRequirementComparison comparison =
      FitnessRequirementComparison.directAscending,
  bool continuousFromPrevious = true,
  double ratioOffset = 0,
}) =>
    FitnessTestLevel(
      levelNumber: n,
      requirementLabel: 'Level $n',
      inputLabel: 'value',
      inputUnit: 'reps',
      thresholdValue: threshold,
      comparison: comparison,
      continuousFromPrevious: continuousFromPrevious,
      ratioOffset: ratioOffset,
    );

FitnessTestSubtest _subtest(String key, List<FitnessTestLevel> levels,
        {bool needsBodyweight = false, bool needsHeight = false}) =>
    FitnessTestSubtest(
      subtestKey: key,
      displayName: key,
      needsBodyweight: needsBodyweight,
      needsHeight: needsHeight,
      levels: levels,
    );

void main() {
  group('LocalFitnessTestAnalyzer', () {
    final analyzer = LocalFitnessTestAnalyzer();

    test('direct ascending: interpolates fractionally between levels', () {
      final subtest = _subtest('push', [
        _level(1, 10),
        _level(2, 20),
        _level(3, 30),
        _level(4, 40),
      ]);
      final axis = FitnessTestAxis(
        axisKey: 'push',
        displayName: 'Push',
        scoringLogic: FitnessAxisScoringLogic.single,
        subtests: [subtest],
      );
      final chart =
          FitnessTestChart(chartKey: 'c', title: 'Chart', axes: [axis]);

      final result = analyzer.analyze(
        chart: chart,
        answers: [
          const FitnessTestSubtestAnswer(
              subtestKey: 'push', failedAtLevel: 3, enteredValue: 22),
        ],
        profile: const FitnessTestProfile(),
      );

      // cleared level 2 (threshold 20), failed level 3 (threshold 30),
      // entered 22 -> 2 + (22-20)/(30-20) = 2.2
      expect(result.axisScores.single.score, closeTo(2.2, 1e-9));
    });

    test('direct descending: lower entered value scores higher', () {
      final subtest = _subtest('run', [
        _level(1, 300,
            comparison: FitnessRequirementComparison.directDescending),
        _level(2, 240,
            comparison: FitnessRequirementComparison.directDescending),
        _level(3, 210,
            comparison: FitnessRequirementComparison.directDescending),
      ]);
      final axis = FitnessTestAxis(
        axisKey: 'run',
        displayName: 'Run',
        scoringLogic: FitnessAxisScoringLogic.single,
        subtests: [subtest],
      );
      final chart =
          FitnessTestChart(chartKey: 'c', title: 'Chart', axes: [axis]);

      final result = analyzer.analyze(
        chart: chart,
        answers: [
          const FitnessTestSubtestAnswer(
              subtestKey: 'run', failedAtLevel: 3, enteredValue: 225),
        ],
        profile: const FitnessTestProfile(),
      );

      // cleared level 2 (240), failed level 3 (210), entered 225 ->
      // 2 + (225-240)/(210-240) = 2 + (-15/-30) = 2.5
      expect(result.axisScores.single.score, closeTo(2.5, 1e-9));
    });

    test('ratio to bodyweight divides entered value before comparing', () {
      final subtest = _subtest(
        'deadlift',
        [
          _level(1, 0.4,
              comparison: FitnessRequirementComparison.ratioToBodyweight),
          _level(2, 0.5,
              comparison: FitnessRequirementComparison.ratioToBodyweight),
          _level(3, 0.75,
              comparison: FitnessRequirementComparison.ratioToBodyweight),
        ],
        needsBodyweight: true,
      );
      final axis = FitnessTestAxis(
        axisKey: 'deadlift',
        displayName: 'Deadlift',
        scoringLogic: FitnessAxisScoringLogic.single,
        subtests: [subtest],
      );
      final chart =
          FitnessTestChart(chartKey: 'c', title: 'Chart', axes: [axis]);

      final result = analyzer.analyze(
        chart: chart,
        answers: [
          const FitnessTestSubtestAnswer(
              subtestKey: 'deadlift', failedAtLevel: 3, enteredValue: 55),
        ],
        profile: const FitnessTestProfile(bodyweightValue: 100),
      );

      // ratio entered = 55/100 = 0.55; cleared level 2 (0.5), failed level 3
      // (0.75) -> 2 + (0.55-0.5)/(0.75-0.5) = 2.2
      expect(result.axisScores.single.score, closeTo(2.2, 1e-9));
    });

    test('ratio to height behaves the same way with height', () {
      final subtest = _subtest(
        'jump',
        [
          _level(1, 0.6,
              comparison: FitnessRequirementComparison.ratioToHeight),
          _level(2, 0.7,
              comparison: FitnessRequirementComparison.ratioToHeight),
        ],
        needsHeight: true,
      );
      final axis = FitnessTestAxis(
        axisKey: 'jump',
        displayName: 'Jump',
        scoringLogic: FitnessAxisScoringLogic.single,
        subtests: [subtest],
      );
      final chart =
          FitnessTestChart(chartKey: 'c', title: 'Chart', axes: [axis]);

      final result = analyzer.analyze(
        chart: chart,
        answers: [
          const FitnessTestSubtestAnswer(
              subtestKey: 'jump', failedAtLevel: 2, enteredValue: 130),
        ],
        profile: const FitnessTestProfile(heightValue: 200),
      );

      // ratio entered = 130/200 = 0.65; cleared level 1 (0.6), failed level 2
      // (0.7) -> 1 + (0.65-0.6)/(0.7-0.6) = 1.5
      expect(result.axisScores.single.score, closeTo(1.5, 1e-9));
    });

    test(
        'ratioOffset adds a flat amount on top of the ratio target '
        "(e.g. Broad Jump's 'Height + 30cm')", () {
      final subtest = _subtest(
        'broad_jump',
        [
          _level(5, 1.0,
              comparison: FitnessRequirementComparison.ratioToHeight),
          _level(6, 1.0,
              comparison: FitnessRequirementComparison.ratioToHeight,
              ratioOffset: 30),
        ],
        needsHeight: true,
      );
      final axis = FitnessTestAxis(
        axisKey: 'broad_jump',
        displayName: 'Broad Jump',
        scoringLogic: FitnessAxisScoringLogic.single,
        subtests: [subtest],
      );
      final chart =
          FitnessTestChart(chartKey: 'c', title: 'Chart', axes: [axis]);

      final result = analyzer.analyze(
        chart: chart,
        answers: [
          const FitnessTestSubtestAnswer(
              subtestKey: 'broad_jump', failedAtLevel: 6, enteredValue: 185),
        ],
        profile: const FitnessTestProfile(heightValue: 180),
      );

      // level 5 target = 1.0*180+0 = 180 (cleared); level 6 target =
      // 1.0*180+30 = 210 (failed) -> 5 + (185-180)/(210-180) = 5.1667
      expect(result.axisScores.single.score, closeTo(5 + 5 / 30, 1e-9));
    });

    test(
        'non-continuous level transition falls back to whole-level score, ignoring entered value',
        () {
      final subtest = _subtest('pistol', [
        _level(1, 0),
        _level(2, 1),
        _level(3, 2),
        _level(4, 4,
            continuousFromPrevious: false), // platform variant kicks in
      ]);
      final axis = FitnessTestAxis(
        axisKey: 'pistol',
        displayName: 'Pistol',
        scoringLogic: FitnessAxisScoringLogic.single,
        subtests: [subtest],
      );
      final chart =
          FitnessTestChart(chartKey: 'c', title: 'Chart', axes: [axis]);

      final result = analyzer.analyze(
        chart: chart,
        answers: [
          const FitnessTestSubtestAnswer(
              subtestKey: 'pistol', failedAtLevel: 4, enteredValue: 3),
        ],
        profile: const FitnessTestProfile(),
      );

      expect(result.axisScores.single.score, 3.0);
    });

    test('failing at level 1 scores 0, no partial credit below it', () {
      final subtest = _subtest('grip', [_level(1, 10), _level(2, 25)]);
      final axis = FitnessTestAxis(
        axisKey: 'grip',
        displayName: 'Grip',
        scoringLogic: FitnessAxisScoringLogic.single,
        subtests: [subtest],
      );
      final chart =
          FitnessTestChart(chartKey: 'c', title: 'Chart', axes: [axis]);

      final result = analyzer.analyze(
        chart: chart,
        answers: [
          const FitnessTestSubtestAnswer(
              subtestKey: 'grip', failedAtLevel: 1, enteredValue: 4),
        ],
        profile: const FitnessTestProfile(),
      );

      expect(result.axisScores.single.score, 0.0);
    });

    test('"I can do all of these" (maxed) scores the full 7.0', () {
      final subtest = _subtest('plank', [_level(1, 40), _level(2, 50)]);
      final axis = FitnessTestAxis(
        axisKey: 'plank',
        displayName: 'Plank',
        scoringLogic: FitnessAxisScoringLogic.single,
        subtests: [subtest],
      );
      final chart =
          FitnessTestChart(chartKey: 'c', title: 'Chart', axes: [axis]);

      final result = analyzer.analyze(
        chart: chart,
        answers: [const FitnessTestSubtestAnswer.maxed('plank')],
        profile: const FitnessTestProfile(),
      );

      expect(result.axisScores.single.score, 7.0);
    });

    test('average-scoring axis averages its 2 subtest scores', () {
      final a = _subtest('handstand_hold', [_level(1, 10), _level(2, 20)]);
      final b = _subtest('handstand_pushup', [_level(1, 2), _level(2, 5)]);
      final axis = FitnessTestAxis(
        axisKey: 'inversion',
        displayName: 'Inversion Mastery',
        scoringLogic: FitnessAxisScoringLogic.average,
        subtests: [a, b],
      );
      final chart =
          FitnessTestChart(chartKey: 'c', title: 'Chart', axes: [axis]);

      final result = analyzer.analyze(
        chart: chart,
        answers: [
          // handstand_hold: cleared 1 (10), failed 2 (20), entered 15 -> 1.5
          const FitnessTestSubtestAnswer(
              subtestKey: 'handstand_hold', failedAtLevel: 2, enteredValue: 15),
          // handstand_pushup: maxed -> 7.0
          const FitnessTestSubtestAnswer.maxed('handstand_pushup'),
        ],
        profile: const FitnessTestProfile(),
      );

      // (1.5 + 7.0) / 2 = 4.25
      expect(result.axisScores.single.score, closeTo(4.25, 1e-9));
    });

    test('preserves axis order and titles from the chart', () {
      final axisA = FitnessTestAxis(
        axisKey: 'a',
        displayName: 'Axis A',
        scoringLogic: FitnessAxisScoringLogic.single,
        subtests: [
          _subtest('a', [_level(1, 10)])
        ],
      );
      final axisB = FitnessTestAxis(
        axisKey: 'b',
        displayName: 'Axis B',
        scoringLogic: FitnessAxisScoringLogic.single,
        subtests: [
          _subtest('b', [_level(1, 10)])
        ],
      );
      final chart = FitnessTestChart(
          chartKey: 'chart1', title: 'My Chart', axes: [axisA, axisB]);

      final result = analyzer.analyze(
        chart: chart,
        answers: [
          const FitnessTestSubtestAnswer.maxed('a'),
          const FitnessTestSubtestAnswer.maxed('b'),
        ],
        profile: const FitnessTestProfile(),
      );

      expect(result.chartKey, 'chart1');
      expect(result.chartTitle, 'My Chart');
      expect(result.axisScores.map((s) => s.axisKey), ['a', 'b']);
      expect(result.axisScores.map((s) => s.displayName), ['Axis A', 'Axis B']);
    });
  });
}
