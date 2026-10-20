import '../../domain/entities/fitness_test_result.dart';
import '../../domain/repositories/fitness_test_results_repository.dart';
import '../datasources/fitness_test_results_local_datasource.dart';
import '../models/hive_fitness_test_result.dart';

class FitnessTestResultsRepositoryImpl implements FitnessTestResultsRepository {
  final FitnessTestResultsLocalDataSource _localDataSource;

  FitnessTestResultsRepositoryImpl({
    required FitnessTestResultsLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  @override
  Future<void> saveResult(FitnessTestStageResult result) async {
    await _localDataSource.add(HiveFitnessTestResult.fromDomain(result));
  }

  @override
  Future<FitnessTestStageResult?> latestResultFor(String chartKey) async {
    final all = await allResults();
    final matching = all.where((r) => r.chartKey == chartKey).toList();
    if (matching.isEmpty) return null;
    matching.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return matching.first;
  }

  @override
  Future<List<FitnessTestStageResult>> allResults() async {
    final rows = await _localDataSource.getAll();
    return rows.map((r) => r.toDomain()).toList();
  }
}
