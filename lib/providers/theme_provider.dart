// ============================================================================
// PROVIDER: ThemeProvider (ChangeNotifier)
// ============================================================================
// State tema aplikasi (light/dark mode), disimpan ke SharedPreferences.
//
// Isi/tanggung jawab utama:
//  - Dipakai bareng theme/app_theme.dart yang berisi definisi ThemeData light & dark.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  static const String _themePrefKey = 'theme_mode';

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  /// Load saved theme preference
  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themePrefKey) ?? 'light';
      
      _themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
      
      debugPrint('✅ Theme loaded: $_themeMode');
    } catch (e) {
      debugPrint('❌ Error loading theme: $e');
    }
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _saveThemeToPrefs();
    notifyListeners();
    
    debugPrint('🎨 Theme changed to: $_themeMode');
  }

  /// Set specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    await _saveThemeToPrefs();
    notifyListeners();
    
    debugPrint('🎨 Theme set to: $_themeMode');
  }

  /// Save theme preference
  Future<void> _saveThemeToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = _themeMode == ThemeMode.dark ? 'dark' : 'light';
      await prefs.setString(_themePrefKey, themeString);
    } catch (e) {
      debugPrint('❌ Error saving theme: $e');
    }
  }
}