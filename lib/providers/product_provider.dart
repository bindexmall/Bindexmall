// ============================================================================
// PROVIDER: ProductProvider (ChangeNotifier)
// ============================================================================
// State management katalog produk: load produk (per kategori/tag), search, filter
// harga, sorting, DAN state wishlist (gabung jadi satu provider).
//
// Isi/tanggung jawab utama:
//  - Bergantung pada ProductRepository (fetch dari WooCommerce) & WishlistRepository
//  -   (simpan lokal per-user).
//  - syncWithUser()/setUserId() dipanggil saat login/logout untuk merge wishlist guest.
//  - _applyFiltersAndSort() adalah tempat semua logic filter harga + search + sort digabung —
//  -   kalau menambah filter baru, mulai dari sini.
// ============================================================================

import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../repositories/wishlist_repository.dart';

class ProductProvider extends ChangeNotifier {
  final ProductRepository _productRepository;
  final WishlistRepository _wishlistRepository;

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<Product> _wishlist = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  double? _minPrice;
  double? _maxPrice;
  String _sortBy = 'name';
  String? _currentUserId;

  ProductProvider(this._productRepository, [WishlistRepository? wishlistRepository])
      : _wishlistRepository = wishlistRepository ?? WishlistRepository() {
    _loadWishlist();
  }

  List<Product> get products => _filteredProducts;
  List<Product> get wishlist => _wishlist;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  double? get minPrice => _minPrice;
  double? get maxPrice => _maxPrice;
  int get wishlistCount => _wishlist.length;

  // Set user ID and reload wishlist
  Future<void> setUserId(String? userId) async {
    if (_currentUserId == userId) return;
    
    _currentUserId = userId;
    _wishlistRepository.setUserId(userId);
    
    // If user just logged in, merge guest wishlist
    if (userId != null) {
      await _mergeGuestWishlist();
    } else {
      // User logged out, reload guest wishlist
      await _loadWishlist();
    }
  }

  // Load wishlist from repository
  Future<void> _loadWishlist() async {
    try {
      _wishlist = await _wishlistRepository.getWishlist();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading wishlist: $e');
    }
  }

  // Merge guest wishlist with user wishlist (after login)
  Future<void> _mergeGuestWishlist() async {
    try {
      _wishlist = await _wishlistRepository.mergeGuestWishlist();
      notifyListeners();
    } catch (e) {
      debugPrint('Error merging wishlist: $e');
    }
  }

  // Load products
  Future<void> loadProducts([String? category]) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (category != null && category.isNotEmpty) {
        _products = await _productRepository.fetchProductsByCategory(category);
      } else {
        _products = await _productRepository.fetchProducts(perPage: 100);
      }
      _applyFiltersAndSort();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }


  // Load products by WooCommerce tag slug (e.g. 'best-seller')
  Future<void> loadProductsByTag(String tag) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _productRepository.fetchProductsByTag(tag);
      _applyFiltersAndSort();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Search products
  void searchProducts(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
    notifyListeners();
  }

  // Set price range
  void setPriceRange(double? min, double? max) {
    _minPrice = min;
    _maxPrice = max;
    _applyFiltersAndSort();
    notifyListeners();
  }

  // Sort products
  void sortProducts(String sortBy) {
    _sortBy = sortBy;
    _applyFiltersAndSort();
    notifyListeners();
  }

  // Clear filters
  void clearFilters() {
    _searchQuery = '';
    _minPrice = null;
    _maxPrice = null;
    _sortBy = 'name';
    _applyFiltersAndSort();
    notifyListeners();
  }

  // Apply filters and sort
  void _applyFiltersAndSort() {
    _filteredProducts = List.from(_products);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      _filteredProducts = _filteredProducts.where((product) {
        final query = _searchQuery.toLowerCase();
        return product.name.toLowerCase().contains(query) ||
            (product.description?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply price range filter
    if (_minPrice != null) {
      _filteredProducts = _filteredProducts.where((product) {
        return product.price >= _minPrice!;
      }).toList();
    }
    if (_maxPrice != null) {
      _filteredProducts = _filteredProducts.where((product) {
        return product.price <= _maxPrice!;
      }).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'price_asc':
        _filteredProducts.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        _filteredProducts.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'date_desc':
        _filteredProducts.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
        break;
      case 'date_asc':
        _filteredProducts.sort((a, b) => a.dateCreated.compareTo(b.dateCreated));
        break;
      case 'name':
      default:
        _filteredProducts.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
  }

  // Toggle wishlist
  Future<void> toggleWishlist(Product product) async {
    try {
      _wishlist = await _wishlistRepository.toggleProduct(product);
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling wishlist: $e');
      rethrow;
    }
  }

  // Add to wishlist
  Future<void> addToWishlist(Product product) async {
    try {
      _wishlist = await _wishlistRepository.addProduct(product);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding to wishlist: $e');
      rethrow;
    }
  }

  // Remove from wishlist
  Future<void> removeFromWishlist(String productId) async {
    try {
      _wishlist = await _wishlistRepository.removeProduct(productId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing from wishlist: $e');
      rethrow;
    }
  }

  // Check if in wishlist
  bool isInWishlist(String productId) {
    return _wishlist.any((product) => product.id == productId);
  }

  // Clear wishlist
  Future<void> clearWishlist() async {
    try {
      await _wishlistRepository.clearWishlist();
      _wishlist = [];
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing wishlist: $e');
      rethrow;
    }
  }

  // Sync wishlist on user change
  Future<void> syncWithUser(String? userId) async {
    await setUserId(userId);
  }

  // Reload wishlist
  Future<void> reloadWishlist() async {
    await _loadWishlist();
  }
}