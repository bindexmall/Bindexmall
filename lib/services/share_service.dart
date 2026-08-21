// ============================================================================
// SERVICE: ShareService
// ============================================================================
// Generate URL produk untuk dibagikan (web URL + custom scheme bindexmall://product)
// dan trigger share sheet native (share_plus) / buka URL (url_launcher).
//
// Isi/tanggung jawab utama:
//  - Pasangan dari deep_link_service.dart yang MENERIMA link ini saat app dibuka dari luar.
//  - getProductUrl() pakai slug produk — kalau slug kosong, generate slug dari nama produk.
// ============================================================================

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product.dart';

class ShareService {
  // Base URL untuk deep linking
  static const String _baseUrl = 'https://bindexmall.com';
  static const String _appScheme = 'bindexmall://product';

  /// Generate product URL untuk sharing menggunakan SLUG saja
  static String getProductUrl(Product product) {
    // Gunakan slug yang sudah ada dari product
    // Jika slug tidak ada, generate dari nama product
    final slug = product.slug ?? _generateSlug(product.name);
    
    return '$_baseUrl/product/$slug';
  }

  /// Generate slug dari nama product (fallback jika slug tidak ada)
  static String _generateSlug(String productName) {
    return productName
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
  }

  /// Generate custom scheme URL menggunakan slug
  static String getAppSchemeUrl(Product product) {
    final slug = product.slug ?? _generateSlug(product.name);
    return '$_appScheme?slug=$slug';
  }

  /// Share product ke berbagai platform
  static Future<void> shareProduct(
    Product product, {
    String? customMessage,
  }) async {
    final productUrl = getProductUrl(product);
    final message = customMessage ?? _buildShareMessage(product, productUrl);

    try {
      await Share.share(
        message,
        subject: product.name,
      );
    } catch (e) {
      throw Exception('Failed to share: $e');
    }
  }

  /// Share ke WhatsApp
  static Future<void> shareToWhatsApp(Product product) async {
    final productUrl = getProductUrl(product);
    final message = _buildShareMessage(product, productUrl);
    
    final whatsappUrl = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(message)}'
    );

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('WhatsApp tidak tersedia');
      }
    } catch (e) {
      throw Exception('Gagal membuka WhatsApp: $e');
    }
  }

  /// Share ke Facebook
  static Future<void> shareToFacebook(Product product) async {
    final productUrl = getProductUrl(product);
    
    // Facebook sharing menggunakan dialog
    final facebookUrl = Uri.parse(
      'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(productUrl)}'
    );

    try {
      if (await canLaunchUrl(facebookUrl)) {
        await launchUrl(facebookUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Facebook tidak tersedia');
      }
    } catch (e) {
      throw Exception('Gagal membuka Facebook: $e');
    }
  }

  /// Share ke Twitter
  static Future<void> shareToTwitter(Product product) async {
    final productUrl = getProductUrl(product);
    final text = '🛍️ ${product.name}\n💰 ${_formatPrice(product.price)}\n\n';
    
    final twitterUrl = Uri.parse(
      'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}&url=${Uri.encodeComponent(productUrl)}'
    );

    try {
      if (await canLaunchUrl(twitterUrl)) {
        await launchUrl(twitterUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Twitter tidak tersedia');
      }
    } catch (e) {
      throw Exception('Gagal membuka Twitter: $e');
    }
  }

  /// Share ke Instagram (Instagram Stories)
  static Future<void> shareToInstagram(Product product) async {
    // Instagram tidak support direct sharing via URL
    // Kita akan copy link dan buka Instagram
    final productUrl = getProductUrl(product);
    
    try {
      // Copy to clipboard
      await Share.share(productUrl);
      
      // Open Instagram
      final instagramUrl = Uri.parse('instagram://');
      if (await canLaunchUrl(instagramUrl)) {
        await launchUrl(instagramUrl, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Instagram tidak terinstall');
      }
    } catch (e) {
      throw Exception('Gagal membuka Instagram: $e');
    }
  }

  /// Share dengan gambar produk (advanced)
  static Future<void> shareProductWithImage(
    Product product, {
    String? imagePath,
  }) async {
    final productUrl = getProductUrl(product);
    final message = _buildShareMessage(product, productUrl);

    try {
      if (imagePath != null) {
        await Share.shareXFiles(
          [XFile(imagePath)],
          text: message,
          subject: product.name,
        );
      } else {
        await Share.share(message, subject: product.name);
      }
    } catch (e) {
      throw Exception('Failed to share: $e');
    }
  }

  /// Build share message
  static String _buildShareMessage(Product product, String url) {
    final buffer = StringBuffer();
    
    buffer.writeln('🛍️ ${product.name}');
    buffer.writeln();
    buffer.writeln('💰 ${_formatPrice(product.price)}');
    
    if (product.hasDiscount) {
      buffer.writeln('🔥 Diskon ${product.discountPercentage}%');
      if (product.regularPrice != null) {
        buffer.writeln('   Harga normal: ${_formatPrice(product.regularPrice!)}');
      }
    }
    
    if (product.averageRating > 0) {
      buffer.writeln('⭐ ${product.averageRating.toStringAsFixed(1)} (${product.ratingCount} ulasan)');
    }
    
    buffer.writeln();
    buffer.writeln('📱 Lihat detail produk:');
    buffer.writeln(url);
    
    return buffer.toString();
  }

  /// Format price
  static String _formatPrice(double price) {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  /// Copy product link to clipboard
  static Future<void> copyProductLink(Product product) async {
    final productUrl = getProductUrl(product);
    await Share.share(productUrl);
  }
}