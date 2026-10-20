import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/features/fitness_test/domain/entities/fitness_test_answer.dart';
import 'package:pahlevani/features/fitness_test/domain/entities/fitness_test_criteria.dart';
import 'package:pahlevani/features/fitness_test/domain/entities/fitness_test_result.dart';
import 'package:pahlevani/features/fitness_test/domain/repositories/fitness_test_results_repository.dart';
import 'package:pahlevani/features/fitness_test/domain/services/fitness_test_analyzer.dart';
import 'package:pahlevani/features/fitness_test/presentation/bloc/wizard/fitness_test_wizard_cubit.dart';
import 'package:pahlevani/features/fitness_test/presentation/bloc/wizard/fitness_test_wizard_state.dart';

class _FakeAnalyzer implements FitnessTestAnalyzer {
  List<FitnessTestSubtestAnswer>? lastAnswers;

  @override
  FitnessTestStageResult analyze({
    required FitnessTestChart chart,
    required List<FitnessTestSubtestAnswer> answers,
    required FitnessTestProfile profile,
  }) {
    lastAnswers = answers;
    return FitnessTestStageResult(
      id: 'r1',
      chartKey: chart.chartKey,
      chartTitle: chart.title,
      completedAt: DateTime(2026, 1, 1),
      axisScores: const [
        FitnessAxisScore(axisKey: 'a', displayName: 'A', score: 3.5),
      ],
    );
  }
}

class _FakeResultsRepository implements FitnessTestResultsRepository {
  final List<FitnessTestStageResult> saved = [];

  @override
  Future<void> saveResult(FitnessTestStageResult result) async {
    saved.add(result);
  }

  @override
  Future<FitnessTestStageResult?> latestResultFor(String chartKey) async =>
      saved.where((r) => r.chartKey == chartKey).lastOrNull;

  @override
  Future<List<FitnessTestStageResult>> allResults() async => saved;
}

FitnessTestLevel _level(int n, double threshold) => FitnessTestLevel(
      levelNumber: n,
      requirementLabel: 'Level $n',
      inputLabel: 'value',
      inputUnit: 'reps',
      thresholdValue: threshold,
      comparison: FitnessRequirementComparison.directAscending,
      continuousFromPrevious: true,
    );

void main() {
  final chart = FitnessTestChart(
    chartKey: 'chart1',
    title: 'Chart 1',
    axes: [
      FitnessTestAxis(
        axisKey: 'axis_a',
        displayName: 'Axis A',
        scoringLogic: FitnessAxisScoringLogic.single,
        subtests: [
          FitnessTestSubtest(
            subtestKey: 'sub_a',
            displayName: 'Axis A',
            needsBodyweight: false,
            needsHeight: false,
            levels: [_level(1, 10), _level(2, 20)],
          ),
        ],
      ),
      FitnessTestAxis(
        axisKey: 'axis_b',
        displayName: 'Axis B',
        scoringLogic: FitnessAxisScoringLogic.single,
        subtests: [
          FitnessTestSubtest(
            subtestKey: 'sub_b',
            displayName: 'Axis B',
            needsBodyweight: false,
            needsHeight: false,
            levels: [_level(1, 10), _level(2, 20)],
          ),
        ],
      ),
    ],
  );

  const answerA = FitnessTestSubtestAnswer(
      subtestKey: 'sub_a', failedAtLevel: 2, enteredValue: 15);
  const answerB = FitnessTestSubtestAnswer(
      subtestKey: 'sub_b', failedAtLevel: 2, enteredValue: 12);

  FitnessTestWizardCubit buildCubit(
          {_FakeAnalyzer? analyzer,
          _FakeResultsRepository? resultsRepository}) =>
      FitnessTestWizardCubit(
        chart: chart,
        analyzer: analyzer ?? _FakeAnalyzer(),
        resultsRepository: resultsRepository ?? _FakeResultsRepository(),
      );

  test('starts on step 0, in progress, not answerable yet', () {
    final cubit = buildCubit();
    final s = cubit.state as FitnessTestWizardInProgress;
    expect(s.currentStepIndex, 0);
    expect(s.canAdvance, isFalse);
    expect(s.needsProfileStep, isFalse); // this chart has no ratio axes
  });

  test('next() is a no-op until the current step is fully answered', () {
    final cubit = buildCubit();
    cubit.next();
    final s = cubit.state as FitnessTestWizardInProgress;
    expect(s.currentStepIndex, 0);
  });

  test('answering a step then next() advances to the next axis', () {
    final cubit = buildCubit();
    cubit.answerSubtest(answerA);
    cubit.next();
    final s = cubit.state as FitnessTestWizardInProgress;
    expect(s.currentStepIndex, 1);
    // previous answer preserved
    expect(s.answers['sub_a'], answerA);
  });

  test('back() preserves answers and moves to the previous step', () {
    final cubit = buildCubit();
    cubit.answerSubtest(answerA);
    cubit.next();
    cubit.back();
    final s = cubit.state as FitnessTestWizardInProgress;
    expect(s.currentStepIndex, 0);
    expect(s.answers['sub_a'], answerA);
  });

  test('back() at step 0 is a no-op', () {
    final cubit = buildCubit();
    cubit.back();
    final s = cubit.state as FitnessTestWizardInProgress;
    expect(s.currentStepIndex, 0);
  });

  test('completing the last step transitions to Review', () {
    final cubit = buildCubit();
    cubit.answerSubtest(answerA);
    cubit.next();
    cubit.answerSubtest(answerB);
    cubit.next();
    final s = cubit.state;
    expect(s, isA<FitnessTestWizardReview>());
    final review = s as FitnessTestWizardReview;
    expect(review.answers.keys, containsAll(['sub_a', 'sub_b']));
  });

  test(
      'editAxis from Review jumps back with returnToReviewOnNext set, and '
      'completing it returns straight to Review', () {
    final cubit = buildCubit();
    cubit.answerSubtest(answerA);
    cubit.next();
    cubit.answerSubtest(answerB);
    cubit.next(); // now in Review

    cubit.editAxis(0);
    final editing = cubit.state as FitnessTestWizardInProgress;
    expect(editing.currentStepIndex, 0);
    expect(editing.returnToReviewOnNext, isTrue);

    const revisedAnswerA = FitnessTestSubtestAnswer(
        subtestKey: 'sub_a', failedAtLevel: 2, enteredValue: 19);
    cubit.answerSubtest(revisedAnswerA);
    cubit.next();

    final backToReview = cubit.state as FitnessTestWizardReview;
    expect(backToReview.answers['sub_a'], revisedAnswerA);
  });

  test('submit analyzes the review answers and saves the result', () async {
    final analyzer = _FakeAnalyzer();
    final resultsRepository = _FakeResultsRepository();
    final cubit =
        buildCubit(analyzer: analyzer, resultsRepository: resultsRepository);

    cubit.answerSubtest(answerA);
    cubit.next();
    cubit.answerSubtest(answerB);
    cubit.next();

    await cubit.submit();

    expect(analyzer.lastAnswers, containsAll([answerA, answerB]));
    expect(resultsRepository.saved, hasLength(1));
    expect(cubit.state, isA<FitnessTestWizardCompleted>());
    final completed = cubit.state as FitnessTestWizardCompleted;
    expect(completed.result.axisScores.single.score, 3.5);
  });

  test('a stage needing bodyweight/height requires the profile step first', () {
    final ratioChart = FitnessTestChart(
      chartKey: 'chart2',
      title: 'Chart 2',
      axes: [
        FitnessTestAxis(
          axisKey: 'deadlift',
          displayName: 'Deadlift',
          scoringLogic: FitnessAxisScoringLogic.single,
          subtests: [
            FitnessTestSubtest(
              subtestKey: 'deadlift',
              displayName: 'Deadlift',
              needsBodyweight: true,
              needsHeight: false,
              levels: [_level(1, 0.4), _level(2, 0.5)],
            ),
          ],
        ),
      ],
    );
    final cubit = FitnessTestWizardCubit(
      chart: ratioChart,
      analyzer: _FakeAnalyzer(),
      resultsRepository: _FakeResultsRepository(),
    );
    var s = cubit.state as FitnessTestWizardInProgress;
    expect(s.needsProfileStep, isTrue);

    cubit.submitProfile(bodyweightValue: 80);
    s = cubit.state as FitnessTestWizardInProgress;
    expect(s.needsProfileStep, isFalse);
    expect(s.profile.bodyweightKg, 80);
  });

  test(
      'submitProfile converts an imperial entry to the metric value used for scoring',
      () {
    final ratioChart = FitnessTestChart(
      chartKey: 'chart2',
      title: 'Chart 2',
      axes: [
        FitnessTestAxis(
          axisKey: 'broad_jump',
          displayName: 'Broad Jump',
          scoringLogic: FitnessAxisScoringLogic.single,
          subtests: [
            FitnessTestSubtest(
              subtestKey: 'broad_jump',
              displayName: 'Broad Jump',
              needsBodyweight: false,
              needsHeight: true,
              levels: [_level(1, 0.8), _level(2, 0.9)],
            ),
          ],
        ),
      ],
    );
    final cubit = FitnessTestWizardCubit(
      chart: ratioChart,
      analyzer: _FakeAnalyzer(),
      resultsRepository: _FakeResultsRepository(),
    );

    cubit.submitProfile(heightValue: 70, heightUnit: HeightUnit.inch);
    final s = cubit.state as FitnessTestWizardInProgress;
    // 70 inches * 2.54 = 177.8 cm — the raw 70 is preserved exactly for
    // redisplay, while heightCm is the derived metric value used for scoring.
    expect(s.profile.heightValue, 70);
    expect(s.profile.heightUnit, HeightUnit.inch);
    expect(s.profile.heightCm, closeTo(177.8, 1e-9));
  });
}
