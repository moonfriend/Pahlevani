import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/fitness_test_answer.dart';
import '../../../domain/entities/fitness_test_criteria.dart';
import '../../../domain/repositories/fitness_test_results_repository.dart';
import '../../../domain/services/fitness_test_analyzer.dart';
import 'fitness_test_wizard_state.dart';

/// Drives one run of the ladder-picker wizard for a single [FitnessTestChart]
/// stage: optional bodyweight/height capture, one step per axis, a review
/// step, then analysis + local save. A fresh cubit instance is created per
/// stage run (see FitnessTestLandingPage), so all state here is scoped to
/// that one run.
class FitnessTestWizardCubit extends Cubit<FitnessTestWizardState> {
  final FitnessTestAnalyzer _analyzer;
  final FitnessTestResultsRepository _resultsRepository;

  FitnessTestWizardCubit({
    required FitnessTestChart chart,
    required FitnessTestAnalyzer analyzer,
    required FitnessTestResultsRepository resultsRepository,
  })  : _analyzer = analyzer,
        _resultsRepository = resultsRepository,
        super(FitnessTestWizardInProgress(
          chart: chart,
          currentStepIndex: 0,
          answers: const {},
          profile: const FitnessTestProfile(),
          profileCaptured: false,
        ));

  void submitProfile({
    int? bodyweightValue,
    WeightUnit bodyweightUnit = WeightUnit.kg,
    int? heightValue,
    HeightUnit heightUnit = HeightUnit.cm,
  }) {
    final s = state;
    if (s is! FitnessTestWizardInProgress) return;
    emit(s.copyWith(
      profile: FitnessTestProfile(
        bodyweightValue: bodyweightValue,
        bodyweightUnit: bodyweightUnit,
        heightValue: heightValue,
        heightUnit: heightUnit,
      ),
      profileCaptured: true,
    ));
  }

  void answerSubtest(FitnessTestSubtestAnswer answer) {
    final s = state;
    if (s is! FitnessTestWizardInProgress) return;
    final updated = Map<String, FitnessTestSubtestAnswer>.from(s.answers)
      ..[answer.subtestKey] = answer;
    emit(s.copyWith(answers: updated));
  }

  /// Advances to the next step, or to Review if this was the last step (or
  /// this step was reached via an edit-from-review). No-op if the current
  /// step isn't fully answered yet.
  void next() {
    final s = state;
    if (s is! FitnessTestWizardInProgress || !s.canAdvance) return;

    if (s.returnToReviewOnNext || s.isLastStep) {
      emit(FitnessTestWizardReview(
          chart: s.chart, answers: s.answers, profile: s.profile));
      return;
    }
    emit(s.copyWith(currentStepIndex: s.currentStepIndex + 1));
  }

  void back() {
    final s = state;
    if (s is! FitnessTestWizardInProgress || s.currentStepIndex == 0) return;
    emit(s.copyWith(currentStepIndex: s.currentStepIndex - 1));
  }

  /// Jumps back into a step from the Review screen to correct an answer.
  /// Completing that one step (`next()`) returns straight to Review.
  void editAxis(int axisIndex) {
    final s = state;
    if (s is! FitnessTestWizardReview) return;
    emit(FitnessTestWizardInProgress(
      chart: s.chart,
      currentStepIndex: axisIndex,
      answers: s.answers,
      profile: s.profile,
      profileCaptured: true,
      returnToReviewOnNext: true,
    ));
  }

  Future<void> submit() async {
    final s = state;
    if (s is! FitnessTestWizardReview) return;
    emit(const FitnessTestWizardSubmitting());
    try {
      final result = _analyzer.analyze(
        chart: s.chart,
        answers: s.answers.values.toList(),
        profile: s.profile,
      );
      await _resultsRepository.saveResult(result);
      emit(FitnessTestWizardCompleted(result));
    } catch (e) {
      emit(FitnessTestWizardError('Failed to analyze results: $e'));
    }
  }
}
