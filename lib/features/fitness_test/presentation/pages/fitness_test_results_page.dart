import 'package:flutter/material.dart';

import '../../domain/entities/fitness_test_result.dart';
import '../widgets/fitness_radar_chart.dart';

/// Radar chart + per-axis breakdown for one completed stage result. Reached
/// either right after a wizard run finishes, or from the landing page's
/// "View Results" for a previously saved run.
class FitnessTestResultsPage extends StatelessWidget {
  const FitnessTestResultsPage({super.key, required this.result});

  final FitnessTestStageResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(result.chartTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FitnessRadarChart(axisScores: result.axisScores),
            const SizedBox(height: 24),
            for (final score in result.axisScores)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(score.displayName),
                trailing: Text(
                  'Level ${score.score.toStringAsFixed(1)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
