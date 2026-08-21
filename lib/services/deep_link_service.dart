// ============================================================================
// SERVICE: DeepLinkService (Singleton)
// ============================================================================
// Menangani deep link (mis. bindexmall://product/... atau link universal dari share)
// menggunakan package app_links, lalu broadcast lewat Stream ke MyApp untuk navigasi.
//
// Isi/tanggung jawab utama:
//  - initialize() dipanggil sekali di main.dart sebelum runApp().
//  - Lihat _handleLink() untuk mapping format URI ke halaman tujuan.
//  - Dipasangkan dengan share_service.dart yang GENERATE link produk untuk dibagikan.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;
  
  final StreamController<Uri> _linkController = StreamController<Uri>.broadcast();
  Stream<Uri> get linkStream => _linkController.stream;

  /// Initialize deep linking
  Future<void> initialize() async {
    _appLinks = AppLinks();

    try {
      // Get initial link (app opened from link)
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('📲 Initial deep link: $initialUri');
        _handleLink(initialUri);
      }

      // Listen for links while app is running
      _subscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          debugPrint('📲 Deep link received: $uri');
          _handleLink(uri);
        },
        onError: (err) {
          debugPrint('❌ Deep link error: $err');
        },
      );
      
      debugPrint('✅ Deep link service initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize deep linking: $e');
    }
  }

  /// Handle incoming deep link
  void _handleLink(Uri uri) {
    debugPrint('🔗 Handling deep link: $uri');
    _linkController.add(uri);
  }

  /// Parse product slug from URI
  /// Struktur yang benar: https://bindexmall.com/product/benex-lem-kertas-batang-15g-pvp-original-1dus
  static String? parseProductSlug(Uri uri) {
    debugPrint('🔍 Parsing URI: $uri');
    debugPrint('   - Scheme: ${uri.scheme}');
    debugPrint('   - Host: ${uri.host}');
    debugPrint('   - Path: ${uri.path}');
    debugPrint('   - Segments: ${uri.pathSegments}');
    
    // Handle custom scheme: bindexmall://product?slug=product-slug-name
    if (uri.scheme == 'bindexmall' && uri.host == 'product') {
      final slug = uri.queryParameters['slug'];
      if (slug != null && slug.isNotEmpty) {
        debugPrint('✅ Product slug from custom scheme: $slug');
        return slug;
      }
      
      // Fallback untuk backward compatibility dengan 'id'
      final id = uri.queryParameters['id'];
      if (id != null && id.isNotEmpty) {
        debugPrint('⚠️ Using legacy ID parameter: $id');
        return id;
      }
    }
    
    // Handle HTTPS: https://bindexmall.com/product/product-slug-name
    if ((uri.host == 'bindexmall.com' || uri.host == 'www.bindexmall.com') && 
        uri.pathSegments.isNotEmpty) {
      
      // /product/product-slug-name (struktur yang benar)
      if (uri.pathSegments.first == 'product' && uri.pathSegments.length > 1) {
        final slug = uri.pathSegments[1];
        debugPrint('✅ Product slug from /product/ path: $slug');
        return slug;
      }
      
      // /p/product-slug-name (short link - alternatif)
      if (uri.pathSegments.first == 'p' && uri.pathSegments.length > 1) {
        final slug = uri.pathSegments[1];
        debugPrint('✅ Product slug from /p/ path: $slug');
        return slug;
      }
    }
    
    debugPrint('⚠️ Could not parse product slug from URI');
    return null;
  }

  /// Check if URI is a product link
  static bool isProductLink(Uri uri) {
    // Custom scheme
    if (uri.scheme == 'bindexmall' && uri.host == 'product') {
      return uri.queryParameters.containsKey('slug') || 
             uri.queryParameters.containsKey('id');
    }
    
    // HTTPS
    if ((uri.host == 'bindexmall.com' || uri.host == 'www.bindexmall.com')) {
      if (uri.pathSegments.isNotEmpty) {
        final firstSegment = uri.pathSegments.first;
        return (firstSegment == 'product' || firstSegment == 'p') && 
               uri.pathSegments.length > 1;
      }
    }
    
    return false;
  }

  /// Check if app was opened from a link
  Future<Uri?> getInitialLink() async {
    try {
      return await _appLinks.getInitialLink();
    } catch (e) {
      debugPrint('❌ Error getting initial link: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _linkController.close();
  }
}