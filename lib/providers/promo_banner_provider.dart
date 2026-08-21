// ============================================================================
// PROVIDER: PromoBannerProvider (ChangeNotifier)
// ============================================================================
// State banner promo di home screen, dengan cache sederhana (_lastFetchTime)
// supaya tidak fetch ulang tiap kali widget rebuild.
//
// Isi/tanggung jawab utama:
//  - loadBanners(silent: true) dipakai untuk refresh diam-diam tanpa munculin loading spinner.
// ============================================================================

import 'package:flutter/foundation.dart';
import '../models/promo_banner.dart';
import '../repositories/promo_banner_repository.dart';

class PromoBannerProvider with ChangeNotifier {
  List<PromoBanner> _banners = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetchTime;

  List<PromoBanner> get banners => _banners;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasBanners => _banners.isNotEmpty;

  Future<void> loadBanners({bool silent = false}) async {
    if (_isLoading && !silent) return;

    if (silent && _lastFetchTime != null) {
      final diff = DateTime.now().difference(_lastFetchTime!);
      if (diff.inMinutes < 1) {
        return;
      }
    }

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final fetchedBanners = await promoBannerRepository.fetchPromoBanners();
      
      _banners = fetchedBanners.where((banner) => banner.isValid).toList();
      _error = null;
      _lastFetchTime = DateTime.now();
      
      
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      
      if (!silent) {
        _banners = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadBanners(silent: true);
  }

  Future<void> forceReload() async {
    _banners = [];
    _lastFetchTime = null;
    await loadBanners(silent: false);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}