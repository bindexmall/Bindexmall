// ============================================================================
// PROVIDER: LocaleProvider (ChangeNotifier)
// ============================================================================
// Menyimpan Locale aktif (default 'id' — Indonesia) untuk flutter_localizations.
//
// Isi/tanggung jawab utama:
//  - Lihat catatan di language_provider.dart soal duplikasi fungsi bahasa.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('id'); // Default to Indonesian
  
  Locale get locale => _locale;
  
  LocaleProvider() {
    _loadLocale();
  }
  
  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'id';
    _locale = Locale(languageCode);
    notifyListeners();
  }
  
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    
    _locale = locale;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }
  
  void clearLocale() {
    _locale = const Locale('id');
    notifyListeners();
  }
  
  bool get isIndonesian => _locale.languageCode == 'id';
  bool get isEnglish => _locale.languageCode == 'en';
}
