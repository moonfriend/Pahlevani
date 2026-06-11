import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ListDensity { banner, compact }

class SettingsState {
  const SettingsState({
    this.themeMode = ThemeMode.dark,
    this.listDensity = ListDensity.banner,
  });
  final ThemeMode themeMode;
  final ListDensity listDensity;

  SettingsState copyWith({ThemeMode? themeMode, ListDensity? listDensity}) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        listDensity: listDensity ?? this.listDensity,
      );
}

class SettingsCubit extends Cubit<SettingsState> {
  static const _keyTheme = 'settings.themeMode';
  static const _keyDensity = 'settings.listDensity';

  SettingsCubit() : super(const SettingsState());

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_keyTheme) ?? ThemeMode.dark.index;
    final densityIndex = prefs.getInt(_keyDensity) ?? ListDensity.banner.index;
    emit(SettingsState(
      themeMode: ThemeMode.values[themeIndex],
      listDensity: ListDensity.values[densityIndex],
    ));
  }

  Future<void> toggleTheme() async {
    final next =
        state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    emit(state.copyWith(themeMode: next));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTheme, next.index);
  }

  Future<void> setListDensity(ListDensity density) async {
    emit(state.copyWith(listDensity: density));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDensity, density.index);
  }
}
