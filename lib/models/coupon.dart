// ============================================================================
// MODEL: Coupon / CouponValidationResult
// ============================================================================
// Data kupon/voucher diskon dari WooCommerce beserta hasil validasinya
// (apakah kupon valid untuk cart saat ini, jumlah diskon, alasan gagal, dll).
//
// Isi/tanggung jawab utama:
//  - Dipakai oleh CouponProvider, voucher_dialog.dart, applied_coupon_card.dart.
// ============================================================================

class Coupon {
  final int id;
  final String code;
  final String discountType; // 'percent' or 'fixed_cart'
  final String amount;
  final String description;
  final DateTime? dateExpires;
  final int usageCount;
  final bool individualUse;
  final List<int> productIds;
  final List<int> excludedProductIds;
  final List<int> productCategories;
  final List<int> excludedProductCategories;
  final int usageLimit;
  final int usageLimitPerUser;
  final String minimumAmount;
  final String maximumAmount;
  final bool freeShipping;
  final bool excludeSaleItems;
  final int? limitUsageToXItems; // Limit to X quantity of items
  final List<String> emailRestrictions;

  Coupon({
    required this.id,
    required this.code,
    required this.discountType,
    required this.amount,
    this.description = '',
    this.dateExpires,
    this.usageCount = 0,
    this.individualUse = false,
    this.productIds = const [],
    this.excludedProductIds = const [],
    this.productCategories = const [],
    this.excludedProductCategories = const [],
    this.usageLimit = 0,
    this.usageLimitPerUser = 0,
    this.minimumAmount = '0',
    this.maximumAmount = '0',
    this.freeShipping = false,
    this.excludeSaleItems = false,
    this.limitUsageToXItems,
    this.emailRestrictions = const [],
  });

  // Factory constructor from JSON
  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      discountType: json['discount_type'] ?? 'percent',
      amount: json['amount'] ?? '0',
      description: json['description'] ?? '',
      dateExpires: json['date_expires'] != null 
          ? DateTime.parse(json['date_expires'])
          : null,
      usageCount: json['usage_count'] ?? 0,
      individualUse: json['individual_use'] ?? false,
      productIds: (json['product_ids'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList() ?? [],
      excludedProductIds: (json['excluded_product_ids'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList() ?? [],
      productCategories: (json['product_categories'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList() ?? [],
      excludedProductCategories: (json['excluded_product_categories'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList() ?? [],
      usageLimit: json['usage_limit'] ?? 0,
      usageLimitPerUser: json['usage_limit_per_user'] ?? 0,
      minimumAmount: json['minimum_amount'] ?? '0',
      maximumAmount: json['maximum_amount'] ?? '0',
      freeShipping: json['free_shipping'] ?? false,
      excludeSaleItems: json['exclude_sale_items'] ?? false,
      limitUsageToXItems: json['limit_usage_to_x_items'] != null 
          ? (json['limit_usage_to_x_items'] is int 
              ? json['limit_usage_to_x_items'] 
              : int.tryParse(json['limit_usage_to_x_items'].toString()))
          : null,
      emailRestrictions: (json['email_restrictions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'discount_type': discountType,
      'amount': amount,
      'description': description,
      'date_expires': dateExpires?.toIso8601String(),
      'usage_count': usageCount,
      'individual_use': individualUse,
      'product_ids': productIds,
      'excluded_product_ids': excludedProductIds,
      'product_categories': productCategories,
      'excluded_product_categories': excludedProductCategories,
      'usage_limit': usageLimit,
      'usage_limit_per_user': usageLimitPerUser,
      'minimum_amount': minimumAmount,
      'maximum_amount': maximumAmount,
      'free_shipping': freeShipping,
      'exclude_sale_items': excludeSaleItems,
      'limit_usage_to_x_items': limitUsageToXItems,
      'email_restrictions': emailRestrictions,
    };
  }

  // Check if coupon is expired
  bool get isExpired {
    if (dateExpires == null) return false;
    return DateTime.now().isAfter(dateExpires!);
  }

  // Check if coupon has reached usage limit
  bool get isUsageLimitReached {
    if (usageLimit == 0) return false;
    return usageCount >= usageLimit;
  }

  // Check if coupon is valid
  bool get isValid {
    return !isExpired && !isUsageLimitReached;
  }

  // Get discount percentage (if percent type)
  double get discountPercentage {
    if (discountType == 'percent') {
      return double.tryParse(amount) ?? 0.0;
    }
    return 0.0;
  }

  // Get fixed discount amount (if fixed_cart type)
  double get fixedDiscountAmount {
    if (discountType == 'fixed_cart') {
      return double.tryParse(amount) ?? 0.0;
    }
    return 0.0;
  }

  // Validate coupon against cart
  CouponValidationResult validateForCart({
    required double subtotal,
    required int totalQuantity,
    List<int>? productIds,
    List<int>? categoryIds,
    bool hasSaleItems = false,
  }) {
    // Check if expired
    if (isExpired) {
      return CouponValidationResult(
        isValid: false,
        reason: 'Kupon sudah kadaluarsa',
      );
    }

    // Check usage limit
    if (isUsageLimitReached) {
      return CouponValidationResult(
        isValid: false,
        reason: 'Kupon sudah mencapai batas penggunaan',
      );
    }

    // Check minimum amount
    final minAmount = double.tryParse(minimumAmount) ?? 0.0;
    if (minAmount > 0 && subtotal < minAmount) {
      return CouponValidationResult(
        isValid: false,
        reason: 'Minimum pembelanjaan Rp ${minAmount.toStringAsFixed(0)}',
      );
    }

    // Check maximum amount
    final maxAmount = double.tryParse(maximumAmount) ?? 0.0;
    if (maxAmount > 0 && subtotal > maxAmount) {
      return CouponValidationResult(
        isValid: false,
        reason: 'Maksimum pembelanjaan Rp ${maxAmount.toStringAsFixed(0)}',
      );
    }

    // Check quantity limit (minimum quantity of items)
    if (limitUsageToXItems != null && limitUsageToXItems! > 0) {
      if (totalQuantity < limitUsageToXItems!) {
        return CouponValidationResult(
          isValid: false,
          reason: 'Minimum $limitUsageToXItems produk untuk menggunakan kupon ini',
        );
      }
    }

    // Check exclude sale items
    if (excludeSaleItems && hasSaleItems) {
      return CouponValidationResult(
        isValid: false,
        reason: 'Kupon tidak berlaku untuk produk diskon',
      );
    }

    // Check specific products allowed
    if (productIds != null && this.productIds.isNotEmpty) {
      final hasAllowedProduct = productIds.any(
        (id) => this.productIds.contains(id)
      );
      if (!hasAllowedProduct) {
        return CouponValidationResult(
          isValid: false,
          reason: 'Kupon hanya berlaku untuk produk tertentu',
        );
      }
    }

    // Check excluded products
    if (productIds != null && excludedProductIds.isNotEmpty) {
      final hasExcludedProduct = productIds.any(
        (id) => excludedProductIds.contains(id)
      );
      if (hasExcludedProduct) {
        return CouponValidationResult(
          isValid: false,
          reason: 'Kupon tidak berlaku untuk beberapa produk di keranjang',
        );
      }
    }

    // Check specific categories allowed
    if (categoryIds != null && productCategories.isNotEmpty) {
      final hasAllowedCategory = categoryIds.any(
        (id) => productCategories.contains(id)
      );
      if (!hasAllowedCategory) {
        return CouponValidationResult(
          isValid: false,
          reason: 'Kupon hanya berlaku untuk kategori tertentu',
        );
      }
    }

    // Check excluded categories
    if (categoryIds != null && excludedProductCategories.isNotEmpty) {
      final hasExcludedCategory = categoryIds.any(
        (id) => excludedProductCategories.contains(id)
      );
      if (hasExcludedCategory) {
        return CouponValidationResult(
          isValid: false,
          reason: 'Kupon tidak berlaku untuk beberapa kategori di keranjang',
        );
      }
    }

    return CouponValidationResult(isValid: true);
  }

  // Calculate discount for given subtotal
  double calculateDiscount(double subtotal) {
    // Check minimum amount
    final minAmount = double.tryParse(minimumAmount) ?? 0.0;
    if (subtotal < minAmount) return 0.0;

    double discount = 0.0;

    if (discountType == 'percent') {
      discount = subtotal * (discountPercentage / 100);
    } else if (discountType == 'fixed_cart') {
      discount = fixedDiscountAmount;
    }

    // Check maximum amount
    final maxAmount = double.tryParse(maximumAmount) ?? 0.0;
    if (maxAmount > 0 && discount > maxAmount) {
      discount = maxAmount;
    }

    // Discount can't be more than subtotal
    if (discount > subtotal) {
      discount = subtotal;
    }

    return discount;
  }

  // Get formatted discount text
  String get discountText {
    if (discountType == 'percent') {
      return '$amount%';
    } else if (discountType == 'fixed_cart') {
      return 'Rp ${amount.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    }
    return amount;
  }

  // Get formatted expiry date
  String get expiryText {
    if (dateExpires == null) return 'Tidak ada batas waktu';
    
    final now = DateTime.now();
    final difference = dateExpires!.difference(now);
    
    if (difference.isNegative) return 'Sudah kadaluarsa';
    
    if (difference.inDays > 0) {
      return 'Berlaku ${difference.inDays} hari lagi';
    } else if (difference.inHours > 0) {
      return 'Berlaku ${difference.inHours} jam lagi';
    } else {
      return 'Berlaku ${difference.inMinutes} menit lagi';
    }
  }

  // Copy with method
  Coupon copyWith({
    int? id,
    String? code,
    String? discountType,
    String? amount,
    String? description,
    DateTime? dateExpires,
    int? usageCount,
    bool? individualUse,
    List<int>? productIds,
    List<int>? excludedProductIds,
    List<int>? productCategories,
    List<int>? excludedProductCategories,
    int? usageLimit,
    int? usageLimitPerUser,
    String? minimumAmount,
    String? maximumAmount,
    bool? freeShipping,
    bool? excludeSaleItems,
    int? limitUsageToXItems,
    List<String>? emailRestrictions,
  }) {
    return Coupon(
      id: id ?? this.id,
      code: code ?? this.code,
      discountType: discountType ?? this.discountType,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      dateExpires: dateExpires ?? this.dateExpires,
      usageCount: usageCount ?? this.usageCount,
      individualUse: individualUse ?? this.individualUse,
      productIds: productIds ?? this.productIds,
      excludedProductIds: excludedProductIds ?? this.excludedProductIds,
      productCategories: productCategories ?? this.productCategories,
      excludedProductCategories: excludedProductCategories ?? this.excludedProductCategories,
      usageLimit: usageLimit ?? this.usageLimit,
      usageLimitPerUser: usageLimitPerUser ?? this.usageLimitPerUser,
      minimumAmount: minimumAmount ?? this.minimumAmount,
      maximumAmount: maximumAmount ?? this.maximumAmount,
      freeShipping: freeShipping ?? this.freeShipping,
      excludeSaleItems: excludeSaleItems ?? this.excludeSaleItems,
      limitUsageToXItems: limitUsageToXItems ?? this.limitUsageToXItems,
      emailRestrictions: emailRestrictions ?? this.emailRestrictions,
    );
  }

  @override
  String toString() {
    return 'Coupon(id: $id, code: $code, type: $discountType, amount: $amount)';
  }
}

// Validation result class
class CouponValidationResult {
  final bool isValid;
  final String? reason;

  CouponValidationResult({
    required this.isValid,
    this.reason,
  });
}