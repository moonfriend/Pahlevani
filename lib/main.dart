import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/dependency_injection.dart';
import 'presentation/bloc/player/audio_player_cubit.dart';
import 'presentation/pages/player/audio_player_page.dart';

/// Application entry point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection and wait for all async dependencies
  await DependencyInjection().init();
  await DependencyInjection().ensureInitialized();

  // Get the AudioPlayerCubit instance (now guaranteed to be ready)
  final audioPlayerCubit = DependencyInjection().getAudioPlayerCubit();

  runApp(MyApp(audioPlayerCubit: audioPlayerCubit));
}

/// Main application widget
class MyApp extends StatelessWidget {
  final AudioPlayerCubit audioPlayerCubit;

  const MyApp({super.key, required this.audioPlayerCubit});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AudioPlayerCubit>(
      create: (context) => audioPlayerCubit,
      child: MaterialApp(
        title: 'Pahlevani',
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
        ),
        home: const AudioPlayerPage(),
      ),
    );
  }
}
