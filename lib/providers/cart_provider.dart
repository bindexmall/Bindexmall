// ============================================================================
// PROVIDER: CartProvider (ChangeNotifier)
// ============================================================================
// State management keranjang belanja. Wrapper reaktif di atas CartRepository
// (yang menyimpan cart di SharedPreferences, terpisah untuk guest vs user login).
//
// Isi/tanggung jawab utama:
//  - setUserId() — dipanggil dari main.dart tiap AuthProvider berubah; otomatis
//  -   merge cart guest ke akun user saat baru login.
//  - total/totalQuantity/items adalah getter turunan dari model Cart.
//  - PENTING (riwayat bug): jangan hitung ulang PPN 11% di sini — harga produk dari
//  -   WooCommerce sudah termasuk pajak. Lihat juga checkout_screen.dart & midtrans_service.dart.
// ============================================================================

import 'package:flutter/foundation.dart';
import '../models/cart.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../repositories/cart_repository.dart';

class CartProvider extends ChangeNotifier {
  final CartRepository _cartRepository;
  Cart _cart = Cart();
  bool _isLoading = false;
  String? _currentUserId;

  CartProvider(this._cartRepository) {
    _loadCart();
  }

  Cart get cart => _cart;
  int get totalQuantity => _cart.totalQuantity;
  double get total => _cart.total;
  List<CartItem> get items => _cart.items;
  bool get isEmpty => _cart.isEmpty;
  bool get isNotEmpty => _cart.isNotEmpty;
  bool get isLoading => _isLoading;

  // Set user ID and reload cart
  Future<void> setUserId(String? userId) async {
    if (_currentUserId == userId) return;
    
    _currentUserId = userId;
    _cartRepository.setUserId(userId);
    
    // If user just logged in, merge guest cart
    if (userId != null) {
      await _mergeGuestCart();
    } else {
      // User logged out, reload guest cart
      await _loadCart();
    }
  }

  // Load cart from repository
  Future<void> _loadCart() async {
    _isLoading = true;
    notifyListeners();

    try {
      _cart = await _cartRepository.getCurrentCart();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cart: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Merge guest cart with user cart (after login)
  Future<void> _mergeGuestCart() async {
    _isLoading = true;
    notifyListeners();

    try {
      _cart = await _cartRepository.mergeGuestCart();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error merging cart: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add product to cart
  Future<void> addProduct(Product product, {int quantity = 1}) async {
    try {
      _cart = await _cartRepository.addItem(product, quantity: quantity);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding product to cart: $e');
      rethrow;
    }
  }

  // Remove product from cart
  Future<void> removeProduct(String productId) async {
    try {
      _cart = await _cartRepository.removeItem(productId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing product from cart: $e');
      rethrow;
    }
  }

  // Update quantity
  Future<void> updateQuantity(String productId, int newQuantity) async {
    try {
      _cart = await _cartRepository.updateQuantity(productId, newQuantity);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating quantity: $e');
      rethrow;
    }
  }

  // Clear cart
  Future<void> clearCart() async {
    try {
      await _cartRepository.clearCart();
      _cart = Cart();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing cart: $e');
      rethrow;
    }
  }

  // Check if product is in cart
  bool isProductInCart(String productId) {
    return _cart.items.any((item) => item.product.id == productId);
  }

  // Get product quantity
  int getProductQuantity(String productId) {
    try {
      final item = _cart.items.firstWhere(
        (item) => item.product.id == productId,
      );
      return item.quantity;
    } catch (e) {
      return 0;
    }
  }

  // Reload cart
  Future<void> reload() async {
    await _loadCart();
  }

  // Sync cart on user change
  Future<void> syncWithUser(String? userId) async {
    await setUserId(userId);
  }
}