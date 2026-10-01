import 'package:equatable/equatable.dart';

import '../../../domain/entities/fitness_test_answer.dart';
import '../../../domain/entities/fitness_test_criteria.dart';
import '../../../domain/entities/fitness_test_result.dart';

sealed class FitnessTestWizardState extends Equatable {
  const FitnessTestWizardState();

  @override
  List<Object?> get props => [];
}

/// Bodyweight/height not captured yet, or mid-question, mid-stage.
class FitnessTestWizardInProgress extends FitnessTestWizardState {
  final FitnessTestChart chart;
  final int currentStepIndex; // index into chart.axes
  final Map<String, FitnessTestSubtestAnswer> answers; // subtestKey -> answer
  final FitnessTestProfile profile;
  final bool profileCaptured;

  /// True when this step was reached by tapping "edit" on the review
  /// screen — completing it returns straight to Review rather than
  /// advancing to the next step.
  final bool returnToReviewOnNext;

  const FitnessTestWizardInProgress({
    required this.chart,
    required this.currentStepIndex,
    required this.answers,
    required this.profile,
    required this.profileCaptured,
    this.returnToReviewOnNext = false,
  });

  bool get needsProfileStep =>
      (chart.needsBodyweight || chart.needsHeight) && !profileCaptured;

  FitnessTestAxis get currentAxis => chart.axes[currentStepIndex];

  bool get canAdvance => currentAxis.subtests
      .every((s) => answers[s.subtestKey]?.isAnswered ?? false);

  bool get isLastStep => currentStepIndex == chart.axes.length - 1;

  FitnessTestWizardInProgress copyWith({
    int? currentStepIndex,
    Map<String, FitnessTestSubtestAnswer>? answers,
    FitnessTestProfile? profile,
    bool? profileCaptured,
    bool? returnToReviewOnNext,
  }) =>
      FitnessTestWizardInProgress(
        chart: chart,
        currentStepIndex: currentStepIndex ?? this.currentStepIndex,
        answers: answers ?? this.answers,
        profile: profile ?? this.profile,
        profileCaptured: profileCaptured ?? this.profileCaptured,
        returnToReviewOnNext: returnToReviewOnNext ?? this.returnToReviewOnNext,
      );

  @override
  List<Object?> get props => [
        chart,
        currentStepIndex,
        answers,
        profile,
        profileCaptured,
        returnToReviewOnNext,
      ];
}

/// Every axis answered — "what you're about to post" review, editable.
class FitnessTestWizardReview extends FitnessTestWizardState {
  final FitnessTestChart chart;
  final Map<String, FitnessTestSubtestAnswer> answers;
  final FitnessTestProfile profile;

  const FitnessTestWizardReview({
    required this.chart,
    required this.answers,
    required this.profile,
  });

  @override
  List<Object?> get props => [chart, answers, profile];
}

class FitnessTestWizardSubmitting extends FitnessTestWizardState {
  const FitnessTestWizardSubmitting();
}

class FitnessTestWizardCompleted extends FitnessTestWizardState {
  final FitnessTestStageResult result;

  const FitnessTestWizardCompleted(this.result);

  @override
  List<Object?> get props => [result];
}

class FitnessTestWizardError extends FitnessTestWizardState {
  final String message;

  const FitnessTestWizardError(this.message);

  @override
  List<Object?> get props => [message];
}
