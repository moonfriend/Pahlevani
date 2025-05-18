import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/config.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/presentation/bloc/player/audio_player_cubit.dart';
import 'package:pahlevani/presentation/bloc/playlist/playlist_cubit.dart';
import 'package:pahlevani/presentation/pages/playlist/playlist_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Application entry point
void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // Initialize dependency injection
  await DependencyInjection().ensureInitialized();

  runApp(const MyApp());
}

/// Main application widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AudioPlayerCubit>(
          create: (context) => getIt<AudioPlayerCubit>(),
        ),
        BlocProvider<PlaylistCubit>(
          create: (context) => getIt<PlaylistCubit>()..initialize(),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        title: 'Pahlevani Player',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            elevation: 1,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
        home: const PlaylistPage(),
      ),
    );
  }
}
