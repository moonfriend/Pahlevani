import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'first_run_state.dart';

/// Decides whether the splash is shown: once per install, for every user
/// (people updating the app included).
///
/// Persists a single local flag, the same way `SettingsCubit` persists its
/// preferences — no repository layer for one boolean.
class FirstRunCubit extends Cubit<FirstRunState> {
  FirstRunCubit() : super(const FirstRunChecking());

  static const splashSeenKey = 'firstRun.splashSeen';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(splashSeenKey) ?? false;
    emit(seen ? const FirstRunDone() : const FirstRunPending());
  }

  /// Called from the splash's Begin. Moves on immediately, then saves the
  /// flag so the next launch skips the splash.
  Future<void> complete() async {
    emit(const FirstRunDone());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(splashSeenKey, true);
  }
}
