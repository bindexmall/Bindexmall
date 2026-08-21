// ============================================================================
// REPOSITORY: CartRepository
// ============================================================================
// Layer penyimpanan keranjang belanja — LOKAL di device (SharedPreferences),
// BUKAN disimpan di server WooCommerce. Ada cart terpisah untuk guest & tiap userId.
//
// Isi/tanggung jawab utama:
//  - mergeGuestCart() — dipanggil sesaat setelah login untuk gabung cart guest ke cart user.
//  - transferCart() — pindahkan isi cart dari satu userId ke userId lain (kasus khusus).
//  - Dipakai oleh CartProvider — jangan dipanggil langsung dari UI, selalu lewat provider.
// ============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartRepository {
  static const String _cartKeyPrefix = 'shopping_cart';
  static const String _guestCartKey = 'shopping_cart_guest';
  String? _currentUserId;

  // Set current user ID
  void setUserId(String? userId) {
    _currentUserId = userId;
  }

  // Get cart key for current user
  String _getCartKey() {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      return '${_cartKeyPrefix}_$_currentUserId';
    }
    return _guestCartKey;
  }

  // Get current cart
  Future<Cart> getCurrentCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartKey = _getCartKey();
      final cartJson = prefs.getString(cartKey);

      if (cartJson != null) {
        final Map<String, dynamic> json = jsonDecode(cartJson);
        return Cart.fromJson(json);
      }

      return Cart();
    } catch (e) {
      return Cart();
    }
  }

  // Save cart
  Future<void> saveCart(Cart cart) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartKey = _getCartKey();
      final cartJson = jsonEncode(cart.toJson());
      await prefs.setString(cartKey, cartJson);
    } catch (e) {
      throw Exception('Failed to save cart: $e');
    }
  }

  // Merge guest cart with user cart (when user logs in)
  Future<Cart> mergeGuestCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get guest cart
      final guestCartJson = prefs.getString(_guestCartKey);
      if (guestCartJson == null) {
        return await getCurrentCart();
      }

      final guestCart = Cart.fromJson(jsonDecode(guestCartJson));
      if (guestCart.isEmpty) {
        return await getCurrentCart();
      }

      // Get current user cart
      final userCart = await getCurrentCart();

      // Merge carts
      Cart mergedCart = userCart;
      for (final guestItem in guestCart.items) {
        mergedCart = mergedCart.addItem(guestItem);
      }

      // Save merged cart
      await saveCart(mergedCart);

      // Clear guest cart
      await prefs.remove(_guestCartKey);

      return mergedCart;
    } catch (e) {
      throw Exception('Failed to merge carts: $e');
    }
  }

  // Add item to cart
  Future<Cart> addItem(Product product, {int quantity = 1}) async {
    try {
      final currentCart = await getCurrentCart();
      
      final cartItem = CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        product: product,
        quantity: quantity,
        addedAt: DateTime.now(),
      );

      final updatedCart = currentCart.addItem(cartItem);
      await saveCart(updatedCart);

      return updatedCart;
    } catch (e) {
      throw Exception('Failed to add item: $e');
    }
  }

  // Remove item from cart
  Future<Cart> removeItem(String productId) async {
    try {
      final currentCart = await getCurrentCart();
      final updatedCart = currentCart.removeItem(productId);
      await saveCart(updatedCart);

      return updatedCart;
    } catch (e) {
      throw Exception('Failed to remove item: $e');
    }
  }

  // Update item quantity
  Future<Cart> updateQuantity(String productId, int quantity) async {
    try {
      final currentCart = await getCurrentCart();
      final updatedCart = currentCart.updateQuantity(productId, quantity);
      await saveCart(updatedCart);

      return updatedCart;
    } catch (e) {
      throw Exception('Failed to update quantity: $e');
    }
  }

  // Clear cart
  Future<void> clearCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartKey = _getCartKey();
      await prefs.remove(cartKey);
    } catch (e) {
      throw Exception('Failed to clear cart: $e');
    }
  }

  // Clear all carts (guest + all users) - for testing
  Future<void> clearAllCarts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cartKeyPrefix) || key == _guestCartKey) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      throw Exception('Failed to clear all carts: $e');
    }
  }

  // Get cart item count
  Future<int> getItemCount() async {
    final cart = await getCurrentCart();
    return cart.itemCount;
  }

  // Get cart total
  Future<double> getTotal() async {
    final cart = await getCurrentCart();
    return cart.total;
  }

  // Check if product is in cart
  Future<bool> isInCart(String productId) async {
    final cart = await getCurrentCart();
    return cart.items.any((item) => item.product.id == productId);
  }

  // Transfer cart from one user to another (when switching accounts)
  Future<void> transferCart(String fromUserId, String toUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fromKey = '${_cartKeyPrefix}_$fromUserId';
      final toKey = '${_cartKeyPrefix}_$toUserId';

      final fromCartJson = prefs.getString(fromKey);
      if (fromCartJson != null) {
        await prefs.setString(toKey, fromCartJson);
        await prefs.remove(fromKey);
      }
    } catch (e) {
      throw Exception('Failed to transfer cart: $e');
    }
  }
}

// Singleton instance
final cartRepository = CartRepository();