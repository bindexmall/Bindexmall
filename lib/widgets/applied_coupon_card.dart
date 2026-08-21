// ============================================================================
// WIDGET: AppliedCouponCard
// ============================================================================
// Kartu kecil yang menampilkan kupon yang sedang aktif diterapkan di cart/checkout
// + tombol hapus kupon.
// ============================================================================

import 'package:flutter/material.dart';
import '../models/coupon.dart';
import '../utils/currency_formatter.dart';

class AppliedCouponCard extends StatelessWidget {
  final Coupon coupon;
  final double discount;
  final VoidCallback? onRemove;

  const AppliedCouponCard({
    super.key,
    required this.coupon,
    required this.discount,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange[50]!,
            Colors.orange[100]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_offer,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voucher Diterapkan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      coupon.code,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Colors.orange[900],
                  ),
                  onPressed: onRemove,
                  tooltip: 'Hapus voucher',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anda Hemat',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(discount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    coupon.discountText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (coupon.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              coupon.description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
      ),
    );
  }
}