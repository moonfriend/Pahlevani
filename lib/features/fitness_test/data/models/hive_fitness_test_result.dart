import 'package:hive/hive.dart';
import 'package:pahlevani/data/models/hive_type_ids.dart';

import '../../domain/entities/fitness_test_result.dart';

part 'hive_fitness_test_result.g.dart';

/// One saved [FitnessTestStageResult]. Axis scores are stored as 3 parallel
/// lists (key/name/score) rather than nested Hive objects — same "parallel
/// primitive lists" convention already used by HiveSessionCompletionRecord
/// in lib/data/models/hive_models.dart for its movement counts.
@HiveType(typeId: HiveTypeIds.fitnessTestResult)
class HiveFitnessTestResult extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String chartKey;

  @HiveField(2)
  final String chartTitle;

  @HiveField(3)
  final int completedAtMillis;

  @HiveField(4)
  final List<String> axisKeys;

  @HiveField(5)
  final List<String> axisDisplayNames;

  @HiveField(6)
  final List<double> axisScores;

  HiveFitnessTestResult({
    required this.id,
    required this.chartKey,
    required this.chartTitle,
    required this.completedAtMillis,
    required this.axisKeys,
    required this.axisDisplayNames,
    required this.axisScores,
  });

  factory HiveFitnessTestResult.fromDomain(FitnessTestStageResult r) =>
      HiveFitnessTestResult(
        id: r.id,
        chartKey: r.chartKey,
        chartTitle: r.chartTitle,
        completedAtMillis: r.completedAt.millisecondsSinceEpoch,
        axisKeys: [for (final s in r.axisScores) s.axisKey],
        axisDisplayNames: [for (final s in r.axisScores) s.displayName],
        axisScores: [for (final s in r.axisScores) s.score],
      );

  FitnessTestStageResult toDomain() => FitnessTestStageResult(
        id: id,
        chartKey: chartKey,
        chartTitle: chartTitle,
        completedAt: DateTime.fromMillisecondsSinceEpoch(completedAtMillis),
        axisScores: [
          for (var i = 0; i < axisKeys.length; i++)
            FitnessAxisScore(
              axisKey: axisKeys[i],
              displayName: axisDisplayNames[i],
              score: axisScores[i],
            ),
        ],
      );
}
