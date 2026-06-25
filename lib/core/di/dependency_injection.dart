import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../data/datasources/training_session/training_session_local_database.dart';
import '../../data/datasources/training_session/training_session_local_datasource.dart';
import '../../data/datasources/training_session/training_session_remote_datasource.dart';
import '../../data/repositories_impl/download_repository_impl.dart';
import '../../data/repositories_impl/training_session_repository_impl.dart';
import '../../data/repositories_impl/version_gate_repository_impl.dart';
import '../../data/services/audio_players_service_impl.dart';
import '../../data/services/connectivity_service_impl.dart';
import '../../data/services/just_audio_player_service.dart';
import '../../data/services/no_op_notification_service.dart';
import '../../data/services/pahlevani_audio_handler.dart';
import '../../domain/repositories/download_repository.dart';
import '../../domain/repositories/training_session_repository.dart';
import '../../domain/repositories/version_gate_repository.dart';
import '../../domain/services/audio_player_service.dart';
import '../../domain/services/connectivity_service.dart';
import '../../domain/services/player_notification_service.dart';
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

    // Audio service + notification: mobile uses just_audio + audio_service handler
    // registered in main.dart; Linux/Web fall back to audioplayers + no-op.
    final bool useMobileAudio =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

    if (useMobileAudio && getIt.isRegistered<PahlevaniAudioHandler>()) {
      final handler = getIt<PahlevaniAudioHandler>();
      getIt.registerFactory<AudioPlayerService>(
          () => JustAudioPlayerService(handler));
      getIt.registerSingleton<PlayerNotificationService>(handler);
    } else {
      getIt
          .registerFactory<AudioPlayerService>(() => AudioPlayersServiceImpl());
      getIt.registerSingleton<PlayerNotificationService>(
          NoOpNotificationService());
    }

    getIt.registerLazySingleton<ConnectivityService>(
        () => ConnectivityServiceImpl());

    getIt.registerLazySingleton<TrainingSessionCubit>(
      () => TrainingSessionCubit(
        sessionRepository: getIt<TrainingSessionRepository>(),
        downloadRepository: getIt<DownloadRepository>(),
      ),
    );

    getIt.registerLazySingleton<VersionGateRepository>(
        () => SupabaseVersionGateRepository());
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) {
      if (!getIt.isRegistered<Dio>()) {
        await init();
      }
    }
    await getIt.allReady();
    _initialized = true;
  }

  Future<void> dispose() async {
    await getIt.reset();
    _initialized = false;
  }
}
