// ============================================================================
// REPOSITORY: PromoBannerRepository
// ============================================================================
// Layer akses data banner promo dari endpoint custom WordPress plugin:
// GET https://bindexmall.com/wp-json/bindexmall/v1/promo-banners
//
// Isi/tanggung jawab utama:
//  - Endpoint ini BUKAN WooCommerce REST API standar — dibuat custom di sisi WordPress
//  -   (kemungkinan lewat plugin/functions.php). Kalau endpoint ini error 404, cek dulu
//  -   apakah plugin/custom endpoint di WP masih aktif.
// ============================================================================

// lib/repositories/promo_banner_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/promo_banner.dart';

class PromoBannerRepository {
  // Gunakan base URL yang sama dengan WooCommerce
  static const String baseUrl = 'https://bindexmall.com';
  
  Future<List<PromoBanner>> fetchPromoBanners() async {
    try {
      final url = Uri.parse('$baseUrl/wp-json/bindexmall/v1/promo-banners');
      
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Please check your connection');
        },
      );


      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        
        // Case 1: Response is direct array of banners
        if (responseData is List) {
          return responseData
              .map((json) => PromoBanner.fromJson(json as Map<String, dynamic>))
              .toList();
        }
        
        // Case 2: Response is wrapped in success/data structure
        if (responseData is Map<String, dynamic>) {
          if (responseData['success'] == true && responseData['data'] != null) {
            final List<dynamic> bannersJson = responseData['data'];
            return bannersJson
                .map((json) => PromoBanner.fromJson(json as Map<String, dynamic>))
                .toList();
          }
          
          // Case 3: Direct data without success wrapper
          if (responseData['data'] is List) {
            final List<dynamic> bannersJson = responseData['data'];
            return bannersJson
                .map((json) => PromoBanner.fromJson(json as Map<String, dynamic>))
                .toList();
          }
        }
        
        return [];
        
      } else if (response.statusCode == 404) {
        // Return empty list instead of throwing error
        return [];
        
      } else {
        throw Exception('Failed to load banners: HTTP ${response.statusCode}');
      }
      
    } on http.ClientException catch (e) {
      throw Exception('Network error: Unable to connect to server');
      
    } on FormatException catch (e) {
      throw Exception('Invalid response format from server');
      
    } catch (e) {
      if (e.toString().contains('timeout')) {
        throw Exception('Connection timeout - Please try again');
      }
      throw Exception('Error loading promo banners: ${e.toString()}');
    }
  }
}

final promoBannerRepository = PromoBannerRepository();