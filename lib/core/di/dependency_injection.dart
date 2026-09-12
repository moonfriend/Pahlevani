import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../data/datasources/audio_catalog/audio_catalog_remote_datasource.dart';
import '../../data/datasources/tracking/training_history_local_database.dart';
import '../../data/datasources/training_session/training_session_local_database.dart';
import '../../data/datasources/training_session/training_session_local_datasource.dart';
import '../../data/datasources/training_session/training_session_remote_datasource.dart';
import '../../data/repositories_impl/audio_catalog_repository_impl.dart';
import '../../data/repositories_impl/auth_repository_impl.dart';
import '../../data/repositories_impl/download_repository_impl.dart';
import '../../data/repositories_impl/tracking/training_history_repository_impl.dart';
import '../../data/repositories_impl/training_session_repository_impl.dart';
import '../../data/repositories_impl/version_gate_repository_impl.dart';
import '../../data/services/audio_players_service_impl.dart';
import '../../data/services/connectivity_service_impl.dart';
import '../../data/services/just_audio_player_service.dart';
import '../../data/services/just_audio_web_player_service.dart';
import '../../data/services/no_op_notification_service.dart';
import '../../data/services/pahlevani_audio_handler.dart';
import '../../domain/repositories/audio_catalog_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/download_repository.dart';
import '../../domain/repositories/tracking/training_history_repository.dart';
import '../../domain/repositories/training_session_repository.dart';
import '../../domain/repositories/version_gate_repository.dart';
import '../../domain/services/audio_player_service.dart';
import '../../domain/services/connectivity_service.dart';
import '../../domain/services/player_notification_service.dart';
import '../../presentation/bloc/audio_catalog/audio_catalog_cubit.dart';
import '../../presentation/bloc/training_session/training_session_cubit.dart';
import '../../presentation/bloc/tracking/training_history_cubit.dart';

final getIt = GetIt.instance;

class DependencyInjection {
  static final DependencyInjection _instance = DependencyInjection._internal();
  factory DependencyInjection() => _instance;
  DependencyInjection._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await TrainingSessionLocalDatabase.init();
    await TrainingHistoryLocalDatabase.init();

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
        authRepository: getIt<AuthRepository>(),
      ),
    );

    getIt.registerLazySingleton<DownloadRepository>(
      () => DownloadRepositoryImpl(
        localDataSource: getIt<TrainingSessionLocalDataSource>(),
      ),
    );

    getIt.registerLazySingleton<TrainingHistoryLocalDatabase>(
        () => TrainingHistoryLocalDatabase());
    getIt.registerLazySingleton<TrainingHistoryRepository>(
      () => TrainingHistoryRepositoryImpl(
        localDatabase: getIt<TrainingHistoryLocalDatabase>(),
      ),
    );
    getIt.registerLazySingleton<TrainingHistoryCubit>(
      () => TrainingHistoryCubit(
        historyRepository: getIt<TrainingHistoryRepository>(),
      ),
    );

    getIt.registerLazySingleton<AudioCatalogRemoteDataSource>(
        () => AudioCatalogRemoteDataSourceImpl());
    getIt.registerLazySingleton<AudioCatalogRepository>(
      () => AudioCatalogRepositoryImpl(
        remoteDataSource: getIt<AudioCatalogRemoteDataSource>(),
      ),
    );
    getIt.registerLazySingleton<AudioCatalogCubit>(
      () => AudioCatalogCubit(repository: getIt<AudioCatalogRepository>()),
    );

    // Audio service + notification: mobile uses just_audio + audio_service
    // handler registered in main.dart; Linux desktop falls back to
    // audioplayers + no-op. Web also uses just_audio (JustAudioWebPlayerService,
    // no handler) rather than audioplayers_web — audioplayers_web unconditionally
    // sets `crossOrigin='anonymous'` on its <audio> element (needed for its
    // stereo-panning Web Audio graph), which makes the browser reject
    // cross-origin media unless the server sends CORS headers. just_audio_web
    // never requests CORS mode, so cross-origin media (e.g. R2-hosted audio)
    // plays with no server-side CORS configuration needed. See
    // JustAudioWebPlayerService's doc comment for the reproduction that
    // confirmed this.
    final bool useMobileAudio =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

    if (useMobileAudio && getIt.isRegistered<PahlevaniAudioHandler>()) {
      final handler = getIt<PahlevaniAudioHandler>();
      getIt.registerFactory<AudioPlayerService>(
          () => JustAudioPlayerService(handler));
      getIt.registerSingleton<PlayerNotificationService>(handler);
    } else if (kIsWeb) {
      getIt.registerFactory<AudioPlayerService>(
          () => JustAudioWebPlayerService());
      getIt.registerSingleton<PlayerNotificationService>(
          NoOpNotificationService());
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

    getIt.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl());
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
