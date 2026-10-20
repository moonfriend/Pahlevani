import '../../domain/entities/fitness_test_criteria.dart';
import '../../domain/repositories/fitness_test_criteria_repository.dart';
import '../datasources/fitness_test_criteria_remote_datasource.dart';

class FitnessTestCriteriaRepositoryImpl
    implements FitnessTestCriteriaRepository {
  final FitnessTestCriteriaRemoteDataSource _remoteDataSource;

  FitnessTestCriteriaRepositoryImpl({
    required FitnessTestCriteriaRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<List<FitnessTestChart>> fetchCriteria() async {
    final chartRows = await _remoteDataSource.fetchCharts();
    final axisRows = await _remoteDataSource.fetchAxes();
    final subtestRows = await _remoteDataSource.fetchSubtests();
    final levelRows = await _remoteDataSource.fetchLevels();

    final levelsBySubtestId = <int, List<FitnessTestLevel>>{};
    for (final row in levelRows) {
      final subtestId = row['subtest_id'] as int;
      (levelsBySubtestId[subtestId] ??= []).add(_mapLevel(row));
    }

    final subtestsByAxisId = <int, List<FitnessTestSubtest>>{};
    for (final row in subtestRows) {
      final axisId = row['axis_id'] as int;
      final subtestId = row['id'] as int;
      (subtestsByAxisId[axisId] ??= []).add(_mapSubtest(
        row,
        levels: levelsBySubtestId[subtestId] ?? const [],
      ));
    }

    final axesByChartId = <int, List<FitnessTestAxis>>{};
    for (final row in axisRows) {
      final chartId = row['chart_id'] as int;
      final axisId = row['id'] as int;
      (axesByChartId[chartId] ??= []).add(_mapAxis(
        row,
        subtests: subtestsByAxisId[axisId] ?? const [],
      ));
    }

    return chartRows
        .map((row) => _mapChart(
              row,
              axes: axesByChartId[row['id'] as int] ?? const [],
            ))
        .toList();
  }

  FitnessTestChart _mapChart(Map<String, dynamic> row,
          {required List<FitnessTestAxis> axes}) =>
      FitnessTestChart(
        chartKey: row['chart_key'] as String,
        title: row['title'] as String,
        axes: axes,
      );

  FitnessTestAxis _mapAxis(Map<String, dynamic> row,
          {required List<FitnessTestSubtest> subtests}) =>
      FitnessTestAxis(
        axisKey: row['axis_key'] as String,
        displayName: row['display_name'] as String,
        scoringLogic: (row['scoring_logic'] as String) == 'average'
            ? FitnessAxisScoringLogic.average
            : FitnessAxisScoringLogic.single,
        subtests: subtests,
      );

  FitnessTestSubtest _mapSubtest(Map<String, dynamic> row,
          {required List<FitnessTestLevel> levels}) =>
      FitnessTestSubtest(
        subtestKey: row['subtest_key'] as String,
        displayName: row['display_name'] as String,
        needsBodyweight: row['needs_bodyweight'] as bool? ?? false,
        needsHeight: row['needs_height'] as bool? ?? false,
        levels: [...levels]
          ..sort((a, b) => a.levelNumber.compareTo(b.levelNumber)),
      );

  FitnessTestLevel _mapLevel(Map<String, dynamic> row) {
    final ratioDenominator = row['ratio_denominator'] as String?;
    final higherIsBetter = row['higher_is_better'] as bool? ?? true;
    final comparison = switch (ratioDenominator) {
      'bodyweight' => FitnessRequirementComparison.ratioToBodyweight,
      'height' => FitnessRequirementComparison.ratioToHeight,
      _ => higherIsBetter
          ? FitnessRequirementComparison.directAscending
          : FitnessRequirementComparison.directDescending,
    };
    return FitnessTestLevel(
      levelNumber: row['level_number'] as int,
      requirementLabel: row['requirement_label'] as String,
      inputLabel: row['input_label'] as String,
      inputUnit: row['input_unit'] as String,
      thresholdValue: (row['threshold_value'] as num).toDouble(),
      comparison: comparison,
      continuousFromPrevious: row['continuous_from_previous'] as bool? ?? true,
      ratioOffset: (row['ratio_offset'] as num?)?.toDouble() ?? 0,
    );
  }
}
