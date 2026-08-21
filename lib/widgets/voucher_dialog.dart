// ============================================================================
// WIDGET: VoucherDialog
// ============================================================================
// Dialog pilih/terapkan kupon voucher saat di CartScreen/CheckoutScreen,
// menampilkan daftar kupon yang applicable dari CouponProvider.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/coupon.dart';
import '../providers/coupon_provider.dart';
import '../providers/cart_provider.dart';
import '../utils/currency_formatter.dart';

class VoucherDialog extends StatefulWidget {
  const VoucherDialog({super.key});

  @override
  State<VoucherDialog> createState() => _VoucherDialogState();
}

class _VoucherDialogState extends State<VoucherDialog> {
  final _codeController = TextEditingController();
  bool _isManualEntry = false;

  @override
  void initState() {
    super.initState();
    // Load coupons when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final couponProvider = Provider.of<CouponProvider>(context, listen: false);
      if (couponProvider.availableCoupons.isEmpty) {
        couponProvider.loadCoupons();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final couponProvider = Provider.of<CouponProvider>(context);
    
    final subtotal = cartProvider.total;
    final totalQuantity = cartProvider.totalQuantity;
    final productIds = cartProvider.items
        .map((item) => int.tryParse(item.product.id) ?? 0)
        .where((id) => id > 0)
        .toList();

    // Get category IDs from cart items
    final categoryIds = cartProvider.items
        .expand((item) => item.product.categoryIds)
        .toSet()
        .toList();

    // Check if any item is on sale
    final hasSaleItems = cartProvider.items.any((item) => item.product.onSale);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(context, couponProvider),
            
            const Divider(height: 1),

            // Cart Summary
            _buildCartSummary(subtotal, totalQuantity),

            // Manual Entry Section (optional)
            if (_isManualEntry)
              _buildManualEntry(
                context,
                couponProvider,
                subtotal,
                totalQuantity,
                productIds,
                categoryIds,
                hasSaleItems,
              ),

            // Coupon List
            Expanded(
              child: couponProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildCouponList(
                      context,
                      couponProvider,
                      subtotal,
                      totalQuantity,
                      productIds,
                      categoryIds,
                      hasSaleItems,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CouponProvider couponProvider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const Icon(Icons.local_offer, color: Colors.orange, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Pilih Voucher',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(_isManualEntry ? Icons.list : Icons.edit),
            tooltip: _isManualEntry ? 'Lihat Daftar' : 'Masukkan Kode',
            onPressed: () {
              setState(() {
                _isManualEntry = !_isManualEntry;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary(double subtotal, int totalQuantity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.blue[50],
      child: Row(
        children: [
          Icon(Icons.shopping_cart, size: 20, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Total: ${CurrencyFormatter.format(subtotal)} • $totalQuantity item${totalQuantity > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.blue[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntry(
    BuildContext context,
    CouponProvider couponProvider,
    double subtotal,
    int totalQuantity,
    List<int> productIds,
    List<int> categoryIds,
    bool hasSaleItems,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Masukkan Kode Voucher',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: DISKON50',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (value) => _applyManualCoupon(
                    context,
                    couponProvider,
                    subtotal,
                    totalQuantity,
                    productIds,
                    categoryIds,
                    hasSaleItems,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _applyManualCoupon(
                  context,
                  couponProvider,
                  subtotal,
                  totalQuantity,
                  productIds,
                  categoryIds,
                  hasSaleItems,
                ),
                child: const Text('Pakai'),
              ),
            ],
          ),
          if (couponProvider.error != null) ...[
            const SizedBox(height: 8),
            Text(
              couponProvider.error!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCouponList(
    BuildContext context,
    CouponProvider couponProvider,
    double subtotal,
    int totalQuantity,
    List<int> productIds,
    List<int> categoryIds,
    bool hasSaleItems,
  ) {
    final couponsWithDiscount = couponProvider.getApplicableCoupons(
      subtotal: subtotal,
      totalQuantity: totalQuantity,
      productIds: productIds,
      categoryIds: categoryIds,
      hasSaleItems: hasSaleItems,
    );

    if (couponsWithDiscount.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada voucher tersedia',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Voucher akan muncul di sini ketika tersedia',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: couponsWithDiscount.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final couponWithDiscount = couponsWithDiscount[index];
        final coupon = couponWithDiscount.coupon;
        final discount = couponWithDiscount.discount;
        final isApplicable = couponWithDiscount.isApplicable;
        final reason = couponWithDiscount.reason;
        final isSelected = couponProvider.appliedCoupon?.id == coupon.id;

        return _buildCouponCard(
          context,
          coupon,
          discount,
          isSelected,
          isApplicable,
          reason,
          couponProvider,
        );
      },
    );
  }

  Widget _buildCouponCard(
    BuildContext context,
    Coupon coupon,
    double discount,
    bool isSelected,
    bool isApplicable,
    String? notApplicableReason,
    CouponProvider couponProvider,
  ) {
    // Colors based on state
    final borderColor = isSelected
        ? Colors.orange
        : isApplicable
            ? Colors.grey[300]!
            : Colors.grey[200]!;
    
    final backgroundColor = isSelected
        ? Colors.orange[50]
        : isApplicable
            ? Colors.white
            : Colors.grey[100];

    final stripColor = isApplicable 
        ? _getCouponColor(coupon)
        : Colors.grey[400]!;

    return Opacity(
      opacity: isApplicable ? 1.0 : 0.6,
      child: InkWell(
        onTap: isApplicable
            ? () {
                if (isSelected) {
                  couponProvider.removeCoupon();
                } else {
                  couponProvider.applyCouponDirect(coupon);
                }
                Navigator.pop(context);
              }
            : () {
                // Show reason why not applicable
                if (notApplicableReason != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(notApplicableReason),
                      backgroundColor: Colors.orange[700],
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1,
            ),
            color: backgroundColor,
          ),
          child: Row(
            children: [
              // Left colored strip
              Container(
                width: 8,
                height: 130,
                decoration: BoxDecoration(
                  color: stripColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              
              // Coupon content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Coupon code and status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              coupon.code,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: isApplicable ? Colors.black : Colors.grey[600],
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'DIPILIH',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else if (!isApplicable)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'TIDAK TERSEDIA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Discount info or reason
                      if (isApplicable) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.discount,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Hemat ${CurrencyFormatter.format(discount)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getCouponColor(coupon).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                coupon.discountText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _getCouponColor(coupon),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (notApplicableReason != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                notApplicableReason,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange[800],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      if (coupon.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          coupon.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isApplicable ? Colors.grey[600] : Colors.grey[500],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      
                      const SizedBox(height: 8),
                      
                      // Expiry date
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: isApplicable ? Colors.grey[500] : Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            coupon.expiryText,
                            style: TextStyle(
                              fontSize: 11,
                              color: isApplicable ? Colors.grey[600] : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Arrow or lock icon
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : isApplicable
                          ? Icons.arrow_forward_ios
                          : Icons.lock_outline,
                  color: isSelected
                      ? Colors.orange
                      : isApplicable
                          ? Colors.grey[400]
                          : Colors.grey[300],
                  size: isApplicable ? 20 : 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCouponColor(Coupon coupon) {
    if (coupon.discountType == 'percent') {
      return Colors.purple;
    } else if (coupon.freeShipping) {
      return Colors.blue;
    } else {
      return Colors.orange;
    }
  }

  void _applyManualCoupon(
    BuildContext context,
    CouponProvider couponProvider,
    double subtotal,
    int totalQuantity,
    List<int> productIds,
    List<int> categoryIds,
    bool hasSaleItems,
  ) async {
    final code = _codeController.text.trim().toUpperCase();
    
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan kode voucher')),
      );
      return;
    }

    try {
      await couponProvider.applyCoupon(
        code: code,
        subtotal: subtotal,
        totalQuantity: totalQuantity,
        productIds: productIds,
        categoryIds: categoryIds,
        hasSaleItems: hasSaleItems,
      );
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voucher $code berhasil diterapkan!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}