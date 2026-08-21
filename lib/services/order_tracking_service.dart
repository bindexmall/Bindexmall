// ============================================================================
// SERVICE: OrderTrackingService (Singleton)
// ============================================================================
// Polling berkala (Timer) ke WooCommerce untuk cek apakah ada perubahan status
// pesanan user yang sedang login, lalu memicu notifikasi lokal lewat NotificationService.
//
// Isi/tanggung jawab utama:
//  - startTracking(userId)/stopTracking() — dipanggil AuthProvider mengikuti status login.
//  - Ini BUKAN real-time (tidak pakai websocket/push) — murni polling, jadi ada jeda deteksi.
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/woocommerce_service.dart';
import '../services/notification_service.dart';

/// Service untuk tracking order status changes
class OrderTrackingService {
  static final OrderTrackingService _instance = OrderTrackingService._internal();
  factory OrderTrackingService() => _instance;
  OrderTrackingService._internal();

  Timer? _trackingTimer;
  String? _currentUserId;
  bool _isTracking = false;

  /// Start tracking orders
  void startTracking(String? userId) {
    if (userId == null) {
      stopTracking();
      return;
    }

    _currentUserId = userId;
    _isTracking = true;

    // Check immediately
    _checkOrders();

    // Then check every 5 minutes
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkOrders(),
    );

    debugPrint('🔔 Order tracking started for user: $userId');
  }

  /// Stop tracking orders
  void stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _currentUserId = null;
    _isTracking = false;
    debugPrint('🔕 Order tracking stopped');
  }

  /// Check for order status changes
  Future<void> _checkOrders() async {
    if (!_isTracking || _currentUserId == null) return;

    try {
      final customerId = int.tryParse(_currentUserId!);
      if (customerId == null) return;

      // Get current orders
      final orders = await wooCommerceService.getCustomerOrders(
        customerId,
        perPage: 20,
      );

      // Check for status changes and notify
      await notificationService.checkOrderStatusChanges(
        orders.map((o) => o as Map<String, dynamic>).toList(),
      );

    } catch (e) {
      debugPrint('Error checking orders: $e');
    }
  }

  /// Manual check (for pull-to-refresh)
  Future<void> checkNow() async {
    await _checkOrders();
  }

  /// Check if tracking is active
  bool get isTracking => _isTracking;
}

final orderTrackingService = OrderTrackingService();