import 'package:flutter/foundation.dart';
import 'theme_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  static final ThemeNotifier _instance = ThemeNotifier._internal();
  
  factory ThemeNotifier() {
    return _instance;
  }
  
  ThemeNotifier._internal();

  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  Future<void> initialize() async {
    _isDarkMode = await ThemePreferences.isDarkMode();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    await ThemePreferences.toggleTheme();
    _isDarkMode = await ThemePreferences.isDarkMode();
    notifyListeners();
  }
}