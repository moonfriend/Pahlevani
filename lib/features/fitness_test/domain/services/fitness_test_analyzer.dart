import '../entities/fitness_test_answer.dart';
import '../entities/fitness_test_criteria.dart';
import '../entities/fitness_test_result.dart';

/// Matches a completed stage's answers against its criteria to produce a
/// radar-chart-ready result. Abstracted so scoring can move server-side
/// later (mirrors this codebase's `AudioPlayerService` pattern) without any
/// wizard/UI change — today's only implementation, [LocalFitnessTestAnalyzer],
/// runs entirely on-device.
abstract class FitnessTestAnalyzer {
  FitnessTestStageResult analyze({
    required FitnessTestChart chart,
    required List<FitnessTestSubtestAnswer> answers,
    required FitnessTestProfile profile,
  });
}
