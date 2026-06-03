import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../data/datasources/training_session/training_session_local_database.dart';
import '../../data/datasources/training_session/training_session_local_datasource.dart';
import '../../data/datasources/training_session/training_session_remote_datasource.dart';
import '../../data/repositories_impl/download_repository_impl.dart';
import '../../data/repositories_impl/training_session_repository_impl.dart';
import '../../domain/repositories/download_repository.dart';
import '../../domain/repositories/training_session_repository.dart';
import '../../presentation/bloc/training_session/training_session_cubit.dart';

final getIt = GetIt.instance;

class DependencyInjection {
  static final DependencyInjection _instance = DependencyInjection._internal();
  factory DependencyInjection() => _instance;
  DependencyInjection._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await TrainingSessionLocalDatabase.init();

    getIt.registerLazySingleton<Dio>(() => Dio());

    getIt.registerLazySingleton<TrainingSessionLocalDataSource>(
        () => TrainingSessionLocalDataSourceImpl(dio: getIt<Dio>()));
    getIt.registerLazySingleton<TrainingSessionRemoteDataSource>(
        () => TrainingSessionRemoteDataSourceImpl());
    getIt.registerLazySingleton<TrainingSessionLocalDatabase>(
        () => TrainingSessionLocalDatabase());

    getIt.registerLazySingleton<TrainingSessionRepository>(
      () => TrainingSessionRepositoryImpl(
        remoteDataSource: getIt<TrainingSessionRemoteDataSource>(),
        localDataSource: getIt<TrainingSessionLocalDataSource>(),
        localDatabase: getIt<TrainingSessionLocalDatabase>(),
      ),
    );

    getIt.registerLazySingleton<DownloadRepository>(
      () => DownloadRepositoryImpl(
        localDataSource: getIt<TrainingSessionLocalDataSource>(),
      ),
    );

    getIt.registerLazySingleton<TrainingSessionCubit>(
      () => TrainingSessionCubit(
        sessionRepository: getIt<TrainingSessionRepository>(),
        downloadRepository: getIt<DownloadRepository>(),
      ),
    );

    print("Dependency Injection setup complete.");
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) {
      if (!getIt.isRegistered<Dio>()) {
        await init();
      }
    }
    await getIt.allReady();
    _initialized = true;
    print("Dependency Injection Initialized and Ready.");
  }

  Future<void> dispose() async {
    await getIt.reset();
    _initialized = false;
  }
}
