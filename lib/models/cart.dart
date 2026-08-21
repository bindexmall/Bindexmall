// ============================================================================
// MODEL: Cart
// ============================================================================
// Representasi keranjang belanja: daftar CartItem + kalkulasi total.
//
// Isi/tanggung jawab utama:
//  - Dipakai oleh CartProvider & CartRepository.
//  - total/totalQuantity dihitung dari items — PENTING: jangan hitung PPN di sini,
//  -   PPN sudah termasuk di harga produk (lihat catatan di checkout_screen.dart).
// ============================================================================

import 'cart_item.dart';

class Cart {
  final List<CartItem> items;

  Cart({this.items = const []});

  // Calculate total
  double get total {
    return items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  // Calculate total with tax (PPN 11%)
  double get totalWithTax {
    return total * 1.11;
  }

  // Calculate tax amount
  double get taxAmount {
    return total * 0.11;
  }

  // Get total quantity
  int get totalQuantity {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  // Check if cart is empty
  bool get isEmpty => items.isEmpty;

  // Check if cart is not empty
  bool get isNotEmpty => items.isNotEmpty;

  // Get item count
  int get itemCount => items.length;

  // Add item
  Cart addItem(CartItem item) {
    final existingIndex = items.indexWhere((i) => i.product.id == item.product.id);
    
    if (existingIndex >= 0) {
      // Update quantity
      final updatedItems = List<CartItem>.from(items);
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: updatedItems[existingIndex].quantity + item.quantity,
      );
      return Cart(items: updatedItems);
    } else {
      // Add new item
      return Cart(items: [...items, item]);
    }
  }

  // Remove item
  Cart removeItem(String productId) {
    return Cart(
      items: items.where((item) => item.product.id != productId).toList(),
    );
  }

  // Update quantity
  Cart updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      return removeItem(productId);
    }

    final updatedItems = items.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    return Cart(items: updatedItems);
  }

  // Clear cart
  Cart clear() {
    return Cart(items: []);
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  // From JSON
  factory Cart.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    final items = itemsList
        .map((item) => CartItem.fromJson(item as Map<String, dynamic>))
        .toList();
    
    return Cart(items: items);
  }

  // Copy with
  Cart copyWith({List<CartItem>? items}) {
    return Cart(items: items ?? this.items);
  }

  // Convert to WooCommerce line items
  List<Map<String, dynamic>> toWooCommerceLineItems() {
    return items.map((item) => item.toWooCommerceLineItem()).toList();
  }

  // Get Midtrans item details
  List<Map<String, dynamic>> toMidtransItemDetails() {
    final itemDetails = items.map((item) => {
      'id': item.product.id,
      'price': item.product.price.toInt(),
      'quantity': item.quantity,
      'name': item.product.name.length > 50 
          ? '${item.product.name.substring(0, 47)}...'
          : item.product.name,
    }).toList();

    // Add tax as separate item
    if (taxAmount > 0) {
      itemDetails.add({
        'id': 'TAX',
        'price': taxAmount.toInt(),
        'quantity': 1,
        'name': 'PPN 11%',
      });
    }

    return itemDetails;
  }
}