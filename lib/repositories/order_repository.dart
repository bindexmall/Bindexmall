// ============================================================================
// REPOSITORY: OrderRepository
// ============================================================================
// Layer akses data pesanan (order) WooCommerce: buat order, ambil daftar/([detail order),
// update status, tandai lunas, filter berdasarkan status.
//
// Isi/tanggung jawab utama:
//  - createOrder() memanggil WooCommerceService.createOrder lalu memicu NotificationService
//  -   untuk kirim notifikasi lokal 'pesanan dibuat'.
//  - fetchOrdersWithFallback() — ada logic fallback kalau fetch dengan customer_id gagal.
//  - Order ini SELALU berasal dari WooCommerce (server jadi source of truth), beda dengan
//  -   Cart yang disimpan lokal.
// ============================================================================

import '../models/cart.dart';
import '../services/woocommerce_service.dart';
import '../services/notification_service.dart'; // ✅ TAMBAHKAN IMPORT

class OrderRepository {
  final WooCommerceService _wooCommerceService = wooCommerceService;

  OrderRepository();

  Future<Map<String, dynamic>> createOrder({
    required Cart cart,
    required Map<String, dynamic> billingAddress,
    required Map<String, dynamic> shippingAddress,
    required String paymentMethod,
    String paymentMethodTitle = 'Midtrans',
    String? customerNote,
    int? customerId,
  }) async {
    try {
      
      if (customerId == null || customerId == 0) {
        throw Exception('Customer ID required. Please login to create order.');
      }

      final int validCustomerId = customerId;

      final orderData = {
        'payment_method': paymentMethod,
        'payment_method_title': paymentMethodTitle,
        'set_paid': false,
        'billing': billingAddress,
        'shipping': shippingAddress,
        'line_items': cart.toWooCommerceLineItems(),
        'customer_id': validCustomerId,
        if (customerNote != null && customerNote.isNotEmpty) 
          'customer_note': customerNote,
      };

      
      final response = await _wooCommerceService.createOrder(orderData);

      if (response is Map<String, dynamic>) {
        
        if (response['customer_id'] == 0 || response['customer_id'] == null) {
        } else {
        }
        
        // ✅ TAMBAHAN: SEND NOTIFICATION
        try {
          await notificationService.showOrderStatusNotification(
            orderId: '#${response['id']}',
            status: response['status'] ?? 'pending',
            message: _getOrderCreatedMessage(response['status'] ?? 'pending'),
          );
        } catch (notifError) {
          // Don't fail the order creation if notification fails
        }
        
        
        return response;
      }

      throw Exception('Invalid order response format');
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  // ✅ TAMBAHAN: Helper method untuk message
  String _getOrderCreatedMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pesanan berhasil dibuat! Silakan lakukan pembayaran.';
      case 'processing':
        return 'Pesanan berhasil dibuat dan sedang diproses!';
      case 'on-hold':
        return 'Pesanan berhasil dibuat. Menunggu konfirmasi.';
      default:
        return 'Pesanan berhasil dibuat!';
    }
  }

  Future<List<Map<String, dynamic>>> fetchOrders({
    int page = 1,
    int perPage = 20,
    int? customerId,
    String? status,
  }) async {
    try {
      
      final response = await _wooCommerceService.getOrders(
        page: page,
        perPage: perPage,
        customer: customerId,
        status: status,
      );

      final orders = response.cast<Map<String, dynamic>>();
      
      return orders;
    } catch (e) {
      throw Exception('Failed to fetch orders: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchOrdersWithFallback({
    required int customerId,
    String? email,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      
      List<Map<String, dynamic>> orders = await fetchOrders(
        customerId: customerId,
        page: page,
        perPage: perPage,
      );


      if (orders.isEmpty && email != null && email.isNotEmpty) {
        
        final allOrders = await _wooCommerceService.getOrders(
          page: page,
          perPage: 100,
        );

        orders = allOrders
            .cast<Map<String, dynamic>>()
            .where((order) {
              final billing = order['billing'] as Map<String, dynamic>?;
              final orderEmail = billing?['email']?.toString().toLowerCase();
              return orderEmail == email.toLowerCase();
            })
            .toList();

      }

      return orders;
    } catch (e) {
      throw Exception('Failed to fetch orders: $e');
    }
  }

  Future<Map<String, dynamic>> fetchOrderById(int orderId) async {
    try {
      final response = await _wooCommerceService.getOrderById(orderId);

      if (response is Map<String, dynamic>) {
        return response;
      }

      throw Exception('Invalid order data');
    } catch (e) {
      throw Exception('Failed to fetch order: $e');
    }
  }

  Future<Map<String, dynamic>> updateOrderStatus(
    int orderId,
    String status,
  ) async {
    try {
      final response = await _wooCommerceService.updateOrder(
        orderId,
        {'status': status},
      );

      if (response is Map<String, dynamic>) {
        return response;
      }

      throw Exception('Invalid response');
    } catch (e) {
      throw Exception('Failed to update order: $e');
    }
  }

  Future<Map<String, dynamic>> markOrderAsPaid(int orderId) async {
    try {
      final response = await _wooCommerceService.updateOrder(
        orderId,
        {
          'set_paid': true,
          'status': 'processing',
        },
      );

      if (response is Map<String, dynamic>) {
        return response;
      }

      throw Exception('Invalid response');
    } catch (e) {
      throw Exception('Failed to mark order as paid: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchOrdersByStatus(String status) async {
    return fetchOrders(status: status, perPage: 50);
  }
  
  Future<List<Map<String, dynamic>>> fetchPendingOrders() async {
    return fetchOrdersByStatus('pending');
  }

  Future<List<Map<String, dynamic>>> fetchProcessingOrders() async {
    return fetchOrdersByStatus('processing');
  }

  Future<List<Map<String, dynamic>>> fetchCompletedOrders() async {
    return fetchOrdersByStatus('completed');
  }
}

final orderRepository = OrderRepository();