import '../../domain/entities/fitness_test_answer.dart';
import '../../domain/entities/fitness_test_criteria.dart';
import '../../domain/entities/fitness_test_result.dart';
import '../../domain/services/fitness_test_analyzer.dart';

/// On-device implementation of [FitnessTestAnalyzer] — no network calls.
/// Matches each subtest answer against its ladder to produce a 0.0-7.0
/// score, fractionally interpolated between the last cleared level and the
/// failed one where the two are [FitnessTestLevel.continuousFromPrevious],
/// otherwise a whole-level score.
class LocalFitnessTestAnalyzer implements FitnessTestAnalyzer {
  @override
  FitnessTestStageResult analyze({
    required FitnessTestChart chart,
    required List<FitnessTestSubtestAnswer> answers,
    required FitnessTestProfile profile,
  }) {
    final answersByKey = {for (final a in answers) a.subtestKey: a};

    final axisScores = chart.axes.map((axis) {
      final subtestScores = axis.subtests.map((subtest) {
        final answer = answersByKey[subtest.subtestKey];
        return _scoreSubtest(subtest, answer, profile);
      });
      final axisScore =
          subtestScores.reduce((a, b) => a + b) / axis.subtests.length;
      return FitnessAxisScore(
        axisKey: axis.axisKey,
        displayName: axis.displayName,
        score: axisScore,
      );
    }).toList();

    return FitnessTestStageResult(
      id: '${chart.chartKey}-${DateTime.now().millisecondsSinceEpoch}',
      chartKey: chart.chartKey,
      chartTitle: chart.title,
      completedAt: DateTime.now(),
      axisScores: axisScores,
    );
  }

  double _scoreSubtest(
    FitnessTestSubtest subtest,
    FitnessTestSubtestAnswer? answer,
    FitnessTestProfile profile,
  ) {
    if (answer == null || !answer.isAnswered) return 0.0;
    if (answer.isMaxed) return 7.0;

    final failedLevel = answer.failedAtLevel!;
    final clearedLevel = failedLevel - 1;
    // No level below 1 to interpolate from — no partial credit.
    if (clearedLevel <= 0) return 0.0;

    final currentLevel = subtest.levelAt(failedLevel);
    if (!currentLevel.continuousFromPrevious) {
      return clearedLevel.toDouble();
    }

    final previousLevel = subtest.levelAt(clearedLevel);
    final currentRequired = currentLevel.requiredRawValue(profile);
    final previousRequired = previousLevel.requiredRawValue(profile);
    if (currentRequired == null || previousRequired == null) {
      // Ratio comparison but bodyweight/height wasn't captured — can't
      // compute a meaningful fraction, fall back to the whole cleared level.
      return clearedLevel.toDouble();
    }

    final entered = answer.enteredValue ?? 0;
    final denominator = currentRequired - previousRequired;
    if (denominator == 0) return clearedLevel.toDouble();

    final fraction =
        ((entered - previousRequired) / denominator).clamp(0.0, 1.0);
    return clearedLevel + fraction;
  }
}
