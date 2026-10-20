import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/features/fitness_test/data/datasources/fitness_test_criteria_remote_datasource.dart';
import 'package:pahlevani/features/fitness_test/data/repositories_impl/fitness_test_criteria_repository_impl.dart';
import 'package:pahlevani/features/fitness_test/domain/entities/fitness_test_criteria.dart';

class _FakeRemoteDataSource implements FitnessTestCriteriaRemoteDataSource {
  final List<Map<String, dynamic>> charts;
  final List<Map<String, dynamic>> axes;
  final List<Map<String, dynamic>> subtests;
  final List<Map<String, dynamic>> levels;

  _FakeRemoteDataSource({
    required this.charts,
    required this.axes,
    required this.subtests,
    required this.levels,
  });

  @override
  Future<List<Map<String, dynamic>>> fetchCharts() async => charts;
  @override
  Future<List<Map<String, dynamic>>> fetchAxes() async => axes;
  @override
  Future<List<Map<String, dynamic>>> fetchSubtests() async => subtests;
  @override
  Future<List<Map<String, dynamic>>> fetchLevels() async => levels;
}

void main() {
  test('fetchCriteria assembles the chart -> axis -> subtest -> level tree',
      () async {
    final repo = FitnessTestCriteriaRepositoryImpl(
      remoteDataSource: _FakeRemoteDataSource(
        charts: [
          {
            'id': 1,
            'chart_key': 'bodyweight_midline',
            'title': 'Bodyweight',
            'sort_order': 0
          },
        ],
        axes: [
          {
            'id': 10,
            'chart_id': 1,
            'axis_key': 'horizontal_push',
            'display_name': 'Horizontal Push',
            'scoring_logic': 'single',
            'sort_order': 0,
          },
          {
            'id': 11,
            'chart_id': 1,
            'axis_key': 'inversion',
            'display_name': 'Inversion Mastery',
            'scoring_logic': 'average',
            'sort_order': 1,
          },
        ],
        subtests: [
          {
            'id': 100,
            'axis_id': 10,
            'subtest_key': 'horizontal_push',
            'display_name': 'Horizontal Push',
            'sort_order': 0,
            'needs_bodyweight': false,
            'needs_height': false,
          },
          {
            'id': 101,
            'axis_id': 11,
            'subtest_key': 'handstand_hold',
            'display_name': 'Handstand Hold',
            'sort_order': 0,
            'needs_bodyweight': false,
            'needs_height': false,
          },
          {
            'id': 102,
            'axis_id': 11,
            'subtest_key': 'handstand_pushup',
            'display_name': 'Handstand Push-up',
            'sort_order': 1,
            'needs_bodyweight': false,
            'needs_height': false,
          },
        ],
        levels: [
          {
            'id': 1000,
            'subtest_id': 100,
            'level_number': 2,
            'requirement_label': '8 Knee OR 2 Standard Push-ups',
            'input_label': 'Push-ups (reps)',
            'input_unit': 'reps',
            'threshold_value': 8,
            'higher_is_better': true,
            'ratio_denominator': null,
            'continuous_from_previous': true,
          },
          {
            'id': 1001,
            'subtest_id': 100,
            'level_number': 1,
            'requirement_label': '20 Incline Knee Push-ups',
            'input_label': 'Push-ups (reps)',
            'input_unit': 'reps',
            'threshold_value': 20,
            'higher_is_better': true,
            'ratio_denominator': null,
            'continuous_from_previous': true,
          },
        ],
      ),
    );

    final charts = await repo.fetchCriteria();

    expect(charts, hasLength(1));
    final chart = charts.single;
    expect(chart.chartKey, 'bodyweight_midline');
    expect(chart.axes, hasLength(2));

    final pushAxis = chart.axes[0];
    expect(pushAxis.scoringLogic, FitnessAxisScoringLogic.single);
    expect(pushAxis.subtests, hasLength(1));
    // Levels come back out of order from the fake and must be sorted.
    expect(pushAxis.subtests.single.levels.map((l) => l.levelNumber), [1, 2]);

    final inversionAxis = chart.axes[1];
    expect(inversionAxis.scoringLogic, FitnessAxisScoringLogic.average);
    expect(inversionAxis.subtests.map((s) => s.subtestKey),
        ['handstand_hold', 'handstand_pushup']);
  });

  test('maps ratio_denominator and higher_is_better into comparison modes',
      () async {
    final repo = FitnessTestCriteriaRepositoryImpl(
      remoteDataSource: _FakeRemoteDataSource(
        charts: [
          {'id': 1, 'chart_key': 'c', 'title': 'C', 'sort_order': 0},
        ],
        axes: [
          {
            'id': 10,
            'chart_id': 1,
            'axis_key': 'a',
            'display_name': 'A',
            'scoring_logic': 'single',
            'sort_order': 0,
          },
        ],
        subtests: [
          {
            'id': 100,
            'axis_id': 10,
            'subtest_key': 'a',
            'display_name': 'A',
            'sort_order': 0,
            'needs_bodyweight': true,
            'needs_height': false,
          },
        ],
        levels: [
          {
            'id': 1,
            'subtest_id': 100,
            'level_number': 1,
            'requirement_label': 'ratio',
            'input_label': 'kg',
            'input_unit': 'kg',
            'threshold_value': 0.4,
            'higher_is_better': true,
            'ratio_denominator': 'bodyweight',
            'continuous_from_previous': true,
          },
          {
            'id': 2,
            'subtest_id': 100,
            'level_number': 2,
            'requirement_label': 'time',
            'input_label': 'time',
            'input_unit': 'minutes',
            'threshold_value': 45,
            'higher_is_better': false,
            'ratio_denominator': null,
            'continuous_from_previous': false,
          },
        ],
      ),
    );

    final charts = await repo.fetchCriteria();
    final levels = charts.single.axes.single.subtests.single.levels;
    expect(
        levels[0].comparison, FitnessRequirementComparison.ratioToBodyweight);
    expect(levels[1].comparison, FitnessRequirementComparison.directDescending);
    expect(levels[1].continuousFromPrevious, false);
  });
}
