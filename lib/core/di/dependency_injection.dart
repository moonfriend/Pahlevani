import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../data/datasources/playlist/playlist_local_database.dart';
import '../../data/datasources/playlist/playlist_local_datasource.dart';
import '../../data/datasources/playlist/playlist_remote_datasource.dart';
import '../../data/repositories_impl/playlist_repository_impl.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../presentation/bloc/player/audio_player_cubit.dart';
import '../../presentation/bloc/playlist/playlist_cubit.dart';

/// GetIt instance for dependency injection
final getIt = GetIt.instance;

/// Class responsible for setting up dependency injection
class DependencyInjection {
  // Singleton instance
  static final DependencyInjection _instance = DependencyInjection._internal();

  factory DependencyInjection() => _instance;

  DependencyInjection._internal();

  bool _initialized = false;

  /// Initialize all dependencies - must be called before using any injected services
  Future<void> init() async {
    if (_initialized) return;

    // Initialize Hive
    await PlaylistLocalDatabase.init();

    // Register services as singletons

    // External dependencies
    getIt.registerLazySingleton<Dio>(() => Dio());

    // Data sources
    getIt.registerLazySingleton<PlaylistLocalDataSource>(() => PlaylistLocalDataSourceImpl(dio: getIt<Dio>()));
    getIt.registerLazySingleton<PlaylistRemoteDataSource>(() => PlaylistRemoteDataSourceImpl());
    getIt.registerLazySingleton<PlaylistLocalDatabase>(() => PlaylistLocalDatabase());

    // Repositories
    getIt.registerLazySingleton<PlaylistRepository>(
      () => PlaylistRepositoryImpl(
        remoteDataSource: getIt<PlaylistRemoteDataSource>(),
        localDataSource: getIt<PlaylistLocalDataSource>(),
        localDatabase: getIt<PlaylistLocalDatabase>(),
      ),
    );

    // State management
    getIt.registerLazySingleton<AudioPlayerCubit>(() => AudioPlayerCubit());
    getIt.registerLazySingleton<PlaylistCubit>(() => PlaylistCubit(
          playlistRepository: getIt<PlaylistRepository>(),
        ));

    print("Dependency Injection setup complete.");
  }

  /// Ensure all async dependencies are ready
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

  /// Get an instance of AudioPlayerCubit
  AudioPlayerCubit get audioPlayerCubit => getIt<AudioPlayerCubit>();

  /// Get an instance of PlaylistCubit
  PlaylistCubit get playlistCubit => getIt<PlaylistCubit>();

  /// Dispose all resources
  Future<void> dispose() async {
    if (getIt.isRegistered<AudioPlayerCubit>()) {
      await getIt<AudioPlayerCubit>().close();
    }

    await getIt.reset();
    _initialized = false;
    print("Dependency Injection Disposed.");
  }
}
