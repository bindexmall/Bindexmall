// ============================================================================
// WIDGET: OrderItemWithReview
// ============================================================================
// Baris item pesanan di dalam OrderDetailScreen yang sekaligus punya tombol/alur
// untuk memberi review produk (WriteReviewDialog) jika pesanan sudah selesai.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/review_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/write_review_dialog.dart';

/// Widget for displaying order items with review option for completed orders
class OrderItemWithReview extends StatefulWidget {
  final Map<String, dynamic> item;
  final int orderId;
  final String orderStatus;
  final Locale locale;

  const OrderItemWithReview({
    super.key,
    required this.item,
    required this.orderId,
    required this.orderStatus,
    required this.locale,
  });

  @override
  State<OrderItemWithReview> createState() => _OrderItemWithReviewState();
}

class _OrderItemWithReviewState extends State<OrderItemWithReview> {
  bool _hasReviewed = false;
  bool _checkingReview = true;

  @override
  void initState() {
    super.initState();
    _checkIfReviewed();
  }

  Future<void> _checkIfReviewed() async {
    final authProvider = context.read<AuthProvider>();
    final reviewProvider = context.read<ReviewProvider>();

    if (!authProvider.isAuthenticated) {
      setState(() {
        _checkingReview = false;
      });
      return;
    }

    try {
      final productId = widget.item['product_id'] as int?;
      if (productId == null) {
        setState(() {
          _checkingReview = false;
        });
        return;
      }

      final hasReviewed = await reviewProvider.hasUserReviewedProduct(
        productId: productId,
        userEmail: authProvider.userEmail ?? '',
      );

      setState(() {
        _hasReviewed = hasReviewed;
        _checkingReview = false;
      });
    } catch (e) {
      debugPrint('Error checking review status: $e');
      setState(() {
        _checkingReview = false;
      });
    }
  }

  Future<void> _showReviewDialog() async {
    final productId = widget.item['product_id'] as int?;
    if (productId == null) return;

    final result = await showWriteReviewDialog(
      context: context,
      productId: productId,
      productName: widget.item['name'] ?? 'Product',
      productImageUrl: widget.item['image']?['src'],
      orderId: widget.orderId,
    );

    if (result == true && mounted) {
      setState(() {
        _hasReviewed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.item['name'] ?? 
        (widget.locale.languageCode == 'en' ? 'Unknown Product' : 'Produk Tidak Diketahui');
    final quantity = widget.item['quantity'] ?? 1;
    final price = double.tryParse(widget.item['price']?.toString() ?? '0') ?? 0.0;
    final total = double.tryParse(widget.item['total']?.toString() ?? '0') ?? 0.0;
    final imageUrl = widget.item['image']?['src'];
    
    // Check if order is completed
    final isCompleted = widget.orderStatus.toLowerCase() == 'completed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.shopping_bag, color: Colors.grey[400]);
                          },
                        ),
                      )
                    : Icon(Icons.shopping_bag, color: Colors.grey[400]),
              ),
              
              const SizedBox(width: 12),
              
              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.locale.languageCode == 'en' ? 'Qty' : 'Jml'}: $quantity × ${CurrencyFormatter.format(price)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Price
              Text(
                CurrencyFormatter.format(total),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),

          // Review Button (Only for completed orders)
          if (isCompleted) ...[
            const SizedBox(height: 12),
            if (_checkingReview)
              const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_hasReviewed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      widget.locale.languageCode == 'en' 
                          ? 'Reviewed'
                          : 'Sudah Diulas',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showReviewDialog,
                  icon: const Icon(Icons.rate_review, size: 16),
                  label: Text(
                    widget.locale.languageCode == 'en'
                        ? 'Write a Review'
                        : 'Tulis Ulasan',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Example usage in OrderDetailScreen's _buildItemsCard method:
/// 
/// Replace the existing _buildItemRow calls with:
/// 
/// Widget _buildItemsCard(Locale locale) {
///   final items = _orderData!['line_items'] as List? ?? [];
///   final orderStatus = _orderData!['status'] ?? 'pending';
///
///   return Card(
///     margin: const EdgeInsets.symmetric(horizontal: 16),
///     elevation: 0,
///     shape: RoundedRectangleBorder(
///       borderRadius: BorderRadius.circular(12),
///       side: BorderSide(color: Colors.grey[200]!, width: 1),
///     ),
///     child: Padding(
///       padding: const EdgeInsets.all(16),
///       child: Column(
///         crossAxisAlignment: CrossAxisAlignment.start,
///         children: [
///           Text(
///             locale.languageCode == 'en' ? 'Order Items' : 'Item Pesanan',
///             style: const TextStyle(
///               fontSize: 16,
///               fontWeight: FontWeight.bold,
///             ),
///           ),
///           const SizedBox(height: 16),
///           ChangeNotifierProvider(
///             create: (_) => ReviewProvider(),
///             child: Column(
///               children: items.map((item) => OrderItemWithReview(
///                 item: item,
///                 orderId: widget.orderId,
///                 orderStatus: orderStatus,
///                 locale: locale,
///               )).toList(),
///             ),
///           ),
///         ],
///       ),
///     ),
///   );
/// }