// ============================================================================
// REPOSITORY: ReviewRepository
// ============================================================================
// Layer akses data review produk (WooCommerce product reviews / comments API).
//
// Isi/tanggung jawab utama:
//  - hasUserReviewedProduct()/getUserReviewForProduct() dipakai untuk cegah user review
//  -   produk yang sama dua kali dan untuk mode edit review.
//  - getReviewStats() — hitung rata-rata rating & distribusi bintang untuk satu produk.
// ============================================================================

import '../models/product_review.dart';
import '../services/woocommerce_service.dart';

class ReviewRepository {
  final WooCommerceService _wooCommerceService = wooCommerceService;

  ReviewRepository();

  /// Fetch reviews for a specific product
  Future<List<ProductReview>> fetchProductReviews({
    required int productId,
    int page = 1,
    int perPage = 20,
    String? orderBy,
    String? order,
  }) async {
    try {
      
      final response = await _wooCommerceService.getProductReviews(
        productId: productId,
        page: page,
        perPage: perPage,
        orderBy: orderBy ?? 'date',
        order: order ?? 'desc',
      );

      final reviews = response
          .map((json) => ProductReview.fromWooCommerce(json as Map<String, dynamic>))
          .toList();

      return reviews;
    } catch (e) {
      throw Exception('Failed to fetch reviews: $e');
    }
  }

  /// Get reviews with rating filter
  Future<List<ProductReview>> fetchProductReviewsByRating({
    required int productId,
    required int rating,
  }) async {
    try {
      final allReviews = await fetchProductReviews(
        productId: productId,
        perPage: 100,
      );

      return allReviews.where((review) => review.rating == rating).toList();
    } catch (e) {
      throw Exception('Failed to fetch reviews by rating: $e');
    }
  }

  /// Get verified purchase reviews only
  Future<List<ProductReview>> fetchVerifiedReviews({
    required int productId,
  }) async {
    try {
      final allReviews = await fetchProductReviews(
        productId: productId,
        perPage: 100,
      );

      return allReviews.where((review) => review.verified).toList();
    } catch (e) {
      throw Exception('Failed to fetch verified reviews: $e');
    }
  }

  /// Get reviews with images only
  Future<List<ProductReview>> fetchReviewsWithImages({
    required int productId,
  }) async {
    try {
      final allReviews = await fetchProductReviews(
        productId: productId,
        perPage: 100,
      );

      return allReviews.where((review) => review.images.isNotEmpty).toList();
    } catch (e) {
      throw Exception('Failed to fetch reviews with images: $e');
    }
  }

  /// Create a new review
  Future<ProductReview> createReview({
    required int productId,
    required String review,
    required String reviewerName,
    required String reviewerEmail,
    required int rating,
  }) async {
    try {
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }

      if (review.trim().isEmpty) {
        throw Exception('Review text cannot be empty');
      }


      final response = await _wooCommerceService.createReview(
        productId: productId,
        review: review,
        reviewerName: reviewerName,
        reviewerEmail: reviewerEmail,
        rating: rating,
      );

      if (response is Map<String, dynamic>) {
        return ProductReview.fromWooCommerce(response);
      }

      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Failed to create review: $e');
    }
  }

  /// Update an existing review
  Future<ProductReview> updateReview({
    required int reviewId,
    String? review,
    int? rating,
  }) async {
    try {
      if (rating != null && (rating < 1 || rating > 5)) {
        throw Exception('Rating must be between 1 and 5');
      }

      final response = await _wooCommerceService.updateReview(
        reviewId: reviewId,
        review: review,
        rating: rating,
      );

      if (response is Map<String, dynamic>) {
        return ProductReview.fromWooCommerce(response);
      }

      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Failed to update review: $e');
    }
  }

  /// Delete a review
  Future<bool> deleteReview(int reviewId) async {
    try {
      await _wooCommerceService.deleteReview(reviewId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get a single review by ID
  Future<ProductReview> fetchReviewById(int reviewId) async {
    try {
      final response = await _wooCommerceService.getReview(reviewId);

      if (response is Map<String, dynamic>) {
        return ProductReview.fromWooCommerce(response);
      }

      throw Exception('Invalid review data');
    } catch (e) {
      throw Exception('Failed to fetch review: $e');
    }
  }

  /// Check if user has reviewed a product
  Future<bool> hasUserReviewedProduct({
    required int productId,
    required String userEmail,
  }) async {
    try {
      final reviews = await fetchProductReviews(
        productId: productId,
        perPage: 100,
      );

      return reviews.any((review) => 
        review.reviewerEmail.toLowerCase() == userEmail.toLowerCase()
      );
    } catch (e) {
      return false;
    }
  }

  /// Get user's review for a product
  Future<ProductReview?> getUserReviewForProduct({
    required int productId,
    required String userEmail,
  }) async {
    try {
      final reviews = await fetchProductReviews(
        productId: productId,
        perPage: 100,
      );

      return reviews.firstWhere(
        (review) => review.reviewerEmail.toLowerCase() == userEmail.toLowerCase(),
        orElse: () => throw Exception('No review found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Calculate review statistics
  Future<Map<String, dynamic>> getReviewStats({
    required int productId,
  }) async {
    try {
      final reviews = await fetchProductReviews(
        productId: productId,
        perPage: 100,
      );

      if (reviews.isEmpty) {
        return {
          'totalReviews': 0,
          'averageRating': 0.0,
          'ratingDistribution': {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
          'verifiedCount': 0,
          'withImagesCount': 0,
        };
      }

      final totalReviews = reviews.length;
      final averageRating = reviews.fold<double>(
        0, 
        (sum, review) => sum + review.rating
      ) / totalReviews;

      final ratingDistribution = <int, int>{
        5: reviews.where((r) => r.rating == 5).length,
        4: reviews.where((r) => r.rating == 4).length,
        3: reviews.where((r) => r.rating == 3).length,
        2: reviews.where((r) => r.rating == 2).length,
        1: reviews.where((r) => r.rating == 1).length,
      };

      final verifiedCount = reviews.where((r) => r.verified).length;
      final withImagesCount = reviews.where((r) => r.images.isNotEmpty).length;

      return {
        'totalReviews': totalReviews,
        'averageRating': averageRating,
        'ratingDistribution': ratingDistribution,
        'verifiedCount': verifiedCount,
        'withImagesCount': withImagesCount,
      };
    } catch (e) {
      throw Exception('Failed to calculate review stats: $e');
    }
  }
}

final reviewRepository = ReviewRepository();