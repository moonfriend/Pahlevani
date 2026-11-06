import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/usage/usage_event_queue.dart';
import '../../data/datasources/usage/usage_remote_datasource.dart';
import '../../data/services/usage/recording_usage_tracker.dart';
import '../../domain/services/usage_tracker.dart';
import '../utils/app_logger.dart';

import '../../data/repositories_impl/download_preferences_repository_impl.dart';
import '../../domain/repositories/download_preferences_repository.dart';
import '../../data/datasources/media/media_size_remote_datasource.dart';
import '../../data/repositories_impl/media_size_repository_impl.dart';
import '../../domain/repositories/media_size_repository.dart';
import '../../data/datasources/audio_catalog/audio_catalog_remote_datasource.dart';
import '../../data/datasources/path/path_local_database.dart';
import '../../data/datasources/path/path_progress_local_database.dart';
import '../../data/datasources/path/path_remote_datasource.dart';
import '../../data/datasources/activation/activation_remote_datasource.dart';
import '../../data/datasources/announcement/announcement_remote_datasource.dart';
import '../../data/datasources/onboarding/onboarding_remote_datasource.dart';
import '../../data/datasources/tracking/training_history_local_database.dart';
import '../../data/datasources/training_session/training_session_local_database.dart';
import '../../data/datasources/training_session/training_session_local_datasource.dart';
import '../../data/datasources/training_session/training_session_remote_datasource.dart';
import '../../data/repositories_impl/audio_catalog_repository_impl.dart';
import '../../data/repositories_impl/auth_repository_impl.dart';
import '../../data/repositories_impl/download_repository_impl.dart';
import '../../data/repositories_impl/learnt_exercises_repository_impl.dart';
import '../../data/repositories_impl/path/path_progress_repository_impl.dart';
import '../../data/repositories_impl/path_repository_impl.dart';
import '../../data/repositories_impl/activation_repository_impl.dart';
import '../../data/repositories_impl/announcement_repository_impl.dart';
import '../../data/repositories_impl/onboarding_repository_impl.dart';
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
import '../../domain/repositories/learnt_exercises_repository.dart';
import '../../domain/repositories/path/path_progress_repository.dart';
import '../../domain/repositories/path_repository.dart';
import '../../domain/repositories/activation_repository.dart';
import '../../domain/repositories/announcement_repository.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../../presentation/bloc/announcement/announcement_cubit.dart';
import '../../domain/repositories/tracking/training_history_repository.dart';
import '../../domain/repositories/training_session_repository.dart';
import '../../domain/repositories/version_gate_repository.dart';
import '../../domain/services/audio_player_service.dart';
import '../../domain/services/connectivity_service.dart';
import '../../domain/services/player_notification_service.dart';
import '../../presentation/bloc/audio_catalog/audio_catalog_cubit.dart';
import '../../presentation/bloc/path/path_cubit.dart';
import '../../presentation/bloc/training_session/training_session_cubit.dart';
import '../../presentation/bloc/tracking/training_history_cubit.dart';
import '../../features/fitness_test/fitness_test_module.dart';
import '../../data/repositories_impl/open_session_store_impl.dart';
import '../../domain/usage/open_session.dart';

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
    await PathProgressLocalDatabase.init();
    await PathLocalDatabase.init();

    // The usage study (docs/usage_study/event_catalogue.md). Needs Hive,
    // so it comes after the local databases.
    getIt.registerSingleton<UsageTracker>(await _createUsageTracker());
    getIt.registerLazySingleton<OpenSessionStore>(() => OpenSessionStoreImpl());

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

    getIt.registerLazySingleton<LearntExercisesRepository>(
        () => LearntExercisesRepositoryImpl());

    getIt.registerLazySingleton<PathRemoteDataSource>(
        () => PathRemoteDataSourceImpl());
    getIt.registerLazySingleton<PathLocalDatabase>(() => PathLocalDatabase());
    getIt.registerLazySingleton<PathRepository>(
      () => PathRepositoryImpl(
        remoteDataSource: getIt<PathRemoteDataSource>(),
        localDatabase: getIt<PathLocalDatabase>(),
      ),
    );
    getIt.registerLazySingleton<PathProgressLocalDatabase>(
        () => PathProgressLocalDatabase());
    getIt.registerLazySingleton<PathProgressRepository>(
      () => PathProgressRepositoryImpl(
        localDatabase: getIt<PathProgressLocalDatabase>(),
      ),
    );
    getIt.registerLazySingleton<PathCubit>(
      () => PathCubit(
        pathRepository: getIt<PathRepository>(),
        progressRepository: getIt<PathProgressRepository>(),
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

    getIt.registerLazySingleton<OnboardingRepository>(
      () => OnboardingRepositoryImpl(
        remoteDataSource: OnboardingRemoteDataSourceImpl(),
      ),
    );

    // Release 1's activation gate (migration 0045).
    getIt.registerLazySingleton<ActivationRepository>(
      () => ActivationRepositoryImpl(
        remoteDataSource: ActivationRemoteDataSourceImpl(),
      ),
    );

    // Home's info card (admin-set announcement, migration 0044).
    getIt.registerLazySingleton<AnnouncementRepository>(
      () => AnnouncementRepositoryImpl(
        remoteDataSource: AnnouncementRemoteDataSourceImpl(),
      ),
    );
    getIt.registerLazySingleton<AnnouncementCubit>(
      () => AnnouncementCubit(repository: getIt<AnnouncementRepository>()),
    );

    getIt.registerLazySingleton<AudioCatalogRemoteDataSource>(
        () => AudioCatalogRemoteDataSourceImpl());
    getIt.registerLazySingleton<MediaSizeRepository>(
        () => MediaSizeRepositoryImpl(remote: MediaSizeRemoteDataSourceImpl()));
    getIt.registerLazySingleton<DownloadPreferencesRepository>(
        () => DownloadPreferencesRepositoryImpl());
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
        audioCatalogRepository: getIt<AudioCatalogRepository>(),
      ),
    );

    getIt.registerLazySingleton<VersionGateRepository>(
        () => SupabaseVersionGateRepository());

    getIt.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl());

    // Self-contained feature module — see fitness_test_module.dart for why
    // its registrations live there instead of inline here.
    await registerFitnessTestDependencies(getIt);
  }

  /// The study's tracker, or a no-op one if it can't start — tracking must
  /// never keep the app from running.
  static Future<UsageTracker> _createUsageTracker() async {
    var version = 'unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (error) {
      AppLogger.w('Usage study: app version unknown', error: error);
    }
    try {
      return await RecordingUsageTracker.create(
        queue: UsageEventQueue(),
        remote: SupabaseUsageRemoteDataSource(),
        prefs: SharedPreferences.getInstance(),
        currentUserId: () => Supabase.instance.client.auth.currentUser?.id,
        appVersion: version,
        platform: kIsWeb ? 'web' : Platform.operatingSystem,
      );
    } catch (error, stack) {
      AppLogger.e('Usage study tracker unavailable — tracking off',
          error: error, stackTrace: stack);
      return const NoOpUsageTracker();
    }
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
