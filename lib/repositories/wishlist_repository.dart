// ============================================================================
// REPOSITORY: WishlistRepository
// ============================================================================
// Layer penyimpanan wishlist — LOKAL di device (SharedPreferences), sama pola dengan
// CartRepository (terpisah per userId + guest, ada mergeGuestWishlist saat login).
//
// Isi/tanggung jawab utama:
//  - Dipakai oleh ProductProvider — jangan panggil langsung dari UI.
// ============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class WishlistRepository {
  static const String _wishlistKeyPrefix = 'wishlist';
  static const String _guestWishlistKey = 'wishlist_guest';
  String? _currentUserId;

  // Set current user ID
  void setUserId(String? userId) {
    _currentUserId = userId;
  }

  // Get wishlist key for current user
  String _getWishlistKey() {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      return '${_wishlistKeyPrefix}_$_currentUserId';
    }
    return _guestWishlistKey;
  }

  // Get wishlist
  Future<List<Product>> getWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wishlistKey = _getWishlistKey();
      final wishlistJson = prefs.getString(wishlistKey);

      if (wishlistJson != null) {
        final List<dynamic> jsonList = jsonDecode(wishlistJson);
        return jsonList
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  // Save wishlist
  Future<void> saveWishlist(List<Product> wishlist) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wishlistKey = _getWishlistKey();
      final jsonList = wishlist.map((product) => product.toJson()).toList();
      final wishlistJson = jsonEncode(jsonList);
      await prefs.setString(wishlistKey, wishlistJson);
    } catch (e) {
      throw Exception('Failed to save wishlist: $e');
    }
  }

  // Merge guest wishlist with user wishlist (when user logs in)
  Future<List<Product>> mergeGuestWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get guest wishlist
      final guestWishlistJson = prefs.getString(_guestWishlistKey);
      if (guestWishlistJson == null) {
        return await getWishlist();
      }

      final List<dynamic> guestJsonList = jsonDecode(guestWishlistJson);
      final guestWishlist = guestJsonList
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      if (guestWishlist.isEmpty) {
        return await getWishlist();
      }

      // Get current user wishlist
      final userWishlist = await getWishlist();

      // Merge wishlists (avoid duplicates)
      final mergedWishlist = <Product>[...userWishlist];
      for (final guestProduct in guestWishlist) {
        if (!mergedWishlist.any((p) => p.id == guestProduct.id)) {
          mergedWishlist.add(guestProduct);
        }
      }

      // Save merged wishlist
      await saveWishlist(mergedWishlist);

      // Clear guest wishlist
      await prefs.remove(_guestWishlistKey);

      return mergedWishlist;
    } catch (e) {
      throw Exception('Failed to merge wishlists: $e');
    }
  }

  // Add product to wishlist
  Future<List<Product>> addProduct(Product product) async {
    try {
      final wishlist = await getWishlist();
      
      // Check if already exists
      if (wishlist.any((p) => p.id == product.id)) {
        return wishlist;
      }

      final updatedWishlist = [...wishlist, product];
      await saveWishlist(updatedWishlist);

      return updatedWishlist;
    } catch (e) {
      throw Exception('Failed to add to wishlist: $e');
    }
  }

  // Remove product from wishlist
  Future<List<Product>> removeProduct(String productId) async {
    try {
      final wishlist = await getWishlist();
      final updatedWishlist = wishlist.where((p) => p.id != productId).toList();
      await saveWishlist(updatedWishlist);

      return updatedWishlist;
    } catch (e) {
      throw Exception('Failed to remove from wishlist: $e');
    }
  }

  // Toggle product in wishlist
  Future<List<Product>> toggleProduct(Product product) async {
    final wishlist = await getWishlist();
    final exists = wishlist.any((p) => p.id == product.id);

    if (exists) {
      return await removeProduct(product.id);
    } else {
      return await addProduct(product);
    }
  }

  // Clear wishlist
  Future<void> clearWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wishlistKey = _getWishlistKey();
      await prefs.remove(wishlistKey);
    } catch (e) {
      throw Exception('Failed to clear wishlist: $e');
    }
  }

  // Check if product is in wishlist
  Future<bool> isInWishlist(String productId) async {
    final wishlist = await getWishlist();
    return wishlist.any((product) => product.id == productId);
  }

  // Get wishlist count
  Future<int> getCount() async {
    final wishlist = await getWishlist();
    return wishlist.length;
  }

  // Clear all wishlists (guest + all users) - for testing
  Future<void> clearAllWishlists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_wishlistKeyPrefix) || key == _guestWishlistKey) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      throw Exception('Failed to clear all wishlists: $e');
    }
  }
}

// Singleton instance
final wishlistRepository = WishlistRepository();