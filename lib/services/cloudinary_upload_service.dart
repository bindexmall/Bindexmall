// ============================================================================
// SERVICE: CloudinaryUploadService
// ============================================================================
// Upload bukti pembayaran (payment proof) ke Cloudinary, termasuk generate
// thumbnail/medium URL dan signed URL untuk akses terbatas waktu.
//
// Isi/tanggung jawab utama:
//  - apiKey & apiSecret sekarang diambil dari config/secrets.dart (di-gitignore).
//    apiSecret bisa dipakai generate signed URL / hapus asset, jadi tetap perlu
//    hati-hati — cek juga permission uploadPreset ('payment_proofs') di dashboard
//    Cloudinary supaya ga bisa dipakai upload sembarangan dari luar app.
//  - testConnection() berguna untuk cek cepat apakah kredensial masih valid.
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../config/secrets.dart';

class CloudinaryUploadService {
  static const String cloudName = 'djcak9l23';
  static const String uploadPreset = 'payment_proofs';

  static const String apiKey = Secrets.cloudinaryApiKey;
  static const String apiSecret = Secrets.cloudinaryApiSecret;
  
  static const String baseUrl = 'https://api.cloudinary.com/v1_1';
  static const String resourceBaseUrl = 'https://res.cloudinary.com';
  
  Future<Map<String, dynamic>?> uploadPaymentProof({
    required File proofFile,
    required String orderId,
    String? customerName,
    String? customerEmail,
    String? transferAmount,
  }) async {
    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📤 Starting Cloudinary upload...');
      debugPrint('☁️ Cloud: $cloudName');
      debugPrint('📋 Order ID: $orderId');
      
      // Validate file
      if (!await proofFile.exists()) {
        throw Exception('File does not exist');
      }

      final fileSize = await proofFile.length();
      debugPrint('📊 File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('File too large. Maximum 10MB allowed.');
      }

      final bytes = await proofFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final publicId = 'payment_proofs/order_${orderId}_$timestamp';
      
      debugPrint('🆔 Public ID: $publicId');
      
      final contextData = <String, String>{
        'order_id': orderId,
        'type': 'payment_proof',
        if (customerName != null && customerName.isNotEmpty) 
          'customer': customerName,
        if (customerEmail != null && customerEmail.isNotEmpty)
          'email': customerEmail,
        if (transferAmount != null && transferAmount.isNotEmpty)
          'amount': transferAmount,
        'uploaded_at': DateTime.now().toIso8601String(),
      };
      
      final contextString = contextData.entries
          .map((e) => '${e.key}=${e.value}')
          .join('|');
      
      final uri = Uri.parse('$baseUrl/$cloudName/image/upload');
      
      debugPrint('🌐 Uploading to: $uri');
      
      final request = http.MultipartRequest('POST', uri);
      
      request.fields.addAll({
        'file': 'data:image/jpeg;base64,$base64Image',
        'upload_preset': uploadPreset,
        'public_id': publicId,
        'folder': 'payment_proofs',
        'context': contextString,
        'tags': 'payment_proof,order_$orderId',
        'resource_type': 'image',
      });
      
      // Send request
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Upload timeout. Please check your connection.');
        },
      );
      
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('📥 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        debugPrint('✅ Upload successful!');
        debugPrint('🔗 URL: ${data['secure_url']}');
        debugPrint('📦 Size: ${data['bytes']} bytes');
        debugPrint('🎨 Format: ${data['format']}');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        
        return {
          'id': data['public_id'],
          'url': data['secure_url'],
          'thumbnail': _getThumbnailUrl(data['secure_url']),
          'medium': _getMediumUrl(data['secure_url']),
          'format': data['format'],
          'size': data['bytes'],
          'width': data['width'],
          'height': data['height'],
          'created_at': data['created_at'],
          'order_id': orderId,
        };
      } else {
        final errorBody = response.body;
        debugPrint('❌ Upload failed: ${response.statusCode}');
        debugPrint('❌ Response: $errorBody');
        
        try {
          final errorData = json.decode(errorBody);
          final errorMessage = errorData['error']?['message'] ?? 'Upload failed';
          throw Exception(errorMessage);
        } catch (e) {
          throw Exception('Upload failed: ${response.statusCode}');
        }
      }
    } on SocketException {
      debugPrint('❌ No internet connection');
      throw Exception('No internet connection. Please check your network.');
    } on TimeoutException {
      debugPrint('❌ Upload timeout');
      throw Exception('Upload timeout. Please try again.');
    } catch (e) {
      debugPrint('❌ Error: $e');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      rethrow;
    }
  }
  
  String _getThumbnailUrl(String originalUrl) {
    return originalUrl.replaceAll(
      '/upload/',
      '/upload/w_200,h_200,c_fill,q_auto,f_auto/',
    );
  }
  
  String _getMediumUrl(String originalUrl) {
    return originalUrl.replaceAll(
      '/upload/',
      '/upload/w_800,h_800,c_limit,q_auto,f_auto/',
    );
  }
  
  Future<List<Map<String, dynamic>>> uploadMultiplePaymentProofs({
    required List<File> proofFiles,
    required String orderId,
    String? customerName,
    String? customerEmail,
  }) async {
    final results = <Map<String, dynamic>>[];
    
    debugPrint('📤 Uploading ${proofFiles.length} files...');
    
    for (int i = 0; i < proofFiles.length; i++) {
      try {
        debugPrint('Uploading file ${i + 1}/${proofFiles.length}...');
        
        final result = await uploadPaymentProof(
          proofFile: proofFiles[i],
          orderId: '${orderId}_${i + 1}',
          customerName: customerName,
          customerEmail: customerEmail,
        );
        
        if (result != null) {
          results.add(result);
        }
      } catch (e) {
        debugPrint('❌ Failed to upload file ${i + 1}: $e');
      }
    }
    
    debugPrint('✅ Uploaded ${results.length}/${proofFiles.length} files');
    return results;
  }
  
  Future<bool> deleteImage(String publicId) async {
    if (apiKey.isEmpty || apiSecret.isEmpty) {
      debugPrint('⚠️ API key/secret not configured. Cannot delete.');
      return false;
    }
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      final toSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
      final signature = sha1.convert(utf8.encode(toSign)).toString();
      
      final uri = Uri.parse('$baseUrl/$cloudName/image/destroy');
      
      final response = await http.post(
        uri,
        body: {
          'public_id': publicId,
          'signature': signature,
          'api_key': apiKey,
          'timestamp': timestamp,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == 'ok') {
          debugPrint('✅ Image deleted: $publicId');
          return true;
        }
      }
      
      debugPrint('❌ Failed to delete image: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting image: $e');
      return false;
    }
  }
  
  String generateSignedUrl(String publicId, {int expiresIn = 3600}) {
    if (apiKey.isEmpty || apiSecret.isEmpty) {
      debugPrint('⚠️ API key/secret not configured. Returning public URL.');
      return '$resourceBaseUrl/$cloudName/image/upload/$publicId';
    }
    
    try {
      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round() + expiresIn;
      final toSign = 'timestamp=$timestamp$apiSecret';
      final signature = sha1.convert(utf8.encode(toSign)).toString().substring(0, 8);
      
      return '$resourceBaseUrl/$cloudName/image/upload/'
             's--$signature--/'
             't_$timestamp/'
             '$publicId';
    } catch (e) {
      debugPrint('❌ Error generating signed URL: $e');
      return '$resourceBaseUrl/$cloudName/image/upload/$publicId';
    }
  }
  
  Future<bool> testConnection() async {
    try {
      debugPrint('🧪 Testing Cloudinary connection...');
      debugPrint('☁️ Cloud name: $cloudName');
      debugPrint('📋 Upload preset: $uploadPreset');
      
      final uri = Uri.parse('$baseUrl/$cloudName/image/upload');
      
      final response = await http.post(
        uri,
        body: {
          'file': 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
          'upload_preset': uploadPreset,
          'public_id': 'test_connection_${DateTime.now().millisecondsSinceEpoch}',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Connection successful!');
        debugPrint('📦 Test upload URL: ${data['secure_url']}');
        
        if (apiKey.isNotEmpty && apiSecret.isNotEmpty) {
          await deleteImage(data['public_id']);
          debugPrint('🗑️ Test image deleted');
        }
        
        return true;
      }
      
      debugPrint('❌ Connection failed: ${response.statusCode}');
      debugPrint('❌ Response: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ Connection test failed: $e');
      return false;
    }
  }
  
  Future<Map<String, dynamic>?> getImageInfo(String publicId) async {
    if (apiKey.isEmpty || apiSecret.isEmpty) {
      debugPrint('⚠️ API key/secret not configured.');
      return null;
    }
    
    try {
      final uri = Uri.parse('$baseUrl/$cloudName/resources/image/upload/$publicId');
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$apiKey:$apiSecret'))}',
        },
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error getting image info: $e');
      return null;
    }
  }
}

final cloudinaryUploadService = CloudinaryUploadService();