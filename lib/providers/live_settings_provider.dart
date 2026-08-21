// ============================================================================
// PROVIDER: LiveSettingsProvider (ChangeNotifier)
// ============================================================================
// State untuk pengaturan fitur live streaming/live shopping (fetch via LiveSettingsService).
//
// Isi/tanggung jawab utama:
//  - loadSettings()/refreshSettings() — ambil status live dari endpoint custom WordPress.
// ============================================================================

import 'package:flutter/material.dart';
import '../models/live_settings.dart';
import '../services/live_settings_service.dart';

class LiveSettingsProvider with ChangeNotifier {
  final LiveSettingsService _service;
  LiveSettings? _settings;
  bool _isLoading = false;
  String? _error;

  LiveSettingsProvider(this._service);

  LiveSettings? get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _settings = await _service.fetchLiveSettings();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSettings() async {
    await loadSettings();
  }
}