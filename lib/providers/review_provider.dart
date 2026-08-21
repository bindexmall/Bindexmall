// ============================================================================
// PROVIDER: ReviewProvider (ChangeNotifier)
// ============================================================================
// State review/rating produk: load review per produk, filter (rating/verified/ada gambar),
// buat/update/hapus review, dan hitung ulang statistik rating (_recalculateStats).
//
// Isi/tanggung jawab utama:
//  - Dipakai oleh product_review_section.dart & write_review_dialog.dart.
// ============================================================================

import 'package:flutter/foundation.dart';
import '../models/product_review.dart';
import '../repositories/review_repository.dart';

class ReviewProvider extends ChangeNotifier {
  final ReviewRepository _reviewRepository;

  List<ProductReview> _reviews = [];
  Map<String, dynamic>? _reviewStats;
  bool _isLoading = false;
  String? _error;
  int? _selectedRatingFilter;
  bool _showVerifiedOnly = false;
  bool _showWithImagesOnly = false;

  ReviewProvider([ReviewRepository? reviewRepository])
      : _reviewRepository = reviewRepository ?? ReviewRepository();

  List<ProductReview> get reviews => _reviews;
  Map<String, dynamic>? get reviewStats => _reviewStats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get selectedRatingFilter => _selectedRatingFilter;
  bool get showVerifiedOnly => _showVerifiedOnly;
  bool get showWithImagesOnly => _showWithImagesOnly;

  List<ProductReview> get filteredReviews {
    var filtered = List<ProductReview>.from(_reviews);

    // Filter by rating
    if (_selectedRatingFilter != null) {
      filtered = filtered
          .where((review) => review.rating == _selectedRatingFilter)
          .toList();
    }

    // Filter verified only
    if (_showVerifiedOnly) {
      filtered = filtered.where((review) => review.verified).toList();
    }

    // Filter with images only
    if (_showWithImagesOnly) {
      filtered = filtered.where((review) => review.images.isNotEmpty).toList();
    }

    return filtered;
  }

  /// Load reviews for a product
  Future<void> loadProductReviews({
    required int productId,
    bool forceRefresh = false,
  }) async {
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('📋 Loading reviews for product: $productId');

      // Load reviews
      _reviews = await _reviewRepository.fetchProductReviews(
        productId: productId,
        perPage: 100,
      );

      // Load stats
      _reviewStats = await _reviewRepository.getReviewStats(
        productId: productId,
      );

      debugPrint('✅ Loaded ${_reviews.length} reviews');
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading reviews: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set rating filter
  void setRatingFilter(int? rating) {
    _selectedRatingFilter = rating;
    notifyListeners();
  }

  /// Toggle verified filter
  void toggleVerifiedFilter() {
    _showVerifiedOnly = !_showVerifiedOnly;
    notifyListeners();
  }

  /// Toggle images filter
  void toggleImagesFilter() {
    _showWithImagesOnly = !_showWithImagesOnly;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _selectedRatingFilter = null;
    _showVerifiedOnly = false;
    _showWithImagesOnly = false;
    notifyListeners();
  }

  /// Create a review
  Future<ProductReview> createReview({
    required int productId,
    required String review,
    required String reviewerName,
    required String reviewerEmail,
    required int rating,
  }) async {
    try {
      debugPrint('📝 Creating review...');

      final newReview = await _reviewRepository.createReview(
        productId: productId,
        review: review,
        reviewerName: reviewerName,
        reviewerEmail: reviewerEmail,
        rating: rating,
      );

      // Add to local list
      _reviews.insert(0, newReview);

      // Recalculate stats
      await _recalculateStats(productId);

      debugPrint('✅ Review created successfully');
      notifyListeners();

      return newReview;
    } catch (e) {
      debugPrint('❌ Error creating review: $e');
      rethrow;
    }
  }

  /// Update a review
  Future<ProductReview> updateReview({
    required int reviewId,
    String? review,
    int? rating,
  }) async {
    try {
      final updatedReview = await _reviewRepository.updateReview(
        reviewId: reviewId,
        review: review,
        rating: rating,
      );

      // Update local list
      final index = _reviews.indexWhere((r) => r.id == reviewId);
      if (index != -1) {
        _reviews[index] = updatedReview;
        notifyListeners();
      }

      return updatedReview;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a review
  Future<bool> deleteReview(int reviewId) async {
    try {
      final success = await _reviewRepository.deleteReview(reviewId);

      if (success) {
        _reviews.removeWhere((review) => review.id == reviewId);
        notifyListeners();
      }

      return success;
    } catch (e) {
      return false;
    }
  }

  /// Check if user has reviewed product
  Future<bool> hasUserReviewedProduct({
    required int productId,
    required String userEmail,
  }) async {
    try {
      return await _reviewRepository.hasUserReviewedProduct(
        productId: productId,
        userEmail: userEmail,
      );
    } catch (e) {
      return false;
    }
  }

  /// Get user's review for product
  Future<ProductReview?> getUserReviewForProduct({
    required int productId,
    required String userEmail,
  }) async {
    try {
      return await _reviewRepository.getUserReviewForProduct(
        productId: productId,
        userEmail: userEmail,
      );
    } catch (e) {
      return null;
    }
  }

  /// Recalculate stats after changes
  Future<void> _recalculateStats(int productId) async {
    try {
      _reviewStats = await _reviewRepository.getReviewStats(
        productId: productId,
      );
    } catch (e) {
      debugPrint('Error recalculating stats: $e');
    }
  }

  /// Clear reviews
  void clearReviews() {
    _reviews = [];
    _reviewStats = null;
    _selectedRatingFilter = null;
    _showVerifiedOnly = false;
    _showWithImagesOnly = false;
    _error = null;
    notifyListeners();
  }
}