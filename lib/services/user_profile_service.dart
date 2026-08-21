// ============================================================================
// SERVICE: UserProfileService
// ============================================================================
// Komunikasi ke endpoint custom WordPress untuk profil user: ambil data user saat ini,
// update profil (nama/no.hp/dll), ganti password, upload foto profil.
//
// Isi/tanggung jawab utama:
//  - baseUrl: https://bindexmall.com — pakai token JWT dari AuthProvider di header Authorization.
//  - Terpisah dari WooCommerceService karena profil user di-manage lewat endpoint custom,
//  -   bukan endpoint /customers standar WooCommerce.
// ============================================================================

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class UserProfileService {
  static const String baseUrl = 'https://bindexmall.com';
  late final Dio _dio;

  UserProfileService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Bypass SSL untuk development
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) {
        return host == 'bindexmall.com';
      };
      return client;
    };
  }

  /// Get current user profile
  /// Requires JWT token
  Future<Map<String, dynamic>> getCurrentUser(String token) async {
    try {
      final response = await _dio.get(
        '/wp-json/wp/v2/users/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          'Error getting user profile: ${e.response?.data ?? e.message}');
    }
  }

  /// Update user profile
  /// Requires JWT token
  Future<Map<String, dynamic>> updateUserProfile({
    required String token,
    required int userId,
    String? firstName,
    String? lastName,
    String? email,
    String? description, // Bio
    Map<String, dynamic>? meta, // Custom meta data
  }) async {
    try {
      final data = <String, dynamic>{};

      if (firstName != null) data['first_name'] = firstName;
      if (lastName != null) data['last_name'] = lastName;
      if (email != null) data['email'] = email;
      if (description != null) data['description'] = description;
      if (meta != null) data['meta'] = meta;

      final response = await _dio.post(
        '/wp-json/wp/v2/users/$userId',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          'Error updating profile: ${e.response?.data ?? e.message}');
    }
  }

  /// Update password
  /// Requires JWT token
  Future<Map<String, dynamic>> updatePassword({
    required String token,
    required int userId,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        '/wp-json/wp/v2/users/$userId',
        data: {
          'password': newPassword,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          'Error updating password: ${e.response?.data ?? e.message}');
    }
  }

  /// Update user profile with custom endpoint
  /// This uses a custom WordPress plugin endpoint that handles both WP user and WooCommerce customer
  Future<Map<String, dynamic>> updateCompleteProfile({
    required String token,
    required int userId,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? bio,
    String? password,
    String? avatarUrl,
  }) async {
    try {
      final data = <String, dynamic>{
        'user_id': userId,
      };

      if (firstName != null) data['first_name'] = firstName;
      if (lastName != null) data['last_name'] = lastName;
      if (email != null) data['email'] = email;
      if (phone != null) data['phone'] = phone;
      if (bio != null) data['bio'] = bio;
      if (password != null && password.isNotEmpty) data['password'] = password;
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;

      final response = await _dio.post(
        '/wp-json/custom/v1/update-profile',
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(
          'Error updating profile: ${e.response?.data['message'] ?? e.message}');
    }
  }

  /// Upload profile image to WordPress Media Library
  Future<String> uploadProfileImage({
    required String token,
    required String filePath,
  }) async {
    try {
      // Get filename from path
      final fileName = filePath.split('/').last;

      // Create FormData
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename:
              'profile_${DateTime.now().millisecondsSinceEpoch}_$fileName',
        ),
      });

      // Upload to WordPress Media Library
      final response = await _dio.post(
        '/wp-json/wp/v2/media',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      // Return the URL of uploaded image
      final imageData = response.data as Map<String, dynamic>;
      return imageData['source_url'] ?? imageData['guid']?['rendered'] ?? '';
    } on DioException catch (e) {
      throw Exception(
          'Error uploading image: ${e.response?.data ?? e.message}');
    }
  }
}

// Singleton instance
final userProfileService = UserProfileService();
