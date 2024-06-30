import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreferences {
  static const String _themeKey = 'theme_mode';
  static const String _isFirstLaunchKey = 'is_first_launch';

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool(_isFirstLaunchKey) ?? true;

    if (isFirstLaunch) {
      await prefs.setBool(_isFirstLaunchKey, false);
      return ThemeMode.system;
    }

    final themeIndex = prefs.getInt(_themeKey);
    if (themeIndex == null) {
      return ThemeMode.system;
    }
    return ThemeMode.values[themeIndex];
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    await prefs.setBool(_isFirstLaunchKey, false);
  }

  static Future<bool> isDarkMode() async {
    final themeMode = await getThemeMode();
    if (themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.window.platformBrightness == Brightness.dark;
    }
    return themeMode == ThemeMode.dark;
  }

  static Future<void> toggleTheme() async {
    final currentMode = await getThemeMode();
    final newMode = currentMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }
}