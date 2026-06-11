import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/config.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/presentation/bloc/settings/settings_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/training_session/training_sessions_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase Crashlytics — requires android/app/google-services.json.
  // Replace the placeholder file with the real one from the Firebase Console
  // (Project settings → Your apps → google-services.json).
  // Crashlytics is intentionally disabled in debug builds so noise stays local.
  bool crashlyticsEnabled = false;
  try {
    await Firebase.initializeApp();
    if (!kDebugMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      crashlyticsEnabled = true;
    }
  } catch (_) {
    // Firebase not configured — crash reporting disabled.
  }
  AppLogger.init(crashlyticsEnabled: crashlyticsEnabled);

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await DependencyInjection().ensureInitialized();

  runZonedGuarded(
    () => runApp(const PahlevaniApp()),
    (error, stack) {
      if (crashlyticsEnabled) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    },
  );
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
