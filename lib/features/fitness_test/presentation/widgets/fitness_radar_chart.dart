import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/fitness_test_result.dart';

/// Renders a [FitnessTestStageResult]'s per-axis scores as a radar chart —
/// same fl_chart package already used for the training-history bar chart,
/// styled to match (rounded card, cs.primary accents).
class FitnessRadarChart extends StatelessWidget {
  const FitnessRadarChart({super.key, required this.axisScores});

  final List<FitnessAxisScore> axisScores;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 1,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 7,
          ticksTextStyle: const TextStyle(fontSize: 0), // hide numeric rings
          radarBorderData: BorderSide(color: cs.outlineVariant),
          gridBorderData: BorderSide(color: cs.outlineVariant, width: 1),
          radarBackgroundColor: Colors.transparent,
          titlePositionPercentageOffset: 0.15,
          getTitle: (index, angle) => RadarChartTitle(
            text: axisScores[index].displayName,
            angle: angle,
          ),
          titleTextStyle: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
          dataSets: [
            RadarDataSet(
              fillColor: cs.primary.withValues(alpha: 0.25),
              borderColor: cs.primary,
              borderWidth: 2,
              entryRadius: 3,
              dataEntries: [
                for (final s in axisScores) RadarEntry(value: s.score),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
