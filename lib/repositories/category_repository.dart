// ============================================================================
// REPOSITORY: CategoryRepository
// ============================================================================
// Layer akses data kategori produk, wrapper tipis di atas WooCommerceService.
//
// Isi/tanggung jawab utama:
//  - fetchCategoriesWithProducts() — filter kategori yang benar-benar punya produk (count > 0).
// ============================================================================

import '../models/category.dart';
import '../services/woocommerce_service.dart';

class CategoryRepository {
  final WooCommerceService _wooCommerceService = wooCommerceService;

  CategoryRepository();

  // Fetch all categories from WooCommerce
  Future<List<Category>> fetchCategories({
    int page = 1,
    int perPage = 100,
    int? parent,
  }) async {
    try {
      final response = await _wooCommerceService.getCategories(
        page: page,
        perPage: perPage,
        parent: parent,
      );

      return response
          .map((json) => Category.fromWooCommerce(json as Map<String, dynamic>))
          .toList();
    
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  // Fetch single category by ID
  Future<Category> fetchCategoryById(String id) async {
    try {
      final response = await _wooCommerceService.getCategoryById(int.parse(id));

      if (response is Map<String, dynamic>) {
        return Category.fromWooCommerce(response);
      }

      throw Exception('Invalid category data');
    } catch (e) {
      throw Exception('Failed to fetch category: $e');
    }
  }

  // Get top level categories (parent = 0)
  Future<List<Category>> fetchTopLevelCategories() async {
    return fetchCategories(parent: 0, perPage: 50);
  }

  // Get subcategories of a category
  Future<List<Category>> fetchSubcategories(String parentId) async {
    return fetchCategories(parent: int.parse(parentId), perPage: 50);
  }

  // Get categories with products only
  Future<List<Category>> fetchCategoriesWithProducts() async {
    try {
      final categories = await fetchCategories();
      return categories.where((cat) => cat.hasProducts).toList();
    } catch (e) {
      throw Exception('Failed to fetch categories with products: $e');
    }
  }
}

// Singleton instance
final categoryRepository = CategoryRepository();