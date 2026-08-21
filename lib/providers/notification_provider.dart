// ============================================================================
// PROVIDER: NotificationProvider (ChangeNotifier)
// ============================================================================
// State untuk pengaturan notifikasi lokal (on/off notifikasi umum, status pesanan,
// newsletter) — disimpan di SharedPreferences lewat NotificationService.
//
// Isi/tanggung jawab utama:
//  - requestPermissions() — minta izin notifikasi ke OS (Android 13+ butuh izin eksplisit).
// ============================================================================

import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  bool _notificationsEnabled = true;
  bool _orderStatusEnabled = true;
  bool _newsletterEnabled = true;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get orderStatusEnabled => _orderStatusEnabled;
  bool get newsletterEnabled => _newsletterEnabled;

  NotificationProvider() {
    _loadSettings();
  }

  /// Load notification settings
  Future<void> _loadSettings() async {
    _notificationsEnabled = await notificationService.areNotificationsEnabled();
    _orderStatusEnabled = await notificationService.areOrderStatusNotificationsEnabled();
    _newsletterEnabled = await notificationService.areNewsletterNotificationsEnabled();
    notifyListeners();
  }

  /// Toggle all notifications
  Future<void> toggleNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
    await notificationService.setNotificationsEnabled(enabled);
    notifyListeners();

    if (!enabled) {
      // Cancel all pending notifications
      await notificationService.cancelAllNotifications();
    }
  }

  /// Toggle order status notifications
  Future<void> toggleOrderStatus(bool enabled) async {
    _orderStatusEnabled = enabled;
    await notificationService.setOrderStatusNotifications(enabled);
    notifyListeners();
  }

  /// Toggle newsletter notifications
  Future<void> toggleNewsletter(bool enabled) async {
    _newsletterEnabled = enabled;
    await notificationService.setNewsletterNotifications(enabled);
    notifyListeners();
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    return await notificationService.requestPermissions();
  }
}