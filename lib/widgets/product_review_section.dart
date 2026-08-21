// ============================================================================
// WIDGET: ProductReviewSection + AllReviewsScreen
// ============================================================================
// Section review di ProductDetailScreen (ringkasan rating + beberapa review teratas)
// dan AllReviewsScreen (halaman terpisah untuk lihat semua review dengan filter).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/product_review.dart';
import '../providers/review_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';

class ProductReviewSection extends StatefulWidget {
  final int productId;
  final String productName;
  final double averageRating;
  final int ratingCount;

  const ProductReviewSection({
    super.key,
    required this.productId,
    required this.productName,
    required this.averageRating,
    required this.ratingCount,
  });

  @override
  State<ProductReviewSection> createState() => _ProductReviewSectionState();
}

class _ProductReviewSectionState extends State<ProductReviewSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReviews();
    });
  }

  Future<void> _loadReviews() async {
    final reviewProvider = context.read<ReviewProvider>();
    await reviewProvider.loadProductReviews(productId: widget.productId);
  }

  String _t(String key, Locale locale) {
    return AppLocalizations(locale).translate(key);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ReviewProvider, LanguageProvider>(
      builder: (context, reviewProvider, languageProvider, child) {
        final locale = languageProvider.currentLocale;
        final stats = reviewProvider.reviewStats;

        if (reviewProvider.isLoading && reviewProvider.reviews.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (reviewProvider.reviews.isEmpty) {
          return _buildEmptyState(locale);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            
            // Reviews Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    locale.languageCode == 'en' 
                        ? 'Reviews (${reviewProvider.reviews.length})'
                        : 'Ulasan (${reviewProvider.reviews.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _showAllReviews(context, locale);
                    },
                    child: Text(locale.languageCode == 'en' ? 'See All' : 'Lihat Semua'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Rating Summary
            if (stats != null) _buildRatingSummary(stats, locale),

            const SizedBox(height: 16),

            // Filter Chips
            _buildFilterChips(reviewProvider, locale),

            const SizedBox(height: 16),

            // Review List (Preview - show 3 reviews)
            ...reviewProvider.filteredReviews
                .take(3)
                .map((review) => _buildReviewCard(review, locale)),

            if (reviewProvider.filteredReviews.length > 3) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {
                    _showAllReviews(context, locale);
                  },
                  child: Text(
                    locale.languageCode == 'en'
                        ? 'View ${reviewProvider.filteredReviews.length - 3} More Reviews'
                        : 'Lihat ${reviewProvider.filteredReviews.length - 3} Ulasan Lainnya',
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(Locale locale) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            locale.languageCode == 'en'
                ? 'No reviews yet'
                : 'Belum ada ulasan',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            locale.languageCode == 'en'
                ? 'Be the first to review this product'
                : 'Jadilah yang pertama mengulas produk ini',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSummary(Map<String, dynamic> stats, Locale locale) {
    final totalReviews = stats['totalReviews'] ?? 0;
    final averageRating = stats['averageRating']?.toDouble() ?? 0.0;
    final ratingDistribution = stats['ratingDistribution'] as Map<int, int>? ?? {};

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Average Rating
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    if (index < averageRating.floor()) {
                      return const Icon(Icons.star, color: Colors.amber, size: 20);
                    } else if (index < averageRating) {
                      return const Icon(Icons.star_half, color: Colors.amber, size: 20);
                    } else {
                      return Icon(Icons.star_border, color: Colors.grey[400], size: 20);
                    }
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalReviews ${locale.languageCode == 'en' ? 'reviews' : 'ulasan'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 24),

          // Rating Distribution
          Expanded(
            flex: 3,
            child: Column(
              children: List.generate(5, (index) {
                final rating = 5 - index;
                final count = ratingDistribution[rating] ?? 0;
                final percentage = totalReviews > 0 ? (count / totalReviews) : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '$rating',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ReviewProvider provider, Locale locale) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Rating Filters
          ...List.generate(5, (index) {
            final rating = 5 - index;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$rating'),
                    const SizedBox(width: 4),
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                  ],
                ),
                selected: provider.selectedRatingFilter == rating,
                onSelected: (selected) {
                  provider.setRatingFilter(selected ? rating : null);
                },
              ),
            );
          }),

          // Verified Filter
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, size: 14),
                const SizedBox(width: 4),
                Text(locale.languageCode == 'en' ? 'Verified' : 'Terverifikasi'),
              ],
            ),
            selected: provider.showVerifiedOnly,
            onSelected: (_) => provider.toggleVerifiedFilter(),
          ),

          const SizedBox(width: 8),

          // With Images Filter
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image, size: 14),
                const SizedBox(width: 4),
                Text(locale.languageCode == 'en' ? 'With Photos' : 'Dengan Foto'),
              ],
            ),
            selected: provider.showWithImagesOnly,
            onSelected: (_) => provider.toggleImagesFilter(),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(ProductReview review, Locale locale) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reviewer Info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  child: Text(
                    review.reviewerName[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            review.reviewerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (review.verified) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.verified,
                              size: 16,
                              color: Colors.green[700],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        review.timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Rating Stars
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review.rating ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    );
                  }),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Review Text
            Text(
              review.review,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),

            // Review Images
            if (review.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.images.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          review.images[index],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Helpful Count
            if (review.helpfulCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.thumb_up, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${review.helpfulCount} ${locale.languageCode == 'en' ? 'found this helpful' : 'merasa terbantu'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAllReviews(BuildContext context, Locale locale) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllReviewsScreen(
          productId: widget.productId,
          productName: widget.productName,
        ),
      ),
    );
  }
}

class AllReviewsScreen extends StatelessWidget {
  final int productId;
  final String productName;

  const AllReviewsScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<ReviewProvider, LanguageProvider>(
      builder: (context, reviewProvider, languageProvider, child) {
        final locale = languageProvider.currentLocale;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              locale.languageCode == 'en' 
                  ? 'Product Reviews'
                  : 'Ulasan Produk',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  // Show filter dialog
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => reviewProvider.loadProductReviews(
              productId: productId,
              forceRefresh: true,
            ),
            child: ListView.builder(
              itemCount: reviewProvider.filteredReviews.length,
              itemBuilder: (context, index) {
                final review = reviewProvider.filteredReviews[index];
                return _buildReviewCard(context, review, locale);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewCard(BuildContext context, ProductReview review, Locale locale) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  child: Text(
                    review.reviewerName[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            review.reviewerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (review.verified) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.verified,
                              size: 16,
                              color: Colors.green[700],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        review.timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < review.rating ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              review.review,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            if (review.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.images.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          review.images[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}