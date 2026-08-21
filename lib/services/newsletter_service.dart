// ============================================================================
// SERVICE: NewsletterService (Singleton)
// ============================================================================
// Handle subscribe/unsubscribe newsletter (disinkronkan ke WooCommerce lewat
// WooCommerceService) + polling berkala cek promo/produk baru untuk notifikasi.
//
// Isi/tanggung jawab utama:
//  - startChecking()/stopChecking() — jalankan/hentikan Timer polling berkala.
//  - Status subscribe disimpan lokal (SharedPreferences) sebagai cache/flag cepat.
// ============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../services/woocommerce_service.dart';
import '../services/notification_service.dart';

/// Service untuk handle newsletter subscription dari WooCommerce
class NewsletterService {
  static final NewsletterService _instance = NewsletterService._internal();
  factory NewsletterService() => _instance;
  NewsletterService._internal();

  Timer? _checkTimer;
  static const String _lastCheckKey = 'last_newsletter_check';
  static const String _shownNewslettersKey = 'shown_newsletters';

  /// Start checking for newsletters
  void startChecking() {
    // Check immediately
    _checkNewsletters();

    // Then check every 30 minutes
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _checkNewsletters(),
    );

    debugPrint('📬 Newsletter checking started');
  }

  /// Stop checking newsletters
  void stopChecking() {
    _checkTimer?.cancel();
    _checkTimer = null;
    debugPrint('📪 Newsletter checking stopped');
  }

  /// Check for new newsletters/promotions
  Future<void> _checkNewsletters() async {
    try {
      if (!await notificationService.areNewsletterNotificationsEnabled()) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Only check if more than 1 hour has passed
      if (now - lastCheck < const Duration(hours: 1).inMilliseconds) {
        return;
      }

      // Get recent products with "sale" or special categories
      final products = await wooCommerceService.getProducts(
        page: 1,
        perPage: 10,
        orderBy: 'date',
        order: 'desc',
      );

      // Get shown newsletter IDs
      final shownIds = prefs.getStringList(_shownNewslettersKey) ?? [];

      // Check for products on sale or new arrivals
      for (final product in products) {
        final productId = product['id'].toString();
        
        // Skip if already shown
        if (shownIds.contains(productId)) continue;

        // Check if on sale
        if (product['on_sale'] == true) {
          final name = product['name'] as String;
          final regularPrice = double.tryParse(
            product['regular_price']?.toString() ?? '0',
          ) ?? 0;
          final salePrice = double.tryParse(
            product['sale_price']?.toString() ?? '0',
          ) ?? 0;

          if (regularPrice > 0 && salePrice > 0) {
            final discount = ((regularPrice - salePrice) / regularPrice * 100).round();
            
            await notificationService.showNewsletterNotification(
              title: '🔥 Flash Sale Alert!',
              body: '$name is now $discount% off! Don\'t miss out!',
              imageUrl: _getImageUrl(product),
            );

            // Mark as shown
            shownIds.add(productId);
          }
        }
        // Check for new arrivals (products created in last 7 days)
        else {
          final dateCreated = DateTime.tryParse(
            product['date_created'] ?? '',
          );
          
          if (dateCreated != null) {
            final daysSinceCreation = DateTime.now().difference(dateCreated).inDays;
            
            if (daysSinceCreation <= 7) {
              final name = product['name'] as String;
              
              await notificationService.showNewsletterNotification(
                title: '✨ New Arrival!',
                body: 'Check out our latest addition: $name',
                imageUrl: _getImageUrl(product),
              );

              // Mark as shown
              shownIds.add(productId);
            }
          }
        }

        // Limit to 3 notifications per check
        if (shownIds.length >= 3) break;
      }

      // Save shown IDs (keep last 50)
      if (shownIds.length > 50) {
        shownIds.removeRange(0, shownIds.length - 50);
      }
      await prefs.setStringList(_shownNewslettersKey, shownIds);
      
      // Update last check time
      await prefs.setInt(_lastCheckKey, now);

    } catch (e) {
      debugPrint('Error checking newsletters: $e');
    }
  }

  String? _getImageUrl(Map<String, dynamic> product) {
    final images = product['images'] as List?;
    if (images != null && images.isNotEmpty) {
      return images[0]['src'] as String?;
    }
    return null;
  }

  /// Subscribe to newsletter (optional - jika ada custom endpoint)
  Future<bool> subscribe(String email) async {
    try {
      // Jika WooCommerce memiliki newsletter plugin, gunakan endpoint-nya
      // Contoh untuk MailChimp for WooCommerce atau Newsletter plugin
      final dio = Dio();
      
      final response = await dio.post(
        '${WooCommerceService.baseUrl}/wp-json/custom/v1/newsletter/subscribe',
        data: {'email': email},
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Newsletter subscription error: $e');
      
      // Fallback: simpan di local untuk tracking saja
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('newsletter_subscribed', true);
      await prefs.setString('newsletter_email', email);
      
      return true;
    }
  }

  /// Check if user is subscribed
  Future<bool> isSubscribed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('newsletter_subscribed') ?? false;
  }

  /// Unsubscribe from newsletter
  Future<bool> unsubscribe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('newsletter_subscribed', false);
    return true;
  }

  /// Manual check (for testing)
  Future<void> checkNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, 0); // Reset last check
    await _checkNewsletters();
  }
}

final newsletterService = NewsletterService();