// ============================================================================
// PROVIDER: CouponProvider (ChangeNotifier) / CouponWithDiscount
// ============================================================================
// State management kupon/voucher: validasi kupon terhadap isi cart,
// hitung besaran diskon, dan list kupon yang applicable untuk cart user saat ini.
//
// Isi/tanggung jawab utama:
//  - CouponWithDiscount: helper class hasil validasi (kupon + nominal diskon terhitung).
//  - getApplicableCoupons() dipakai di voucher_dialog.dart untuk menampilkan pilihan kupon.
// ============================================================================

import 'package:flutter/foundation.dart';
import '../models/coupon.dart';
import '../services/woocommerce_service.dart';

class CouponProvider extends ChangeNotifier {
  final WooCommerceService _wooCommerceService = wooCommerceService;
  
  List<Coupon> _availableCoupons = [];
  Coupon? _appliedCoupon;
  bool _isLoading = false;
  String? _error;

  List<Coupon> get availableCoupons => _availableCoupons;
  Coupon? get appliedCoupon => _appliedCoupon;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCoupon => _appliedCoupon != null;

  // Load available coupons from WooCommerce
  Future<void> loadCoupons() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _wooCommerceService.getCoupons(perPage: 100);
      
      _availableCoupons = response
          .map((json) => Coupon.fromJson(json as Map<String, dynamic>))
          .where((coupon) => coupon.isValid) // Only show valid coupons
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Gagal memuat kupon: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading coupons: $e');
    }
  }

  // Apply coupon by code
  Future<void> applyCoupon({
    required String code,
    required double subtotal,
    required int totalQuantity,
    List<int>? productIds,
    List<int>? categoryIds,
    bool hasSaleItems = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get coupon by code from WooCommerce
      final coupons = await _wooCommerceService.getCouponByCode(code);
      
      if (coupons.isEmpty) {
        throw Exception('Kupon tidak ditemukan');
      }

      final couponData = coupons.first as Map<String, dynamic>;
      final coupon = Coupon.fromJson(couponData);

      // Validate coupon
      final validation = coupon.validateForCart(
        subtotal: subtotal,
        totalQuantity: totalQuantity,
        productIds: productIds,
        categoryIds: categoryIds,
        hasSaleItems: hasSaleItems,
      );

      if (!validation.isValid) {
        throw Exception(validation.reason ?? 'Kupon tidak valid');
      }

      _appliedCoupon = coupon;
      _isLoading = false;
      notifyListeners();
      
      debugPrint('✅ Coupon applied: ${_appliedCoupon!.code}');
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      _appliedCoupon = null;
      notifyListeners();
      debugPrint('❌ Error applying coupon: $e');
      rethrow;
    }
  }

  // Apply coupon directly (from selection)
  void applyCouponDirect(Coupon coupon) {
    _appliedCoupon = coupon;
    _error = null;
    notifyListeners();
    debugPrint('✅ Coupon applied: ${coupon.code}');
  }

  // Remove applied coupon
  void removeCoupon() {
    _appliedCoupon = null;
    _error = null;
    notifyListeners();
    debugPrint('🗑️ Coupon removed');
  }

  // Calculate discount for current cart
  double calculateDiscount(double subtotal) {
    if (_appliedCoupon == null) return 0.0;
    return _appliedCoupon!.calculateDiscount(subtotal);
  }

  // Get total after discount
  double getTotalWithDiscount(double subtotal) {
    final discount = calculateDiscount(subtotal);
    return subtotal - discount;
  }

  // Check if coupon can be applied to cart
  bool canApplyCoupon(
    Coupon coupon, {
    required double subtotal,
    required int totalQuantity,
    List<int>? productIds,
    List<int>? categoryIds,
    bool hasSaleItems = false,
  }) {
    final validation = coupon.validateForCart(
      subtotal: subtotal,
      totalQuantity: totalQuantity,
      productIds: productIds,
      categoryIds: categoryIds,
      hasSaleItems: hasSaleItems,
    );
    
    return validation.isValid;
  }

  // Get validation reason for a coupon
  String? getCouponValidationReason(
    Coupon coupon, {
    required double subtotal,
    required int totalQuantity,
    List<int>? productIds,
    List<int>? categoryIds,
    bool hasSaleItems = false,
  }) {
    final validation = coupon.validateForCart(
      subtotal: subtotal,
      totalQuantity: totalQuantity,
      productIds: productIds,
      categoryIds: categoryIds,
      hasSaleItems: hasSaleItems,
    );
    
    return validation.reason;
  }

  // Get applicable coupons for current cart (sorted by discount amount)
  List<CouponWithDiscount> getApplicableCoupons({
    required double subtotal,
    required int totalQuantity,
    List<int>? productIds,
    List<int>? categoryIds,
    bool hasSaleItems = false,
  }) {
    final applicable = <CouponWithDiscount>[];
    final notApplicable = <CouponWithDiscount>[];

    for (final coupon in _availableCoupons) {
      final validation = coupon.validateForCart(
        subtotal: subtotal,
        totalQuantity: totalQuantity,
        productIds: productIds,
        categoryIds: categoryIds,
        hasSaleItems: hasSaleItems,
      );

      final discount = validation.isValid 
          ? coupon.calculateDiscount(subtotal)
          : 0.0;

      final couponWithDiscount = CouponWithDiscount(
        coupon: coupon,
        discount: discount,
        isApplicable: validation.isValid,
        reason: validation.reason,
      );

      if (validation.isValid) {
        applicable.add(couponWithDiscount);
      } else {
        notApplicable.add(couponWithDiscount);
      }
    }

    // Sort applicable coupons by discount amount (highest first)
    applicable.sort((a, b) => b.discount.compareTo(a.discount));
    
    // Sort not applicable coupons by potential discount (if they were applicable)
    notApplicable.sort((a, b) {
      final aDiscount = a.coupon.discountType == 'percent' 
          ? a.coupon.discountPercentage 
          : a.coupon.fixedDiscountAmount;
      final bDiscount = b.coupon.discountType == 'percent' 
          ? b.coupon.discountPercentage 
          : b.coupon.fixedDiscountAmount;
      return bDiscount.compareTo(aDiscount);
    });

    // Return applicable first, then not applicable
    return [...applicable, ...notApplicable];
  }

  // Clear all
  void clear() {
    _appliedCoupon = null;
    _availableCoupons = [];
    _error = null;
    notifyListeners();
  }

  // Refresh coupons
  Future<void> refresh() async {
    await loadCoupons();
  }
}

// Helper class to store coupon with its discount
class CouponWithDiscount {
  final Coupon coupon;
  final double discount;
  final bool isApplicable;
  final String? reason;

  CouponWithDiscount({
    required this.coupon,
    required this.discount,
    required this.isApplicable,
    this.reason,
  });
}