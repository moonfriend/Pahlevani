import 'package:equatable/equatable.dart';

/// One axis's computed score, ready to plot as a radar chart spoke.
class FitnessAxisScore extends Equatable {
  final String axisKey;
  final String displayName;

  /// 0.0-7.0. Whole number when the winning level-transition wasn't
  /// [FitnessTestLevel.continuousFromPrevious], otherwise fractionally
  /// interpolated between the last cleared level and the failed one.
  final double score;

  const FitnessAxisScore({
    required this.axisKey,
    required this.displayName,
    required this.score,
  });

  @override
  List<Object?> get props => [axisKey, displayName, score];
}

/// The analyzed result of one completed (or partially completed, if the
/// test-taker skipped a stage) chart run.
class FitnessTestStageResult extends Equatable {
  final String id;
  final String chartKey;
  final String chartTitle;
  final DateTime completedAt;

  /// One entry per axis in the chart, same order as the criteria.
  final List<FitnessAxisScore> axisScores;

  const FitnessTestStageResult({
    required this.id,
    required this.chartKey,
    required this.chartTitle,
    required this.completedAt,
    required this.axisScores,
  });

  @override
  List<Object?> get props =>
      [id, chartKey, chartTitle, completedAt, axisScores];
}
