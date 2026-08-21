// ============================================================================
// SERVICE: WooCommerceService
// ============================================================================
// Client HTTP inti untuk semua komunikasi ke WooCommerce REST API (wc/v3) —
// produk, kategori, pesanan. Ini SERVICE PALING SENTRAL di app; hampir semua
// repository bergantung pada service ini.
//
// Isi/tanggung jawab utama:
//  - consumerKey & consumerSecret sekarang diambil dari config/secrets.dart
//    (file itu di-gitignore, ga ikut commit). TAPI ini baru nyelesain masalah
//    "bocor lewat git" — APK yang sudah di-build TETAP bisa di-decompile dan
//    key ini tetap kebaca di situ. consumerSecret bisa dipakai baca-tulis
//    data toko lewat REST API, jadi idealnya di masa depan endpoint yang
//    butuh write access dipindah ke proxy backend, bukan dipanggil langsung
//    dari app. Lihat catatan tingkat risiko di config/secrets.dart.
//  - get/post/put adalah method HTTP generik — dipakai semua method spesifik di bawahnya
//    (getProducts, createOrder, dst). Kalau nambah endpoint WooCommerce baru, pakai
//    method generik ini, jangan bikin instance Dio baru.
//  - baseUrl: https://bindexmall.com (domain toko WordPress + WooCommerce).
// ============================================================================

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../config/secrets.dart';

class WooCommerceService {
  static const String baseUrl = 'https://bindexmall.com';
  static const String consumerKey = Secrets.wooCommerceConsumerKey;
  static const String consumerSecret = Secrets.wooCommerceConsumerSecret;
  static const String apiVersion = 'wc/v3';

  late final Dio _dio;

  WooCommerceService() {
    _dio = Dio(BaseOptions(
      baseUrl: '$baseUrl/wp-json/$apiVersion/',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) {
        return host == 'bindexmall.com';
      };
      return client;
    };
  }

  Map<String, dynamic> _buildAuthParams([Map<String, dynamic>? extra]) {
    return {
      'consumer_key': consumerKey,
      'consumer_secret': consumerSecret,
      ...?extra,
    };
  }

  Future<dynamic> get(String endpoint, {Map<String, dynamic>? params}) async {
    try {
      final queryParams = _buildAuthParams(params);
      final response = await _dio.get(endpoint, queryParameters: queryParams);
      return response.data;
    } on DioException catch (e) {
      throw Exception('API Error: ${e.message}');
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      if (data.containsKey('customer_id')) {
        final customerId = data['customer_id'];
        if (customerId != null) {
          if (customerId is String) {
            data['customer_id'] = int.parse(customerId);
          } else if (customerId is! int) {
            throw Exception(
                'customer_id must be int, got ${customerId.runtimeType}');
          }
          if (data['customer_id'] == 0) {
            data.remove('customer_id');
          }
        }
      }

      final queryParams = _buildAuthParams();
      final response = await _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParams,
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {}
      throw Exception('API Error: ${e.message}');
    }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final queryParams = _buildAuthParams();
      final response = await _dio.put(
        endpoint,
        data: data,
        queryParameters: queryParams,
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception('API Error: ${e.message}');
    }
  }

  Future<List<dynamic>> getProducts({
    int page = 1,
    int perPage = 20,
    String? category,
    String? search,
    String? orderBy,
    String? order,
    bool? onSale,
    String? slug,
    String? tag,
    String status = 'publish', // ✅ default hanya produk published
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      'status': status, // ✅ filter status
    };

    if (category != null) params['category'] = category;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (orderBy != null) params['orderby'] = orderBy;
    if (order != null) params['order'] = order;
    if (onSale != null && onSale) params['on_sale'] = 'true';
    if (slug != null && slug.isNotEmpty) params['slug'] = slug;
    if (tag != null && tag.isNotEmpty) params['tag'] = tag;

    final result = await get('products', params: params);
    return result is List ? result : [];
  }

  Future<dynamic> getProduct(int productId) async {
    return await get('products/$productId');
  }

  Future<dynamic> getProductById(int productId) async {
    return await getProduct(productId);
  }

  Future<List<dynamic>> getProductsByCategory(int categoryId,
      {int page = 1, int perPage = 20}) async {
    return await getProducts(
      page: page,
      perPage: perPage,
      category: categoryId.toString(),
    );
  }

  Future<List<dynamic>> getCategories({
    int page = 1,
    int perPage = 100,
    int? parent,
  }) async {
    final params = {
      'page': page.toString(),
      'per_page': perPage.toString(),
      'hide_empty': 'true',
    };

    if (parent != null) {
      params['parent'] = parent.toString();
    }

    final result = await get('products/categories', params: params);
    return result is List ? result : [];
  }

  Future<int?> getProductTagIdBySlug(String slug) async {
    try {
      final result =
          await get('products/tags', params: {'slug': slug, 'per_page': '1'});
      if (result is List && result.isNotEmpty) {
        return result.first['id'] as int?;
      }
      return null;
    } on Exception {
      return null;
    }
  }

  Future<dynamic> getCategory(int categoryId) async {
    return await get('products/categories/$categoryId');
  }

  Future<dynamic> getCategoryById(int categoryId) async {
    return await getCategory(categoryId);
  }

  Future<List<dynamic>> getOrders({
    int page = 1,
    int perPage = 10,
    String? status,
    int? customer,
  }) async {
    final params = {
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (status != null) params['status'] = status;
    if (customer != null) params['customer'] = customer.toString();

    final result = await get('orders', params: params);
    return result is List ? result : [];
  }

  Future<dynamic> createOrder(Map<String, dynamic> orderData) async {
    return await post('orders', orderData);
  }

  Future<dynamic> createOrderWithDropshipper({
    required Map<String, dynamic> orderData,
    required bool isDropshipper,
    String? dropshipperName,
    String? dropshipperPhone,
    String? receiptUrl,
  }) async {
    if (isDropshipper) {
      final metaData = orderData['meta_data'] as List? ?? [];
      metaData.addAll([
        {'key': '_is_dropshipper', 'value': 'yes'},
        if (dropshipperName != null && dropshipperName.isNotEmpty)
          {'key': '_dropshipper_name', 'value': dropshipperName},
        if (dropshipperPhone != null && dropshipperPhone.isNotEmpty)
          {'key': '_dropshipper_phone', 'value': dropshipperPhone},
        if (receiptUrl != null && receiptUrl.isNotEmpty)
          {'key': '_receipt_url', 'value': receiptUrl},
        {
          'key': '_dropshipper_submitted_at',
          'value': DateTime.now().toIso8601String()
        },
      ]);
      orderData['meta_data'] = metaData;
    }
    return await createOrder(orderData);
  }

  Future<dynamic> getOrder(int orderId) async {
    return await get('orders/$orderId');
  }

  Future<dynamic> getOrderById(int orderId) async {
    return await getOrder(orderId);
  }

  Future<List<dynamic>> getCustomerOrders(int customerId,
      {int page = 1, int perPage = 10}) async {
    final params = {
      'customer': customerId.toString(),
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    final result = await get('orders', params: params);
    return result is List ? result : [];
  }

  Future<dynamic> updateOrderStatus(int orderId, String status) async {
    return await put('orders/$orderId', {'status': status});
  }

  Future<dynamic> updateOrder(int orderId, Map<String, dynamic> data) async {
    return await put('orders/$orderId', data);
  }

  Future<bool> updateOrderMetaData({
    required int orderId,
    required Map<String, String> metaData,
  }) async {
    try {
      final metaDataList = metaData.entries
          .map((entry) => {'key': entry.key, 'value': entry.value})
          .toList();
      await put('orders/$orderId', {'meta_data': metaDataList});
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addOrderNote({
    required int orderId,
    required String note,
    bool isCustomerNote = false,
  }) async {
    try {
      await post('orders/$orderId/notes', {
        'note': note,
        'customer_note': isCustomerNote,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<dynamic> createCustomer(Map<String, dynamic> customerData) async {
    return await post('customers', customerData);
  }

  Future<dynamic> getCustomer(int customerId) async {
    return await get('customers/$customerId');
  }

  Future<List<dynamic>> getCustomerByEmail(String email) async {
    final params = {'email': email};
    final result = await get('customers', params: params);
    return result is List ? result : [];
  }

  Future<dynamic> updateCustomer(
      int customerId, Map<String, dynamic> data) async {
    return await put('customers/$customerId', data);
  }

  Future<List<dynamic>> getPaymentGateways() async {
    final result = await get('payment_gateways');
    return result is List ? result : [];
  }

  Future<List<dynamic>> getShippingZones() async {
    final result = await get('shipping/zones');
    return result is List ? result : [];
  }

  Future<List<dynamic>> getShippingMethods(int zoneId) async {
    final result = await get('shipping/zones/$zoneId/methods');
    return result is List ? result : [];
  }

  Future<List<dynamic>> getCoupons({
    int page = 1,
    int perPage = 20,
    String? code,
  }) async {
    final params = {
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (code != null && code.isNotEmpty) {
      params['code'] = code;
    }

    final result = await get('coupons', params: params);
    return result is List ? result : [];
  }

  Future<dynamic> getCoupon(int couponId) async {
    return await get('coupons/$couponId');
  }

  Future<List<dynamic>> getCouponByCode(String code) async {
    final params = {'code': code};
    final result = await get('coupons', params: params);
    return result is List ? result : [];
  }

  Future<List<dynamic>> getProductReviews({
    required int productId,
    int page = 1,
    int perPage = 20,
    String? orderBy,
    String? order,
  }) async {
    final params = {
      'product': productId.toString(),
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (orderBy != null) params['orderby'] = orderBy;
    if (order != null) params['order'] = order;

    final result = await get('products/reviews', params: params);
    return result is List ? result : [];
  }

  Future<List<dynamic>> getReviews({
    int page = 1,
    int perPage = 20,
    String? status,
    int? reviewer,
  }) async {
    final params = {
      'page': page.toString(),
      'per_page': perPage.toString(),
    };

    if (status != null) params['status'] = status;
    if (reviewer != null) params['reviewer'] = reviewer.toString();

    final result = await get('products/reviews', params: params);
    return result is List ? result : [];
  }

  Future<dynamic> createReview({
    required int productId,
    required String review,
    required String reviewerName,
    required String reviewerEmail,
    required int rating,
  }) async {
    final data = {
      'product_id': productId,
      'review': review,
      'reviewer': reviewerName,
      'reviewer_email': reviewerEmail,
      'rating': rating,
    };
    return await post('products/reviews', data);
  }

  Future<dynamic> updateReview({
    required int reviewId,
    String? review,
    int? rating,
    String? status,
  }) async {
    final data = <String, dynamic>{};
    if (review != null) data['review'] = review;
    if (rating != null) data['rating'] = rating;
    if (status != null) data['status'] = status;
    return await put('products/reviews/$reviewId', data);
  }

  Future<dynamic> deleteReview(int reviewId) async {
    try {
      final queryParams = _buildAuthParams({'force': 'true'});
      final response = await _dio.delete(
        'products/reviews/$reviewId',
        queryParameters: queryParams,
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception('API Error: ${e.message}');
    }
  }

  Future<dynamic> getReview(int reviewId) async {
    return await get('products/reviews/$reviewId');
  }

  Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required double subtotal,
    List<int>? productIds,
  }) async {
    try {
      final coupons = await getCouponByCode(code);

      if (coupons.isEmpty) {
        throw Exception('Kupon tidak ditemukan');
      }

      final couponData = coupons.first as Map<String, dynamic>;

      if (couponData['date_expires'] != null) {
        final expiryDate = DateTime.parse(couponData['date_expires']);
        if (DateTime.now().isAfter(expiryDate)) {
          throw Exception('Kupon sudah kadaluarsa');
        }
      }

      final usageLimit = couponData['usage_limit'] ?? 0;
      final usageCount = couponData['usage_count'] ?? 0;
      if (usageLimit > 0 && usageCount >= usageLimit) {
        throw Exception('Kupon sudah mencapai batas penggunaan');
      }

      final minimumAmount =
          double.tryParse(couponData['minimum_amount'] ?? '0') ?? 0.0;
      if (subtotal < minimumAmount) {
        throw Exception(
            'Minimum pembelian Rp ${minimumAmount.toStringAsFixed(0)} untuk menggunakan kupon ini');
      }

      final allowedProducts =
          (couponData['product_ids'] as List<dynamic>?)?.cast<int>() ?? [];
      final excludedProducts =
          (couponData['excluded_product_ids'] as List<dynamic>?)?.cast<int>() ??
              [];

      if (allowedProducts.isNotEmpty && productIds != null) {
        final hasAllowedProduct =
            productIds.any((id) => allowedProducts.contains(id));
        if (!hasAllowedProduct) {
          throw Exception('Kupon tidak berlaku untuk produk yang dipilih');
        }
      }

      if (excludedProducts.isNotEmpty && productIds != null) {
        final hasExcludedProduct =
            productIds.any((id) => excludedProducts.contains(id));
        if (hasExcludedProduct) {
          throw Exception(
              'Kupon tidak berlaku untuk beberapa produk di keranjang');
        }
      }

      return couponData;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}

final wooCommerceService = WooCommerceService();
