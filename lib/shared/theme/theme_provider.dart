import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_is_dark';

  final SharedPreferences _prefs;
  bool _isDark;

  ThemeProvider(this._prefs)
      : _isDark = _prefs.getBool(_themeKey) ??
            (PlatformDispatcher.instance.platformBrightness == Brightness.dark);

  bool get isDarkMode => _isDark;

  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  void setLightMode() {
    _isDark = false;
    _prefs.setBool(_themeKey, false);
    notifyListeners();
  }

  void setDarkmode() {
    _isDark = true;
    _prefs.setBool(_themeKey, true);
    notifyListeners();
  }

  void toggleTheme() => _isDark ? setLightMode() : setDarkmode();
}

