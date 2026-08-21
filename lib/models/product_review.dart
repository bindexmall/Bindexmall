// ============================================================================
// MODEL: ProductReview
// ============================================================================
// Review/rating produk dari WooCommerce (comments API dengan meta rating).
//
// Isi/tanggung jawab utama:
//  - Dipakai oleh ReviewProvider, ReviewRepository, product_review_section.dart.
// ============================================================================

class ProductReview {
  final int id;
  final int productId;
  final String productName;
  final String reviewerName;
  final String reviewerEmail;
  final String reviewerAvatarUrl;
  final int rating;
  final String review;
  final DateTime dateCreated;
  final bool verified;
  final List<String> images;
  final int helpfulCount;
  final Map<String, dynamic>? reviewer;

  ProductReview({
    required this.id,
    required this.productId,
    required this.productName,
    required this.reviewerName,
    required this.reviewerEmail,
    this.reviewerAvatarUrl = '',
    required this.rating,
    required this.review,
    required this.dateCreated,
    this.verified = false,
    this.images = const [],
    this.helpfulCount = 0,
    this.reviewer,
  });

  factory ProductReview.fromWooCommerce(Map<String, dynamic> json) {
    // Extract images from review content if any
    List<String> images = [];
    if (json['review_images'] != null) {
      images = List<String>.from(json['review_images']);
    }

    // Get reviewer avatar
    String avatarUrl = '';
    if (json['reviewer_avatar_urls'] != null) {
      final avatars = json['reviewer_avatar_urls'] as Map<String, dynamic>;
      avatarUrl = avatars['96'] ?? avatars['48'] ?? avatars['24'] ?? '';
    }

    // Check if purchase is verified
    bool verified = false;
    if (json['verified'] != null) {
      verified = json['verified'] as bool;
    }

    DateTime dateCreated;
    try {
      dateCreated = DateTime.parse(json['date_created'] ?? DateTime.now().toIso8601String());
    } catch (e) {
      dateCreated = DateTime.now();
    }

    return ProductReview(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      reviewerName: json['reviewer'] ?? 'Anonymous',
      reviewerEmail: json['reviewer_email'] ?? '',
      reviewerAvatarUrl: avatarUrl,
      rating: json['rating'] ?? 0,
      review: _stripHtmlTags(json['review'] ?? ''),
      dateCreated: dateCreated,
      verified: verified,
      images: images,
      helpfulCount: json['helpful_count'] ?? 0,
      reviewer: json['reviewer_data'] as Map<String, dynamic>?,
    );
  }

  static String _stripHtmlTags(String htmlString) {
    if (htmlString.isEmpty) return '';
    
    final RegExp exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    return htmlString
        .replaceAll(exp, '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'reviewer': reviewerName,
      'reviewer_email': reviewerEmail,
      'reviewer_avatar_url': reviewerAvatarUrl,
      'rating': rating,
      'review': review,
      'date_created': dateCreated.toIso8601String(),
      'verified': verified,
      'review_images': images,
      'helpful_count': helpfulCount,
    };
  }

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    return ProductReview(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? '',
      reviewerName: json['reviewer'] ?? 'Anonymous',
      reviewerEmail: json['reviewer_email'] ?? '',
      reviewerAvatarUrl: json['reviewer_avatar_url'] ?? '',
      rating: json['rating'] ?? 0,
      review: json['review'] ?? '',
      dateCreated: DateTime.parse(json['date_created'] ?? DateTime.now().toIso8601String()),
      verified: json['verified'] ?? false,
      images: List<String>.from(json['review_images'] ?? []),
      helpfulCount: json['helpful_count'] ?? 0,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(dateCreated);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  ProductReview copyWith({
    int? id,
    int? productId,
    String? productName,
    String? reviewerName,
    String? reviewerEmail,
    String? reviewerAvatarUrl,
    int? rating,
    String? review,
    DateTime? dateCreated,
    bool? verified,
    List<String>? images,
    int? helpfulCount,
  }) {
    return ProductReview(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewerEmail: reviewerEmail ?? this.reviewerEmail,
      reviewerAvatarUrl: reviewerAvatarUrl ?? this.reviewerAvatarUrl,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      dateCreated: dateCreated ?? this.dateCreated,
      verified: verified ?? this.verified,
      images: images ?? this.images,
      helpfulCount: helpfulCount ?? this.helpfulCount,
    );
  }
}