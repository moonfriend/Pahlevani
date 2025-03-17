import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import '../../data/datasources/audio/audio_local_datasource.dart';
import '../../data/repositories_impl/audio_repository_impl.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../presentation/bloc/player/audio_player_cubit.dart';

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

    // Register services as singletons

    // External dependencies
    getIt.registerLazySingleton<AudioPlayer>(() => AudioPlayer());

    // Data sources
    getIt.registerLazySingleton<AudioLocalDataSource>(() => AudioLocalDataSourceImpl(assetBundle: rootBundle));

    // Repositories
    getIt.registerLazySingleton<AudioRepository>(
      () => AudioRepositoryImpl(dataSource: getIt<AudioLocalDataSource>()),
    );

    // State management
    getIt.registerSingletonAsync<AudioPlayerCubit>(() async {
      final cubit = AudioPlayerCubit(
        audioRepository: getIt<AudioRepository>(),
      );
      await cubit.loadTracks();
      return cubit;
    });

    _initialized = true;
  }

  /// Ensure all async dependencies are ready
  Future<void> ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
    // Wait for async singletons to be ready
    await getIt.allReady();
  }

  /// Get an instance of AudioPlayerCubit
  AudioPlayerCubit getAudioPlayerCubit() {
    return getIt<AudioPlayerCubit>();
  }

  /// Dispose all resources
  Future<void> dispose() async {
    if (getIt.isRegistered<AudioPlayerCubit>()) {
      await getIt<AudioPlayerCubit>().close();
    }

    if (getIt.isRegistered<AudioPlayer>()) {
      await getIt<AudioPlayer>().dispose();
    }

    await getIt.reset();
    _initialized = false;
  }
}
