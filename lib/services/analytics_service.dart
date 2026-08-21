// ============================================================================
// SERVICE: AnalyticsService (Singleton)
// ============================================================================
// Kirim event tracking ke Google Analytics 4 lewat Measurement Protocol (HTTP,
// TANPA Firebase SDK). initialize() harus dipanggil sebelum event lain dikirim.
//
// Isi/tanggung jawab utama:
//  - Menyimpan measurementId & apiSecret GA4 — kalau ganti properti GA4, update pemanggil
//  -   initialize() (biasanya dari main.dart atau tempat setup awal lain).
//  - Event standar e-commerce sudah disediakan: logViewItem, logAddToCart, logBeginCheckout,
//  -   logPurchase, dll — pakai method ini, jangan bikin event mentah baru kecuali perlu.
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/product.dart';

/// Analytics Service untuk tracking events ke Google Analytics 4
/// menggunakan Measurement Protocol (HTTP-based, NO Firebase required)
/// 
/// Setup: Panggil initialize() di main.dart sebelum runApp()
/// Usage: analyticsService.logEvent('event_name', parameters: {...})
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  String? _measurementId;
  String? _apiSecret;
  String? _clientId;
  String? _userId;
  bool _isInitialized = false;

  final _uuid = const Uuid();
  
  // GA4 Measurement Protocol endpoint
  static const String _baseUrl = 'https://www.google-analytics.com/mp/collect';

  /// Initialize GA4 dengan Measurement ID dan API Secret
  /// 
  /// Cara mendapatkan:
  /// 1. Buka GA4 > Admin > Data Streams > pilih stream Anda
  /// 2. Scroll ke "Measurement Protocol API secrets"
  /// 3. Klik "Create" untuk buat API Secret baru
  /// 4. Copy Measurement ID (G-XXXXXXXXXX) dan API Secret
  Future<void> initialize(String measurementId, String apiSecret) async {
    try {
      _measurementId = measurementId;
      _apiSecret = apiSecret;
      
      _clientId = _uuid.v4();
      
      _isInitialized = true;
      debugPrint('✅ GA4 Analytics initialized');
      debugPrint('   Measurement ID: $measurementId');
      debugPrint('   Client ID: $_clientId');
    } catch (e) {
      debugPrint('❌ Failed to initialize GA4: $e');
      _isInitialized = false;
    }
  }

  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null && userId.isNotEmpty) {
      debugPrint('📊 GA4: User ID set to $userId');
    } else {
      debugPrint('📊 GA4: User ID cleared');
    }
  }

  Future<void> _sendEvent(String eventName, Map<String, dynamic>? parameters) async {
    if (!_isInitialized || _measurementId == null || _apiSecret == null) {
      debugPrint('⚠️ GA4 not initialized, skipping event: $eventName');
      return;
    }

    try {
      final url = Uri.parse('$_baseUrl?measurement_id=$_measurementId&api_secret=$_apiSecret');
      
      final payload = {
        'client_id': _clientId,
        if (_userId != null) 'user_id': _userId,
        'events': [
          {
            'name': eventName,
            'params': parameters ?? {},
          }
        ],
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('📊 GA4 Event Sent: $eventName ${parameters != null ? '- $parameters' : ''}');
      } else {
        debugPrint('❌ GA4 Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ GA4: Error sending event $eventName: $e');
    }
  }

  Future<void> logEvent(String eventName, {Map<String, dynamic>? parameters}) async {
    await _sendEvent(eventName, parameters);
  }

  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    await _sendEvent('screen_view', {
      'screen_name': screenName,
      if (screenClass != null) 'screen_class': screenClass,
    });
  }

  Future<void> logLogin(String method) async {
    await _sendEvent('login', {
      'method': method,
    });
  }

  Future<void> logSignUp(String method) async {
    await _sendEvent('sign_up', {
      'method': method,
    });
  }

  Future<void> logSearch(String searchTerm) async {
    await _sendEvent('search', {
      'search_term': searchTerm,
    });
  }

  Future<void> logViewItem(Product product) async {
    await _sendEvent('view_item', {
      'currency': 'IDR',
      'value': product.price,
      'items': [
        {
          'item_id': product.id.toString(),
          'item_name': product.name,
          'item_category': product.category,
          'price': product.price,
          'quantity': 1,
        }
      ],
    });
  }

  Future<void> logViewItemList(String listName, List<Product> products) async {
    await _sendEvent('view_item_list', {
      'item_list_name': listName,
      'items': products.take(10).map((product) => {
        'item_id': product.id.toString(),
        'item_name': product.name,
        'item_category': product.category,
        'price': product.price,
      }).toList(),
    });
  }

  Future<void> logAddToCart(Product product, int quantity) async {
    await _sendEvent('add_to_cart', {
      'currency': 'IDR',
      'value': product.price * quantity,
      'items': [
        {
          'item_id': product.id.toString(),
          'item_name': product.name,
          'item_category': product.category,
          'price': product.price,
          'quantity': quantity,
        }
      ],
    });
  }

  Future<void> logRemoveFromCart(Product product, int quantity) async {
    await _sendEvent('remove_from_cart', {
      'currency': 'IDR',
      'value': product.price * quantity,
      'items': [
        {
          'item_id': product.id.toString(),
          'item_name': product.name,
          'item_category': product.category,
          'price': product.price,
          'quantity': quantity,
        }
      ],
    });
  }

  /// Track add to wishlist
  Future<void> logAddToWishlist(Product product) async {
    await _sendEvent('add_to_wishlist', {
      'currency': 'IDR',
      'value': product.price,
      'items': [
        {
          'item_id': product.id.toString(),
          'item_name': product.name,
          'item_category': product.category,
          'price': product.price,
        }
      ],
    });
  }

  /// Track begin checkout
  Future<void> logBeginCheckout(double totalValue, List<Map<String, dynamic>> items) async {
    await _sendEvent('begin_checkout', {
      'currency': 'IDR',
      'value': totalValue,
      'items': items,
    });
  }

  /// Track add shipping info
  Future<void> logAddShippingInfo(
    double totalValue,
    String shippingMethod,
    List<Map<String, dynamic>> items,
  ) async {
    await _sendEvent('add_shipping_info', {
      'currency': 'IDR',
      'value': totalValue,
      'shipping_tier': shippingMethod,
      'items': items,
    });
  }

  /// Track add payment info
  Future<void> logAddPaymentInfo(
    double totalValue,
    String paymentType,
    List<Map<String, dynamic>> items,
  ) async {
    await _sendEvent('add_payment_info', {
      'currency': 'IDR',
      'value': totalValue,
      'payment_type': paymentType,
      'items': items,
    });
  }

  /// Track purchase (Order Success) - MOST IMPORTANT EVENT
  Future<void> logPurchase({
    required String transactionId,
    required double totalValue,
    required double tax,
    required double shipping,
    required String currency,
    required List<Map<String, dynamic>> items,
    String? coupon,
  }) async {
    await _sendEvent('purchase', {
      'transaction_id': transactionId,
      'value': totalValue,
      'tax': tax,
      'shipping': shipping,
      'currency': currency,
      'items': items,
      if (coupon != null) 'coupon': coupon,
    });
  }

  /// Track refund
  Future<void> logRefund({
    required String transactionId,
    required double value,
    String? currency,
  }) async {
    await _sendEvent('refund', {
      'transaction_id': transactionId,
      'value': value,
      'currency': currency ?? 'IDR',
    });
  }

  // ==========================================
  // CUSTOM EVENTS (Specific to Bindexmall)
  // ==========================================

  /// Track live stream view
  Future<void> logLiveStreamView(String liveType) async {
    await _sendEvent('live_stream_view', {
      'live_type': liveType, // 'tiktok' or 'youtube'
    });
  }

  /// Track live chat open
  Future<void> logLiveChatOpen() async {
    await _sendEvent('live_chat_open', {});
  }

  /// Track promo banner click
  Future<void> logPromoBannerClick(String bannerId, String bannerName) async {
    await _sendEvent('promo_banner_click', {
      'banner_id': bannerId,
      'banner_name': bannerName,
    });
  }

  /// Track apply coupon
  Future<void> logApplyCoupon(String couponCode, bool success) async {
    await _sendEvent('apply_coupon', {
      'coupon_code': couponCode,
      'success': success,
    });
  }

  /// Track order tracking view
  Future<void> logTrackOrderView(String orderId) async {
    await _sendEvent('track_order_view', {
      'order_id': orderId,
    });
  }

  /// Track notification permission
  Future<void> logNotificationPermission(bool granted) async {
    await _sendEvent('notification_permission', {
      'granted': granted,
    });
  }

  /// Track language change
  Future<void> logLanguageChange(String language) async {
    await _sendEvent('language_change', {
      'language': language,
    });
  }

  /// Track share product
  Future<void> logShareProduct(Product product) async {
    await _sendEvent('share', {
      'content_type': 'product',
      'item_id': product.id.toString(),
      'item_name': product.name,
    });
  }
}

// Global instance
final analyticsService = AnalyticsService();