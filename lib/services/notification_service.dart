// ============================================================================
// SERVICE: NotificationService (Singleton)
// ============================================================================
// Wrapper flutter_local_notifications — semua notifikasi LOKAL di app ini
// (bukan push notification server/FCM): status pesanan berubah, newsletter, dll.
//
// Isi/tanggung jawab utama:
//  - initialize() + requestPermissions() dipanggil di main.dart sebelum runApp().
//  - areXxxEnabled()/setXxxEnabled() — baca/tulis preferensi on-off per jenis notifikasi
//  -   (dikontrol dari NotificationProvider & notification settings di ProfileScreen).
//  - checkOrderStatusChanges() dipanggil OrderTrackingService secara berkala untuk deteksi
//  -   perubahan status order lalu memicu showOrderStatusNotification().
// ============================================================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  
  // Notification settings keys
  static const String _notificationEnabledKey = 'notifications_enabled';
  static const String _orderStatusKey = 'order_status_notifications';
  static const String _newsletterKey = 'newsletter_notifications';
  static const String _lastCheckedOrdersKey = 'last_checked_orders';

  /// ✅ IMPROVED: Initialize with better error handling
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('✅ NotificationService already initialized');
      return;
    }

    try {
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      final initialized = await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = initialized ?? false;
      
      if (_isInitialized) {
        debugPrint('✅ NotificationService initialized successfully');
      } else {
        debugPrint('⚠️ NotificationService initialization returned false');
      }
    } catch (e) {
      debugPrint('❌ NotificationService initialization failed: $e');
      _isInitialized = false;
    }
  }

  /// ✅ IMPROVED: Better notification tap handling
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📲 Notification tapped: ${response.payload}');
    
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = json.decode(response.payload!) as Map<String, dynamic>;
        
        // TODO: Implement navigation based on notification type
        switch (data['type']) {
          case 'order_status':
            debugPrint('→ Navigate to order: ${data['orderId']}');
            // navigatorKey.currentState?.pushNamed('/order-detail', arguments: data['orderId']);
            break;
          case 'newsletter':
            debugPrint('→ Handle newsletter notification');
            break;
          default:
            debugPrint('→ Unknown notification type: ${data['type']}');
        }
      } catch (e) {
        debugPrint('❌ Error parsing notification payload: $e');
      }
    }
  }

  /// ✅ IMPROVED: Better permission request with result logging
  Future<bool> requestPermissions() async {
    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('📱 Android notification permission: ${granted ?? false}');
        return granted ?? false;
      }

      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('📱 iOS notification permission: ${granted ?? false}');
        return granted ?? false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return false;
    }
  }

  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationEnabledKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationEnabledKey, enabled);
    debugPrint('🔔 Notifications ${enabled ? 'enabled' : 'disabled'}');
  }

  Future<bool> areOrderStatusNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_orderStatusKey) ?? true;
  }

  Future<void> setOrderStatusNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_orderStatusKey, enabled);
    debugPrint('📦 Order notifications ${enabled ? 'enabled' : 'disabled'}');
  }

  Future<bool> areNewsletterNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_newsletterKey) ?? true;
  }

  Future<void> setNewsletterNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_newsletterKey, enabled);
    debugPrint('📰 Newsletter notifications ${enabled ? 'enabled' : 'disabled'}');
  }

  /// ✅ IMPROVED: Added initialization check
  Future<void> showOrderStatusNotification({
    required String orderId,
    required String status,
    required String message,
  }) async {
    if (!_isInitialized) {
      debugPrint('⚠️ Cannot show notification: Service not initialized');
      return;
    }

    if (!await areNotificationsEnabled()) {
      debugPrint('⚠️ Notifications disabled globally');
      return;
    }
    
    if (!await areOrderStatusNotificationsEnabled()) {
      debugPrint('⚠️ Order status notifications disabled');
      return;
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'order_status_channel',
        'Order Status',
        channelDescription: 'Notifications for order status updates',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = json.encode({
        'type': 'order_status',
        'orderId': orderId,
        'status': status,
      });

      await _notificationsPlugin.show(
        id: orderId.hashCode,
        title: 'Order Update',
        body: message,
        notificationDetails: details,
        payload: payload,
      );

      debugPrint('✅ Order notification sent: $orderId - $status');
    } catch (e) {
      debugPrint('❌ Error showing order notification: $e');
    }
  }

  /// ✅ IMPROVED: Check for order status changes with better logging
  Future<void> checkOrderStatusChanges(List<Map<String, dynamic>> currentOrders) async {
    if (!await areOrderStatusNotificationsEnabled()) {
      debugPrint('⚠️ Order status monitoring disabled');
      return;
    }

    try {
      final savedStatuses = await getSavedOrderStatuses();
      final newStatuses = <String, String>{};
      int changesDetected = 0;

      debugPrint('🔍 Checking ${currentOrders.length} orders for status changes');

      for (final order in currentOrders) {
        final orderId = order['id'].toString();
        final currentStatus = order['status'] as String;
        
        newStatuses[orderId] = currentStatus;

        // Check if status changed
        if (savedStatuses.containsKey(orderId)) {
          final previousStatus = savedStatuses[orderId]!;
          
          if (previousStatus != currentStatus) {
            changesDetected++;
            debugPrint('📢 Order #$orderId: $previousStatus → $currentStatus');
            
            // Status changed - send notification
            await showOrderStatusNotification(
              orderId: '#$orderId',
              status: currentStatus,
              message: _getOrderStatusMessage(currentStatus),
            );
          }
        } else {
          debugPrint('🆕 New order detected: #$orderId ($currentStatus)');
        }
      }

      // Save new statuses
      await saveOrderStatuses(newStatuses);
      
      debugPrint('✅ Order status check complete: $changesDetected changes detected');
    } catch (e) {
      debugPrint('❌ Error checking order status changes: $e');
    }
  }

  Future<void> saveOrderStatuses(Map<String, String> orderStatuses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCheckedOrdersKey, json.encode(orderStatuses));
  }

  Future<Map<String, String>> getSavedOrderStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_lastCheckedOrdersKey);
    
    if (saved == null) return {};
    
    try {
      final decoded = json.decode(saved) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      debugPrint('❌ Error loading saved order statuses: $e');
      return {};
    }
  }

  String _getOrderStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pesanan Anda menunggu pembayaran';
      case 'processing':
        return 'Pesanan Anda sedang diproses';
      case 'on-hold':
        return 'Pesanan Anda ditahan sementara';
      case 'completed':
        return 'Pesanan Anda telah selesai!';
      case 'cancelled':
        return 'Pesanan Anda telah dibatalkan';
      case 'refunded':
        return 'Pesanan Anda telah dikembalikan';
      case 'failed':
        return 'Pembayaran pesanan Anda gagal';
      default:
        return 'Status pesanan Anda telah diperbarui';
    }
  }

  Future<void> showNewsletterNotification({
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    if (!_isInitialized) return;
    if (!await areNotificationsEnabled()) return;
    if (!await areNewsletterNotificationsEnabled()) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'newsletter_channel',
        'Newsletter',
        channelDescription: 'Notifications for newsletters and promotions',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = json.encode({
        'type': 'newsletter',
        'imageUrl': imageUrl,
      });

      await _notificationsPlugin.show(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );

      debugPrint('✅ Newsletter notification sent: $title');
    } catch (e) {
      debugPrint('❌ Error showing newsletter notification: $e');
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (!_isInitialized) return;
    if (!await areNotificationsEnabled()) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'general_channel',
        'General',
        channelDescription: 'General notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = data != null ? json.encode(data) : null;

      await _notificationsPlugin.show(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );

      debugPrint('✅ General notification sent: $title');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint('🗑️ All notifications cancelled');
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
    debugPrint('🗑️ Notification $id cancelled');
  }
}

final notificationService = NotificationService();