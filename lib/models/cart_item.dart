// ============================================================================
// MODEL: CartItem
// ============================================================================
// Satu baris item di keranjang: product + quantity (+ optional variasi produk).
//
// Isi/tanggung jawab utama:
//  - Dipakai di dalam Cart dan ditampilkan lewat CartItemCard widget.
// ============================================================================

import 'product.dart';

class CartItem {
  final String id;
  final Product product;
  final int quantity;
  final DateTime addedAt;

  CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.addedAt,
  });

  // Calculate total price
  double get totalPrice => product.price * quantity;
  
  // Alias for totalPrice
  double get subtotal => totalPrice;

  // Copy with method
  CartItem copyWith({
    String? id,
    Product? product,
    int? quantity,
    DateTime? addedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product.toJson(),
      'quantity': quantity,
      'added_at': addedAt.toIso8601String(),
    };
  }

  // From JSON
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] ?? '',
      product: Product.fromJson(json['product']),
      quantity: json['quantity'] ?? 1,
      addedAt: DateTime.parse(json['added_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  // For WooCommerce line item
  Map<String, dynamic> toWooCommerceLineItem() {
    return {
      'product_id': int.parse(product.id),
      'quantity': quantity,
    };
  }
}