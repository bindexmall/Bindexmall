// ============================================================================
// PROVIDER: LanguageProvider (ChangeNotifier)
// ============================================================================
// Menyimpan preferensi bahasa UI (kode bahasa) ke SharedPreferences.
//
// Isi/tanggung jawab utama:
//  - CATATAN: mirip fungsinya dengan LocaleProvider di bawah — app ini punya DUA provider
//  -   bahasa (Language & Locale). Cek main.dart & app_localizations.dart untuk pahami mana
//  -   yang benar-benar dipakai sebelum refactor, supaya tidak salah hapus.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  LanguageProvider() {
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    _currentLocale = Locale(languageCode);
    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    _currentLocale = Locale(languageCode);
    notifyListeners();
  }
}