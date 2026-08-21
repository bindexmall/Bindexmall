// ============================================================================
// SERVICE: JWTAuthService
// ============================================================================
// Komunikasi ke endpoint custom JWT auth di WordPress (bukan WooCommerce REST API
// standar) untuk login, register, validasi token, lupa/reset password.
//
// Isi/tanggung jawab utama:
//  - baseUrl: https://bindexmall.com — endpoint di bawah /wp-json/... (kemungkinan plugin
//  -   'JWT Authentication for WP-API' atau custom endpoint serupa di sisi WordPress).
//  - Dipakai oleh AuthProvider — token hasil login disimpan AuthProvider ke SharedPreferences,
//  -   service ini sendiri tidak menyimpan state.
// ============================================================================

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class JWTAuthService {
  static const String baseUrl = 'https://bindexmall.com';
  late final Dio _dio;

  JWTAuthService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Bypass SSL untuk development (sama seperti WooCommerceService)
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) {
        return host == 'bindexmall.com';
      };
      return client;
    };
  }

  /// Login dengan username/email dan password
  /// Returns: {token, user_email, user_nicename, user_display_name}
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '/wp-json/jwt-auth/v1/token',
        data: {
          'username': username, // bisa email atau username
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Login gagal');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('Email atau password salah');
      }
      throw Exception('Error: ${e.response?.data['message'] ?? e.message}');
    }
  }

  /// Validate token
  /// Returns user data if token valid
  Future<Map<String, dynamic>> validateToken(String token) async {
    try {
      final response = await _dio.post(
        '/wp-json/jwt-auth/v1/token/validate',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Token tidak valid: ${e.message}');
    }
  }

  /// Register user baru menggunakan custom endpoint
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final data = {
        'name': name,
        'email': email,
        'password': password,
      };

      // Add phone if provided
      if (phone != null && phone.isNotEmpty) {
        data['phone'] = phone;
      }

      final response = await _dio.post(
        '/wp-json/custom/v1/register',
        data: data,
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      // Handle error dengan lebih baik
      String errorMessage = 'Registration gagal';

      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          errorMessage = data['message'];
        }
      }

      throw Exception(errorMessage);
    }
  }

  /// Reset password - kirim email reset password
  /// Menggunakan WordPress lost password endpoint
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      // Method 1: Try custom endpoint first (jika tersedia)
      try {
        final response = await _dio.post(
          '/wp-json/custom/v1/reset-password',
          data: {
            'email': email,
          },
        );

        if (response.statusCode == 200) {
          return response.data as Map<String, dynamic>;
        }
      } catch (e) {
        // Jika custom endpoint tidak tersedia, gunakan WordPress default
      }

      // Method 2: WordPress default lost password endpoint
      final response = await _dio.post(
        '/wp-json/bdpwr/v1/reset-password',
        data: {
          'email': email,
        },
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Gagal mengirim email reset password');
      }
    } on DioException catch (e) {
      String errorMessage = 'Gagal mengirim email reset password';

      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          if (data['message'] != null) {
            errorMessage = data['message'];
          } else if (data['data']?['message'] != null) {
            errorMessage = data['data']['message'];
          }
        } else if (data is String) {
          errorMessage = data;
        }
      }

      // Jika email tidak ditemukan
      if (e.response?.statusCode == 404 || errorMessage.contains('not found')) {
        throw Exception('Email tidak terdaftar');
      }

      throw Exception(errorMessage);
    }
  }

  /// Verify reset code (opsional - jika menggunakan custom endpoint dengan kode verifikasi)
  Future<bool> verifyResetCode(String email, String code) async {
    try {
      final response = await _dio.post(
        '/wp-json/custom/v1/verify-reset-code',
        data: {
          'email': email,
          'code': code,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Set new password (opsional - jika menggunakan custom endpoint)
  Future<Map<String, dynamic>> setNewPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        '/wp-json/custom/v1/set-new-password',
        data: {
          'email': email,
          'code': code,
          'password': newPassword,
        },
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      String errorMessage = 'Gagal mengatur password baru';

      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          errorMessage = data['message'];
        }
      }

      throw Exception(errorMessage);
    }
  }
}

// Singleton instance
final jwtAuthService = JWTAuthService();
