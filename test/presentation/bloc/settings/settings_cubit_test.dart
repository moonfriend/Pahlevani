import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pahlevani/presentation/bloc/settings/settings_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsCubit — initial state', () {
    test('starts with dark theme and banner density', () {
      final cubit = SettingsCubit();
      expect(cubit.state.themeMode, ThemeMode.dark);
      expect(cubit.state.listDensity, ListDensity.banner);
      cubit.close();
    });
  });

  group('load()', () {
    test('emits defaults when SharedPreferences is empty', () async {
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.themeMode, ThemeMode.dark);
      expect(cubit.state.listDensity, ListDensity.banner);
    });

    test('restores persisted themeMode', () async {
      SharedPreferences.setMockInitialValues({
        'settings.themeMode': ThemeMode.light.index,
      });
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.themeMode, ThemeMode.light);
    });

    test('restores persisted listDensity', () async {
      SharedPreferences.setMockInitialValues({
        'settings.listDensity': ListDensity.compact.index,
      });
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.listDensity, ListDensity.compact);
    });

    test('restores both theme and density together', () async {
      SharedPreferences.setMockInitialValues({
        'settings.themeMode': ThemeMode.light.index,
        'settings.listDensity': ListDensity.compact.index,
      });
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.themeMode, ThemeMode.light);
      expect(cubit.state.listDensity, ListDensity.compact);
    });
  });

  group('toggleTheme()', () {
    test('dark → light on first toggle', () async {
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      await cubit.toggleTheme();
      expect(cubit.state.themeMode, ThemeMode.light);
    });

    test('light → dark on second toggle', () async {
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      await cubit.toggleTheme(); // dark → light
      await cubit.toggleTheme(); // light → dark
      expect(cubit.state.themeMode, ThemeMode.dark);
    });

    test('toggle persists to SharedPreferences', () async {
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      await cubit.toggleTheme(); // now light

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('settings.themeMode'), ThemeMode.light.index);
    });

    test('toggle does not change density', () async {
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      await cubit.setListDensity(ListDensity.compact);
      await cubit.toggleTheme();
      expect(cubit.state.listDensity, ListDensity.compact);
    });
  });

  group('setListDensity()', () {
    test('emits new density immediately', () async {
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      await cubit.setListDensity(ListDensity.compact);
      expect(cubit.state.listDensity, ListDensity.compact);
    });

    test('persists density to SharedPreferences', () async {
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      await cubit.setListDensity(ListDensity.compact);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('settings.listDensity'), ListDensity.compact.index);
    });

    test('setting banner density preserves theme', () async {
      final cubit = SettingsCubit();
      addTearDown(cubit.close);
      await cubit.toggleTheme(); // now light
      await cubit.setListDensity(ListDensity.banner);
      expect(cubit.state.themeMode, ThemeMode.light);
      expect(cubit.state.listDensity, ListDensity.banner);
    });
  });
}
