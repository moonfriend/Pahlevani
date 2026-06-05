import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/config.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/presentation/bloc/settings/settings_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/training_session/training_sessions_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await DependencyInjection().ensureInitialized();
  runApp(const PahlevaniApp());
}

class PahlevaniApp extends StatelessWidget {
  const PahlevaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>(
          create: (_) => SettingsCubit()..load(),
          lazy: false,
        ),
        BlocProvider<TrainingSessionCubit>(
          create: (_) => getIt<TrainingSessionCubit>()..initialize(),
          lazy: false,
        ),
      ],
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) => MaterialApp(
          title: 'Pahlevani',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: PahlevaniTheme.light(),
          darkTheme: PahlevaniTheme.dark(),
          home: const TrainingSessionPage(),
        ),
      ),
    );
  }
}
