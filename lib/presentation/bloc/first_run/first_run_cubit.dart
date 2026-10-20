import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_logger.dart';
import 'first_run_state.dart';

/// Decides whether the splash is shown: once per install, for every user
/// (people updating the app included).
///
/// Persists a single local flag, the same way `SettingsCubit` persists its
/// preferences — no repository layer for one boolean.
///
/// The splash is cosmetic, so storage failures never block the app: an
/// unreadable store skips the splash, an unwritable one only means it may
/// show again next launch.
class FirstRunCubit extends Cubit<FirstRunState> {
  FirstRunCubit({Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance,
        super(const FirstRunChecking());

  static const splashSeenKey = 'firstRun.splashSeen';

  final Future<SharedPreferences> Function() _preferences;

  Future<void> load() async {
    try {
      final prefs = await _preferences();
      final seen = prefs.getBool(splashSeenKey) ?? false;
      emit(seen ? const FirstRunDone() : const FirstRunPending());
    } catch (error, stackTrace) {
      AppLogger.w('First-run flag unreadable — skipping the splash',
          error: error, stackTrace: stackTrace);
      emit(const FirstRunDone());
    }
  }

  /// Called from the splash's Begin. Moves on immediately, then saves the
  /// flag so the next launch skips the splash.
  Future<void> complete() async {
    emit(const FirstRunDone());
    try {
      final prefs = await _preferences();
      await prefs.setBool(splashSeenKey, true);
    } catch (error, stackTrace) {
      AppLogger.w('Could not save the first-run flag',
          error: error, stackTrace: stackTrace);
    }
  }
}
