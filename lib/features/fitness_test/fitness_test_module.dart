import 'package:get_it/get_it.dart';

import 'data/datasources/fitness_test_criteria_remote_datasource.dart';
import 'data/datasources/fitness_test_results_local_datasource.dart';
import 'data/repositories_impl/fitness_test_criteria_repository_impl.dart';
import 'data/repositories_impl/fitness_test_results_repository_impl.dart';
import 'data/services/local_fitness_test_analyzer.dart';
import 'domain/entities/fitness_test_criteria.dart';
import 'domain/repositories/fitness_test_criteria_repository.dart';
import 'domain/repositories/fitness_test_results_repository.dart';
import 'domain/services/fitness_test_analyzer.dart';
import 'presentation/bloc/criteria/fitness_test_criteria_cubit.dart';
import 'presentation/bloc/wizard/fitness_test_wizard_cubit.dart';

/// Everything this module needs to register with the app's GetIt instance,
/// kept in one place so the module stays a single unit to wire in (or lift
/// out into another app) rather than scattered across the shared DI file.
Future<void> registerFitnessTestDependencies(GetIt getIt) async {
  await FitnessTestResultsLocalDataSourceImpl.init();

  getIt.registerLazySingleton<FitnessTestCriteriaRemoteDataSource>(
      () => FitnessTestCriteriaRemoteDataSourceImpl());
  getIt.registerLazySingleton<FitnessTestCriteriaRepository>(
    () => FitnessTestCriteriaRepositoryImpl(
      remoteDataSource: getIt<FitnessTestCriteriaRemoteDataSource>(),
    ),
  );
  getIt.registerLazySingleton<FitnessTestCriteriaCubit>(
    () => FitnessTestCriteriaCubit(
      repository: getIt<FitnessTestCriteriaRepository>(),
    ),
  );

  getIt.registerLazySingleton<FitnessTestResultsLocalDataSource>(
      () => FitnessTestResultsLocalDataSourceImpl());
  getIt.registerLazySingleton<FitnessTestResultsRepository>(
    () => FitnessTestResultsRepositoryImpl(
      localDataSource: getIt<FitnessTestResultsLocalDataSource>(),
    ),
  );

  getIt.registerLazySingleton<FitnessTestAnalyzer>(
      () => LocalFitnessTestAnalyzer());

  // One fresh cubit per stage run, keyed by the chart it's testing.
  getIt.registerFactoryParam<FitnessTestWizardCubit, FitnessTestChart, void>(
    (chart, _) => FitnessTestWizardCubit(
      chart: chart,
      analyzer: getIt<FitnessTestAnalyzer>(),
      resultsRepository: getIt<FitnessTestResultsRepository>(),
    ),
  );
}
