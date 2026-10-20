import 'package:equatable/equatable.dart';

import 'fitness_test_answer.dart';

/// Whether an axis's score is its one subtest's score directly, or the
/// average of 2 subtest scores (e.g. Inversion Mastery averages Handstand
/// Hold + Handstand Push-up).
enum FitnessAxisScoringLogic { single, average }

/// How a level's [FitnessTestLevel.thresholdValue] compares against the
/// value the test-taker enters.
enum FitnessRequirementComparison {
  /// Higher entered value is better (reps, seconds held, meters, minutes-as-volume).
  directAscending,

  /// Lower entered value is better (run times).
  directDescending,

  /// entered value ÷ bodyweight vs threshold — higher ratio is better.
  ratioToBodyweight,

  /// entered value ÷ height vs threshold — higher ratio is better.
  ratioToHeight,
}

/// One rung of a subtest's 7-level ladder.
class FitnessTestLevel extends Equatable {
  final int levelNumber; // 1-7
  final String
      requirementLabel; // shown in the read-only ladder, e.g. "25 Standard Push-ups"
  final String inputLabel; // e.g. "Standard Push-ups (reps)"
  final String inputUnit; // 'reps' | 'seconds' | 'meters' | 'kg' | 'minutes'
  final double thresholdValue;
  final FitnessRequirementComparison comparison;

  /// Only meaningful for [FitnessRequirementComparison.ratioToBodyweight]/
  /// `.ratioToHeight` — an additive offset on top of the ratio, e.g. Broad
  /// Jump's "Height + 30cm" levels: `thresholdValue = 1.0, ratioOffset = 30`.
  /// Zero for every ordinary ratio (and ignored for direct comparisons).
  final double ratioOffset;

  /// False at a level that introduces a different exercise/unit than the
  /// level directly below it (e.g. One Leg Squat level 3→4 switching from
  /// Side Lunges to platform-assisted Pistol Squat) — the analyzer can't
  /// fractionally interpolate across that boundary.
  final bool continuousFromPrevious;

  const FitnessTestLevel({
    required this.levelNumber,
    required this.requirementLabel,
    required this.inputLabel,
    required this.inputUnit,
    required this.thresholdValue,
    required this.comparison,
    required this.continuousFromPrevious,
    this.ratioOffset = 0,
  });

  /// The actual value the test-taker must meet or beat at this level, in
  /// [inputUnit] — a plain number for direct comparisons, or
  /// `thresholdValue * bodyMetric + ratioOffset` for ratio comparisons (e.g.
  /// "80% of your height" becomes a real centimeter target once the
  /// profile's height is known). Null only when a ratio comparison needs a
  /// profile field ([FitnessTestProfile.bodyweightKg]/`.heightCm`) that
  /// hasn't been captured.
  double? requiredRawValue(FitnessTestProfile profile) {
    switch (comparison) {
      case FitnessRequirementComparison.directAscending:
      case FitnessRequirementComparison.directDescending:
        return thresholdValue;
      case FitnessRequirementComparison.ratioToBodyweight:
        final bw = profile.bodyweightKg;
        if (bw == null) return null;
        return thresholdValue * bw + ratioOffset;
      case FitnessRequirementComparison.ratioToHeight:
        final h = profile.heightCm;
        if (h == null) return null;
        return thresholdValue * h + ratioOffset;
    }
  }

  @override
  List<Object?> get props => [
        levelNumber,
        requirementLabel,
        inputLabel,
        inputUnit,
        thresholdValue,
        comparison,
        continuousFromPrevious,
        ratioOffset,
      ];
}

/// One independently-scored ladder within an axis. Most axes have exactly
/// one subtest; axes with [FitnessAxisScoringLogic.average] have 2 (e.g.
/// Lower Body Mastery = Jumping Squats + One Leg Squat).
class FitnessTestSubtest extends Equatable {
  final String subtestKey;
  final String displayName;
  final bool needsBodyweight;
  final bool needsHeight;

  /// Exactly 7, sorted by [FitnessTestLevel.levelNumber].
  final List<FitnessTestLevel> levels;

  const FitnessTestSubtest({
    required this.subtestKey,
    required this.displayName,
    required this.needsBodyweight,
    required this.needsHeight,
    required this.levels,
  });

  FitnessTestLevel levelAt(int levelNumber) =>
      levels.firstWhere((l) => l.levelNumber == levelNumber);

  @override
  List<Object?> get props =>
      [subtestKey, displayName, needsBodyweight, needsHeight, levels];
}

/// One wizard step / one spoke of the radar chart.
class FitnessTestAxis extends Equatable {
  final String axisKey;
  final String displayName;
  final FitnessAxisScoringLogic scoringLogic;

  /// 1 subtest for [FitnessAxisScoringLogic.single], 2 for `.average`.
  final List<FitnessTestSubtest> subtests;

  const FitnessTestAxis({
    required this.axisKey,
    required this.displayName,
    required this.scoringLogic,
    required this.subtests,
  });

  bool get needsBodyweight => subtests.any((s) => s.needsBodyweight);
  bool get needsHeight => subtests.any((s) => s.needsHeight);

  @override
  List<Object?> get props => [axisKey, displayName, scoringLogic, subtests];
}

/// One of the two test stages ("Bodyweight & Midline" / "Athletics & Power"),
/// exactly 7 axes each.
class FitnessTestChart extends Equatable {
  final String chartKey;
  final String title;
  final List<FitnessTestAxis> axes;

  const FitnessTestChart({
    required this.chartKey,
    required this.title,
    required this.axes,
  });

  bool get needsBodyweight => axes.any((a) => a.needsBodyweight);
  bool get needsHeight => axes.any((a) => a.needsHeight);

  @override
  List<Object?> get props => [chartKey, title, axes];
}
