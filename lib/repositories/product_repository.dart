// ============================================================================
// REPOSITORY: ProductRepository
// ============================================================================
// Layer akses data produk WooCommerce: fetch produk (dengan auto-pagination lewat
// _fetchAllPages), search, filter kategori/tag, produk unggulan/terlaris/diskon/terbaru.
//
// Isi/tanggung jawab utama:
//  - _fetchAllPages() dipakai internal supaya screen tidak perlu mikirin pagination manual —
//  -   hati-hati kalau katalog sudah sangat besar, ini fetch SEMUA halaman sekaligus.
//  - Semua request lewat WooCommerceService (yang pegang consumer key/secret).
// ============================================================================

import '../models/product.dart';
import '../services/woocommerce_service.dart';

class ProductRepository {
  final WooCommerceService _wooCommerceService = wooCommerceService;

  ProductRepository();

  // ✅ Internal helper: fetch semua halaman secara otomatis
  Future<List<Product>> _fetchAllPages({
    int perPage = 100,
    String? category,
    String? search,
    String? orderBy,
    String? order,
    bool? onSale,
    String? tag,
    int maxPages = 20, // safety cap: maksimal 2000 produk
  }) async {
    final List<Product> all = [];
    int page = 1;

    while (page <= maxPages) {
      final response = await _wooCommerceService.getProducts(
        page: page,
        perPage: perPage,
        category: category,
        search: search,
        orderBy: orderBy,
        order: order,
        onSale: onSale,
        tag: tag,
        status: 'publish', // ✅ hanya produk published
      );

      if (response.isEmpty) break;

      all.addAll(
        response.map(
            (json) => Product.fromWooCommerce(json as Map<String, dynamic>)),
      );

      // Jika hasil < perPage → ini halaman terakhir
      if (response.length < perPage) break;

      page++;
    }

    return all;
  }

  // Fetch products — sekarang otomatis paginated + hanya publish
  Future<List<Product>> fetchProducts({
    int page = 1,
    int perPage = 20,
    String? category,
    String? search,
    String? orderBy,
    String? order,
    bool? onSale,
  }) async {
    try {
      // Tanpa filter khusus → ambil SEMUA halaman
      if (category == null &&
          search == null &&
          orderBy == null &&
          onSale == null) {
        return await _fetchAllPages(perPage: 100);
      }

      // Dengan filter/sort → single-page tapi tetap publish-only
      final response = await _wooCommerceService.getProducts(
        page: page,
        perPage: perPage,
        category: category,
        search: search,
        orderBy: orderBy,
        order: order,
        onSale: onSale,
        status: 'publish', // ✅
      );

      return response
          .map((json) => Product.fromWooCommerce(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch products: $e');
    }
  }

  // Fetch single product by ID
  Future<Product> fetchProductById(String id) async {
    try {
      final response = await _wooCommerceService.getProductById(int.parse(id));
      if (response is Map<String, dynamic>) {
        return Product.fromWooCommerce(response);
      }
      throw Exception('Invalid product data');
    } catch (e) {
      throw Exception('Failed to fetch product: $e');
    }
  }

  // Fetch single product by SLUG
  Future<Product> fetchProductBySlug(String slug) async {
    try {
      final response = await _wooCommerceService.getProducts(
        page: 1,
        perPage: 1,
        slug: slug,
        status: 'publish', // ✅
      );

      if (response.isEmpty) {
        throw Exception('Product not found with slug: $slug');
      }

      return Product.fromWooCommerce(response.first as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to fetch product by slug: $e');
    }
  }

  // Search products — ✅ paginated
  Future<List<Product>> searchProducts(String query) async {
    try {
      return await _fetchAllPages(search: query, perPage: 100);
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }

  // Get products by category — ✅ paginated
  Future<List<Product>> fetchProductsByCategory(String categoryId) async {
    try {
      return await _fetchAllPages(category: categoryId, perPage: 100);
    } catch (e) {
      throw Exception('Failed to fetch products by category: $e');
    }
  }

  // Get featured products
  Future<List<Product>> fetchFeaturedProducts() async {
    try {
      final response = await _wooCommerceService.getProducts(
        page: 1,
        perPage: 10,
        status: 'publish', // ✅
      );
      return response
          .map((json) => Product.fromWooCommerce(json as Map<String, dynamic>))
          .where((p) => p.onSale || p.averageRating >= 4.0)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch featured products: $e');
    }
  }

  // Get best seller products
  Future<List<Product>> fetchBestSellerProducts({int perPage = 10}) async {
    try {
      final response = await _wooCommerceService.getProducts(
        page: 1,
        perPage: perPage,
        tag: 'best-seller',
        status: 'publish', // ✅
      );

      if (response.isEmpty) return fetchBestSellingProducts();

      return response
          .map((json) => Product.fromWooCommerce(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return fetchBestSellingProducts();
    }
  }

  // Get products on sale — ✅ paginated
  Future<List<Product>> fetchSaleProducts() async {
    try {
      return await _fetchAllPages(onSale: true, perPage: 100);
    } catch (e) {
      throw Exception('Failed to fetch sale products: $e');
    }
  }

  // Get products by WooCommerce tag slug — ✅ resolve slug → ID, paginated
  Future<List<Product>> fetchProductsByTag(String tagSlug,
      {int perPage = 100}) async {
    try {
      final tagId = await _wooCommerceService.getProductTagIdBySlug(tagSlug);
      if (tagId == null) return [];

      return await _fetchAllPages(
        tag: tagId.toString(),
        perPage: perPage,
      );
    } catch (e) {
      throw Exception('Failed to fetch products by tag: $e');
    }
  }

  // Get latest products
  Future<List<Product>> fetchLatestProducts() async {
    return fetchProducts(
      perPage: 20,
      orderBy: 'date',
      order: 'desc',
    );
  }

  // Get best selling products
  Future<List<Product>> fetchBestSellingProducts() async {
    return fetchProducts(
      perPage: 20,
      orderBy: 'popularity',
      order: 'desc',
    );
  }

  // Get top rated products
  Future<List<Product>> fetchTopRatedProducts() async {
    return fetchProducts(
      perPage: 20,
      orderBy: 'rating',
      order: 'desc',
    );
  }
}

final productRepository = ProductRepository();
