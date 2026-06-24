import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:pahlevani/data/services/pahlevani_audio_handler.dart';
import 'package:pahlevani/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pahlevani/core/config.dart';
import 'package:pahlevani/core/di/dependency_injection.dart';
import 'package:pahlevani/core/theme/pahlevani_theme.dart';
import 'package:pahlevani/core/utils/app_logger.dart';
import 'package:pahlevani/presentation/bloc/settings/settings_cubit.dart';
import 'package:pahlevani/presentation/bloc/training_session/training_session_cubit.dart';
import 'package:pahlevani/presentation/pages/training_session/training_sessions_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase Crashlytics — requires android/app/google-services.json.
  // Replace the placeholder file with the real one from the Firebase Console
  // (Project settings → Your apps → google-services.json).
  // Crashlytics is intentionally disabled in debug builds so noise stays local.
  bool crashlyticsEnabled = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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

  // Initialize audio_service on mobile so the handler is available to DI.
  // On Linux / Web, the handler is skipped and DI falls back to audioplayers.
  // Non-fatal: DependencyInjection's isRegistered<PahlevaniAudioHandler> check
  // already falls back to AudioPlayersServiceImpl, so a failure here should
  // degrade the notification card, not take down the whole app.
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
    try {
      final handler = await AudioService.init<PahlevaniAudioHandler>(
        builder: () => PahlevaniAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.pahlevani.app.audio',
          androidNotificationChannelName: 'Pahlevani Audio',
          androidNotificationIcon: 'mipmap/ic_launcher',
          androidShowNotificationBadge: false,
          androidStopForegroundOnPause: false,
        ),
      );
      getIt.registerSingleton<PahlevaniAudioHandler>(handler);
    } catch (error, stack) {
      AppLogger.e('AudioService.init failed — falling back to audioplayers',
          error: error, stackTrace: stack);
    }
  }

  await DependencyInjection().ensureInitialized();

  // Request POST_NOTIFICATIONS on Android 13+ (needed for the media card).
  if (!kIsWeb && Platform.isAndroid) {
    try {
      await Permission.notification.request();
    } catch (error, stack) {
      AppLogger.w('Notification permission request failed',
          error: error, stackTrace: stack);
    }
  }

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
