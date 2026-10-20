import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/features/fitness_test/domain/entities/fitness_test_result.dart';
import 'package:pahlevani/features/fitness_test/presentation/widgets/fitness_radar_chart.dart';

void main() {
  testWidgets('renders a RadarChart with one entry per axis score',
      (tester) async {
    const scores = [
      FitnessAxisScore(axisKey: 'a', displayName: 'Axis A', score: 3.5),
      FitnessAxisScore(axisKey: 'b', displayName: 'Axis B', score: 6.0),
      FitnessAxisScore(axisKey: 'c', displayName: 'Axis C', score: 1.0),
    ];

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FitnessRadarChart(axisScores: scores)),
    ));

    final chart = tester.widget<RadarChart>(find.byType(RadarChart));
    expect(chart.data.dataSets.single.dataEntries, hasLength(3));
    expect(
      chart.data.dataSets.single.dataEntries.map((e) => e.value),
      [3.5, 6.0, 1.0],
    );
  });
}
