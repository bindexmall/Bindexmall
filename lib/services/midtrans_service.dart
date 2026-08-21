// ============================================================================
// SERVICE: MidtransService / MidtransException
// ============================================================================
// Integrasi pembayaran Midtrans (Snap): ambil Snap token, cek status transaksi,
// batalkan transaksi. isProduction=true berarti sudah pakai environment PRODUCTION,
// bukan sandbox — hati-hati saat testing.
//
// Isi/tanggung jawab utama:
//  - serverKey & clientKey sekarang diambil dari config/secrets.dart (di-gitignore).
//    serverKey ini SANGAT SENSITIF (bisa dipakai untuk cek/batalin transaksi) —
//    ini yang PALING PRIORITAS buat dipindah ke proxy backend, karena pemisahan
//    ke file terpisah cuma nyelesain "bocor lewat git", bukan "kebaca kalau APK
//    di-decompile". clientKey aman tetap di app, itu memang didesain publik.
//  - buildSnapUrl() menghasilkan URL WebView Snap yang dibuka di MidtransPaymentScreen
//    (lihat screens/checkout_screen.dart).
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

class MidtransService {
  static const String serverKey = Secrets.midtransServerKey;
  static const String clientKey = Secrets.midtransClientKey;
  static const bool isProduction = true;

  // Midtrans API URLs
  static String get snapUrl => isProduction
      ? 'https://app.midtrans.com/snap/v1/transactions'
      : 'https://app.sandbox.midtrans.com/snap/v1/transactions';

  static String get coreApiUrl => isProduction
      ? 'https://api.midtrans.com/v2'
      : 'https://api.sandbox.midtrans.com/v2';

  // Get Snap Token for payment
  Future<String> getSnapToken({
    required String orderId,
    required double grossAmount,
    required Map<String, dynamic> customerDetails,
    List<Map<String, dynamic>>? itemDetails,
  }) async {
    try {
      // Encode server key untuk Basic Auth
      final auth = base64.encode(utf8.encode('$serverKey:'));


      final requestBody = {
        'transaction_details': {
          'order_id': orderId,
          'gross_amount': grossAmount.toInt(),
        },
        'customer_details': customerDetails,
        'item_details': itemDetails,
        'credit_card': {
          'secure': true,
        },
        // Tambahan untuk mobile app
        'enabled_payments': [
          'credit_card',
          'bca_va',
          'bni_va',
          'bri_va',
          'mandiri_va',
          'permata_va',
          'cimb_va',
          'other_va',
          'gopay',
          'shopeepay',
          'qris',
        ],
      };


      final response = await http.post(
        Uri.parse(snapUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Basic $auth',
        },
        body: json.encode(requestBody),
      );


      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['token'];
      } else {
        final errorData = json.decode(response.body);
        throw MidtransException(
          'Failed to get snap token: ${response.statusCode}',
          'Status: ${errorData['status_code']}\n'
              'Message: ${errorData['status_message']}\n'
              'Details: ${errorData['error_messages']?.join(', ')}',
        );
      }
    } catch (e) {
      if (e is MidtransException) rethrow;
      throw MidtransException('Error getting snap token: $e');
    }
  }

  // Check transaction status
  Future<Map<String, dynamic>> checkTransactionStatus(String orderId) async {
    try {
      final auth = base64.encode(utf8.encode('$serverKey:'));

      final response = await http.get(
        Uri.parse('$coreApiUrl/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Basic $auth',
        },
      );


      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw MidtransException(
          'Failed to check status: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      throw MidtransException('Error checking status: $e');
    }
  }

  // Cancel transaction
  Future<void> cancelTransaction(String orderId) async {
    try {
      final auth = base64.encode(utf8.encode('$serverKey:'));

      final response = await http.post(
        Uri.parse('$coreApiUrl/$orderId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Basic $auth',
        },
      );

      if (response.statusCode != 200) {
        throw MidtransException(
          'Failed to cancel: ${response.statusCode}',
          response.body,
        );
      }
    } catch (e) {
      throw MidtransException('Error canceling transaction: $e');
    }
  }

  // Build Snap URL for WebView
  String buildSnapUrl(String snapToken) {
    return isProduction
        ? 'https://app.midtrans.com/snap/v2/vtweb/$snapToken'
        : 'https://app.sandbox.midtrans.com/snap/v2/vtweb/$snapToken';
  }

  // Validate configuration
  bool isConfigured() {
    return serverKey.isNotEmpty &&
        !serverKey.contains('xxxxx') &&
        clientKey.isNotEmpty &&
        !clientKey.contains('xxxxx');
  }
}

class MidtransException implements Exception {
  final String message;
  final String? details;

  MidtransException(this.message, [this.details]);

  @override
  String toString() =>
      'MidtransException: $message${details != null ? '\nDetails: $details' : ''}';
}

final midtransService = MidtransService();
